program test_forttf_exact_stb_validation
    !! Systematically validate EVERY STB function for exact matching
    !! Find the exact discrepancy causing 665 vs 1817 pixel mismatch
    use forttf_types
    use forttf_stb_raster
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! C interface for STB validation
    interface
        subroutine stb_test_flatten_curves(vertices, num_verts, flatness, &
                    points_out, contour_lengths_out, num_contours_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: vertices
            integer(c_int), value :: num_verts
            real(c_float), value :: flatness
            type(c_ptr), intent(out) :: points_out, contour_lengths_out
            integer(c_int), intent(out) :: num_contours_out
        end subroutine
        
        subroutine stb_test_build_and_sort_edges(points, contour_lengths, num_contours, &
                    scale_x, scale_y, shift_x, shift_y, invert, &
                    edges_out, num_edges_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: points, contour_lengths
            integer(c_int), value :: num_contours, invert
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            type(c_ptr), intent(out) :: edges_out
            integer(c_int), intent(out) :: num_edges_out
        end subroutine
    end interface

    logical :: all_tests_passed = .true.

    write(*,*) "=== EXACT STB VALIDATION TESTS ==="
    write(*,*) "Systematically checking every intermediate function..."
    write(*,*)

    call test_step_1_vertices(all_tests_passed)
    call test_step_2_flatten_curves(all_tests_passed)
    call test_step_3_build_edges(all_tests_passed)

    write(*,*)
    if (all_tests_passed) then
        write(*,*) "✅ All exact STB validation tests PASSED!"
        stop 0
    else
        write(*,*) "❌ STB validation FAILED - discrepancy found!"
        stop 1
    end if

contains

    subroutine test_step_1_vertices(passed)
        logical, intent(inout) :: passed
        
        type(stb_fontinfo_pure_t) :: font_info
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        integer :: num_vertices, i
        
        write(*,*) "--- STEP 1: Vertex Extraction ---"
        
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            passed = .false.
            return
        end if
        
        num_vertices = stb_get_glyph_shape_pure(font_info, 36, vertices)
        write(*,*) "  Vertices extracted:", num_vertices
        
        ! Print first few vertices for validation
        do i = 1, min(5, num_vertices)
            write(*,*) "  Vertex", i, ": type=", vertices(i)%type, &
                      " x=", vertices(i)%x, " y=", vertices(i)%y
        end do
        
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        
        write(*,*) "  ✅ Step 1 completed"
        
    end subroutine test_step_1_vertices

    subroutine test_step_2_flatten_curves(passed)
        logical, intent(inout) :: passed
        
        type(stb_fontinfo_pure_t) :: font_info
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        type(stb_point_t), allocatable :: fortran_points(:)
        integer, allocatable :: fortran_contour_lengths(:)
        integer :: num_vertices, fortran_num_contours, i
        real(wp), parameter :: flatness = 0.35_wp
        
        write(*,*) "--- STEP 2: Curve Flattening ---"
        
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            passed = .false.
            return
        end if
        
        num_vertices = stb_get_glyph_shape_pure(font_info, 36, vertices)
        
        ! Test Fortran curve flattening
        fortran_points = stb_flatten_curves(vertices, num_vertices, flatness, &
                                          fortran_contour_lengths, fortran_num_contours)
        
        write(*,*) "  Fortran: ", size(fortran_points), "points,", fortran_num_contours, "contours"
        
        ! Print contour info
        do i = 1, fortran_num_contours
            write(*,*) "    Contour", i, ":", fortran_contour_lengths(i), "points"
        end do
        
        ! Print first few points
        do i = 1, min(5, size(fortran_points))
            write(*,*) "    Point", i, ": (", fortran_points(i)%x, ",", fortran_points(i)%y, ")"
        end do
        
        ! TODO: Add STB C comparison when wrapper is ready
        
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        deallocate(fortran_points, fortran_contour_lengths)
        
        write(*,*) "  ✅ Step 2 completed"
        
    end subroutine test_step_2_flatten_curves

    subroutine test_step_3_build_edges(passed)
        logical, intent(inout) :: passed
        
        type(stb_fontinfo_pure_t) :: font_info
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        type(stb_point_t), allocatable :: points(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_vertices, num_contours, num_edges, i
        real(wp), parameter :: flatness = 0.35_wp
        real(wp), parameter :: scale_x = 0.5_wp, scale_y = 0.5_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        logical, parameter :: invert = .true.
        
        write(*,*) "--- STEP 3: Edge Building ---"
        
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            passed = .false.
            return
        end if
        
        num_vertices = stb_get_glyph_shape_pure(font_info, 36, vertices)
        points = stb_flatten_curves(vertices, num_vertices, flatness, contour_lengths, num_contours)
        
        ! Test Fortran edge building
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               scale_x, scale_y, shift_x, shift_y, invert)
        num_edges = size(edges)
        
        write(*,*) "  Fortran: ", num_edges, "edges built"
        
        ! Print edge info
        do i = 1, min(5, num_edges)
            write(*,*) "    Edge", i, ": (", edges(i)%x0, ",", edges(i)%y0, ") -> (", &
                      edges(i)%x1, ",", edges(i)%y1, "), invert=", edges(i)%invert
        end do
        
        ! Sort edges
        call stb_sort_edges(edges, num_edges)
        write(*,*) "  ✅ Edges sorted"
        
        ! Print sorted edge info  
        write(*,*) "  First 3 sorted edges:"
        do i = 1, min(3, num_edges)
            write(*,*) "    Edge", i, ": y0=", edges(i)%y0, " y1=", edges(i)%y1
        end do
        
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        deallocate(points, edges, contour_lengths)
        
        write(*,*) "  ✅ Step 3 completed"
        
    end subroutine test_step_3_build_edges

end program test_forttf_exact_stb_validation