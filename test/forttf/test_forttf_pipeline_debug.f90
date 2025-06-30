program test_forttf_pipeline_debug
    !! Debug the STB rasterization pipeline step by step
    !! Test each intermediate step to find the pixel count issue
    use forttf_types
    use forttf_stb_raster
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    logical :: all_tests_passed = .true.

    write(*,*) "=== STB Pipeline Debug Tests ==="
    write(*,*) "Testing each step of STB rasterization pipeline..."
    write(*,*) 

    call test_pipeline_steps_letter_a(all_tests_passed)

    write(*,*)
    if (all_tests_passed) then
        write(*,*) "✅ All STB pipeline debug tests completed!"
        stop 0
    else
        write(*,*) "❌ Some STB pipeline debug tests revealed issues!"
        stop 1
    end if

contains

    subroutine test_pipeline_steps_letter_a(passed)
        logical, intent(inout) :: passed
        
        ! Test parameters (match bitmap content test)
        integer, parameter :: glyph_index = 36  ! Letter 'A' in DejaVuSans
        real(wp), parameter :: scale_x = 0.5_wp, scale_y = 0.5_wp  ! Match bitmap content test
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        integer, parameter :: x_off = 0, y_off = 0
        real(wp), parameter :: flatness = 0.35_wp
        
        ! Test data
        type(stb_fontinfo_pure_t) :: font_info
        type(stb_bitmap_t) :: bitmap
        integer(c_int8_t), allocatable, target :: pixels(:)
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        type(stb_point_t), allocatable :: points(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_vertices, num_contours, num_edges
        integer :: width, height, non_zero_count, i
        
        write(*,*) "--- Debug: Pipeline Steps for Letter 'A' ---"
        
        ! Initialize font
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/TTF/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            passed = .false.
            return
        end if
        
        ! Step 1: Get glyph vertices
        num_vertices = stb_get_glyph_shape_pure(font_info, glyph_index, vertices)
        if (num_vertices <= 0) then
            write(*,*) "❌ Failed to get glyph vertices"
            passed = .false.
            return
        end if
        
        write(*,*) "  ✅ Step 1: Got", num_vertices, "vertices"
        
        ! Step 2: Flatten curves to points
        points = stb_flatten_curves(vertices, num_vertices, flatness, contour_lengths, num_contours)
        write(*,*) "  ✅ Step 2: Flattened to", size(points), "points in", num_contours, "contours"
        
        if (size(points) == 0) then
            write(*,*) "  ❌ No points generated from curve flattening"
            passed = .false.
            return
        end if
        
        ! Print some contour info
        do i = 1, min(3, num_contours)
            write(*,*) "    Contour", i, "has", contour_lengths(i), "points"
        end do
        
        ! Step 3: Build edges
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               scale_x, scale_y, shift_x, shift_y, .false.)
        num_edges = size(edges)
        write(*,*) "  ✅ Step 3: Built", num_edges, "edges"
        
        if (num_edges == 0) then
            write(*,*) "  ❌ No edges generated from points"
            passed = .false.
            return
        end if
        
        ! Print some edge info
        do i = 1, min(3, num_edges)
            write(*,*) "    Edge", i, ": (", edges(i)%x0, ",", edges(i)%y0, ") -> (", &
                      edges(i)%x1, ",", edges(i)%y1, "), invert=", edges(i)%invert
        end do
        
        ! Step 4: Sort edges
        call stb_sort_edges(edges, num_edges)
        write(*,*) "  ✅ Step 4: Sorted edges"
        
        ! Step 5: Create bitmap and rasterize
        width = 100
        height = 100
        allocate(pixels(width * height))
        pixels = 0
        
        bitmap%w = width
        bitmap%h = height
        bitmap%stride = width
        bitmap%pixels => pixels
        
        call stb_rasterize_sorted_edges(bitmap, edges, num_edges, 1, x_off, y_off, c_null_ptr)
        write(*,*) "  ✅ Step 5: Rasterized sorted edges"
        
        ! Count non-zero pixels
        non_zero_count = 0
        do i = 1, width * height
            if (pixels(i) /= 0) non_zero_count = non_zero_count + 1
        end do
        
        write(*,*) "  📊 Final result: ", non_zero_count, "non-zero pixels out of", width * height
        
        ! Expected for STB with these parameters should be similar to what we saw before
        if (non_zero_count > 0) then
            write(*,*) "  ✅ Rasterization produced pixels"
        else
            write(*,*) "  ❌ No pixels generated - rasterization failed"
            passed = .false.
        end if
        
        ! Test with actual font metrics
        write(*,*) "  --- Testing with larger canvas ---"
        deallocate(pixels)
        width = 684  ! Use actual STB dimensions
        height = 747
        allocate(pixels(width * height))
        pixels = 0
        
        bitmap%w = width
        bitmap%h = height
        bitmap%stride = width
        bitmap%pixels => pixels
        
        call stb_rasterize_sorted_edges(bitmap, edges, num_edges, 1, x_off, y_off, c_null_ptr)
        
        non_zero_count = 0
        do i = 1, width * height
            if (pixels(i) /= 0) non_zero_count = non_zero_count + 1
        end do
        
        write(*,*) "  📊 Large canvas result: ", non_zero_count, "non-zero pixels"
        write(*,*) "  📊 STB reference should be around 1817 pixels"
        
        ! Cleanup
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        deallocate(pixels, points, edges, contour_lengths)
        
    end subroutine test_pipeline_steps_letter_a

end program test_forttf_pipeline_debug