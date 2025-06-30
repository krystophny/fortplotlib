program test_forttf_pixel_by_pixel_comparison
    !! Detailed pixel-by-pixel comparison between STB and Fortran implementations
    !! to identify the exact source of the remaining 270-pixel difference
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_stb_raster, only: stbtt_rasterize
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_detailed_pixel_comparison()

contains

    subroutine test_detailed_pixel_comparison()
        !! Compare STB vs Fortran pixel-by-pixel for letter 'A'
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.02_wp

        ! STB C variables
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:)

        ! Pure Fortran variables
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: pure_bitmap(:)

        ! Analysis variables
        integer :: total_pixels, stb_nonzero, pure_nonzero, differences
        integer :: i, j, pixel_idx, stb_val, pure_val
        integer :: diff_histogram(-255:255)

        write(*,*) "=== Detailed Pixel-by-Pixel STB vs Fortran Comparison ==="

        ! Find and initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)

        ! Get STB C bitmap
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint_a, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        if (.not. c_associated(stb_bitmap_ptr)) then
            write(*,*) "❌ STB C failed to render 'A'"
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        ! Get Pure Fortran bitmap
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint_a, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        if (.not. c_associated(pure_bitmap_ptr)) then
            write(*,*) "❌ Pure Fortran failed to render 'A'"
            call stb_free_bitmap(stb_bitmap_ptr)
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        write(*,*) "--- Bitmap Dimensions ---"
        write(*,*) "STB:  ", stb_width, "x", stb_height, " offset:", stb_xoff, stb_yoff
        write(*,*) "Pure: ", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff

        ! Verify dimensions match
        if (stb_width /= pure_width .or. stb_height /= pure_height .or. &
            stb_xoff /= pure_xoff .or. stb_yoff /= pure_yoff) then
            write(*,*) "❌ DIMENSIONS MISMATCH - Cannot compare pixels"
            call stb_free_bitmap(stb_bitmap_ptr)
            call stb_free_bitmap_pure(pure_bitmap_ptr)
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        ! Convert pointers to arrays
        total_pixels = stb_width * stb_height
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [total_pixels])
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [total_pixels])

        ! Count pixels and differences
        stb_nonzero = 0
        pure_nonzero = 0
        differences = 0
        diff_histogram = 0

        do i = 1, total_pixels
            ! Convert signed c_int8_t to unsigned range (0-255)
            stb_val = iand(int(stb_bitmap(i), kind=4), 255)
            pure_val = iand(int(pure_bitmap(i), kind=4), 255)

            if (stb_val /= 0) stb_nonzero = stb_nonzero + 1
            if (pure_val /= 0) pure_nonzero = pure_nonzero + 1

            if (stb_val /= pure_val) then
                differences = differences + 1
                diff_histogram(pure_val - stb_val) = diff_histogram(pure_val - stb_val) + 1
            end if
        end do

        write(*,*) "--- Pixel Analysis ---"
        write(*,*) "Total pixels:     ", total_pixels
        write(*,*) "STB non-zero:     ", stb_nonzero
        write(*,*) "Pure non-zero:    ", pure_nonzero
        write(*,*) "Pixel differences:", differences
        write(*,*) "Match percentage: ", 100.0 * (total_pixels - differences) / total_pixels, "%"

        ! Analyze difference patterns
        write(*,*) "--- Difference Histogram (Pure - STB) ---"
        do i = -255, 255
            if (diff_histogram(i) > 0) then
                write(*,*) "Difference", i, ":", diff_histogram(i), "pixels"
            end if
        end do

        ! Find first few different pixels for detailed analysis
        write(*,*) "--- First 10 Different Pixel Locations ---"
        differences = 0
        do j = 0, stb_height - 1
            do i = 0, stb_width - 1
                pixel_idx = j * stb_width + i + 1
                ! Convert signed c_int8_t to unsigned range (0-255)
                stb_val = iand(int(stb_bitmap(pixel_idx), kind=4), 255)
                pure_val = iand(int(pure_bitmap(pixel_idx), kind=4), 255)

                if (stb_val /= pure_val) then
                    differences = differences + 1
                    write(*,*) "Pixel (", i, ",", j, "): STB =", stb_val, ", Pure =", pure_val, ", Diff =", pure_val - stb_val
                    if (differences >= 10) exit
                end if
            end do
            if (differences >= 10) exit
        end do

        ! Sample pixel values from different regions
        write(*,*) "--- Regional Pixel Sampling ---"
        call sample_region("Top-left", 0, 0, min(10, stb_width), min(10, stb_height), &
                          stb_bitmap, pure_bitmap, stb_width, stb_height)
        call sample_region("Center", stb_width/2-5, stb_height/2-5, 10, 10, &
                          stb_bitmap, pure_bitmap, stb_width, stb_height)
        call sample_region("Bottom-right", max(0, stb_width-10), max(0, stb_height-10), 10, 10, &
                          stb_bitmap, pure_bitmap, stb_width, stb_height)

        ! Cleanup
        call stb_free_bitmap(stb_bitmap_ptr)
        call stb_free_bitmap_pure(pure_bitmap_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)

        if (differences == 0) then
            write(*,*) "🎉 PERFECT MATCH: All pixels identical!"
        else
            write(*,*) "📊 Analysis complete - detailed differences identified"
        end if

    end subroutine test_detailed_pixel_comparison

    subroutine sample_region(region_name, start_x, start_y, width, height, &
                            stb_bitmap, pure_bitmap, bitmap_width, bitmap_height)
        character(len=*), intent(in) :: region_name
        integer, intent(in) :: start_x, start_y, width, height
        integer(c_int8_t), intent(in) :: stb_bitmap(:), pure_bitmap(:)
        integer, intent(in) :: bitmap_width, bitmap_height
        integer :: x, y, pixel_idx, stb_val, pure_val

        write(*,*) "  ", trim(region_name), " region (", start_x, ",", start_y, ") size", width, "x", height, ":"
        do y = start_y, min(start_y + height - 1, bitmap_height - 1)
            do x = start_x, min(start_x + width - 1, bitmap_width - 1)
                pixel_idx = y * bitmap_width + x + 1
                ! Convert signed c_int8_t to unsigned range (0-255)
                stb_val = iand(int(stb_bitmap(pixel_idx), kind=4), 255)
                pure_val = iand(int(pure_bitmap(pixel_idx), kind=4), 255)
                if (stb_val /= 0 .or. pure_val /= 0) then
                    write(*,*) "    (", x, ",", y, "): STB =", stb_val, ", Pure =", pure_val
                end if
            end do
        end do
    end subroutine sample_region

end program test_forttf_pixel_by_pixel_comparison
