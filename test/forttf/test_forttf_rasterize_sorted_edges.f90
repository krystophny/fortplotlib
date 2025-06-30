program test_forttf_rasterize_sorted_edges
    !! Test STB-compatible rasterize_sorted_edges function using TDD methodology
    !! Validates Fortran implementation against STB C reference
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! C interface declarations for STB test wrapper
    interface
        subroutine stb_test_rasterize_sorted_edges(pixels, width, height, stride, &
                    edge_x0, edge_y0, edge_x1, edge_y1, edge_invert, &
                    num_edges, vsubsample, off_x, off_y) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: pixels
            integer(c_int), value :: width, height, stride, num_edges, vsubsample, off_x, off_y
            real(c_float), intent(in) :: edge_x0(*), edge_y0(*), edge_x1(*), edge_y1(*)
            integer(c_int), intent(in) :: edge_invert(*)
        end subroutine
        
        subroutine stb_test_rasterize_single_vertical_edge(pixels, width, height, &
                    x, y0, y1, direction) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: pixels
            integer(c_int), value :: width, height, direction
            real(c_float), value :: x, y0, y1
        end subroutine
    end interface

    logical :: all_tests_passed = .true.

    write(*,*) "=== STB Rasterize Sorted Edges TDD Tests ==="
    write(*,*) "Testing stb_rasterize_sorted_edges() against STB C reference..."
    write(*,*)

    call test_rasterize_empty_edges(all_tests_passed)
    call test_rasterize_single_vertical_edge_vs_stb(all_tests_passed)
    call test_rasterize_basic_functionality(all_tests_passed)

    write(*,*)
    if (all_tests_passed) then
        write(*,*) "✅ All STB rasterize_sorted_edges tests PASSED!"
        stop 0
    else
        write(*,*) "❌ Some STB rasterize_sorted_edges tests FAILED!"
        stop 1
    end if

