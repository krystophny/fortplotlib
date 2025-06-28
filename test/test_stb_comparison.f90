program test_stb_comparison
    !! Main test program orchestrating comprehensive STB vs Pure Fortran comparison
    !! Individual test modules are run automatically by fpm test
    use test_utils
    use test_stb_metrics
    use test_stb_mapping
    use test_stb_bitmap
    use fortplot_stb_truetype
    use fortplot_stb
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    logical :: overall_success
    integer :: failed_tests, total_tests

    ! Font and character test data
    character(len=256), allocatable :: available_fonts(:)
    integer :: num_fonts

    failed_tests = 0
    total_tests = 0

    write(*,*) "=== STB TrueType vs Pure Fortran Comprehensive Comparison ==="
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

    ! Test with multiple fonts comprehensively
    call test_comprehensive_comparison(available_fonts, num_fonts)

    ! Summary
    write(*,*) ""
    write(*,*) "=== Test Summary ==="
    write(*,'(A,I0,A,I0)') "Failed: ", failed_tests, " / ", total_tests

    overall_success = (failed_tests == 0)
    if (overall_success) then
        write(*,*) "✅ All comprehensive tests PASSED"
    else
        write(*,*) "❌ Some comprehensive tests FAILED"
    end if

    if (.not. overall_success) then
        error stop 1
    end if

contains

    subroutine test_comprehensive_comparison(fonts, num_fonts)
        !! Run comprehensive tests using modular test functions
        character(len=256), intent(in) :: fonts(:)
        integer, intent(in) :: num_fonts

        integer :: font_idx, fonts_tested, fonts_passed
        logical :: font_passed

        fonts_tested = min(num_fonts, 3)  ! Test up to 3 fonts
        fonts_passed = 0

        do font_idx = 1, fonts_tested
            write(*,'(A,I0,A,A)') "🔍 Testing font ", font_idx, ": ", &
                                  trim(fonts(font_idx))

            call test_single_font_all_modules(fonts(font_idx), font_passed)

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
                                 fonts_tested, " fonts passed all comprehensive tests"

    end subroutine test_comprehensive_comparison

    subroutine test_single_font_all_modules(font_path, success)
        !! Test a single font using all modular test functions
        character(len=*), intent(in) :: font_path
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

        ! Run all modular tests
        write(*,*) "  📊 Running metrics tests..."
        if (.not. test_font_metrics(stb_font, pure_font)) then
            call cleanup_fonts(stb_font, pure_font, stb_success, pure_success)
            return
        end if

        call test_metrics_functions(stb_font, pure_font)
        call test_bounding_box_functions(stb_font, pure_font)
        call test_os2_metrics_functions(stb_font, pure_font)
        call test_kerning_functions(stb_font, pure_font)

        write(*,*) "  🔤 Running mapping tests..."
        call test_glyph_mapping(stb_font, pure_font)
        call test_character_lookup(stb_font, pure_font)
        call test_glyph_indices(stb_font, pure_font)

        write(*,*) "  🖼️  Running bitmap tests..."
        call test_bitmap_boxes(stb_font, pure_font)
        call test_bitmap_rendering(stb_font, pure_font)
        call test_subpixel_rendering(stb_font, pure_font)

        call cleanup_fonts(stb_font, pure_font, stb_success, pure_success)
        success = .true.

    end subroutine test_single_font_all_modules

    subroutine cleanup_fonts(stb_font, pure_font, stb_success, pure_success)
        !! Clean up font resources
        type(stb_fontinfo_t), intent(inout) :: stb_font
        type(stb_fontinfo_pure_t), intent(inout) :: pure_font
        logical, intent(in) :: stb_success, pure_success

        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)

    end subroutine cleanup_fonts

end program test_stb_comparison