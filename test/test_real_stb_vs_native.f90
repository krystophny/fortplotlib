program test_real_stb_vs_native
    !! Compare output between real STB TrueType (via C wrapper) and native Fortran implementation
    !! This test calls the actual STB library through C bindings to ensure true comparison
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    use fortplot_truetype_native
    use fortplot_bmp, only: save_grayscale_bmp
    implicit none

    ! C interface to the STB wrapper
    interface
        function stb_wrapper_load_font_from_file(wrapper, filename) bind(c, name='stb_wrapper_load_font_from_file') result(success)
            import :: c_ptr, c_char, c_int
            type(c_ptr), value :: wrapper
            character(kind=c_char), intent(in) :: filename(*)
            integer(c_int) :: success
        end function

        function stb_wrapper_scale_for_pixel_height(wrapper, height) &
                 bind(c, name='stb_wrapper_scale_for_pixel_height') result(scale)
            import :: c_ptr, c_float
            type(c_ptr), value :: wrapper
            real(c_float), value :: height
            real(c_float) :: scale
        end function

        function stb_wrapper_get_codepoint_bitmap(wrapper, scale_x, scale_y, codepoint, width, height, xoff, yoff) &
                bind(c, name='stb_wrapper_get_codepoint_bitmap') result(bitmap_ptr)
            import :: c_ptr, c_float, c_int
            type(c_ptr), value :: wrapper
            real(c_float), value :: scale_x, scale_y
            integer(c_int), value :: codepoint
            integer(c_int), intent(out) :: width, height, xoff, yoff
            type(c_ptr) :: bitmap_ptr
        end function

        subroutine stb_wrapper_free_bitmap(bitmap_ptr) bind(c, name='stb_wrapper_free_bitmap')
            import :: c_ptr
            type(c_ptr), value :: bitmap_ptr
        end subroutine

        subroutine stb_wrapper_cleanup_font(wrapper) bind(c, name='stb_wrapper_cleanup_font')
            import :: c_ptr
            type(c_ptr), value :: wrapper
        end subroutine

        function stb_wrapper_find_glyph_index(wrapper, codepoint) bind(c, name='stb_wrapper_find_glyph_index') result(glyph_index)
            import :: c_ptr, c_int
            type(c_ptr), value :: wrapper
            integer(c_int), value :: codepoint
            integer(c_int) :: glyph_index
        end function

        subroutine stb_wrapper_get_codepoint_bitmap_box(wrapper, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1) &
                bind(c, name='stb_wrapper_get_codepoint_bitmap_box')
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: wrapper
            integer(c_int), value :: codepoint
            real(c_float), value :: scale_x, scale_y
            integer(c_int), intent(out) :: ix0, iy0, ix1, iy1
        end subroutine
    end interface

    ! STB wrapper context structure (must match C structure layout)
    type, bind(c) :: stb_fontinfo_wrapper_t
        type(c_ptr) :: data_ptr
        integer(c_int) :: fontstart
        integer(c_int) :: numGlyphs
        type(c_ptr) :: private_data
    end type

    ! Test parameters
    character(len=256) :: font_paths(3)
    character(len=*), parameter :: TEST_CHAR = "A"
    integer, parameter :: TEST_CODEPOINT = ichar(TEST_CHAR)
    real(wp), parameter :: FONT_SIZE = 24.0_wp

    ! Font objects
    type(stb_fontinfo_wrapper_t), target :: stb_wrapper
    type(native_fontinfo_t) :: native_font

    ! Results
    integer :: stb_width, stb_height, stb_xoff, stb_yoff
    integer :: native_width, native_height, native_xoff, native_yoff
    type(c_ptr) :: stb_bitmap_ptr
    integer(int8), pointer :: stb_bitmap(:), native_bitmap(:)

    real(c_float) :: scale
    logical :: stb_success, native_success
    integer :: i, pixel_diff_count
    character(len=256) :: font_path
    integer :: stb_ix0, stb_iy0, stb_ix1, stb_iy1

    print *, "=== Real STB vs Native TrueType Comparison ==="
    print *, ""

    ! Try multiple font paths
    font_paths(1) = "/System/Library/Fonts/Supplemental/Arial.ttf"
    font_paths(2) = "/System/Library/Fonts/Geneva.ttf"
    font_paths(3) = "/System/Library/Fonts/Monaco.ttf"

    stb_success = .false.
    native_success = .false.

    ! Find a working font
    do i = 1, size(font_paths)
        inquire(file=trim(font_paths(i)), exist=stb_success)
        if (stb_success) then
            font_path = font_paths(i)
            print *, "Using font: ", trim(font_path)
            exit
        end if
    end do

    if (.not. stb_success) then
        print *, "ERROR: No suitable font found for testing"
        stop 1
    end if

    ! Initialize STB wrapper
    stb_success = (stb_wrapper_load_font_from_file(c_loc(stb_wrapper), &
                  trim(font_path)//c_null_char) == 1)

    if (.not. stb_success) then
        print *, "ERROR: Failed to initialize STB font from ", trim(font_path)
        stop 1
    end if

    ! Initialize native font
    native_success = native_init_font(native_font, font_path)

    if (.not. native_success) then
        print *, "ERROR: Failed to initialize native font from ", trim(font_path)
        call stb_wrapper_cleanup_font(c_loc(stb_wrapper))
        stop 1
    end if

    print *, "Both fonts initialized successfully"
    print *, ""

    ! Calculate scale for desired font size
    scale = stb_wrapper_scale_for_pixel_height(c_loc(stb_wrapper), real(FONT_SIZE, c_float))
    print *, "Scale for ", FONT_SIZE, " pixels: ", scale
    
    ! DEBUG: Check what glyph index STB finds for 'A'
    print *, "STB glyph index for 'A':", stb_wrapper_find_glyph_index(c_loc(stb_wrapper), TEST_CODEPOINT)
    
    ! DEBUG: Check what STB calculates for bitmap box
    call stb_wrapper_get_codepoint_bitmap_box(c_loc(stb_wrapper), TEST_CODEPOINT, scale, scale, &
                                              stb_ix0, stb_iy0, stb_ix1, stb_iy1)
    print *, "STB bitmap box calculation: (", stb_ix0, ",", stb_iy0, ") to (", stb_ix1, ",", stb_iy1, ")"
    print *, "Expected STB box: (-1,-16) to (15,0) = 16x16"
    
    ! FAIL THE TEST if STB box doesn't match expected values
    if (stb_ix0 /= -1 .or. stb_iy0 /= -16 .or. stb_ix1 /= 15 .or. stb_iy1 /= 0) then
        print *, "ERROR: STB bitmap box calculation is wrong!"
        print *, "Expected: (-1,-16) to (15,0), got: (", stb_ix0, ",", stb_iy0, ") to (", stb_ix1, ",", stb_iy1, ")"
        call cleanup_and_exit(1)
    end if
    
    print *, "✅ STB bitmap box calculation matches expected values"

    ! Get STB bitmap
    print *, "Rendering character '", TEST_CHAR, "' (codepoint ", TEST_CODEPOINT, ") with STB..."
    stb_bitmap_ptr = stb_wrapper_get_codepoint_bitmap(c_loc(stb_wrapper), scale, scale, &
                                                      TEST_CODEPOINT, stb_width, stb_height, stb_xoff, stb_yoff)

    if (c_associated(stb_bitmap_ptr)) then
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])
        print *, "STB bitmap: ", stb_width, "x", stb_height, " offset=(", stb_xoff, ",", stb_yoff, ")"
    else
        print *, "ERROR: STB bitmap allocation failed"
        call cleanup_and_exit(1)
    end if

    ! Get native bitmap
    print *, "Rendering character '", TEST_CHAR, "' with native implementation..."
    native_bitmap => native_get_codepoint_bitmap(native_font, real(scale, wp), real(scale, wp), &
                                                  TEST_CODEPOINT, native_width, native_height, native_xoff, native_yoff)

    if (associated(native_bitmap)) then
        print *, "Native bitmap: ", native_width, "x", native_height, " offset=(", native_xoff, ",", native_yoff, ")"
    else
        print *, "ERROR: Native bitmap allocation failed"
        call cleanup_and_exit(1)
    end if

    ! Compare dimensions
    print *, ""
    print *, "=== Dimension Comparison ==="
    print *, "STB:    ", stb_width, "x", stb_height, " offset=(", stb_xoff, ",", stb_yoff, ")"
    print *, "Native: ", native_width, "x", native_height, " offset=(", native_xoff, ",", native_yoff, ")"

    if (stb_width /= native_width .or. stb_height /= native_height) then
        print *, "ERROR: Dimension mismatch between STB and native implementations"
        call cleanup_and_exit(1)
    else
        print *, "Dimensions match!"
    end if

    ! Save both bitmaps for inspection
    call save_grayscale_bmp("stb_real_" // trim(TEST_CHAR) // ".bmp", stb_bitmap, stb_width, stb_height)
    call save_grayscale_bmp("native_real_" // trim(TEST_CHAR) // ".bmp", native_bitmap, native_width, native_height)
    print *, "Bitmaps saved as stb_real_", trim(TEST_CHAR), ".bmp and native_real_", trim(TEST_CHAR), ".bmp"

    ! Pixel-by-pixel comparison (if dimensions match)
    if (stb_width == native_width .and. stb_height == native_height) then
        print *, ""
        print *, "=== Pixel-by-pixel Comparison ==="

        pixel_diff_count = 0
        do i = 1, stb_width * stb_height
            if (stb_bitmap(i) /= native_bitmap(i)) then
                pixel_diff_count = pixel_diff_count + 1
            end if
        end do

        print *, "Different pixels: ", pixel_diff_count, " out of ", stb_width * stb_height

        if (pixel_diff_count == 0) then
            print *, "BITMAPS ARE IDENTICAL!"
        else
            print *, "Bitmaps differ by ", real(pixel_diff_count) / real(stb_width * stb_height) * 100.0, "%"

            ! Show some sample differences
            print *, "Sample pixel values:"
            do i = 1, min(10, stb_width * stb_height)
                if (stb_bitmap(i) /= native_bitmap(i)) then
                    print '(A,I0,A,I0,A,I0)', "  Pixel ", i, ": STB=", stb_bitmap(i), " Native=", native_bitmap(i)
                end if
            end do
        end if
    end if

    ! Show some bitmap statistics
    print *, ""
    print *, "=== Bitmap Statistics ==="
    call print_bitmap_stats("STB", stb_bitmap, stb_width * stb_height)
    call print_bitmap_stats("Native", native_bitmap, native_width * native_height)

    call cleanup_and_exit(0)

contains

    subroutine cleanup_and_exit(exit_code)
        integer, intent(in) :: exit_code

        if (c_associated(stb_bitmap_ptr)) then
            call stb_wrapper_free_bitmap(stb_bitmap_ptr)
        end if

        if (associated(native_bitmap)) then
            deallocate(native_bitmap)
        end if

        call stb_wrapper_cleanup_font(c_loc(stb_wrapper))
        call native_cleanup_font(native_font)

        stop exit_code
    end subroutine

    subroutine print_bitmap_stats(name, bitmap, size)
        character(len=*), intent(in) :: name
        integer(int8), intent(in) :: bitmap(:)
        integer, intent(in) :: size

        integer :: non_zero_count, i
        integer :: min_val, max_val, total

        if (size == 0) return

        non_zero_count = 0
        min_val = bitmap(1)
        max_val = bitmap(1)
        total = 0

        do i = 1, size
            if (bitmap(i) /= 0) non_zero_count = non_zero_count + 1
            min_val = min(min_val, int(bitmap(i)))
            max_val = max(max_val, int(bitmap(i)))
            total = total + bitmap(i)
        end do

        print '(A,A,I0,A,I0,A,I0,A,I0,A,F6.2)', name, " bitmap: non-zero pixels=", &
              non_zero_count, "/", size, &
              " min=", min_val, " max=", max_val, " avg=", real(total)/real(size)
    end subroutine

end program test_real_stb_vs_native
