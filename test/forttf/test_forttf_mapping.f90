program test_forttf_mapping
    !! Character mapping and glyph lookup tests for STB TrueType vs Pure Fortran
    !! Tests character-to-glyph mapping, glyph index lookup, and cmap functionality
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! Test execution
    call run_all_mapping_tests()

contains

    subroutine run_all_mapping_tests()
        !! Main test runner for all mapping tests
        logical :: all_tests_passed
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        write(*,*) "=== Running ForTTF Mapping Tests ==="
        all_tests_passed = .true.
        
        ! Use a default test font path
        font_path = "/usr/share/fonts/TTF/DejaVuSerif.ttf"
        if (.not. init_both_fonts(font_path, stb_font, pure_font, stb_success, pure_success)) then
            write(*,*) "❌ Failed to initialize test fonts"
            error stop 1
        end if
        
        ! Run all test subroutines
        call test_glyph_mapping(stb_font, pure_font)
        call test_character_lookup(stb_font, pure_font)
        call test_glyph_indices(stb_font, pure_font)
        
        ! Cleanup
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
        if (all_tests_passed) then
            write(*,*) "✅ All mapping tests passed!"
        else
            write(*,*) "❌ Some mapping tests failed!"
            error stop 1
        end if
    end subroutine run_all_mapping_tests

    subroutine test_glyph_mapping(stb_font, pure_font)
        !! Test character-to-glyph mapping consistency (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: test_chars(10)
        integer :: stb_glyph, pure_glyph
        integer :: i
        logical :: all_match

        write(*,*) "  Testing character-to-glyph mapping (TDD)..."
        all_match = .true.

        ! Test common ASCII characters
        test_chars = [iachar('A'), iachar('B'), iachar('a'), iachar('b'), &
                     iachar('0'), iachar('1'), iachar('!'), iachar('?'), &
                     iachar(' '), iachar('@')]

        do i = 1, size(test_chars)
            stb_glyph = stb_find_glyph_index(stb_font, test_chars(i))
            pure_glyph = stb_find_glyph_index_pure(pure_font, test_chars(i))

            write(*,'(A,I0,A,A,A,I0,A,I0)') "    Char ", test_chars(i), &
                    " ('", char(test_chars(i)), "'): STB=", stb_glyph, &
                    ", Pure=", pure_glyph

            if (stb_glyph == pure_glyph) then
                write(*,'(A,A,A)') "      ✅ Glyph index for '", &
                                  char(test_chars(i)), "' matches"
            else
                write(*,'(A,A,A)') "      ❌ Glyph index for '", &
                                  char(test_chars(i)), "' mismatch"
                all_match = .false.
            end if
        end do

        if (all_match) then
            write(*,*) "   ✅ All character-to-glyph mappings match"
        else
            write(*,*) "   ❌ Character-to-glyph mapping failed"
        end if

    end subroutine test_glyph_mapping

    subroutine test_character_lookup(stb_font, pure_font)
        !! Test character lookup edge cases (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: stb_glyph, pure_glyph
        logical :: all_match

        write(*,*) "  Testing character lookup edge cases (TDD)..."
        all_match = .true.

        ! Test 1: Missing glyph (should return 0)
        stb_glyph = stb_find_glyph_index(stb_font, 0)
        pure_glyph = stb_find_glyph_index_pure(pure_font, 0)

        write(*,'(A,I0,A,I0)') "    Null character (0): STB=", stb_glyph, &
                              ", Pure=", pure_glyph

        if (stb_glyph == pure_glyph) then
            write(*,*) "      ✅ Null character lookup matches"
        else
            write(*,*) "      ❌ Null character lookup mismatch"
            all_match = .false.
        end if

        ! Test 2: High Unicode codepoint
        stb_glyph = stb_find_glyph_index(stb_font, 65536)
        pure_glyph = stb_find_glyph_index_pure(pure_font, 65536)

        write(*,'(A,I0,A,I0)') "    High codepoint (65536): STB=", stb_glyph, &
                              ", Pure=", pure_glyph

        if (stb_glyph == pure_glyph) then
            write(*,*) "      ✅ High codepoint lookup matches"
        else
            write(*,*) "      ❌ High codepoint lookup mismatch"
            all_match = .false.
        end if

        ! Test 3: Unicode characters
        call test_unicode_char(stb_font, pure_font, 8364, "Euro symbol", all_match)  ! € symbol
        call test_unicode_char(stb_font, pure_font, 169, "Copyright symbol", all_match)  ! © symbol
        call test_unicode_char(stb_font, pure_font, 8212, "Em dash", all_match)  ! — symbol

        if (all_match) then
            write(*,*) "   ✅ All character lookup tests match"
        else
            write(*,*) "   ❌ Character lookup tests failed"
        end if

    end subroutine test_character_lookup

    subroutine test_unicode_char(stb_font, pure_font, codepoint, char_name, all_match)
        !! Test a specific Unicode character lookup
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        character(len=*), intent(in) :: char_name
        logical, intent(inout) :: all_match

        integer :: stb_glyph, pure_glyph

        stb_glyph = stb_find_glyph_index(stb_font, codepoint)
        pure_glyph = stb_find_glyph_index_pure(pure_font, codepoint)

        write(*,'(A,A,A,I0,A,I0,A,I0)') "    ", char_name, " (", codepoint, &
                ") STB=", stb_glyph, ", Pure=", pure_glyph

        if (stb_glyph == pure_glyph) then
            write(*,'(A,A,A)') "      ✅ ", char_name, " lookup matches"
        else
            write(*,'(A,A,A)') "      ❌ ", char_name, " lookup mismatch"
            all_match = .false.
        end if

    end subroutine test_unicode_char

    subroutine test_glyph_indices(stb_font, pure_font)
        !! Test glyph index consistency across common characters (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: alphabet_start, alphabet_end
        integer :: digit_start, digit_end
        integer :: stb_glyph, pure_glyph
        integer :: i, char_code
        logical :: all_match

        write(*,*) "  Testing glyph indices consistency (TDD)..."
        all_match = .true.

        ! Test 1: Uppercase alphabet A-Z
        alphabet_start = iachar('A')
        alphabet_end = iachar('Z')

        write(*,*) "    Testing uppercase alphabet A-Z..."
        do i = alphabet_start, alphabet_end
            stb_glyph = stb_find_glyph_index(stb_font, i)
            pure_glyph = stb_find_glyph_index_pure(pure_font, i)

            if (stb_glyph /= pure_glyph) then
                write(*,'(A,A,A,I0,A,I0)') "      ❌ Mismatch for '", &
                        char(i), "': STB=", stb_glyph, ", Pure=", pure_glyph
                all_match = .false.
            end if
        end do

        if (all_match) then
            write(*,*) "      ✅ Uppercase alphabet indices match"
        end if

        ! Test 2: Lowercase alphabet a-z
        alphabet_start = iachar('a')
        alphabet_end = iachar('z')

        write(*,*) "    Testing lowercase alphabet a-z..."
        do i = alphabet_start, alphabet_end
            stb_glyph = stb_find_glyph_index(stb_font, i)
            pure_glyph = stb_find_glyph_index_pure(pure_font, i)

            if (stb_glyph /= pure_glyph) then
                write(*,'(A,A,A,I0,A,I0)') "      ❌ Mismatch for '", &
                        char(i), "': STB=", stb_glyph, ", Pure=", pure_glyph
                all_match = .false.
            end if
        end do

        if (all_match) then
            write(*,*) "      ✅ Lowercase alphabet indices match"
        end if

        ! Test 3: Digits 0-9
        digit_start = iachar('0')
        digit_end = iachar('9')

        write(*,*) "    Testing digits 0-9..."
        do i = digit_start, digit_end
            stb_glyph = stb_find_glyph_index(stb_font, i)
            pure_glyph = stb_find_glyph_index_pure(pure_font, i)

            if (stb_glyph /= pure_glyph) then
                write(*,'(A,A,A,I0,A,I0)') "      ❌ Mismatch for '", &
                        char(i), "': STB=", stb_glyph, ", Pure=", pure_glyph
                all_match = .false.
            end if
        end do

        if (all_match) then
            write(*,*) "      ✅ Digit indices match"
        end if

        ! Test 4: Common punctuation
        call test_punctuation_glyph(stb_font, pure_font, iachar('.'), "period", all_match)
        call test_punctuation_glyph(stb_font, pure_font, iachar(','), "comma", all_match)
        call test_punctuation_glyph(stb_font, pure_font, iachar(';'), "semicolon", all_match)
        call test_punctuation_glyph(stb_font, pure_font, iachar(':'), "colon", all_match)
        call test_punctuation_glyph(stb_font, pure_font, iachar('!'), "exclamation", all_match)
        call test_punctuation_glyph(stb_font, pure_font, iachar('?'), "question", all_match)

        if (all_match) then
            write(*,*) "   ✅ All glyph indices consistency tests match"
        else
            write(*,*) "   ❌ Glyph indices consistency tests failed"
        end if

    end subroutine test_glyph_indices

    subroutine test_punctuation_glyph(stb_font, pure_font, char_code, char_name, all_match)
        !! Test a specific punctuation character glyph index
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: char_code
        character(len=*), intent(in) :: char_name
        logical, intent(inout) :: all_match

        integer :: stb_glyph, pure_glyph

        stb_glyph = stb_find_glyph_index(stb_font, char_code)
        pure_glyph = stb_find_glyph_index_pure(pure_font, char_code)

        write(*,'(A,A,A,A,A,I0,A,I0)') "    ", char_name, " ('", &
                char(char_code), "'): STB=", stb_glyph, ", Pure=", pure_glyph

        if (stb_glyph == pure_glyph) then
            write(*,'(A,A,A)') "      ✅ ", char_name, " glyph index matches"
        else
            write(*,'(A,A,A)') "      ❌ ", char_name, " glyph index mismatch"
            all_match = .false.
        end if

    end subroutine test_punctuation_glyph

end program test_forttf_mapping