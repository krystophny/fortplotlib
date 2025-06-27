program test_stb_intermediate_steps
    !! Compare intermediate steps of TrueType rendering against real STB library
    !! This test identifies where the native implementation diverges from STB
    use fortplot_truetype_native
    use fortplot_truetype_types
    use fortplot_bmp, only: save_grayscale_bmp
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    use iso_c_binding
    implicit none

    ! C interface to the real STB wrapper
    interface
        function stb_wrapper_load_font_from_file(wrapper, filename) bind(c, name='stb_wrapper_load_font_from_file') result(success)
            import :: c_ptr, c_char, c_int
            type(c_ptr), value :: wrapper
            character(kind=c_char), intent(in) :: filename(*)
            integer(c_int) :: success
        end function

        function stb_wrapper_scale_for_pixel_height(wrapper, height) bind(c, name='stb_wrapper_scale_for_pixel_height') result(scale)
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

        subroutine stb_wrapper_get_codepoint_hmetrics(wrapper, codepoint, advanceWidth, leftSideBearing) &
                bind(c, name='stb_wrapper_get_codepoint_hmetrics')
            import :: c_ptr, c_int
            type(c_ptr), value :: wrapper
            integer(c_int), value :: codepoint
            integer(c_int), intent(out) :: advanceWidth, leftSideBearing
        end subroutine

        subroutine stb_wrapper_get_font_vmetrics(wrapper, ascent, descent, lineGap) &
                bind(c, name='stb_wrapper_get_font_vmetrics')
            import :: c_ptr, c_int
            type(c_ptr), value :: wrapper
            integer(c_int), intent(out) :: ascent, descent, lineGap
        end subroutine

        subroutine stb_wrapper_get_codepoint_bitmap_box(wrapper, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1) &
                bind(c, name='stb_wrapper_get_codepoint_bitmap_box')
            import :: c_ptr, c_float, c_int
            type(c_ptr), value :: wrapper
            integer(c_int), value :: codepoint
            real(c_float), value :: scale_x, scale_y
            integer(c_int), intent(out) :: ix0, iy0, ix1, iy1
        end subroutine
    end interface

    ! STB wrapper type
    type :: stb_fontinfo_wrapper_t
        integer(c_int) :: userdata(4)
        integer(c_int) :: data_offset
        integer(c_int) :: fontstart
        integer(c_int) :: numGlyphs
        type(c_ptr) :: private_data
    end type

    ! Test parameters
    character(len=256) :: font_path
    character(len=*), parameter :: TEST_CHAR = "A"
    integer, parameter :: TEST_CODEPOINT = ichar(TEST_CHAR)
    real(wp), parameter :: FONT_SIZE = 24.0_wp

    ! Font objects
    type(stb_fontinfo_wrapper_t), target :: stb_wrapper
    type(native_fontinfo_t) :: native_font

    logical :: all_tests_passed

    print *, "=== STB vs Native Intermediate Steps Comparison ==="
    print *, ""

    ! Find a working font
    if (.not. find_working_font(font_path)) then
        print *, "ERROR: No suitable font found for testing"
        stop 1
    end if

    print *, "Using font: ", trim(font_path)

    all_tests_passed = .true.

    ! Step 1: Test font initialization
    if (.not. test_font_initialization()) all_tests_passed = .false.

    ! Step 2: Test scale calculation
    if (.not. test_scale_calculation()) all_tests_passed = .false.

    ! Step 3: Test glyph index lookup
    if (.not. test_glyph_index_lookup()) all_tests_passed = .false.

    ! Step 4: Test font metrics
    if (.not. test_font_metrics()) all_tests_passed = .false.

    ! Step 5: Test horizontal metrics
    if (.not. test_horizontal_metrics()) all_tests_passed = .false.

    ! Step 6: Test bitmap box calculation
    if (.not. test_bitmap_box_calculation()) all_tests_passed = .false.

    ! Step 7: Test final bitmap rendering
    if (.not. test_bitmap_rendering()) all_tests_passed = .false.

    print *, ""
    print *, "=== SUMMARY ==="
    if (all_tests_passed) then
        print *, "✅ All intermediate steps match between STB and Native"
    else
        print *, "❌ Found discrepancies in intermediate steps"
        print *, "   This helps identify where the native implementation needs fixing"
    end if

