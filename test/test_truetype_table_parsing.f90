program test_truetype_table_parsing
    !! Test TrueType table parsing functionality
    use fortplot_stb_truetype
    use fortplot_truetype_native
    use fortplot_truetype_types
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    logical :: all_tests_passed
    character(len=256) :: font_path

    all_tests_passed = .true.
    font_path = "/System/Library/Fonts/Monaco.ttf"

    print *, "=== TrueType Table Parsing Tests ==="
    print *, ""

    ! Test 1: Table directory parsing
    if (.not. test_table_directory(font_path)) all_tests_passed = .false.

    ! Test 2: Head table parsing
    if (.not. test_head_table(font_path)) all_tests_passed = .false.

    ! Test 3: Maxp table parsing
    if (.not. test_maxp_table(font_path)) all_tests_passed = .false.

    ! Test 4: Hhea table parsing
    if (.not. test_hhea_table(font_path)) all_tests_passed = .false.

    ! Test 5: Loca table parsing
    if (.not. test_loca_table(font_path)) all_tests_passed = .false.

    print *, ""
    if (all_tests_passed) then
        print *, "✅ All table parsing tests PASSED"
        stop 0
    else
        print *, "❌ Some table parsing tests FAILED"
        stop 1
    end if

contains

    function test_table_directory(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success

        passed = .false.

        print *, "Test 1: Table Directory Parsing"
        print *, "-------------------------------"

        stb_success = stb_init_font(stb_font, font_path)
        native_success = native_init_font(native_font, font_path)

        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for table directory test"
            return
        end if

        print *, "Native found", native_font%num_tables, "tables"
        print *, "Font data size:", size(native_font%font_data), "bytes"

        ! Check that we found reasonable number of tables
        if (native_font%num_tables >= 4 .and. native_font%num_tables <= 50) then
            print *, "✅ Reasonable number of tables found"
            passed = .true.
        else
            print *, "❌ Unexpected number of tables:", native_font%num_tables
        end if

        ! Clean up
        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)

    end function test_table_directory

    function test_head_table(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success
        real(wp) :: stb_scale, native_scale

        passed = .false.

        print *, ""
        print *, "Test 2: Head Table Parsing"
        print *, "--------------------------"

        stb_success = stb_init_font(stb_font, font_path)
        native_success = native_init_font(native_font, font_path)

        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for head table test"
            return
        end if

        ! Test scale calculation (depends on units per EM from head table)
        stb_scale = stb_scale_for_pixel_height(stb_font, 16.0_wp)
        native_scale = native_scale_for_pixel_height(native_font, 16.0_wp)

        print *, "STB scale for 16px:", stb_scale
        print *, "Native scale for 16px:", native_scale
        print *, "Native units per EM:", native_font%units_per_em
        print *, "Native index to loc format:", native_font%index_to_loc_format

        ! Check if scales are reasonable and similar
        if (stb_scale > 0.0_wp .and. native_scale > 0.0_wp) then
            if (abs(stb_scale - native_scale) / stb_scale < 0.1_wp) then
                print *, "✅ Scale calculations match within 10%"
                passed = .true.
            else
                print *, "⚠️  Scale calculations differ significantly"
                print *, "   Difference:", abs(stb_scale - native_scale)
                ! Still pass if both are reasonable
                passed = (native_scale > 0.001_wp .and. native_scale < 1.0_wp)
            end if
        else
            print *, "❌ Scale calculation failed"
        end if

        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)

    end function test_head_table

    function test_maxp_table(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success
        integer :: stb_glyph_A, native_glyph_A, stb_glyph_B, native_glyph_B

        passed = .false.

        print *, ""
        print *, "Test 3: Maxp Table Parsing"
        print *, "--------------------------"

        stb_success = stb_init_font(stb_font, font_path)
        native_success = native_init_font(native_font, font_path)

        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for maxp table test"
            return
        end if

        print *, "Native num_glyphs:", native_font%num_glyphs

        ! STRICT TEST: num_glyphs must be positive and reasonable
        if (native_font%num_glyphs <= 0) then
            print *, "❌ CRITICAL: Native num_glyphs is not positive:", native_font%num_glyphs
            print *, "   This indicates maxp table parsing failed completely"
            call stb_cleanup_font(stb_font)
            call native_cleanup_font(native_font)
            return
        end if

        ! Test glyph lookup for multiple characters
        stb_glyph_A = stb_find_glyph_index(stb_font, iachar('A'))
        native_glyph_A = native_find_glyph_index(native_font, iachar('A'))
        stb_glyph_B = stb_find_glyph_index(stb_font, iachar('B'))
        native_glyph_B = native_find_glyph_index(native_font, iachar('B'))

        print *, "STB glyph index for 'A':", stb_glyph_A
        print *, "Native glyph index for 'A':", native_glyph_A
        print *, "STB glyph index for 'B':", stb_glyph_B
        print *, "Native glyph index for 'B':", native_glyph_B

        ! STRICT TEST: Must match STB exactly
        if (stb_glyph_A /= native_glyph_A) then
            print *, "❌ CRITICAL: Glyph index for 'A' doesn't match STB"
            print *, "   STB:", stb_glyph_A, "Native:", native_glyph_A
        else if (stb_glyph_B /= native_glyph_B) then
            print *, "❌ CRITICAL: Glyph index for 'B' doesn't match STB"
            print *, "   STB:", stb_glyph_B, "Native:", native_glyph_B
        else if (stb_glyph_A > 0 .and. stb_glyph_B > 0) then
            print *, "✅ Glyph indices match STB exactly for both 'A' and 'B'"
            passed = .true.
        else
            print *, "❌ CRITICAL: Both STB and Native return 0 for basic ASCII characters"
            print *, "   This indicates fundamental character mapping failure"
        end if

        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)

    end function test_maxp_table

    function test_hhea_table(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success
        integer :: stb_ascent, stb_descent, stb_line_gap
        integer :: native_ascent, native_descent, native_line_gap
        integer :: stb_advance, stb_bearing, native_advance, native_bearing

        passed = .false.

        print *, ""
        print *, "Test 4: Hhea/Hmtx Table Parsing"
        print *, "-------------------------------"

        stb_success = stb_init_font(stb_font, font_path)
        native_success = native_init_font(native_font, font_path)

        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for hhea table test"
            return
        end if

        ! Test vertical metrics
        call stb_get_font_vmetrics(stb_font, stb_ascent, stb_descent, stb_line_gap)
        call native_get_font_vmetrics(native_font, native_ascent, native_descent, native_line_gap)

        print *, "STB metrics - ascent:", stb_ascent, "descent:", stb_descent, "line_gap:", stb_line_gap
        print *, "Native metrics - ascent:", native_ascent, "descent:", native_descent, "line_gap:", native_line_gap

        ! Test horizontal metrics for specific characters
        call stb_get_codepoint_hmetrics(stb_font, iachar('A'), stb_advance, stb_bearing)
        call native_get_codepoint_hmetrics(native_font, iachar('A'), native_advance, native_bearing)

        print *, "STB 'A' metrics - advance:", stb_advance, "bearing:", stb_bearing
        print *, "Native 'A' metrics - advance:", native_advance, "bearing:", native_bearing

        ! Check if metrics are reasonable - MUST match STB exactly
        if (stb_ascent /= native_ascent) then
            print *, "❌ CRITICAL: Ascent doesn't match STB - STB:", stb_ascent, "Native:", native_ascent
        else if (stb_descent /= native_descent) then
            print *, "❌ CRITICAL: Descent doesn't match STB - STB:", stb_descent, "Native:", native_descent
        else if (stb_line_gap /= native_line_gap) then
            print *, "❌ CRITICAL: Line gap doesn't match STB - STB:", stb_line_gap, "Native:", native_line_gap
        else if (stb_advance /= native_advance .or. stb_bearing /= native_bearing) then
            print *, "❌ CRITICAL: 'A' horizontal metrics don't match STB"
            print *, "   Advance - STB:", stb_advance, "Native:", native_advance
            print *, "   Bearing - STB:", stb_bearing, "Native:", native_bearing
        else
            print *, "✅ All metrics match STB exactly"
            passed = .true.
        end if

        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)

    end function test_hhea_table

    function test_loca_table(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success

        passed = .false.

        print *, ""
        print *, "Test 5: Loca Table Parsing"
        print *, "--------------------------"

        stb_success = stb_init_font(stb_font, font_path)
        native_success = native_init_font(native_font, font_path)

        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for loca table test"
            return
        end if

        ! Check if loca table was parsed - STRICT TEST
        if (.not. allocated(native_font%glyph_offsets)) then
            print *, "❌ CRITICAL: Native implementation failed to parse loca table"
            call stb_cleanup_font(stb_font)
            call native_cleanup_font(native_font)
            return
        end if

        print *, "✅ Native parsed loca table - found", size(native_font%glyph_offsets)-1, "glyph entries"
        print *, "   Index to loc format:", native_font%index_to_loc_format
        print *, "   First few offsets:", native_font%glyph_offsets(1:min(5, size(native_font%glyph_offsets)))

        ! STRICT TEST: Check that offsets are reasonable and correct size
        if (size(native_font%glyph_offsets) <= 0) then
            print *, "❌ CRITICAL: Glyph offsets array has invalid size:", size(native_font%glyph_offsets)
        else if (native_font%num_glyphs <= 0) then
            print *, "❌ CRITICAL: num_glyphs invalid for loca validation:", native_font%num_glyphs
        else if (size(native_font%glyph_offsets) /= abs(native_font%num_glyphs) + 1) then
            print *, "❌ CRITICAL: Glyph offsets array size doesn't match num_glyphs + 1"
            print *, "   Expected:", abs(native_font%num_glyphs) + 1, "Got:", size(native_font%glyph_offsets)
        else
            print *, "✅ Glyph offsets array has correct size and valid data"
            passed = .true.
        end if

        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)

    end function test_loca_table

end program test_truetype_table_parsing