contains

    subroutine test_rasterize_empty_edges(passed)
        logical, intent(inout) :: passed
        
        ! Test parameters
        integer, parameter :: width = 5, height = 5
        type(stb_bitmap_t) :: bitmap
        type(stb_edge_t), allocatable :: edges(:)
        integer(c_int8_t), allocatable, target :: pixels(:)
        
        write(*,*) "--- Test 1: Empty Edge Array ---"
        
        ! Create bitmap
        allocate(pixels(width * height))
        pixels = -1  ! Initialize to non-zero to verify they stay unchanged
        
        bitmap%w = width
        bitmap%h = height
        bitmap%stride = width
        bitmap%pixels => pixels
        
        ! Create empty edge array
        allocate(edges(0))
        
        ! Test rasterization with no edges
        call stb_rasterize_sorted_edges(bitmap, edges, 0, 1, 0, 0, c_null_ptr)
        
        ! Verify all pixels are now zero (background)
        if (all(pixels == 0)) then
            write(*,*) "  ✅ Empty edges test PASSED - all pixels cleared to 0"
        else
            write(*,*) "  ❌ Empty edges test FAILED - pixels not properly cleared"
            write(*,*) "    First few pixels:", pixels(1:min(10, size(pixels)))
            passed = .false.
        end if
        
        deallocate(pixels, edges)
        
    end subroutine test_rasterize_empty_edges

    subroutine test_rasterize_single_vertical_edge_vs_stb(passed)
        logical, intent(inout) :: passed
        
        ! Test parameters
        integer, parameter :: width = 8, height = 8
        real(wp), parameter :: tolerance = 1e-3_wp
        
        ! Test data
        type(stb_bitmap_t) :: fortran_bitmap
        integer(c_int8_t), allocatable, target :: fortran_pixels(:)
        integer(c_int8_t), allocatable, target :: stb_pixels(:)
        type(stb_edge_t), allocatable :: edges(:)
        
        ! Edge parameters
        real(wp), parameter :: edge_x = 3.5_wp, edge_y0 = 2.0_wp, edge_y1 = 6.0_wp
        
        write(*,*) "--- Test 2: Single Vertical Edge vs STB C ---"
        
        ! Create Fortran bitmap
        allocate(fortran_pixels(width * height))
        fortran_pixels = 0
        
        fortran_bitmap%w = width
        fortran_bitmap%h = height
        fortran_bitmap%stride = width
        fortran_bitmap%pixels => fortran_pixels
        
        ! Create edge for Fortran test
        allocate(edges(1))
        edges(1) = stb_edge_t(x0=edge_x, y0=edge_y0, x1=edge_x, y1=edge_y1, invert=0)
        
        ! Test Fortran implementation
        call stb_rasterize_sorted_edges(fortran_bitmap, edges, 1, 1, 0, 0, c_null_ptr)
        
        ! Create STB C test
        allocate(stb_pixels(width * height))
        stb_pixels = 0
        
        call stb_test_rasterize_single_vertical_edge(c_loc(stb_pixels(1)), width, height, &
                    real(edge_x, c_float), real(edge_y0, c_float), real(edge_y1, c_float), 0)
        
        ! Compare results
        call compare_bitmaps("Single Vertical Edge", fortran_pixels, stb_pixels, &
                           width, height, tolerance, passed)
        
        deallocate(fortran_pixels, stb_pixels, edges)
        
    end subroutine test_rasterize_single_vertical_edge_vs_stb

    subroutine test_rasterize_basic_functionality(passed)
        logical, intent(inout) :: passed
        
        ! Test parameters
        integer, parameter :: width = 10, height = 10
        type(stb_bitmap_t) :: bitmap
        type(stb_edge_t), allocatable :: edges(:)
        integer(c_int8_t), allocatable, target :: pixels(:)
        integer :: i, non_zero_count
        logical :: has_expected_pattern
        
        write(*,*) "--- Test 3: Basic Functionality Check ---"
        
        ! Create bitmap
        allocate(pixels(width * height))
        pixels = 0
        
        bitmap%w = width
        bitmap%h = height
        bitmap%stride = width
        bitmap%pixels => pixels
        
        ! Create simple triangle edges: (2,2), (8,2), (5,8)
        allocate(edges(3))
        edges(1) = stb_edge_t(x0=2.0_wp, y0=2.0_wp, x1=8.0_wp, y1=2.0_wp, invert=0)
        edges(2) = stb_edge_t(x0=8.0_wp, y0=2.0_wp, x1=5.0_wp, y1=8.0_wp, invert=0)
        edges(3) = stb_edge_t(x0=5.0_wp, y0=8.0_wp, x1=2.0_wp, y1=2.0_wp, invert=0)
        
        ! Test rasterization
        call stb_rasterize_sorted_edges(bitmap, edges, 3, 1, 0, 0, c_null_ptr)
        
        ! Count non-zero pixels
        non_zero_count = 0
        do i = 1, size(pixels)
            if (pixels(i) /= 0) non_zero_count = non_zero_count + 1
        end do
        
        ! For a triangle, expect reasonable number of pixels (not empty, not full)
        has_expected_pattern = (non_zero_count > 5 .and. non_zero_count < width * height * 0.8)
        
        if (has_expected_pattern) then
            write(*,*) "  ✅ Basic functionality test PASSED"
            write(*,*) "    Non-zero pixels:", non_zero_count, "out of", size(pixels)
        else
            write(*,*) "  ❌ Basic functionality test FAILED"
            write(*,*) "    Non-zero pixels:", non_zero_count, "out of", size(pixels)
            write(*,*) "    Expected: > 5 and < ", int(width * height * 0.8)
            passed = .false.
        end if
        
        deallocate(pixels, edges)
        
    end subroutine test_rasterize_basic_functionality

    subroutine compare_bitmaps(test_name, fortran_pixels, stb_pixels, width, height, tolerance, passed)
        character(len=*), intent(in) :: test_name
        integer(c_int8_t), intent(in) :: fortran_pixels(:), stb_pixels(:)
        integer, intent(in) :: width, height
        real(wp), intent(in) :: tolerance
        logical, intent(inout) :: passed
        
        logical :: pixels_match
        integer :: i, diff_count, max_diff, diff
        
        ! Compare pixel by pixel
        pixels_match = .true.
        diff_count = 0
        max_diff = 0
        
        do i = 1, width * height
            diff = abs(int(fortran_pixels(i)) - int(stb_pixels(i)))
            if (diff > nint(tolerance * 255)) then
                pixels_match = .false.
                diff_count = diff_count + 1
                max_diff = max(max_diff, diff)
            end if
        end do
        
        ! Report results
        if (pixels_match) then
            write(*,*) "  ✅ ", trim(test_name), " PASSED - pixel-perfect match with STB"
        else
            write(*,*) "  ❌ ", trim(test_name), " FAILED"
            write(*,*) "    Differing pixels:", diff_count, "out of", width * height
            write(*,*) "    Max difference:", max_diff
            
            ! Print first few pixels for debugging
            write(*,*) "    First 8 Fortran pixels:", fortran_pixels(1:min(8, size(fortran_pixels)))
            write(*,*) "    First 8 STB pixels:    ", stb_pixels(1:min(8, size(stb_pixels)))
            
            ! Print bitmap patterns for small bitmaps
            if (width <= 8 .and. height <= 8) then
                write(*,*) "    Fortran bitmap pattern:"
                do i = 0, height - 1
                    write(*,'(A,8I4)') "      ", fortran_pixels(i*width+1:(i+1)*width)
                end do
                write(*,*) "    STB C bitmap pattern:"
                do i = 0, height - 1
                    write(*,'(A,8I4)') "      ", stb_pixels(i*width+1:(i+1)*width)
                end do
            end if
            
            passed = .false.
        end if
        
    end subroutine compare_bitmaps

end program test_forttf_rasterize_sorted_edges
