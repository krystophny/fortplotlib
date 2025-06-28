program test_forttf_edge_debug
    !! Debug edge building differences between Fortran and STB
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use forttf_stb_raster  
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! C interface for STB debug wrapper with STB points
    interface
        subroutine stb_test_build_edges_exact(pts, wcount, windings, &
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
        
        subroutine stb_free_edges(ptr) bind(c)
            import :: c_ptr
            type(c_ptr), value :: ptr
        end subroutine
    end interface

    ! Variables
    type(stb_fontinfo_pure_t) :: font_info
    type(ttf_vertex_t), allocatable, target :: vertices(:)
    type(stb_point_t), allocatable :: points(:)
    integer, allocatable :: contour_lengths(:)
    type(stb_edge_t), allocatable :: fortran_edges(:)
    integer :: num_vertices, glyph_index, num_fortran_edges, num_contours
    real(wp), parameter :: scale_x = 1.0_wp, scale_y = 1.0_wp
    real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
    logical, parameter :: invert = .false.
    
    type(c_ptr) :: stb_edges_ptr, stb_points_ptr, stb_contour_lengths_ptr
    integer(c_int) :: num_stb_edges, stb_num_contours, total_points
    real(c_float), parameter :: flatness = 1.0

    ! Initialize font
    if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/TTF/DejaVuSans.ttf")) then
        write(*,*) "❌ Failed to initialize font"
        stop 1
    end if

    write(*,*)
    write(*,*) "=== 🔧 Edge Building Debug Analysis ==="
    write(*,*)

    ! Test character '$' (the one showing edge count mismatch)
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

    ! Flatten curves using STB for comparison
    call stb_debug_flatten_curves(c_loc(vertices(1)), int(num_vertices, c_int), flatness, &
                                stb_points_ptr, stb_contour_lengths_ptr, stb_num_contours, total_points)
    
    write(*,'(A,I0,A,I0,A)') "✓ STB flattened to ", total_points, " points in ", stb_num_contours, " contours"

    ! Build edges using STB with STB points (no conversion needed)
    call stb_test_build_edges_exact(stb_points_ptr, stb_contour_lengths_ptr, &
                                   int(stb_num_contours, c_int), &
                                   real(scale_x, c_float), real(scale_y, c_float), &
                                   real(shift_x, c_float), real(shift_y, c_float), &
                                   merge(1, 0, invert), &
                                   stb_edges_ptr, num_stb_edges)

    write(*,'(A,I0,A)') "✓ STB built ", num_stb_edges, " edges"

    ! Build edges using Fortran
    ! First, flatten curves to get points
    points = stb_flatten_curves(vertices, num_vertices, real(flatness, wp), &
                               contour_lengths, num_contours)
    
    ! Build edges from points
    fortran_edges = stb_build_edges(points, contour_lengths, num_contours, &
                                   scale_x, scale_y, shift_x, shift_y, invert)
    num_fortran_edges = size(fortran_edges)

    write(*,'(A,I0,A)') "✓ Fortran built ", num_fortran_edges, " edges"

    ! Compare counts
    write(*,*)
    write(*,*) "=== 📊 Edge Count Comparison ==="
    write(*,'(A,I0)') "STB edges:     ", num_stb_edges
    write(*,'(A,I0)') "Fortran edges: ", num_fortran_edges
    
    if (num_stb_edges == num_fortran_edges) then
        write(*,*) "✅ Edge counts match!"
    else
        write(*,'(A,I0)') "❌ Edge count difference: ", abs(num_stb_edges - num_fortran_edges)
    end if

    ! Clean up
    call stb_free_points(stb_points_ptr)
    call stb_free_points(stb_contour_lengths_ptr)
    call stb_free_edges(stb_edges_ptr)
    call stb_free_shape_pure(vertices)
    if (allocated(points)) deallocate(points)
    if (allocated(contour_lengths)) deallocate(contour_lengths)
    if (allocated(fortran_edges)) deallocate(fortran_edges)
    call stb_cleanup_font_pure(font_info)

    write(*,*)
    write(*,*) "=== ✅ Debug Analysis Complete ==="

end program test_forttf_edge_debug
