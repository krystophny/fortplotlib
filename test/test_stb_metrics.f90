module test_stb_metrics
    !! Metrics comparison tests for STB TrueType vs Pure Fortran
    !! Tests horizontal metrics, vertical metrics, OS/2 metrics, and kerning
    use fortplot_stb_truetype
    use fortplot_stb
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    private

    ! Public interface
    public :: test_font_metrics
    public :: test_metrics_functions
    public :: test_bounding_box_functions
    public :: test_os2_metrics_functions
    public :: test_kerning_functions

contains

    function test_font_metrics(stb_font, pure_font) result(success)
        !! Test basic font metrics consistency
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        logical :: success

        real(wp) :: stb_scale, pure_scale
        integer :: stb_ascent, stb_descent, stb_line_gap
        integer :: pure_ascent, pure_descent, pure_line_gap

        ! Test scale factor calculation
        stb_scale = stb_scale_for_pixel_height(stb_font, 16.0_wp)
        pure_scale = stb_scale_for_pixel_height_pure(pure_font, 16.0_wp)

        ! Test vertical metrics
        call stb_get_font_vmetrics(stb_font, stb_ascent, stb_descent, stb_line_gap)
        call stb_get_font_vmetrics_pure(pure_font, pure_ascent, pure_descent, pure_line_gap)

        ! Check if metrics match
        success = (abs(stb_scale - pure_scale) < 1e-6_wp) .and. &
                  (stb_ascent == pure_ascent) .and. &
                  (stb_descent == pure_descent) .and. &
                  (stb_line_gap == pure_line_gap)

        if (success) then
            write(*,'(A,F8.6)') "    ✓ Metrics and scale factors match (scale: ", stb_scale, ")"
        else
            write(*,*) "    ❌ Metrics mismatch"
            write(*,'(A,F8.6,A,F8.6)') "      Scale: STB=", stb_scale, ", Pure=", pure_scale
            write(*,'(A,3I6,A,3I6)') "      Vmetrics: STB=(", stb_ascent, stb_descent, stb_line_gap, &
                                    "), Pure=(", pure_ascent, pure_descent, pure_line_gap, ")"
        end if

    end function test_font_metrics

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

        if (metrics_match) then
            write(*,*) "     ✅ Horizontal metrics match"
        else
            write(*,*) "     ❌ Horizontal metrics mismatch"
        end if

        ! Test 2: stb_scale_for_mapping_em_to_pixels comparison
        stb_em_scale = stb_scale_for_mapping_em_to_pixels(stb_font, 16.0_wp)
        pure_em_scale = stb_scale_for_mapping_em_to_pixels_pure(pure_font, 16.0_wp)

        write(*,'(A,F8.6,A,F8.6)') "    EM scale for 16px: STB=", stb_em_scale, ", Pure=", pure_em_scale

        if (abs(stb_em_scale - pure_em_scale) < 1e-6_wp) then
            write(*,*) "     ✅ EM scale matches"
        else
            write(*,*) "     ❌ EM scale mismatch"
        end if

        if (metrics_match .and. abs(stb_em_scale - pure_em_scale) < 1e-6_wp) then
            write(*,*) "   ✅ All metrics functions match"
        else
            write(*,*) "   ❌ Metrics functions failed"
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

        if (bbox_match) then
            write(*,*) "     ✅ Font bounding box matches"
        else
            write(*,*) "     ❌ Font bounding box mismatch"
        end if

        ! Test 2: stb_get_codepoint_box comparison
        test_codepoint = iachar('A')
        call stb_get_codepoint_box(stb_font, test_codepoint, stb_x0, stb_y0, stb_x1, stb_y1)
        call stb_get_codepoint_box_pure(pure_font, test_codepoint, pure_x0, pure_y0, pure_x1, pure_y1)

        write(*,'(A,4I6,A,4I6)') "    Char 'A' bbox: STB=(", stb_x0, stb_y0, stb_x1, stb_y1, &
                                "), Pure=(", pure_x0, pure_y0, pure_x1, pure_y1, ")"

        bbox_match = bbox_match .and. (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. &
                                      stb_x1 == pure_x1 .and. stb_y1 == pure_y1)

        if (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. &
            stb_x1 == pure_x1 .and. stb_y1 == pure_y1) then
            write(*,*) "     ✅ Character bounding box matches"
        else
            write(*,*) "     ❌ Character bounding box mismatch"
        end if

        ! Test 3: stb_get_glyph_box comparison
        test_glyph_index = stb_find_glyph_index(stb_font, test_codepoint)
        call stb_get_glyph_box(stb_font, test_glyph_index, stb_x0, stb_y0, stb_x1, stb_y1)
        call stb_get_glyph_box_pure(pure_font, test_glyph_index, pure_x0, pure_y0, pure_x1, pure_y1)

        write(*,'(A,I0,A,4I6,A,4I6)') "    Glyph ", test_glyph_index, " bbox: STB=(", &
                                     stb_x0, stb_y0, stb_x1, stb_y1, "), Pure=(", pure_x0, pure_y0, pure_x1, pure_y1, ")"

        bbox_match = bbox_match .and. (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. &
                                      stb_x1 == pure_x1 .and. stb_y1 == pure_y1)

        if (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. &
            stb_x1 == pure_x1 .and. stb_y1 == pure_y1) then
            write(*,*) "     ✅ Glyph bounding box matches"
        else
            write(*,*) "     ❌ Glyph bounding box mismatch"
        end if

        if (bbox_match) then
            write(*,*) "   ✅ All bounding box functions match"
        else
            write(*,*) "   ❌ Bounding box functions failed"
        end if

    end subroutine test_bounding_box_functions

    subroutine test_os2_metrics_functions(stb_font, pure_font)
        !! Test Level 8: OS/2 Metrics (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: stb_typo_ascent, stb_typo_descent, stb_typo_line_gap
        integer :: pure_typo_ascent, pure_typo_descent, pure_typo_line_gap
        integer :: stb_success, pure_success
        logical :: os2_match

        write(*,*) "  Testing OS/2 metrics functions (TDD)..."

        ! Test OS/2 table vertical metrics
        stb_success = stb_get_font_vmetrics_os2(stb_font, stb_typo_ascent, stb_typo_descent, stb_typo_line_gap)
        pure_success = stb_get_font_vmetrics_os2_pure(pure_font, pure_typo_ascent, pure_typo_descent, pure_typo_line_gap)

        write(*,'(A,3I6,A,I0,A,3I6)') "    OS/2 metrics: STB=(", stb_typo_ascent, stb_typo_descent, stb_typo_line_gap, &
                                     "), Pure=", pure_success, " (", pure_typo_ascent, pure_typo_descent, pure_typo_line_gap, ")"

        os2_match = (stb_success == pure_success) .and. &
                    (stb_typo_ascent == pure_typo_ascent) .and. &
                    (stb_typo_descent == pure_typo_descent) .and. &
                    (stb_typo_line_gap == pure_typo_line_gap)

        if (os2_match) then
            write(*,*) "     ✅ OS/2 metrics match"
        else
            write(*,*) "     ❌ OS/2 metrics mismatch"
        end if

        if (os2_match) then
            write(*,*) "   ✅ All OS/2 metrics functions match"
        else
            write(*,*) "   ❌ OS/2 metrics functions failed"
        end if

    end subroutine test_os2_metrics_functions

    subroutine test_kerning_functions(stb_font, pure_font)
        !! Test Level 9: Kerning Support (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(inout) :: pure_font
        integer :: stb_kern, pure_kern
        integer :: stb_table_length, pure_table_length
        logical :: all_match

        write(*,*) "  Testing kerning functions (TDD)..."
        all_match = .true.

        ! Test 1: Codepoint kerning A-V
        stb_kern = stb_get_codepoint_kern_advance(stb_font, iachar('A'), iachar('V'))
        pure_kern = stb_get_codepoint_kern_advance_pure(pure_font, iachar('A'), iachar('V'))

        write(*,'(A,I0,A,I0)') "  Codepoint kerning A-V: STB=", stb_kern, ", Pure=", pure_kern

        if (stb_kern == pure_kern) then
            write(*,*) "     ✅ Codepoint kerning A-V matches"
        else
            write(*,*) "     ❌ Codepoint kerning A-V mismatch"
            all_match = .false.
        end if

        ! Test 2: Glyph kerning A-V
        stb_kern = stb_get_glyph_kern_advance(stb_font, stb_find_glyph_index(stb_font, iachar('A')), &
                                                        stb_find_glyph_index(stb_font, iachar('V')))
        pure_kern = stb_get_glyph_kern_advance_pure(pure_font, stb_find_glyph_index_pure(pure_font, iachar('A')), &
                                                               stb_find_glyph_index_pure(pure_font, iachar('V')))

        write(*,'(A,I0,A,I0)') "  Glyph kerning A-V: STB=", stb_kern, ", Pure=", pure_kern

        if (stb_kern == pure_kern) then
            write(*,*) "     ✅ Glyph kerning A-V matches"
        else
            write(*,*) "     ❌ Glyph kerning A-V mismatch"
            all_match = .false.
        end if

        ! Test 3: Kerning table length
        stb_table_length = stb_get_kerning_table_length(stb_font)
        pure_table_length = stb_get_kerning_table_length_pure(pure_font)

        write(*,'(A,I0,A,I0)') "  Kerning table length: STB=", stb_table_length, ", Pure=", pure_table_length

        if (stb_table_length == pure_table_length) then
            write(*,*) "     ✅ Kerning table length matches"
        else
            write(*,*) "     ❌ Kerning table length mismatch"
            all_match = .false.
        end if

        ! Test additional kerning pairs
        call test_kerning_pair(stb_font, pure_font, iachar('A'), iachar('W'), 'A-W', all_match)
        call test_kerning_pair(stb_font, pure_font, iachar('T'), iachar('o'), 'T-o', all_match)
        call test_kerning_pair(stb_font, pure_font, iachar('V'), iachar('A'), 'V-A', all_match)

        if (all_match) then
            write(*,*) "   ✅ All kerning functions match"
        else
            write(*,*) "   ❌ Kerning functions failed"
        end if

    end subroutine test_kerning_functions

    subroutine test_kerning_pair(stb_font, pure_font, ch1, ch2, pair_name, all_match)
        !! Test a specific kerning pair
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(inout) :: pure_font
        integer, intent(in) :: ch1, ch2
        character(len=*), intent(in) :: pair_name
        logical, intent(inout) :: all_match

        integer :: stb_kern, pure_kern

        stb_kern = stb_get_codepoint_kern_advance(stb_font, ch1, ch2)
        pure_kern = stb_get_codepoint_kern_advance_pure(pure_font, ch1, ch2)

        write(*,'(A,A,A,I0,A,I0)') "  Kerning ", pair_name, ": STB=", stb_kern, ", Pure=", pure_kern

        if (stb_kern == pure_kern) then
            write(*,'(A,A,A)') "    ✅ Kerning ", pair_name, " matches"
        else
            write(*,'(A,A,A)') "    ❌ Kerning ", pair_name, " mismatch"
            all_match = .false.
        end if

    end subroutine test_kerning_pair

end module test_stb_metrics