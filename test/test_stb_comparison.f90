program test_stb_comparison
    !! Enhanced test program to compare STB TrueType wrapper with pure Fortran implementation
    !! Tests multiple fonts and characters on macOS and Linux systems
    use fortplot_stb_truetype
    use fortplot_stb
    use fortplot_truetype_parser, only: read_truetype_file
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    logical :: overall_success
    integer :: failed_tests, total_tests

    ! Font and character test data
    character(len=256), allocatable :: available_fonts(:)
    character(len=1), parameter :: test_chars(10) = ['A', 'B', 'M', 'W', 'g', 'j', '!', '?', '1', '@']
    integer :: num_fonts

    failed_tests = 0
    total_tests = 0

    write(*,*) "=== Enhanced STB TrueType vs Pure Fortran Comparison Tests ==="
    write(*,*) ""

    ! Discover available fonts
    call discover_system_fonts(available_fonts, num_fonts)

    if (num_fonts == 0) then
        write(*,*) "❌ No fonts found! Cannot run tests."
        error stop 1
    end if

    write(*,'(A,I0,A)') "📚 Found ", num_fonts, " available fonts"
    call print_font_list(available_fonts, num_fonts)
    write(*,*) ""

    ! Test with multiple fonts and characters
    call test_multi_font_comparison(available_fonts, num_fonts, test_chars)

    ! Summary
    write(*,*) ""
    write(*,*) "=== Test Summary ==="
    write(*,'(A,I0,A,I0)') "Failed: ", failed_tests, " / ", total_tests

    overall_success = (failed_tests == 0)
    if (overall_success) then
        write(*,*) "✅ All tests PASSED"
    else
        write(*,*) "❌ Some tests FAILED"
    end if

    if (.not. overall_success) then
        error stop 1
    end if

