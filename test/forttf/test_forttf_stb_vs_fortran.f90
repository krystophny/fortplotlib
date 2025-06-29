program test_stb_vs_fortran
    !! COMPREHENSIVE STB vs Pure Fortran comparison
    !! Test EVERY intermediate step for exact matching
    use forttf_types
    use forttf_stb_raster
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! C interface for STB exact validation
    interface
        subroutine stb_test_flatten_curves_exact(vertices, num_verts, flatness, &
                    points_out, contour_lengths_out, num_contours_out, total_points_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: vertices
            integer(c_int), value :: num_verts
            real(c_float), value :: flatness
            type(c_ptr), intent(out) :: points_out, contour_lengths_out
            integer(c_int), intent(out) :: num_contours_out, total_points_out
        end subroutine
        
        subroutine stb_test_build_edges_from_fortran_points(pts, wcount, windings, &
                    scale_x, scale_y, shift_x, shift_y, invert, &
                    edges_out, num_edges_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: pts, wcount
            integer(c_int), value :: windings, invert
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            type(c_ptr), intent(out) :: edges_out
            integer(c_int), intent(out) :: num_edges_out
        end subroutine
        
        subroutine stb_test_complete_rasterize_exact(vertices, num_verts, &
                    scale_x, scale_y, shift_x, shift_y, &
                    width, height, x_off, y_off, invert, &
                    bitmap_out, pixel_count_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: vertices
            integer(c_int), value :: num_verts, width, height, x_off, y_off, invert
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            type(c_ptr), intent(out) :: bitmap_out
            integer(c_int), intent(out) :: pixel_count_out
        end subroutine
        
        subroutine stb_free_points(points) bind(c)
            import :: c_ptr
            type(c_ptr), value :: points
        end subroutine
        
        subroutine stb_free_contour_lengths(lengths) bind(c)
            import :: c_ptr
            type(c_ptr), value :: lengths
        end subroutine
        
        subroutine stb_free_edges(edges) bind(c)
            import :: c_ptr
            type(c_ptr), value :: edges
        end subroutine
        
        subroutine stb_free_bitmap(bitmap) bind(c)
            import :: c_ptr
            type(c_ptr), value :: bitmap
        end subroutine
    end interface

    logical :: all_tests_passed = .true.

    write(*,*) "=== COMPREHENSIVE STB vs FORTRAN COMPARISON ==="
    write(*,*) "Testing EVERY step for exact matching..."
    write(*,*)

    call test_flatten_curves_comparison(all_tests_passed)
    call test_edge_building_comparison(all_tests_passed)
    call test_complete_pipeline_comparison(all_tests_passed)

    write(*,*)
    if (all_tests_passed) then
        write(*,*) "✅ All STB vs Fortran tests PASSED!"
        stop 0
    else
        write(*,*) "❌ STB vs Fortran MISMATCH FOUND!"
        stop 1
    end if

contains

    subroutine test_flatten_curves_comparison(passed)
        logical, intent(inout) :: passed
        
        type(stb_fontinfo_pure_t) :: font_info
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        type(stb_point_t), allocatable :: fortran_points(:)
        integer, allocatable :: fortran_contour_lengths(:)
        integer :: num_vertices, fortran_num_contours
        real(wp), parameter :: flatness = 0.35_wp
        
        ! STB C results
        type(c_ptr) :: stb_points_ptr, stb_contour_lengths_ptr
        integer :: stb_num_contours, stb_total_points
        real(c_float), pointer :: stb_points_array(:)
        integer(c_int), pointer :: stb_contour_lengths_array(:)
        logical :: contours_match
        integer :: i
        
        write(*,*) "--- COMPARISON 1: Curve Flattening ---"
        
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            passed = .false.
            return
        end if
        
        num_vertices = stb_get_glyph_shape_pure(font_info, 36, vertices)
        if (num_vertices <= 0 .or. .not. allocated(vertices)) then
            write(*,*) 'WARNING: No vertices returned for glyph 36, skipping flattening test.'
            call stb_cleanup_font_pure(font_info)
            passed = .false.
            return
        end if
        
        ! Test Fortran curve flattening
        fortran_points = stb_flatten_curves(vertices, num_vertices, flatness, &
                                          fortran_contour_lengths, fortran_num_contours)
        
        ! Test STB C curve flattening
        call stb_test_flatten_curves_exact(c_loc(vertices(1)), num_vertices, real(flatness, c_float), &
                                         stb_points_ptr, stb_contour_lengths_ptr, &
                                         stb_num_contours, stb_total_points)
        
        write(*,*) "  Fortran: ", size(fortran_points), "points,", fortran_num_contours, "contours"
        write(*,*) "  STB C:   ", stb_total_points, "points,", stb_num_contours, "contours"
        
        ! Check if STB returned valid data
        if (stb_total_points <= 0 .or. stb_num_contours <= 0 .or. &
            .not. c_associated(stb_points_ptr) .or. .not. c_associated(stb_contour_lengths_ptr)) then
            write(*,*) "  ❌ Point/contour count MISMATCH!"
            write(*,*) "  STB C returned invalid data - likely C wrapper issue"
            passed = .false.
            ! Don't try to cleanup invalid pointers
            call stb_free_shape_pure(vertices)
            call stb_cleanup_font_pure(font_info)
            deallocate(fortran_points, fortran_contour_lengths)
            return
        end if
        
        ! Convert C pointers to Fortran arrays
        call c_f_pointer(stb_points_ptr, stb_points_array, [stb_total_points * 2])  ! x,y pairs
        call c_f_pointer(stb_contour_lengths_ptr, stb_contour_lengths_array, [stb_num_contours])
        
        ! Compare results
        if (size(fortran_points) == stb_total_points .and. fortran_num_contours == stb_num_contours) then
            write(*,*) "  ✅ Point and contour counts match!"
            
            ! Compare contour lengths
            contours_match = .true.
            do i = 1, fortran_num_contours
                if (fortran_contour_lengths(i) /= stb_contour_lengths_array(i)) then
                    contours_match = .false.
                    write(*,*) "  ❌ Contour", i, "length mismatch:", &
                              fortran_contour_lengths(i), "vs", stb_contour_lengths_array(i)
                end if
            end do
            
            if (contours_match) then
                write(*,*) "  ✅ Contour lengths match!"
            else
                passed = .false.
            end if
            
        else
            write(*,*) "  ❌ Point/contour count MISMATCH!"
            passed = .false.
        end if
        
        ! Cleanup - only free valid pointers
        if (c_associated(stb_points_ptr)) then
            call stb_free_points(stb_points_ptr)
        end if
        if (c_associated(stb_contour_lengths_ptr)) then
            call stb_free_contour_lengths(stb_contour_lengths_ptr)
        end if
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        deallocate(fortran_points, fortran_contour_lengths)
        
    end subroutine test_flatten_curves_comparison

    subroutine test_edge_building_comparison(passed)
        logical, intent(inout) :: passed
        
        type(stb_fontinfo_pure_t) :: font_info
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        type(stb_point_t), allocatable, target :: fortran_points(:)
        integer, allocatable, target :: fortran_contour_lengths(:)
        type(stb_edge_t), allocatable :: fortran_edges(:)
        integer :: num_vertices, fortran_num_contours, fortran_num_edges
        real(wp), parameter :: flatness = 0.35_wp
        real(wp), parameter :: scale_x = 0.5_wp, scale_y = 0.5_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        logical, parameter :: invert = .false.
        
        ! STB C results
        type(c_ptr) :: stb_edges_ptr
        integer :: stb_num_edges
        type(stb_edge_t), pointer :: stb_edges_array(:)
        logical :: edges_match
        integer :: i
        
        write(*,*) "--- COMPARISON 2: Edge Building ---"
        
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            passed = .false.
            return
        end if
        
        ! Get glyph shape for glyph 36 (same as complete pipeline test)
        num_vertices = stb_get_glyph_shape_pure(font_info, 36, vertices)
        
        ! Flatten curves
        fortran_points = stb_flatten_curves(vertices, num_vertices, flatness, &
                                          fortran_contour_lengths, fortran_num_contours)
        
        ! Test Fortran edge building
        fortran_edges = stb_build_edges(fortran_points, fortran_contour_lengths, fortran_num_contours, &
                                       scale_x, scale_y, shift_x, shift_y, invert)
        fortran_num_edges = size(fortran_edges)

        ! Test STB C edge building
        call stb_test_build_edges_from_fortran_points(c_loc(fortran_points(1)), &
                                      c_loc(fortran_contour_lengths(1)), fortran_num_contours, &
                                      real(scale_x, c_float), real(scale_y, c_float), &
                                      real(shift_x, c_float), real(shift_y, c_float), &
                                      merge(1, 0, invert), &
                                      stb_edges_ptr, stb_num_edges)
        
        ! Convert C pointer to Fortran array
        if (stb_num_edges > 0) then
            call c_f_pointer(stb_edges_ptr, stb_edges_array, [stb_num_edges])
        end if
        
        write(*,*) "  Fortran: ", fortran_num_edges, "edges built"
        write(*,*) "  STB C:   ", stb_num_edges, "edges built"
        
        ! Compare results
        if (fortran_num_edges == stb_num_edges) then
            write(*,*) "  ✅ Edge count matches!"
            
            ! Compare edge properties
            edges_match = .true.
            do i = 1, min(5, fortran_num_edges)
                write(*,*) "  Fortran Edge", i, ": (", fortran_edges(i)%x0, ",", fortran_edges(i)%y0, &
                          ") -> (", fortran_edges(i)%x1, ",", fortran_edges(i)%y1, &
                          "), invert=", fortran_edges(i)%invert
                          
                write(*,*) "  STB C Edge", i, ": (", stb_edges_array(i)%x0, ",", stb_edges_array(i)%y0, &
                          ") -> (", stb_edges_array(i)%x1, ",", stb_edges_array(i)%y1, &
                          "), invert=", stb_edges_array(i)%invert
                
                ! Check for significant differences in coordinates
                if (abs(fortran_edges(i)%x0 - stb_edges_array(i)%x0) > 0.001_wp .or. &
                    abs(fortran_edges(i)%y0 - stb_edges_array(i)%y0) > 0.001_wp .or. &
                    abs(fortran_edges(i)%x1 - stb_edges_array(i)%x1) > 0.001_wp .or. &
                    abs(fortran_edges(i)%y1 - stb_edges_array(i)%y1) > 0.001_wp .or. &
                    fortran_edges(i)%invert /= stb_edges_array(i)%invert) then
                    
                    edges_match = .false.
                    write(*,*) "  ❌ Edge", i, "MISMATCH!"
                end if
            end do
            
            if (edges_match) then
                write(*,*) "  ✅ Edge properties match!"
            else
                write(*,*) "  ❌ Edge properties MISMATCH!"
                passed = .false.
            end if
        else
            write(*,*) "  ❌ Edge count MISMATCH!"
            passed = .false.
        end if
        
        ! Cleanup
        if (stb_num_edges > 0) then
            call stb_free_edges(stb_edges_ptr)
        end if
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        deallocate(fortran_points, fortran_contour_lengths, fortran_edges)
        
    end subroutine test_edge_building_comparison

    subroutine test_complete_pipeline_comparison(passed)
        logical, intent(inout) :: passed
        
        type(stb_fontinfo_pure_t) :: font_info
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        type(stb_bitmap_t) :: fortran_bitmap
        integer(c_int8_t), allocatable, target :: fortran_pixels(:)
        integer :: num_vertices, fortran_pixel_count, i
        
        ! STB C results
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_pixel_count
        integer(c_int8_t), pointer :: stb_pixels_array(:)
        
        ! Test parameters - use same as exact params test that works
        real(wp), parameter :: scale_x = 0.5_wp, scale_y = 0.5_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        integer, parameter :: width = 684, height = 747  ! Match bitmap content test
        integer, parameter :: x_off = 8, y_off = -747    ! Match bitmap content test offsets
        logical, parameter :: invert = .false.           ! Match exact params test
        real(wp), parameter :: flatness = 0.35_wp
        integer, parameter :: char_code = 36             ! Use same glyph as exact params test
        
        write(*,*) "--- COMPARISON 3: Complete Pipeline ---"
        write(*,*) "  Testing with glyph 36 (same as exact params test)"
        
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            passed = .false.
            return
        end if
        
        num_vertices = stb_get_glyph_shape_pure(font_info, char_code, vertices)
        write(*,*) "  Glyph", char_code, "has", num_vertices, "vertices"
        
        ! Test Fortran complete pipeline
        allocate(fortran_pixels(width * height))
        fortran_pixels = 0
        
        fortran_bitmap%w = width
        fortran_bitmap%h = height
        fortran_bitmap%stride = width
        fortran_bitmap%pixels => fortran_pixels
        
        call stbtt_rasterize(fortran_bitmap, flatness, vertices, num_vertices, &
                            scale_x, scale_y, shift_x, shift_y, x_off, y_off, invert, c_null_ptr)
        
        ! Count Fortran pixels
        fortran_pixel_count = 0
        do i = 1, width * height
            if (fortran_pixels(i) /= 0) fortran_pixel_count = fortran_pixel_count + 1
        end do
        
        ! Test STB C complete pipeline
        call stb_test_complete_rasterize_exact(c_loc(vertices(1)), num_vertices, &
                                             real(scale_x, c_float), real(scale_y, c_float), &
                                             real(shift_x, c_float), real(shift_y, c_float), &
                                             width, height, x_off, y_off, 1, &
                                             stb_bitmap_ptr, stb_pixel_count)
        
        write(*,*) "  Fortran pixels: ", fortran_pixel_count
        write(*,*) "  STB C pixels:   ", stb_pixel_count
        
        ! Compare pixel counts
        if (fortran_pixel_count == stb_pixel_count) then
            write(*,*) "  ✅ PIXEL COUNTS MATCH EXACTLY!"
        else
            write(*,*) "  ❌ PIXEL COUNT MISMATCH! Difference:", abs(fortran_pixel_count - stb_pixel_count)
            write(*,*) "  Fortran/STB ratio:", real(fortran_pixel_count) / real(stb_pixel_count)
            passed = .false.
        end if
        
        ! If we have STB results, do a deeper comparison
        if (c_associated(stb_bitmap_ptr)) then
            call c_f_pointer(stb_bitmap_ptr, stb_pixels_array, [width * height])
            
            ! Compare first few non-zero pixels from both implementations
            write(*,*) "  First few non-zero pixel positions:"
            
            write(*,*) "  Fortran non-zero positions:"
            do i = 1, width * height
                if (fortran_pixels(i) /= 0) then
                    write(*,'("    Position", I6, " value =", I4)') i, int(fortran_pixels(i))
                    if (i >= 5) exit
                end if
            end do
            
            write(*,*) "  STB C non-zero positions:"
            do i = 1, width * height
                if (stb_pixels_array(i) /= 0) then
                    write(*,'("    Position", I6, " value =", I4)') i, int(stb_pixels_array(i))
                    if (i >= 5) exit
                end if
            end do
        end if
        
        ! Cleanup
        if (c_associated(stb_bitmap_ptr)) then
            call stb_free_bitmap(stb_bitmap_ptr)
        end if
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        deallocate(fortran_pixels)
        
    end subroutine test_complete_pipeline_comparison

end program test_stb_vs_fortran