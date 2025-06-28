program test_forttf_conversion_validation
    !! Validate data conversion between Fortran and STB C wrapper
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use forttf_stb_raster  
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! C structures for conversion testing
    type, bind(c) :: fortran_point_t
        real(c_double) :: x, y
    end type

    type, bind(c) :: fortran_edge_t
        real(c_double) :: x0, y0, x1, y1
        integer(c_int) :: invert
    end type

    ! C interface for conversion-aware wrapper
    interface
        subroutine stb_test_build_edges_from_fortran_points_c(pts, wcount, windings, &
                    scale_x, scale_y, shift_x, shift_y, invert_flag, &
                    edges_out, num_edges_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: pts, wcount
            integer(c_int), value :: windings, invert_flag
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            type(c_ptr), intent(out) :: edges_out
            integer(c_int), intent(out) :: num_edges_out
        end subroutine
        
        subroutine stb_debug_flatten_curves(vertices, num_verts, flatness, &
                    points_out, contour_lengths_out, num_contours_out, total_points_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: vertices
            integer(c_int), value :: num_verts
            real(c_float), value :: flatness
            type(c_ptr), intent(out) :: points_out, contour_lengths_out
            integer(c_int), intent(out) :: num_contours_out, total_points_out
        end subroutine
        
        subroutine stb_free_points(ptr) bind(c)
            import :: c_ptr
            type(c_ptr), value :: ptr
        end subroutine
        
        subroutine stb_free_fortran_edges(ptr) bind(c)
            import :: c_ptr
            type(c_ptr), value :: ptr
        end subroutine
    end interface

    ! Variables
    type(stb_fontinfo_pure_t) :: font_info
    type(ttf_vertex_t), allocatable, target :: vertices(:)
    type(stb_point_t), allocatable :: fortran_points(:)
    type(fortran_point_t), allocatable, target :: conversion_points(:)
    integer, allocatable, target :: contour_lengths(:)
    type(stb_edge_t), allocatable :: fortran_edges(:)
    integer :: num_vertices, glyph_index, num_fortran_edges, num_contours
    real(wp), parameter :: scale_x = 1.0_wp, scale_y = 1.0_wp
    real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
    logical, parameter :: invert = .false.
    
    type(c_ptr) :: stb_edges_ptr
    integer(c_int) :: num_stb_edges
    real(c_float), parameter :: flatness = 1.0
    type(fortran_edge_t), pointer :: converted_edges(:)
    integer :: i

    ! Initialize font
    if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/TTF/DejaVuSans.ttf")) then
        write(*,*) "❌ Failed to initialize font"
        stop 1
    end if

    write(*,*)
    write(*,*) "=== 🔧 Data Conversion Validation ==="
    write(*,*)

    ! Test character '$' 
    glyph_index = 36
    write(*,'(A,I0)') "Testing character index: ", glyph_index

    ! Get shape vertices
    num_vertices = stb_get_glyph_shape_pure(font_info, glyph_index, vertices)
    
    if (num_vertices == 0) then
        write(*,*) "❌ No vertices found for glyph"
        call stb_cleanup_font_pure(font_info)
        stop 1
    end if
    
    write(*,'(A,I0,A)') "✓ Found ", num_vertices, " vertices"

    ! Build edges using pure Fortran
    fortran_points = stb_flatten_curves(vertices, num_vertices, real(flatness, wp), &
                                       contour_lengths, num_contours)
    fortran_edges = stb_build_edges(fortran_points, contour_lengths, num_contours, &
                                   scale_x, scale_y, shift_x, shift_y, invert)
    num_fortran_edges = size(fortran_edges)

    write(*,'(A,I0,A)') "✓ Fortran built and sorted ", num_fortran_edges, " edges"

    ! Convert Fortran points to C-compatible format for testing
    allocate(conversion_points(size(fortran_points)))
    do i = 1, size(fortran_points)
        conversion_points(i)%x = real(fortran_points(i)%x, c_double)
        conversion_points(i)%y = real(fortran_points(i)%y, c_double)
    end do

    ! Build edges using conversion-aware C wrapper
    call stb_test_build_edges_from_fortran_points_c( &
        c_loc(conversion_points(1)), c_loc(contour_lengths(1)), &
        int(num_contours, c_int), &
        real(scale_x, c_float), real(scale_y, c_float), &
        real(shift_x, c_float), real(shift_y, c_float), &
        merge(1, 0, invert), &
        stb_edges_ptr, num_stb_edges)

    write(*,'(A,I0,A)') "✓ C conversion wrapper built ", num_stb_edges, " edges"

    ! Compare edge counts
    write(*,*)
    write(*,*) "=== 📊 Edge Count Comparison ==="
    write(*,'(A,I0)') "Fortran edges:        ", num_fortran_edges
    write(*,'(A,I0)') "C conversion edges:   ", num_stb_edges
    
    if (num_stb_edges == num_fortran_edges) then
        write(*,*) "✅ Edge counts match!"
    else
        write(*,'(A,I0)') "❌ Edge count difference: ", abs(num_stb_edges - num_fortran_edges)
        goto 999
    end if

    ! Convert C pointer to Fortran array for detailed comparison
    if (num_stb_edges > 0) then
        call c_f_pointer(stb_edges_ptr, converted_edges, [num_stb_edges])
        
        write(*,*)
        write(*,*) "=== 🔍 Edge Coordinate Comparison ==="
        
        do i = 1, min(num_stb_edges, num_fortran_edges)
            write(*,'(A,I0)') "Edge ", i
            write(*,'(A,F10.3,A,F10.3,A,F10.3,A,F10.3,A,I0)') &
                "  Fortran: (", fortran_edges(i)%x0, ",", fortran_edges(i)%y0, &
                ") -> (", fortran_edges(i)%x1, ",", fortran_edges(i)%y1, &
                ") invert=", fortran_edges(i)%invert
            write(*,'(A,F10.3,A,F10.3,A,F10.3,A,F10.3,A,I0)') &
                "  C Conv:  (", converted_edges(i)%x0, ",", converted_edges(i)%y0, &
                ") -> (", converted_edges(i)%x1, ",", converted_edges(i)%y1, &
                ") invert=", converted_edges(i)%invert
            
            ! Check for exact match
            if (abs(converted_edges(i)%x0 - real(fortran_edges(i)%x0, c_double)) < 1e-10 .and. &
                abs(converted_edges(i)%y0 - real(fortran_edges(i)%y0, c_double)) < 1e-10 .and. &
                abs(converted_edges(i)%x1 - real(fortran_edges(i)%x1, c_double)) < 1e-10 .and. &
                abs(converted_edges(i)%y1 - real(fortran_edges(i)%y1, c_double)) < 1e-10 .and. &
                converted_edges(i)%invert == fortran_edges(i)%invert) then
                write(*,*) "    ✅ Perfect match!"
            else
                write(*,*) "    ❌ Coordinate mismatch!"
                write(*,'(A,E12.5,A,E12.5,A,E12.5,A,E12.5)') &
                    "    Diff: dx0=", abs(converted_edges(i)%x0 - real(fortran_edges(i)%x0, c_double)), &
                    " dy0=", abs(converted_edges(i)%y0 - real(fortran_edges(i)%y0, c_double)), &
                    " dx1=", abs(converted_edges(i)%x1 - real(fortran_edges(i)%x1, c_double)), &
                    " dy1=", abs(converted_edges(i)%y1 - real(fortran_edges(i)%y1, c_double))
            end if
            write(*,*)
        end do
    end if

999 continue
    ! Clean up
    if (c_associated(stb_edges_ptr)) call stb_free_fortran_edges(stb_edges_ptr)
    call stb_free_shape_pure(vertices)
    if (allocated(fortran_points)) deallocate(fortran_points)
    if (allocated(conversion_points)) deallocate(conversion_points)
    if (allocated(contour_lengths)) deallocate(contour_lengths)
    if (allocated(fortran_edges)) deallocate(fortran_edges)
    call stb_cleanup_font_pure(font_info)

    write(*,*)
    write(*,*) "=== ✅ Conversion Validation Complete ==="

end program test_forttf_conversion_validation