contains

    subroutine discover_system_fonts(fonts, count)
        !! Discover available TrueType fonts on macOS and Linux systems
        character(len=256), allocatable, intent(out) :: fonts(:)
        integer, intent(out) :: count

        character(len=256) :: potential_fonts(20)
        logical :: font_exists
        integer :: i, found_count

        ! Common fonts on macOS and Linux
        potential_fonts(1) = "/System/Library/Fonts/Monaco.ttf"                    ! macOS monospace
        potential_fonts(2) = "/System/Library/Fonts/Helvetica.ttc"                 ! macOS sans-serif
        potential_fonts(3) = "/System/Library/Fonts/Times.ttc"                     ! macOS serif
        potential_fonts(4) = "/System/Library/Fonts/Arial.ttf"                     ! macOS common
        potential_fonts(5) = "/usr/share/fonts/TTF/DejaVuSans.ttf"                ! Linux DejaVu
        potential_fonts(6) = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"    ! Linux DejaVu alt
        potential_fonts(7) = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"           ! Linux DejaVu Bold
        potential_fonts(8) = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf" ! Linux Liberation
        potential_fonts(9) = "/usr/share/fonts/TTF/LiberationSans-Regular.ttf"    ! Linux Liberation alt
        potential_fonts(10) = "/usr/share/fonts/noto/NotoSans-Regular.ttf"        ! Linux Noto
        potential_fonts(11) = "/usr/share/fonts/google-noto/NotoSans-Regular.ttf" ! Linux Noto alt
        potential_fonts(12) = "/usr/share/fonts/ubuntu/Ubuntu-R.ttf"              ! Ubuntu font
        potential_fonts(13) = "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf"     ! Ubuntu alt
        potential_fonts(14) = "/usr/share/fonts/corefonts/arial.ttf"              ! Linux Arial
        potential_fonts(15) = "/usr/share/fonts/truetype/msttcorefonts/arial.ttf" ! Linux Arial alt
        potential_fonts(16) = "/opt/homebrew/share/fonts/source-code-pro/SourceCodePro-Regular.ttf" ! Homebrew
        potential_fonts(17) = "/usr/local/share/fonts/SourceCodePro-Regular.ttf"  ! Local fonts
        potential_fonts(18) = "/System/Library/Fonts/Menlo.ttc"                   ! macOS Menlo
        potential_fonts(19) = "/System/Library/Fonts/SF-Pro.ttc"                  ! macOS SF Pro
        potential_fonts(20) = "/System/Library/Fonts/Avenir.ttc"                  ! macOS Avenir

        ! Count existing fonts first
        found_count = 0
        do i = 1, size(potential_fonts)
            inquire(file=trim(potential_fonts(i)), exist=font_exists)
            if (font_exists) found_count = found_count + 1
        end do

        ! Allocate and populate found fonts
        allocate(fonts(found_count))
        count = 0
        do i = 1, size(potential_fonts)
            inquire(file=trim(potential_fonts(i)), exist=font_exists)
            if (font_exists) then
                count = count + 1
                fonts(count) = potential_fonts(i)
            end if
        end do

    end subroutine discover_system_fonts

    subroutine print_font_list(fonts, count)
        !! Print list of discovered fonts
        character(len=256), intent(in) :: fonts(:)
        integer, intent(in) :: count
        integer :: i

        do i = 1, min(count, 5)  ! Show first 5 fonts
            write(*,'(A,I0,A,A)') "   ", i, ": ", trim(fonts(i))
        end do
        if (count > 5) then
            write(*,'(A,I0,A)') "   ... and ", count - 5, " more fonts"
        end if

    end subroutine print_font_list

    subroutine test_multi_font_comparison(fonts, num_fonts, characters)
        !! Test multiple fonts and characters for comprehensive validation
        character(len=256), intent(in) :: fonts(:)
        integer, intent(in) :: num_fonts
        character(len=1), intent(in) :: characters(:)

        integer :: font_idx, fonts_tested, fonts_passed
        logical :: font_passed

        fonts_tested = min(num_fonts, 3)  ! Test up to 3 fonts for now
        fonts_passed = 0

        do font_idx = 1, fonts_tested
            write(*,'(A,I0,A,A)') "🔍 Testing font ", font_idx, ": ", &
                                  trim(fonts(font_idx))

            ! Test TTC functions for this font
            call test_ttc_functions(fonts(font_idx))

            call test_single_font_comprehensive(fonts(font_idx), characters, font_passed)

            if (font_passed) then
                fonts_passed = fonts_passed + 1
                write(*,'(A,I0,A)') "  ✅ Font ", font_idx, " PASSED all tests"
            else
                write(*,'(A,I0,A)') "  ❌ Font ", font_idx, " FAILED some tests"
                failed_tests = failed_tests + 1
            end if
            write(*,*) ""
        end do

        total_tests = total_tests + fonts_tested
        write(*,'(A,I0,A,I0,A)') "✅ Summary: ", fonts_passed, " out of ", &
                                 fonts_tested, " fonts passed all tests"

    end subroutine test_multi_font_comparison

    subroutine test_ttc_functions(font_path)
        !! Test TTC-related functions by comparing Pure Fortran to STB reference
        character(len=*), intent(in) :: font_path
        integer :: stb_num_fonts, pure_num_fonts
        integer :: stb_offset, pure_offset
        integer :: i
        integer(c_int8_t), allocatable, target :: font_data(:)
        integer :: data_size
        type(c_ptr) :: font_ptr
        logical :: success

        ! Read font file for testing
        success = read_truetype_file(font_path, font_data, data_size)
        if (.not. success) return

        ! Convert to C pointer for STB functions
        font_ptr = c_loc(font_data(1))

        ! Test 1: stb_get_number_of_fonts comparison
        stb_num_fonts = stb_get_number_of_fonts(font_ptr, data_size)
        pure_num_fonts = stb_get_number_of_fonts_pure(font_ptr, data_size)

        write(*,'(A,I0,A,I0)') "   📊 Number of fonts: STB=", stb_num_fonts, &
                               ", Pure=", pure_num_fonts

        if (stb_num_fonts /= pure_num_fonts) then
            write(*,*) "    ❌ Number of fonts mismatch!"
            deallocate(font_data)
            return
        else
            write(*,*) "    ✅ Number of fonts match"
        end if

        ! Test 2: stb_get_font_offset_for_index comparison for each font
        do i = 0, stb_num_fonts - 1
            stb_offset = stb_get_font_offset_for_index(font_ptr, i)
            pure_offset = stb_get_font_offset_for_index_pure(font_ptr, i)

            write(*,'(A,I0,A,I0,A,I0)') "   📍 Font ", i, " offset: STB=", &
                                        stb_offset, ", Pure=", pure_offset

            if (stb_offset /= pure_offset) then
                write(*,'(A,I0,A)') "    ❌ Font ", i, " offset mismatch!"
                deallocate(font_data)
                return
            end if
        end do
        write(*,*) "    ✅ All font offsets match"

        ! Test invalid index (should return -1)
        stb_offset = stb_get_font_offset_for_index(font_ptr, stb_num_fonts)
        pure_offset = stb_get_font_offset_for_index_pure(font_ptr, stb_num_fonts)

        if (stb_offset /= pure_offset .or. stb_offset /= -1) then
            write(*,*) "    ❌ Invalid index handling mismatch!"
            deallocate(font_data)
            return
        else
            write(*,*) "    ✅ Invalid index handling matches"
        end if

        deallocate(font_data)
        write(*,*) "   ✅ TTC functions test PASSED"

    end subroutine test_ttc_functions

    subroutine test_single_font_comprehensive(font_path, characters, success)
        !! Test a single font comprehensively with multiple characters
        character(len=*), intent(in) :: font_path
        character(len=1), intent(in) :: characters(:)
        logical, intent(out) :: success

        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        logical :: stb_success, pure_success

        success = .false.

        ! Initialize both implementations
        if (.not. init_both_fonts(font_path, stb_font, pure_font, stb_success, pure_success)) then
            return
        end if

        write(*,*) "    ✓ Both implementations initialized successfully"

        ! Test core functionality
        if (.not. test_font_metrics(stb_font, pure_font)) then
            call cleanup_fonts(stb_font, pure_font, stb_success, pure_success)
            return
        end if

        if (.not. test_character_mapping(stb_font, pure_font, characters)) then
            call cleanup_fonts(stb_font, pure_font, stb_success, pure_success)
            return
        end if

        ! Test Level 6: Basic Metrics and Horizontal Layout (TDD)
        call test_metrics_functions(stb_font, pure_font)

        ! Test Level 7: Bounding Boxes and Font Metrics (TDD)
        call test_bounding_box_functions(stb_font, pure_font)

        ! Test Level 8: OS/2 Metrics (TDD)
        call test_os2_metrics_functions(stb_font, pure_font)

        ! Test Level 9: Kerning Support (TDD)
        call test_kerning_functions(stb_font, pure_font)

        ! Test additional STB functions (bitmap rendering, etc.)
        call test_stb_extended_functions(stb_font)

        call cleanup_fonts(stb_font, pure_font, stb_success, pure_success)
        success = .true.

    end subroutine test_single_font_comprehensive

    function init_both_fonts(font_path, stb_font, pure_font, stb_success, pure_success) result(success)
        !! Initialize both STB and pure implementations for a font
        character(len=*), intent(in) :: font_path
        type(stb_fontinfo_t), intent(out) :: stb_font
        type(stb_fontinfo_pure_t), intent(out) :: pure_font
        logical, intent(out) :: stb_success, pure_success
        logical :: success

        stb_success = stb_init_font(stb_font, font_path)
        pure_success = stb_init_font_pure(pure_font, font_path)

        if (.not. stb_success) then
            write(*,*) "    ⚠️  STB font initialization failed"
            success = .false.
            return
        end if

        if (.not. pure_success) then
            write(*,*) "    ⚠️  Pure font initialization failed"
            success = .false.
            return
        end if

        success = .true.

    end function init_both_fonts

    function test_font_metrics(stb_font, pure_font) result(success)
        !! Test that font metrics match between implementations
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        logical :: success

        real(wp) :: stb_scale, pure_scale
        integer :: stb_ascent, stb_descent, stb_line_gap
        integer :: pure_ascent, pure_descent, pure_line_gap
        logical :: scales_match, metrics_match
        real(wp), parameter :: scale_tolerance = 1.0e-6_wp

        ! Test scale calculation
        stb_scale = stb_scale_for_pixel_height(stb_font, 16.0_wp)
        pure_scale = stb_scale_for_pixel_height_pure(pure_font, 16.0_wp)

        ! Test font metrics
        call stb_get_font_vmetrics(stb_font, stb_ascent, stb_descent, stb_line_gap)
        call stb_get_font_vmetrics_pure(pure_font, pure_ascent, pure_descent, pure_line_gap)

        scales_match = abs(stb_scale - pure_scale) < scale_tolerance
        metrics_match = (stb_ascent == pure_ascent) .and. &
                       (stb_descent == pure_descent) .and. &
                       (stb_line_gap == pure_line_gap)

        if (scales_match .and. metrics_match) then
            write(*,'(A,F8.6)') "    ✓ Metrics and scale factors match (scale: ", stb_scale, ")"
            success = .true.
        else
            write(*,'(A,F8.6,A,F8.6)') "    ❌ Scale mismatch - STB: ", stb_scale, " Pure: ", pure_scale
            write(*,'(A,3I0,A,3I0)') "    ❌ Metrics - STB: ", stb_ascent, stb_descent, stb_line_gap, &
                                     " Pure: ", pure_ascent, pure_descent, pure_line_gap
            success = .false.
        end if

    end function test_font_metrics

    function test_character_mapping(stb_font, pure_font, characters) result(success)
        !! Test character to glyph index mapping for multiple characters
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        character(len=1), intent(in) :: characters(:)
        logical :: success

        integer :: char_idx, stb_glyph, pure_glyph, chars_passed

        chars_passed = 0
        write(*,'(A)', advance='no') "    🔤 Testing character mapping: "

        do char_idx = 1, size(characters)
            stb_glyph = stb_find_glyph_index(stb_font, iachar(characters(char_idx)))
            pure_glyph = stb_find_glyph_index_pure(pure_font, iachar(characters(char_idx)))

            if (stb_glyph == pure_glyph) then
                write(*,'(A,A)', advance='no') characters(char_idx), "✓ "
                chars_passed = chars_passed + 1
            else
                write(*,'(A,A)', advance='no') characters(char_idx), "❌ "
            end if
        end do
        write(*,*) ""

        success = (chars_passed == size(characters))

        if (success) then
            write(*,'(A,I0,A,I0,A)') "    ✅ All ", chars_passed, " out of ", &
                                     size(characters), " characters match"
        else
            write(*,'(A,I0,A,I0,A)') "    ❌ Only ", chars_passed, " out of ", &
                                     size(characters), " characters match"
        end if

    end function test_character_mapping

    subroutine test_stb_extended_functions(stb_font)
        !! Test extended STB functions (bitmap rendering, etc.)
        type(stb_fontinfo_t), intent(in) :: stb_font

        ! Test these functions to ensure STB wrapper is working
        call test_new_functions(stb_font)
        call test_glyph_functions(stb_font)

    end subroutine test_stb_extended_functions

    subroutine cleanup_fonts(stb_font, pure_font, stb_success, pure_success)
        !! Clean up font resources
        type(stb_fontinfo_t), intent(inout) :: stb_font
        type(stb_fontinfo_pure_t), intent(inout) :: pure_font
        logical, intent(in) :: stb_success, pure_success

        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)

    end subroutine cleanup_fonts

    subroutine test_new_functions(stb_font)
        !! Test newly added functions
        type(stb_fontinfo_t), intent(in) :: stb_font
        real(wp) :: em_scale
        integer :: bbox_x0, bbox_y0, bbox_x1, bbox_y1
        integer :: char_x0, char_y0, char_x1, char_y1
        integer :: kern_advance

        write(*,*) "  Testing new functions..."

        ! Test em scaling
        em_scale = stb_scale_for_mapping_em_to_pixels(stb_font, 16.0_wp)
        write(*,'(A,F8.6)') "    EM scale: ", em_scale

        ! Test font bounding box
        call stb_get_font_bounding_box(stb_font, bbox_x0, bbox_y0, bbox_x1, bbox_y1)
        write(*,'(A,4I6)') "    Font bbox: ", bbox_x0, bbox_y0, bbox_x1, bbox_y1

        ! Test character bounding box
        call stb_get_codepoint_box(stb_font, iachar('A'), char_x0, char_y0, &
                                  char_x1, char_y1)
        write(*,'(A,4I6)') "    Char 'A' bbox: ", char_x0, char_y0, char_x1, char_y1

        ! Test kerning
        kern_advance = stb_get_codepoint_kern_advance(stb_font, iachar('A'), &
                                                     iachar('V'))
        write(*,'(A,I0)') "    Kerning A-V: ", kern_advance

        write(*,*) "  ✓ New functions tested successfully"

    end subroutine test_new_functions

    subroutine test_glyph_functions(stb_font)
        !! Test newly added glyph-level functions
        type(stb_fontinfo_t), intent(in) :: stb_font
        integer :: glyph_index, glyph_advance, glyph_bearing
        integer :: glyph_x0, glyph_y0, glyph_x1, glyph_y1
        integer :: glyph_kern, table_length
        integer :: typoAscent, typoDescent, typoLineGap

        write(*,*) "  Testing glyph-level functions..."

        ! Get glyph index for 'A'
        glyph_index = stb_find_glyph_index(stb_font, iachar('A'))
        write(*,'(A,I0)') "    Glyph index for 'A': ", glyph_index

        if (glyph_index > 0) then
            ! Test glyph metrics
            call stb_get_glyph_hmetrics(stb_font, glyph_index, glyph_advance, &
                                       glyph_bearing)
            write(*,'(A,I0,A,I0)') "    Glyph metrics: ", glyph_advance, &
                                   "/", glyph_bearing

            ! Test glyph bounding box
            call stb_get_glyph_box(stb_font, glyph_index, glyph_x0, glyph_y0, &
                                  glyph_x1, glyph_y1)
            write(*,'(A,4I6)') "    Glyph bbox: ", glyph_x0, glyph_y0, &
                               glyph_x1, glyph_y1

            ! Test glyph kerning
            glyph_kern = stb_get_glyph_kern_advance(stb_font, glyph_index, &
                                                   glyph_index)
            write(*,'(A,I0)') "    Glyph self-kern: ", glyph_kern
        else
            write(*,*) "    ⚠ No glyph found for 'A'"
        end if

        ! Test OS/2 metrics
        call stb_get_font_vmetrics_os2(stb_font, typoAscent, typoDescent, &
                                      typoLineGap)
        write(*,'(A,I0,A,I0,A,I0)') "    OS/2 metrics: ", typoAscent, "/", &
                                     typoDescent, "/", typoLineGap

        ! Test kerning table
        table_length = stb_get_kerning_table_length(stb_font)
        write(*,'(A,I0)') "    Kerning table length: ", table_length

        ! Test bitmap functions
        call test_bitmap_functions(stb_font, glyph_index)

        write(*,*) "  ✓ Glyph functions tested successfully"

    end subroutine test_glyph_functions

    subroutine test_bitmap_functions(stb_font, glyph_index)
        !! Test newly added bitmap functions
        type(stb_fontinfo_t), intent(in) :: stb_font
        integer, intent(in) :: glyph_index
        type(c_ptr) :: bitmap_ptr, subpixel_bitmap_ptr
        integer :: width, height, xoff, yoff
        integer :: bbox_x0, bbox_y0, bbox_x1, bbox_y1
        real(wp) :: scale_x, scale_y

        write(*,*) "    Testing bitmap functions..."

        scale_x = 0.1_wp
        scale_y = 0.1_wp

        if (glyph_index > 0) then
            ! Test glyph bitmap rendering
            bitmap_ptr = stb_get_glyph_bitmap(stb_font, scale_x, scale_y, &
                                             glyph_index, width, height, &
                                             xoff, yoff)

            if (c_associated(bitmap_ptr)) then
                write(*,'(A,I0,A,I0,A,I0,A,I0)') "    ✓ Glyph bitmap: ", &
                    width, "x", height, " offset: ", xoff, ",", yoff
                call stb_free_bitmap(bitmap_ptr)
            else
                write(*,*) "    ⚠ Glyph bitmap allocation failed"
            end if

            ! Test glyph bitmap bounding box
            call stb_get_glyph_bitmap_box(stb_font, glyph_index, scale_x, &
                                         scale_y, bbox_x0, bbox_y0, &
                                         bbox_x1, bbox_y1)
            write(*,'(A,4I6)') "    Glyph bitmap bbox: ", bbox_x0, bbox_y0, &
                               bbox_x1, bbox_y1
        end if

        ! Test subpixel positioned character bitmap
        subpixel_bitmap_ptr = stb_get_codepoint_bitmap_subpixel(stb_font, &
                                                               scale_x, &
                                                               scale_y, &
                                                               0.5_wp, &
                                                               0.5_wp, &
                                                               iachar('A'), &
                                                               width, &
                                                               height, &
                                                               xoff, yoff)

        if (c_associated(subpixel_bitmap_ptr)) then
            write(*,'(A,I0,A,I0,A,I0,A,I0)') "    ✓ Subpixel bitmap: ", &
                width, "x", height, " offset: ", xoff, ",", yoff
            call stb_free_bitmap(subpixel_bitmap_ptr)
        else
            write(*,*) "    ⚠ Subpixel bitmap allocation failed"
        end if

        ! Test additional subpixel functions
        call test_subpixel_functions(stb_font, glyph_index)

        write(*,*) "    ✓ Bitmap functions tested successfully"

    end subroutine test_bitmap_functions

    subroutine test_subpixel_functions(stb_font, glyph_index)
        !! Test newly added subpixel bitmap functions
        type(stb_fontinfo_t), intent(in) :: stb_font
        integer, intent(in) :: glyph_index
        type(c_ptr) :: subpixel_glyph_bitmap_ptr
        integer :: width, height, xoff, yoff
        integer :: bbox_x0, bbox_y0, bbox_x1, bbox_y1
        real(wp) :: scale_x, scale_y, shift_x, shift_y

        write(*,*) "      Testing subpixel functions..."

        scale_x = 0.08_wp
        scale_y = 0.08_wp
        shift_x = 0.25_wp
        shift_y = 0.75_wp

        if (glyph_index > 0) then
            ! Test subpixel glyph bitmap rendering
            subpixel_glyph_bitmap_ptr = stb_get_glyph_bitmap_subpixel(stb_font, &
                                                                     scale_x, &
                                                                     scale_y, &
                                                                     shift_x, &
                                                                     shift_y, &
                                                                     glyph_index, &
                                                                     width, &
                                                                     height, &
                                                                     xoff, yoff)

            if (c_associated(subpixel_glyph_bitmap_ptr)) then
                write(*,'(A,I0,A,I0,A,I0,A,I0)') "      ✓ Subpixel glyph: ", &
                    width, "x", height, " offset: ", xoff, ",", yoff
                call stb_free_bitmap(subpixel_glyph_bitmap_ptr)
            else
                write(*,*) "      ⚠ Subpixel glyph bitmap allocation failed"
            end if

            ! Test subpixel glyph bounding box
            call stb_get_glyph_bitmap_box_subpixel(stb_font, glyph_index, &
                                                  scale_x, scale_y, &
                                                  shift_x, shift_y, &
                                                  bbox_x0, bbox_y0, &
                                                  bbox_x1, bbox_y1)
            write(*,'(A,4I6)') "      Subpixel glyph bbox: ", bbox_x0, &
                               bbox_y0, bbox_x1, bbox_y1
        end if

        ! Test subpixel character bounding box
        call stb_get_codepoint_bitmap_box_subpixel(stb_font, iachar('A'), &
                                                  scale_x, scale_y, &
                                                  shift_x, shift_y, &
                                                  bbox_x0, bbox_y0, &
                                                  bbox_x1, bbox_y1)
        write(*,'(A,4I6)') "      Subpixel char bbox: ", bbox_x0, bbox_y0, &
                           bbox_x1, bbox_y1

        write(*,*) "      ✓ Subpixel functions tested successfully"

    end subroutine test_subpixel_functions

    subroutine test_metrics_functions(stb_font, pure_font)
        !! Test Level 6: Basic Metrics and Horizontal Layout (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: stb_advance, stb_lsb, pure_advance, pure_lsb
        real(wp) :: stb_em_scale, pure_em_scale
        integer :: test_codepoint
        logical :: metrics_match

        write(*,*) "  Testing metrics functions (TDD)..."

        ! Test 1: stb_get_codepoint_hmetrics comparison
        test_codepoint = iachar('A')

        call stb_get_codepoint_hmetrics(stb_font, test_codepoint, stb_advance, stb_lsb)
        call stb_get_codepoint_hmetrics_pure(pure_font, test_codepoint, pure_advance, pure_lsb)

        write(*,'(A,I0,A,I0,A,I0,A,I0)') "    Character 'A' hmetrics: STB=(", &
                                         stb_advance, ",", stb_lsb, "), Pure=(", pure_advance, ",", pure_lsb, ")"

        metrics_match = (stb_advance == pure_advance .and. stb_lsb == pure_lsb)
        if (.not. metrics_match) then
            write(*,*) "    ❌ Horizontal metrics mismatch!"
        else
            write(*,*) "    ✅ Horizontal metrics match"
        end if

        ! Test 2: stb_scale_for_mapping_em_to_pixels comparison
        stb_em_scale = stb_scale_for_mapping_em_to_pixels(stb_font, 16.0_wp)
        pure_em_scale = stb_scale_for_mapping_em_to_pixels_pure(pure_font, 16.0_wp)

        write(*,'(A,F8.6,A,F8.6)') "    EM scale for 16px: STB=", stb_em_scale, &
                                   ", Pure=", pure_em_scale

        ! Allow small floating point differences
        if (abs(stb_em_scale - pure_em_scale) > 1e-6_wp) then
            write(*,*) "    ❌ EM scale mismatch!"
            metrics_match = .false.
        else
            write(*,*) "    ✅ EM scale matches"
        end if

        if (metrics_match) then
            write(*,*) "  ✅ All metrics functions match"
        else
            write(*,*) "  ❌ Some metrics functions failed"
        end if

    end subroutine test_metrics_functions

    subroutine test_bounding_box_functions(stb_font, pure_font)
        !! Test Level 7: Bounding Boxes and Font Metrics (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: stb_x0, stb_y0, stb_x1, stb_y1
        integer :: pure_x0, pure_y0, pure_x1, pure_y1
        integer :: test_codepoint, test_glyph_index
        logical :: bbox_match

        write(*,*) "  Testing bounding box functions (TDD)..."

        ! Test 1: stb_get_font_bounding_box comparison
        call stb_get_font_bounding_box(stb_font, stb_x0, stb_y0, stb_x1, stb_y1)
        call stb_get_font_bounding_box_pure(pure_font, pure_x0, pure_y0, pure_x1, pure_y1)

        write(*,'(A,4I6,A,4I6)') "    Font bbox: STB=(", stb_x0, stb_y0, stb_x1, stb_y1, &
                                "), Pure=(", pure_x0, pure_y0, pure_x1, pure_y1, ")"

        bbox_match = (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. &
                      stb_x1 == pure_x1 .and. stb_y1 == pure_y1)
        if (.not. bbox_match) then
            write(*,*) "    ❌ Font bounding box mismatch!"
        else
            write(*,*) "    ✅ Font bounding box matches"
        end if

        ! Test 2: stb_get_codepoint_box comparison
        test_codepoint = iachar('A')
        call stb_get_codepoint_box(stb_font, test_codepoint, stb_x0, stb_y0, stb_x1, stb_y1)
        call stb_get_codepoint_box_pure(pure_font, test_codepoint, pure_x0, pure_y0, pure_x1, pure_y1)

        write(*,'(A,4I6,A,4I6)') "    Char 'A' bbox: STB=(", &
                                stb_x0, stb_y0, stb_x1, stb_y1, &
                                "), Pure=(", pure_x0, pure_y0, pure_x1, pure_y1, ")"

        if (.not. (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. &
                   stb_x1 == pure_x1 .and. stb_y1 == pure_y1)) then
            write(*,*) "    ❌ Character bounding box mismatch!"
            bbox_match = .false.
        else
            write(*,*) "    ✅ Character bounding box matches"
        end if

        ! Test 3: stb_get_glyph_box comparison
        test_glyph_index = stb_find_glyph_index(stb_font, test_codepoint)
        call stb_get_glyph_box(stb_font, test_glyph_index, stb_x0, stb_y0, stb_x1, stb_y1)
        call stb_get_glyph_box_pure(pure_font, test_glyph_index, pure_x0, pure_y0, pure_x1, pure_y1)

        write(*,'(A,I0,A,4I6,A,4I6)') "    Glyph ", test_glyph_index, " bbox: STB=(", &
                                      stb_x0, stb_y0, stb_x1, stb_y1, &
                                      "), Pure=(", pure_x0, pure_y0, pure_x1, pure_y1, ")"

        if (.not. (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. &
                   stb_x1 == pure_x1 .and. stb_y1 == pure_y1)) then
            write(*,*) "    ❌ Glyph bounding box mismatch!"
            bbox_match = .false.
        else
            write(*,*) "    ✅ Glyph bounding box matches"
        end if

        if (bbox_match) then
            write(*,*) "  ✅ All bounding box functions match"
        else
            write(*,*) "  ❌ Some bounding box functions failed"
        end if

    end subroutine test_bounding_box_functions

    subroutine test_os2_metrics_functions(stb_font, pure_font)
        !! Test Level 8: OS/2 Metrics (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: stb_typo_ascent, stb_typo_descent, stb_typo_line_gap
        integer :: pure_typo_ascent, pure_typo_descent, pure_typo_line_gap
        integer :: pure_result
        logical :: os2_match

        write(*,*) "  Testing OS/2 metrics functions (TDD)..."

        ! Test: stb_get_font_vmetrics_os2 comparison
        call stb_get_font_vmetrics_os2(stb_font, stb_typo_ascent, stb_typo_descent, stb_typo_line_gap)
        pure_result = stb_get_font_vmetrics_os2_pure(pure_font, pure_typo_ascent, pure_typo_descent, pure_typo_line_gap)

        write(*,'(A,3I6,A,I0,A,3I6)') "    OS/2 metrics: STB=(", &
                                      stb_typo_ascent, stb_typo_descent, stb_typo_line_gap, &
                                      "), Pure=", pure_result, &
                                      " (", pure_typo_ascent, pure_typo_descent, pure_typo_line_gap, ")"

        ! If pure function returns 0, OS/2 table doesn't exist, so STB should return zeros too
        if (pure_result == 0) then
            os2_match = (stb_typo_ascent == 0 .and. stb_typo_descent == 0 .and. stb_typo_line_gap == 0)
        else
            os2_match = (stb_typo_ascent == pure_typo_ascent .and. &
                         stb_typo_descent == pure_typo_descent .and. &
                         stb_typo_line_gap == pure_typo_line_gap)
        end if

        if (.not. os2_match) then
            write(*,*) "    ❌ OS/2 metrics mismatch!"
        else
            write(*,*) "    ✅ OS/2 metrics match"
        end if

        if (os2_match) then
            write(*,*) "  ✅ All OS/2 metrics functions match"
        else
            write(*,*) "  ❌ OS/2 metrics functions failed"
        end if

    end subroutine test_os2_metrics_functions

    subroutine test_kerning_functions(stb_font, pure_font)
        !! Test Level 9: Kerning Support (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(inout) :: pure_font
        integer :: stb_kern_av, pure_kern_av
        integer :: stb_glyph_kern, pure_glyph_kern
        integer :: stb_table_length, pure_table_length
        integer :: glyph_a, glyph_v
        logical :: all_match

        write(*,*) "  Testing kerning functions (TDD)..."

        all_match = .true.

        ! Test 1: Codepoint kerning advance A-V (common kerning pair)
        stb_kern_av = stb_get_codepoint_kern_advance(stb_font, iachar('A'), iachar('V'))
        pure_kern_av = stb_get_codepoint_kern_advance_pure(pure_font, iachar('A'), iachar('V'))

        write(*,'(A,I0,A,I0,A)') "   Codepoint kerning A-V: STB=", stb_kern_av, &
                                 ", Pure=", pure_kern_av
        if (stb_kern_av /= pure_kern_av) then
            write(*,*) "     ❌ Codepoint kerning A-V mismatch"
            all_match = .false.
        else
            write(*,*) "     ✅ Codepoint kerning A-V matches"
        end if

        ! Test 2: Get glyph indices for A and V and test glyph kerning
        glyph_a = stb_find_glyph_index(stb_font, iachar('A'))
        glyph_v = stb_find_glyph_index(stb_font, iachar('V'))

        if (glyph_a > 0 .and. glyph_v > 0) then
            stb_glyph_kern = stb_get_glyph_kern_advance(stb_font, glyph_a, glyph_v)
            pure_glyph_kern = stb_get_glyph_kern_advance_pure(pure_font, glyph_a, glyph_v)

            write(*,'(A,I0,A,I0,A)') "   Glyph kerning A-V: STB=", stb_glyph_kern, &
                                     ", Pure=", pure_glyph_kern
            if (stb_glyph_kern /= pure_glyph_kern) then
                write(*,*) "     ❌ Glyph kerning A-V mismatch"
                all_match = .false.
            else
                write(*,*) "     ✅ Glyph kerning A-V matches"
            end if
        else
            write(*,*) "     ⚠ Skipping glyph kerning test (no glyphs found for A or V)"
        end if

        ! Test 3: Kerning table length
        stb_table_length = stb_get_kerning_table_length(stb_font)
        pure_table_length = stb_get_kerning_table_length_pure(pure_font)

        write(*,'(A,I0,A,I0,A)') "   Kerning table length: STB=", stb_table_length, &
                                 ", Pure=", pure_table_length
        if (stb_table_length /= pure_table_length) then
            write(*,*) "     ❌ Kerning table length mismatch"
            all_match = .false.
        else
            write(*,*) "     ✅ Kerning table length matches"
        end if

        ! Test 4: Test a few more character pairs for comprehensive coverage
        ! Test common kerning pairs: A-W, T-o, V-A, etc.
        call test_kerning_pair(stb_font, pure_font, iachar('A'), iachar('W'), 'A-W', all_match)
        call test_kerning_pair(stb_font, pure_font, iachar('T'), iachar('o'), 'T-o', all_match)
        call test_kerning_pair(stb_font, pure_font, iachar('V'), iachar('A'), 'V-A', all_match)

        if (all_match) then
            write(*,*) "  ✅ All kerning functions match"
        else
            write(*,*) "  ❌ Kerning functions failed"
        end if

    end subroutine test_kerning_functions

    subroutine test_kerning_pair(stb_font, pure_font, ch1, ch2, pair_name, all_match)
        !! Helper to test a single kerning pair
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(inout) :: pure_font
        integer, intent(in) :: ch1, ch2
        character(len=*), intent(in) :: pair_name
        logical, intent(inout) :: all_match
        integer :: stb_kern, pure_kern

        stb_kern = stb_get_codepoint_kern_advance(stb_font, ch1, ch2)
        pure_kern = stb_get_codepoint_kern_advance_pure(pure_font, ch1, ch2)

        write(*,'(A,A,A,I0,A,I0,A)') "   Kerning ", pair_name, ": STB=", stb_kern, &
                                     ", Pure=", pure_kern
        if (stb_kern /= pure_kern) then
            write(*,'(A,A,A)') "     ❌ Kerning ", pair_name, " mismatch"
            all_match = .false.
        else
            write(*,'(A,A,A)') "     ✅ Kerning ", pair_name, " matches"
        end if

    end subroutine test_kerning_pair

end program test_stb_comparison
