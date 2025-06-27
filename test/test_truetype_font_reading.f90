program test_truetype_font_reading
    !! Test TrueType font file reading and basic initialization
    use fortplot_stb_truetype
    use fortplot_truetype_native
    use fortplot_truetype_types
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    logical :: all_tests_passed
    character(len=256) :: font_path

    all_tests_passed = .true.
    font_path = "/System/Library/Fonts/Monaco.ttf"

    print *, "=== TrueType Font Reading Tests ==="
    print *, ""

    ! Test 1: Basic font file reading
    if (.not. test_basic_font_reading(font_path)) all_tests_passed = .false.

    ! Test 2: Font data validation
    if (.not. test_font_data_validation(font_path)) all_tests_passed = .false.

    ! Test 3: Error handling for invalid files
    if (.not. test_invalid_font_handling()) all_tests_passed = .false.

    print *, ""
    if (all_tests_passed) then
        print *, "✅ All font reading tests PASSED"
        stop 0
    else
        print *, "❌ Some font reading tests FAILED"
        stop 1
    end if

contains

    function test_basic_font_reading(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success

        passed = .false.

        print *, "Test 1: Basic Font File Reading"
        print *, "-------------------------------"

        ! Test STB implementation
        stb_success = stb_init_font(stb_font, font_path)

        ! Test native implementation
        native_success = native_init_font(native_font, font_path)

        print *, "Font path: ", trim(font_path)
        print *, "STB TrueType initialization:", merge("SUCCESS", "FAILED ", stb_success)
        print *, "Native implementation init:", merge("SUCCESS", "FAILED ", native_success)

        if (stb_success .and. native_success) then
            print *, "✅ Both implementations can read font file"
            print *, "   Font data size:", size(native_font%font_data), "bytes"
            print *, "   Number of tables:", native_font%num_tables
            passed = .true.
        else if (stb_success .and. .not. native_success) then
            print *, "❌ Native implementation failed while STB succeeded"
        else if (.not. stb_success .and. .not. native_success) then
            print *, "⚠️  Both failed - likely no font file available"
        end if

        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (native_success) call native_cleanup_font(native_font)

    end function test_basic_font_reading

    function test_font_data_validation(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(native_fontinfo_t) :: native_font
        logical :: native_success

        passed = .false.

        print *, ""
        print *, "Test 2: Font Data Validation"
        print *, "----------------------------"

        native_success = native_init_font(native_font, font_path)

        if (.not. native_success) then
            print *, "❌ Cannot initialize font for validation test"
            return
        end if

        ! Check basic font data integrity
        if (allocated(native_font%font_data)) then
            print *, "✅ Font data allocated successfully"
            print *, "   Size:", size(native_font%font_data), "bytes"
        else
            print *, "❌ Font data not allocated"
            call native_cleanup_font(native_font)
            return
        end if

        ! Check table directory
        if (native_font%num_tables > 0) then
            print *, "✅ Table directory parsed, found", native_font%num_tables, "tables"
        else
            print *, "❌ No tables found in font"
            call native_cleanup_font(native_font)
            return
        end if

        ! Check essential tables are present
        if (native_font%head_offset > 0) then
            print *, "✅ Head table found at offset:", native_font%head_offset
        else
            print *, "❌ Head table not found"
        end if

        if (native_font%maxp_offset > 0) then
            print *, "✅ Maxp table found at offset:", native_font%maxp_offset
        else
            print *, "❌ Maxp table not found"
        end if

        if (native_font%hhea_offset > 0) then
            print *, "✅ Hhea table found at offset:", native_font%hhea_offset
        else
            print *, "❌ Hhea table not found"
        end if

        passed = (native_font%head_offset > 0 .and. native_font%maxp_offset > 0)

        call native_cleanup_font(native_font)

    end function test_font_data_validation

    function test_invalid_font_handling() result(passed)
        logical :: passed
        type(native_fontinfo_t) :: native_font
        logical :: native_success

        passed = .false.

        print *, ""
        print *, "Test 3: Invalid Font Handling"
        print *, "-----------------------------"

        ! Test with non-existent file
        native_success = native_init_font(native_font, "/nonexistent/font.ttf")

        if (.not. native_success) then
            print *, "✅ Correctly handled non-existent font file"
        else
            print *, "❌ Should have failed with non-existent file"
            call native_cleanup_font(native_font)
            return
        end if

        ! Test with empty filename
        native_success = native_init_font(native_font, "")

        if (.not. native_success) then
            print *, "✅ Correctly handled empty filename"
            passed = .true.
        else
            print *, "❌ Should have failed with empty filename"
            call native_cleanup_font(native_font)
        end if

    end function test_invalid_font_handling

end program test_truetype_font_reading