contains

    function find_working_font(font_path) result(success)
        character(len=256), intent(out) :: font_path
        logical :: success
        character(len=256) :: font_paths(3)
        integer :: i

        font_paths(1) = "/System/Library/Fonts/Supplemental/Arial.ttf"
        font_paths(2) = "/System/Library/Fonts/Geneva.ttf"
        font_paths(3) = "/System/Library/Fonts/Monaco.ttf"

        success = .false.
        do i = 1, size(font_paths)
            inquire(file=trim(font_paths(i)), exist=success)
            if (success) then
                font_path = font_paths(i)
                return
            end if
        end do
    end function

    function test_font_initialization() result(passed)
        logical :: passed
        logical :: stb_success, native_success

        print *, ""
        print *, "Step 1: Font Initialization"
        print *, "----------------------------"

        ! Initialize STB
        stb_success = (stb_wrapper_load_font_from_file(c_loc(stb_wrapper), &
                      trim(font_path) // c_null_char) == 1)

        ! Initialize Native
        native_success = native_init_font(native_font, font_path)

        print *, "STB initialization:    ", merge("SUCCESS", "FAILED ", stb_success)
        print *, "Native initialization: ", merge("SUCCESS", "FAILED ", native_success)

        if (stb_success .and. native_success) then
            print *, "✅ Both implementations initialize successfully"
            passed = .true.
        else if (stb_success .and. .not. native_success) then
            print *, "❌ Native failed to initialize while STB succeeded"
            passed = .false.
        else if (.not. stb_success .and. native_success) then
            print *, "❌ STB failed to initialize while Native succeeded"
            passed = .false.
        else
            print *, "❌ Both implementations failed to initialize"
            passed = .false.
        end if

        if (.not. stb_success) then
            print *, "ERROR: Cannot continue without working STB reference"
            stop 1
        end if

    end function

    function test_scale_calculation() result(passed)
        logical :: passed
        real(c_float) :: stb_scale, native_scale
        real(wp) :: diff_percent

        print *, ""
        print *, "Step 2: Scale Calculation"
        print *, "-------------------------"

        stb_scale = stb_wrapper_scale_for_pixel_height(c_loc(stb_wrapper), real(FONT_SIZE, c_float))
        native_scale = real(native_scale_for_pixel_height(native_font, FONT_SIZE), c_float)

        print *, "STB scale for ", FONT_SIZE, "px:    ", stb_scale
        print *, "Native scale for ", FONT_SIZE, "px: ", native_scale

        if (stb_scale /= 0.0) then
            diff_percent = abs(stb_scale - native_scale) / abs(stb_scale) * 100.0
            print *, "Difference: ", diff_percent, "%"

            if (diff_percent < 1.0) then
                print *, "✅ Scale calculations match closely"
                passed = .true.
            else
                print *, "❌ Scale calculations differ significantly"
                passed = .false.
            end if
        else
            print *, "❌ STB returned zero scale"
            passed = .false.
        end if

    end function

    function test_glyph_index_lookup() result(passed)
        logical :: passed
        integer(c_int) :: stb_glyph_index, native_glyph_index

        print *, ""
        print *, "Step 3: Glyph Index Lookup"
        print *, "---------------------------"

        stb_glyph_index = stb_wrapper_find_glyph_index(c_loc(stb_wrapper), int(TEST_CODEPOINT, c_int))
        native_glyph_index = int(native_find_glyph_index(native_font, TEST_CODEPOINT), c_int)

        print *, "Character '", TEST_CHAR, "' (codepoint ", TEST_CODEPOINT, "):"
        print *, "STB glyph index:    ", stb_glyph_index
        print *, "Native glyph index: ", native_glyph_index

        if (stb_glyph_index == native_glyph_index) then
            print *, "✅ Glyph indices match"
            passed = .true.
        else
            print *, "❌ Glyph indices differ"
            passed = .false.
        end if

    end function

    function test_font_metrics() result(passed)
        logical :: passed
        integer(c_int) :: stb_ascent, stb_descent, stb_lineGap
        integer(c_int) :: native_ascent, native_descent, native_lineGap
        integer :: native_ascent_i, native_descent_i, native_lineGap_i

        print *, ""
        print *, "Step 4: Font Metrics"
        print *, "--------------------"

        call stb_wrapper_get_font_vmetrics(c_loc(stb_wrapper), stb_ascent, stb_descent, stb_lineGap)
        call native_get_font_vmetrics(native_font, native_ascent_i, native_descent_i, native_lineGap_i)

        native_ascent = int(native_ascent_i, c_int)
        native_descent = int(native_descent_i, c_int)
        native_lineGap = int(native_lineGap_i, c_int)

        print *, "STB metrics:    ascent=", stb_ascent, " descent=", stb_descent, " lineGap=", stb_lineGap
        print *, "Native metrics: ascent=", native_ascent, " descent=", native_descent, " lineGap=", native_lineGap

        if (stb_ascent == native_ascent .and. stb_descent == native_descent .and. stb_lineGap == native_lineGap) then
            print *, "✅ Font metrics match"
            passed = .true.
        else
            print *, "❌ Font metrics differ"
            passed = .false.
        end if

    end function

    function test_horizontal_metrics() result(passed)
        logical :: passed
        integer(c_int) :: stb_advanceWidth, stb_leftSideBearing
        integer(c_int) :: native_advanceWidth, native_leftSideBearing
        integer :: native_advanceWidth_i, native_leftSideBearing_i

        print *, ""
        print *, "Step 5: Horizontal Metrics"
        print *, "--------------------------"

        call stb_wrapper_get_codepoint_hmetrics(c_loc(stb_wrapper), int(TEST_CODEPOINT, c_int), &
                                               stb_advanceWidth, stb_leftSideBearing)
        call native_get_codepoint_hmetrics(native_font, TEST_CODEPOINT, &
                                          native_advanceWidth_i, native_leftSideBearing_i)

        native_advanceWidth = int(native_advanceWidth_i, c_int)
        native_leftSideBearing = int(native_leftSideBearing_i, c_int)

        print *, "Character '", TEST_CHAR, "' horizontal metrics:"
        print *, "STB:    advanceWidth=", stb_advanceWidth, " leftSideBearing=", stb_leftSideBearing
        print *, "Native: advanceWidth=", native_advanceWidth, " leftSideBearing=", native_leftSideBearing

        if (stb_advanceWidth == native_advanceWidth .and. stb_leftSideBearing == native_leftSideBearing) then
            print *, "✅ Horizontal metrics match"
            passed = .true.
        else
            print *, "❌ Horizontal metrics differ"
            passed = .false.
        end if

    end function

    function test_bitmap_box_calculation() result(passed)
        logical :: passed
        real(c_float) :: scale
        integer(c_int) :: stb_ix0, stb_iy0, stb_ix1, stb_iy1
        integer(c_int) :: native_ix0, native_iy0, native_ix1, native_iy1
        integer :: native_ix0_i, native_iy0_i, native_ix1_i, native_iy1_i

        print *, ""
        print *, "Step 6: Bitmap Box Calculation"
        print *, "-------------------------------"

        scale = stb_wrapper_scale_for_pixel_height(c_loc(stb_wrapper), real(FONT_SIZE, c_float))

        call stb_wrapper_get_codepoint_bitmap_box(c_loc(stb_wrapper), int(TEST_CODEPOINT, c_int), &
                                                 scale, scale, stb_ix0, stb_iy0, stb_ix1, stb_iy1)
        call native_get_codepoint_bitmap_box(native_font, TEST_CODEPOINT, real(scale, wp), real(scale, wp), &
                                            native_ix0_i, native_iy0_i, native_ix1_i, native_iy1_i)

        native_ix0 = int(native_ix0_i, c_int)
        native_iy0 = int(native_iy0_i, c_int)
        native_ix1 = int(native_ix1_i, c_int)
        native_iy1 = int(native_iy1_i, c_int)

        print *, "Character '", TEST_CHAR, "' bitmap box:"
        print *, "STB:    (", stb_ix0, ",", stb_iy0, ") to (", stb_ix1, ",", stb_iy1, ")"
        print *, "Native: (", native_ix0, ",", native_iy0, ") to (", native_ix1, ",", native_iy1, ")"

        if (stb_ix0 == native_ix0 .and. stb_iy0 == native_iy0 .and. &
            stb_ix1 == native_ix1 .and. stb_iy1 == native_iy1) then
            print *, "✅ Bitmap boxes match"
            passed = .true.
        else
            print *, "❌ Bitmap boxes differ"
            passed = .false.
        end if

    end function

    function test_bitmap_rendering() result(passed)
        logical :: passed
        real(c_float) :: scale
        integer(c_int) :: stb_width, stb_height, stb_xoff, stb_yoff
        integer :: native_width, native_height, native_xoff, native_yoff
        type(c_ptr) :: stb_bitmap_ptr
        integer(int8), pointer :: stb_bitmap(:), native_bitmap(:)
        integer :: i, differences, total_pixels
        real(wp) :: difference_percent

        print *, ""
        print *, "Step 7: Final Bitmap Rendering"
        print *, "-------------------------------"

        scale = stb_wrapper_scale_for_pixel_height(c_loc(stb_wrapper), real(FONT_SIZE, c_float))

        ! Generate STB bitmap
        stb_bitmap_ptr = stb_wrapper_get_codepoint_bitmap(c_loc(stb_wrapper), scale, scale, &
                                                         int(TEST_CODEPOINT, c_int), &
                                                         stb_width, stb_height, stb_xoff, stb_yoff)

        ! Generate native bitmap
        native_bitmap => native_get_codepoint_bitmap(native_font, real(scale, wp), real(scale, wp), TEST_CODEPOINT, &
                                                     native_width, native_height, native_xoff, native_yoff)

        print *, "STB bitmap:    ", stb_width, "x", stb_height, " offset=(", stb_xoff, ",", stb_yoff, ")"
        print *, "Native bitmap: ", native_width, "x", native_height, " offset=(", native_xoff, ",", native_yoff, ")"

        if (.not. c_associated(stb_bitmap_ptr)) then
            print *, "❌ STB failed to generate bitmap"
            passed = .false.
            return
        end if

        if (.not. associated(native_bitmap)) then
            print *, "❌ Native failed to generate bitmap"
            passed = .false.
            call stb_wrapper_free_bitmap(stb_bitmap_ptr)
            return
        end if

        ! Convert STB bitmap to Fortran array
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [int(stb_width * stb_height)])

        ! Compare dimensions first
        if (stb_width /= native_width .or. stb_height /= native_height) then
            print *, "❌ Bitmap dimensions differ"
            passed = .false.
        else if (stb_xoff /= native_xoff .or. stb_yoff /= native_yoff) then
            print *, "❌ Bitmap offsets differ"
            passed = .false.
        else
            ! Compare pixel content
            total_pixels = stb_width * stb_height
            differences = 0

            do i = 1, total_pixels
                if (stb_bitmap(i) /= native_bitmap(i)) then
                    differences = differences + 1
                end if
            end do

            if (total_pixels > 0) then
                difference_percent = real(differences) / real(total_pixels) * 100.0_wp
                print *, "Pixel differences: ", differences, "/", total_pixels, " (", difference_percent, "%)"

                if (difference_percent < 5.0_wp) then
                    print *, "✅ Bitmap rendering matches closely"
                    passed = .true.
                else
                    print *, "❌ Bitmap rendering differs significantly"
                    passed = .false.
                end if
            else
                passed = .false.
            end if
        end if

        ! Save bitmaps for visual inspection
        call save_grayscale_bmp("stb_step_" // trim(TEST_CHAR) // ".bmp", stb_bitmap, int(stb_width), int(stb_height))
        call save_grayscale_bmp("native_step_" // trim(TEST_CHAR) // ".bmp", native_bitmap, native_width, native_height)
        print *, "Saved bitmaps: stb_step_", trim(TEST_CHAR), ".bmp and native_step_", trim(TEST_CHAR), ".bmp"

        ! Cleanup
        call stb_wrapper_free_bitmap(stb_bitmap_ptr)
        call native_free_bitmap(native_bitmap)

    end function

end program test_stb_intermediate_steps
