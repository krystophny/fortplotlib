module test_stb_bitmap
    !! Bitmap rendering tests for STB TrueType vs Pure Fortran
    !! Tests bitmap box calculations, rendering functions, and subpixel positioning
    use fortplot_stb_truetype
    use fortplot_stb
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    private

    ! Public interface
    public :: test_bitmap_boxes
    public :: test_bitmap_rendering
    public :: test_subpixel_rendering

contains

    subroutine test_bitmap_boxes(stb_font, pure_font)
        !! Test bitmap bounding box calculations (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer :: stb_ix0, stb_iy0, stb_ix1, stb_iy1
        integer :: pure_ix0, pure_iy0, pure_ix1, pure_iy1
        real(wp) :: scale_x, scale_y
        integer :: test_codepoint
        logical :: all_match

        write(*,*) "  Testing bitmap bounding boxes (TDD)..."
        all_match = .true.

        ! Test scale factors
        scale_x = 1.0_wp
        scale_y = 1.0_wp

        ! Test 1: Character 'A' bitmap box
        test_codepoint = iachar('A')
        call stb_get_codepoint_bitmap_box(stb_font, test_codepoint, scale_x, scale_y, &
                                         stb_ix0, stb_iy0, stb_ix1, stb_iy1)
        call stb_get_codepoint_bitmap_box_pure(pure_font, test_codepoint, scale_x, scale_y, &
                                              pure_ix0, pure_iy0, pure_ix1, pure_iy1)

        write(*,'(A,4I6,A,4I6)') "    Char 'A' bitmap box: STB=(", &
                stb_ix0, stb_iy0, stb_ix1, stb_iy1, "), Pure=(", &
                pure_ix0, pure_iy0, pure_ix1, pure_iy1, ")"

        if (stb_ix0 == pure_ix0 .and. stb_iy0 == pure_iy0 .and. &
            stb_ix1 == pure_ix1 .and. stb_iy1 == pure_iy1) then
            write(*,*) "      ✅ Character 'A' bitmap box matches"
        else
            write(*,*) "      ❌ Character 'A' bitmap box mismatch"
            all_match = .false.
        end if

        ! Test 2: Character 'g' bitmap box (descender)
        test_codepoint = iachar('g')
        call stb_get_codepoint_bitmap_box(stb_font, test_codepoint, scale_x, scale_y, &
                                         stb_ix0, stb_iy0, stb_ix1, stb_iy1)
        call stb_get_codepoint_bitmap_box_pure(pure_font, test_codepoint, scale_x, scale_y, &
                                              pure_ix0, pure_iy0, pure_ix1, pure_iy1)

        write(*,'(A,4I6,A,4I6)') "    Char 'g' bitmap box: STB=(", &
                stb_ix0, stb_iy0, stb_ix1, stb_iy1, "), Pure=(", &
                pure_ix0, pure_iy0, pure_ix1, pure_iy1, ")"

        if (stb_ix0 == pure_ix0 .and. stb_iy0 == pure_iy0 .and. &
            stb_ix1 == pure_ix1 .and. stb_iy1 == pure_iy1) then
            write(*,*) "      ✅ Character 'g' bitmap box matches"
        else
            write(*,*) "      ❌ Character 'g' bitmap box mismatch"
            all_match = .false.
        end if

        ! Test 3: Different scale factors
        scale_x = 2.0_wp
        scale_y = 2.0_wp
        call test_bitmap_box_scale(stb_font, pure_font, iachar('M'), scale_x, scale_y, all_match)

        scale_x = 0.5_wp
        scale_y = 0.5_wp
        call test_bitmap_box_scale(stb_font, pure_font, iachar('W'), scale_x, scale_y, all_match)

        if (all_match) then
            write(*,*) "   ✅ All bitmap box calculations match"
        else
            write(*,*) "   ❌ Bitmap box calculations failed"
        end if

    end subroutine test_bitmap_boxes

    subroutine test_bitmap_box_scale(stb_font, pure_font, codepoint, scale_x, scale_y, all_match)
        !! Test bitmap box calculation with specific scale factors
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        logical, intent(inout) :: all_match

        integer :: stb_ix0, stb_iy0, stb_ix1, stb_iy1
        integer :: pure_ix0, pure_iy0, pure_ix1, pure_iy1

        call stb_get_codepoint_bitmap_box(stb_font, codepoint, scale_x, scale_y, &
                                         stb_ix0, stb_iy0, stb_ix1, stb_iy1)
        call stb_get_codepoint_bitmap_box_pure(pure_font, codepoint, scale_x, scale_y, &
                                              pure_ix0, pure_iy0, pure_ix1, pure_iy1)

        write(*,'(A,A,A,F4.1,A,F4.1,A,4I6,A,4I6)') "    Char '", char(codepoint), &
                "' scale (", scale_x, ",", scale_y, "): STB=(", &
                stb_ix0, stb_iy0, stb_ix1, stb_iy1, "), Pure=(", &
                pure_ix0, pure_iy0, pure_ix1, pure_iy1, ")"

        if (stb_ix0 == pure_ix0 .and. stb_iy0 == pure_iy0 .and. &
            stb_ix1 == pure_ix1 .and. stb_iy1 == pure_iy1) then
            write(*,'(A,A,A)') "      ✅ Scaled bitmap box for '", char(codepoint), "' matches"
        else
            write(*,'(A,A,A)') "      ❌ Scaled bitmap box for '", char(codepoint), "' mismatch"
            all_match = .false.
        end if

    end subroutine test_bitmap_box_scale

    subroutine test_bitmap_rendering(stb_font, pure_font)
        !! Test bitmap rendering functions (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        type(c_ptr) :: stb_bitmap, pure_bitmap
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        real(wp) :: scale_x, scale_y
        integer :: test_codepoint
        logical :: all_match

        write(*,*) "  Testing bitmap rendering functions (TDD)..."
        all_match = .true.

        scale_x = 1.0_wp
        scale_y = 1.0_wp

        ! Test 1: Character 'A' bitmap rendering
        test_codepoint = iachar('A')
        stb_bitmap = stb_get_codepoint_bitmap(stb_font, scale_x, scale_y, test_codepoint, &
                                            stb_width, stb_height, stb_xoff, stb_yoff)
        pure_bitmap = stb_get_codepoint_bitmap_pure(pure_font, scale_x, scale_y, test_codepoint, &
                                                   pure_width, pure_height, pure_xoff, pure_yoff)

        write(*,'(A,4I6,A,4I6)') "    Char 'A' bitmap: STB=(", &
                stb_width, stb_height, stb_xoff, stb_yoff, "), Pure=(", &
                pure_width, pure_height, pure_xoff, pure_yoff, ")"

        ! Note: Pure implementation returns null bitmap pointer for now (stub)
        if (stb_width == pure_width .and. stb_height == pure_height .and. &
            stb_xoff == pure_xoff .and. stb_yoff == pure_yoff) then
            write(*,*) "      ✅ Character 'A' bitmap dimensions match"
        else
            write(*,*) "      ❌ Character 'A' bitmap dimensions mismatch"
            all_match = .false.
        end if

        ! Clean up STB bitmap (Pure returns null, so no cleanup needed)
        if (c_associated(stb_bitmap)) then
            call stb_free_bitmap(stb_bitmap)
        end if

        ! Test 2: Glyph bitmap rendering
        call test_glyph_bitmap_rendering(stb_font, pure_font, test_codepoint, scale_x, scale_y, all_match)

        if (all_match) then
            write(*,*) "   ✅ All bitmap rendering functions match"
        else
            write(*,*) "   ❌ Bitmap rendering functions failed"
        end if

    end subroutine test_bitmap_rendering

    subroutine test_glyph_bitmap_rendering(stb_font, pure_font, codepoint, scale_x, scale_y, all_match)
        !! Test glyph bitmap rendering by glyph index
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        logical, intent(inout) :: all_match

        integer :: glyph_index
        type(c_ptr) :: stb_bitmap, pure_bitmap
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer :: pure_width, pure_height, pure_xoff, pure_yoff

        ! Get glyph index
        glyph_index = stb_find_glyph_index(stb_font, codepoint)

        ! Test glyph bitmap rendering
        stb_bitmap = stb_get_glyph_bitmap(stb_font, scale_x, scale_y, glyph_index, &
                                        stb_width, stb_height, stb_xoff, stb_yoff)
        pure_bitmap = stb_get_glyph_bitmap_pure(pure_font, scale_x, scale_y, glyph_index, &
                                              pure_width, pure_height, pure_xoff, pure_yoff)

        write(*,'(A,I0,A,4I6,A,4I6)') "    Glyph ", glyph_index, " bitmap: STB=(", &
                stb_width, stb_height, stb_xoff, stb_yoff, "), Pure=(", &
                pure_width, pure_height, pure_xoff, pure_yoff, ")"

        if (stb_width == pure_width .and. stb_height == pure_height .and. &
            stb_xoff == pure_xoff .and. stb_yoff == pure_yoff) then
            write(*,'(A,I0,A)') "      ✅ Glyph ", glyph_index, " bitmap dimensions match"
        else
            write(*,'(A,I0,A)') "      ❌ Glyph ", glyph_index, " bitmap dimensions mismatch"
            all_match = .false.
        end if

        ! Clean up STB bitmap
        if (c_associated(stb_bitmap)) then
            call stb_free_bitmap(stb_bitmap)
        end if

    end subroutine test_glyph_bitmap_rendering

    subroutine test_subpixel_rendering(stb_font, pure_font)
        !! Test subpixel positioning bitmap rendering (TDD)
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        type(c_ptr) :: stb_bitmap, pure_bitmap
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        real(wp) :: scale_x, scale_y, shift_x, shift_y
        integer :: test_codepoint, glyph_index
        logical :: all_match

        write(*,*) "  Testing subpixel positioning rendering (TDD)..."
        all_match = .true.

        scale_x = 1.0_wp
        scale_y = 1.0_wp
        shift_x = 0.25_wp
        shift_y = 0.5_wp

        ! Test 1: Character subpixel bitmap
        test_codepoint = iachar('A')
        stb_bitmap = stb_get_codepoint_bitmap_subpixel(stb_font, scale_x, scale_y, &
                                                      shift_x, shift_y, test_codepoint, &
                                                      stb_width, stb_height, stb_xoff, stb_yoff)
        pure_bitmap = stb_get_codepoint_bitmap_subpixel_pure(pure_font, scale_x, scale_y, &
                                                            shift_x, shift_y, test_codepoint, &
                                                            pure_width, pure_height, pure_xoff, pure_yoff)

        write(*,'(A,4I6,A,4I6)') "    Char 'A' subpixel bitmap: STB=(", &
                stb_width, stb_height, stb_xoff, stb_yoff, "), Pure=(", &
                pure_width, pure_height, pure_xoff, pure_yoff, ")"

        if (stb_width == pure_width .and. stb_height == pure_height .and. &
            stb_xoff == pure_xoff .and. stb_yoff == pure_yoff) then
            write(*,*) "      ✅ Character 'A' subpixel bitmap dimensions match"
        else
            write(*,*) "      ❌ Character 'A' subpixel bitmap dimensions mismatch"
            all_match = .false.
        end if

        ! Clean up STB bitmap
        if (c_associated(stb_bitmap)) then
            call stb_free_bitmap(stb_bitmap)
        end if

        ! Test 2: Glyph subpixel bitmap
        glyph_index = stb_find_glyph_index(stb_font, test_codepoint)
        stb_bitmap = stb_get_glyph_bitmap_subpixel(stb_font, scale_x, scale_y, &
                                                  shift_x, shift_y, glyph_index, &
                                                  stb_width, stb_height, stb_xoff, stb_yoff)
        pure_bitmap = stb_get_glyph_bitmap_subpixel_pure(pure_font, scale_x, scale_y, &
                                                        shift_x, shift_y, glyph_index, &
                                                        pure_width, pure_height, pure_xoff, pure_yoff)

        write(*,'(A,I0,A,4I6,A,4I6)') "    Glyph ", glyph_index, " subpixel bitmap: STB=(", &
                stb_width, stb_height, stb_xoff, stb_yoff, "), Pure=(", &
                pure_width, pure_height, pure_xoff, pure_yoff, ")"

        if (stb_width == pure_width .and. stb_height == pure_height .and. &
            stb_xoff == pure_xoff .and. stb_yoff == pure_yoff) then
            write(*,'(A,I0,A)') "      ✅ Glyph ", glyph_index, " subpixel bitmap dimensions match"
        else
            write(*,'(A,I0,A)') "      ❌ Glyph ", glyph_index, " subpixel bitmap dimensions mismatch"
            all_match = .false.
        end if

        ! Clean up STB bitmap
        if (c_associated(stb_bitmap)) then
            call stb_free_bitmap(stb_bitmap)
        end if

        ! Test 3: Subpixel bitmap boxes
        call test_subpixel_bitmap_boxes(stb_font, pure_font, test_codepoint, glyph_index, &
                                       scale_x, scale_y, shift_x, shift_y, all_match)

        if (all_match) then
            write(*,*) "   ✅ All subpixel rendering functions match"
        else
            write(*,*) "   ❌ Subpixel rendering functions failed"
        end if

    end subroutine test_subpixel_rendering

    subroutine test_subpixel_bitmap_boxes(stb_font, pure_font, codepoint, glyph_index, &
                                         scale_x, scale_y, shift_x, shift_y, all_match)
        !! Test subpixel bitmap bounding boxes
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint, glyph_index
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        logical, intent(inout) :: all_match

        integer :: stb_ix0, stb_iy0, stb_ix1, stb_iy1
        integer :: pure_ix0, pure_iy0, pure_ix1, pure_iy1

        ! Test character subpixel bitmap box
        call stb_get_codepoint_bitmap_box_subpixel(stb_font, codepoint, scale_x, scale_y, &
                                                  shift_x, shift_y, stb_ix0, stb_iy0, stb_ix1, stb_iy1)
        call stb_get_codepoint_bitmap_box_subpixel_pure(pure_font, codepoint, scale_x, scale_y, &
                                                        shift_x, shift_y, pure_ix0, pure_iy0, pure_ix1, pure_iy1)

        write(*,'(A,4I6,A,4I6)') "    Char subpixel bitmap box: STB=(", &
                stb_ix0, stb_iy0, stb_ix1, stb_iy1, "), Pure=(", &
                pure_ix0, pure_iy0, pure_ix1, pure_iy1, ")"

        if (stb_ix0 == pure_ix0 .and. stb_iy0 == pure_iy0 .and. &
            stb_ix1 == pure_ix1 .and. stb_iy1 == pure_iy1) then
            write(*,*) "      ✅ Character subpixel bitmap box matches"
        else
            write(*,*) "      ❌ Character subpixel bitmap box mismatch"
            all_match = .false.
        end if

        ! Test glyph subpixel bitmap box
        call stb_get_glyph_bitmap_box_subpixel(stb_font, glyph_index, scale_x, scale_y, &
                                              shift_x, shift_y, stb_ix0, stb_iy0, stb_ix1, stb_iy1)
        call stb_get_glyph_bitmap_box_subpixel_pure(pure_font, glyph_index, scale_x, scale_y, &
                                                    shift_x, shift_y, pure_ix0, pure_iy0, pure_ix1, pure_iy1)

        write(*,'(A,I0,A,4I6,A,4I6)') "    Glyph ", glyph_index, " subpixel bitmap box: STB=(", &
                stb_ix0, stb_iy0, stb_ix1, stb_iy1, "), Pure=(", &
                pure_ix0, pure_iy0, pure_ix1, pure_iy1, ")"

        if (stb_ix0 == pure_ix0 .and. stb_iy0 == pure_iy0 .and. &
            stb_ix1 == pure_ix1 .and. stb_iy1 == pure_iy1) then
            write(*,'(A,I0,A)') "      ✅ Glyph ", glyph_index, " subpixel bitmap box matches"
        else
            write(*,'(A,I0,A)') "      ❌ Glyph ", glyph_index, " subpixel bitmap box mismatch"
            all_match = .false.
        end if

    end subroutine test_subpixel_bitmap_boxes

end module test_stb_bitmap