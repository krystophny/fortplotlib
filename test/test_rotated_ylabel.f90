program test_rotated_ylabel
    use fortplot_raster, only: draw_rotated_ylabel_raster
    use fortplot_png, only: png_context, create_png_canvas
    use fortplot_text, only: init_text_system
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    type(png_context) :: ctx
    integer, parameter :: width = 400, height = 300
    integer :: i, non_white_pixels, left_margin_pixels
    integer(1) :: r, g, b
    logical :: test_passed
    character(len=*), parameter :: test_label = "Y-axis Test"

    ! Initialize text system
    if (.not. init_text_system()) then
        print *, "ERROR: Failed to initialize text system"
        stop 1
    end if

    print *, "=== Testing draw_rotated_ylabel_png Function ==="
    print *, ""

    ! Create PNG context and set up plot area
    ctx = create_png_canvas(width, height)
    ctx%x_min = 0.0_wp
    ctx%x_max = 10.0_wp
    ctx%y_min = 0.0_wp
    ctx%y_max = 10.0_wp

    print *, "Plot area setup:"
    print *, "  left:", ctx%plot_area%left, "bottom:", ctx%plot_area%bottom
    print *, "  width:", ctx%plot_area%width, "height:", ctx%plot_area%height
    print *, ""

    ! Test 1: Basic functionality - should not crash
    print *, "Test 1: Basic functionality (no crash test)"
    call draw_rotated_ylabel_raster(ctx, test_label)
    print *, "PASS: Function completed without crashing"
    print *, ""

    ! Test 2: Verify text was actually rendered
    print *, "Test 2: Text rendering verification"
    non_white_pixels = 0
    left_margin_pixels = 0

    ! Count non-white pixels in entire image
    do i = 1, height * (1 + width * 3) - 2, 3  ! -2 to avoid accessing last+1 and last+2
        if (i + 3 <= size(ctx%raster%image_data)) then
            r = ctx%raster%image_data(i + 1)
            g = ctx%raster%image_data(i + 2)
            b = ctx%raster%image_data(i + 3)
            ! Count non-white pixels (white is -1_1 which represents 255)
            if (r /= -1_1 .or. g /= -1_1 .or. b /= -1_1) then
                non_white_pixels = non_white_pixels + 1
            end if
        end if
    end do

    ! Count pixels specifically in left margin area (where Y-axis label should be)
    call count_left_margin_pixels(ctx, left_margin_pixels)

    print *, "Non-white pixels total:", non_white_pixels
    print *, "Non-white pixels in left margin:", left_margin_pixels

    test_passed = .true.

    if (non_white_pixels < 10) then
        print *, "FAIL: Too few non-white pixels - text likely not rendered"
        test_passed = .false.
    else
        print *, "PASS: Text appears to be rendered"
    end if

    if (left_margin_pixels == 0) then
        print *, "FAIL: No pixels found in left margin area - Y-axis label missing"
        test_passed = .false.
    else
        print *, "PASS: Y-axis label found in left margin area"
    end if
    print *, ""

    ! Test 3: Edge case - empty string
    print *, "Test 3: Edge case - empty string"
    call draw_rotated_ylabel_raster(ctx, "")
    print *, "PASS: Empty string handled without crashing"
    print *, ""

    ! Test 4: Edge case - single character
    print *, "Test 4: Edge case - single character"
    call draw_rotated_ylabel_raster(ctx, "Y")
    print *, "PASS: Single character handled without crashing"
    print *, ""

    ! Test 5: Edge case - long string
    print *, "Test 5: Edge case - long string"
    call draw_rotated_ylabel_raster(ctx, "Very Long Y-Axis Label Text")
    print *, "PASS: Long string handled without crashing"
    print *, ""

    ! Save test image for visual inspection
    call ctx%save('test_rotated_ylabel_output.png')
    print *, "Visual test: test_rotated_ylabel_output.png created"
    print *, "Expected: Rotated Y-axis labels on left side of plot"
    print *, ""

    if (test_passed) then
        print *, "All tests PASSED!"
        stop 0
    else
        print *, "Some tests FAILED!"
        stop 1
    end if

contains

    subroutine count_left_margin_pixels(ctx, pixel_count)
        !! Count non-white pixels in the left margin area where Y-axis label should be
        type(png_context), intent(in) :: ctx
        integer, intent(out) :: pixel_count
        integer :: x, y, pixel_idx
        integer(1) :: r, g, b

        pixel_count = 0

        ! Check left margin area (x=1 to plot_area%left-1)
        do y = 1, ctx%height
            do x = 1, max(1, ctx%plot_area%left - 1)
                pixel_idx = (y - 1) * (1 + ctx%width * 3) + 1 + (x - 1) * 3 + 1

                if (pixel_idx > 0 .and. pixel_idx <= size(ctx%raster%image_data) - 2) then
                    r = ctx%raster%image_data(pixel_idx)
                    g = ctx%raster%image_data(pixel_idx + 1)
                    b = ctx%raster%image_data(pixel_idx + 2)

                    ! Count non-white pixels
                    if (r /= -1_1 .or. g /= -1_1 .or. b /= -1_1) then
                        pixel_count = pixel_count + 1
                    end if
                end if
            end do
        end do
    end subroutine count_left_margin_pixels

end program test_rotated_ylabel
