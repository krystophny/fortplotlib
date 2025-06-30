program test_forttf_bbox_comparison
    !! Debug test to compare bitmap bounding box calculations between STB and Pure Fortran
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call debug_bbox_calculations()

contains

    subroutine debug_bbox_calculations()
        !! Compare bounding box calculations step by step
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.5_wp

        ! Character-level bounding boxes
        integer :: stb_char_x0, stb_char_y0, stb_char_x1, stb_char_y1
        integer :: pure_char_x0, pure_char_y0, pure_char_x1, pure_char_y1

        ! Bitmap-level bounding boxes
        integer :: stb_bitmap_x0, stb_bitmap_y0, stb_bitmap_x1, stb_bitmap_y1
        integer :: pure_bitmap_x0, pure_bitmap_y0, pure_bitmap_x1, pure_bitmap_y1

        write(*,*) "=== Debugging Bitmap Bounding Box Calculations ==="

        ! Find and initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)

        ! Step 1: Compare character bounding boxes (font units)
        write(*,*) "--- Step 1: Character Bounding Boxes (font units) ---"
        call stb_get_codepoint_box(stb_font, codepoint_a, stb_char_x0, stb_char_y0, stb_char_x1, stb_char_y1)
        call stb_get_codepoint_box_pure(pure_font, codepoint_a, pure_char_x0, pure_char_y0, pure_char_x1, pure_char_y1)

        write(*,*) "STB char box (font units):  (", stb_char_x0, stb_char_y0, stb_char_x1, stb_char_y1, ")"
        write(*,*) "Pure char box (font units): (", pure_char_x0, pure_char_y0, pure_char_x1, pure_char_y1, ")"

        if (stb_char_x0 == pure_char_x0 .and. stb_char_y0 == pure_char_y0 .and. &
            stb_char_x1 == pure_char_x1 .and. stb_char_y1 == pure_char_y1) then
            write(*,*) "✅ Character bounding boxes match"
        else
            write(*,*) "❌ Character bounding boxes differ"
        end if

        ! Step 2: Compare bitmap bounding boxes (pixel units)
        write(*,*) "--- Step 2: Bitmap Bounding Boxes (pixel units) ---"
        call stb_get_codepoint_bitmap_box(stb_font, codepoint_a, scale, scale, &
                                         stb_bitmap_x0, stb_bitmap_y0, stb_bitmap_x1, stb_bitmap_y1)
        call stb_get_codepoint_bitmap_box_pure(pure_font, codepoint_a, scale, scale, &
                                              pure_bitmap_x0, pure_bitmap_y0, pure_bitmap_x1, pure_bitmap_y1)

        write(*,*) "STB bitmap box (pixels):  (", stb_bitmap_x0, stb_bitmap_y0, stb_bitmap_x1, stb_bitmap_y1, ")"
        write(*,*) "Pure bitmap box (pixels): (", pure_bitmap_x0, pure_bitmap_y0, pure_bitmap_x1, pure_bitmap_y1, ")"

        if (stb_bitmap_x0 == pure_bitmap_x0 .and. stb_bitmap_y0 == pure_bitmap_y0 .and. &
            stb_bitmap_x1 == pure_bitmap_x1 .and. stb_bitmap_y1 == pure_bitmap_y1) then
            write(*,*) "✅ Bitmap bounding boxes match"
        else
            write(*,*) "❌ Bitmap bounding boxes differ"
        end if

        ! Step 3: Manual calculation of transformation
        write(*,*) "--- Step 3: Manual Transformation Analysis ---"
        write(*,*) "Scale factor:", scale
        write(*,*) "Font units → pixels transformation:"
        write(*,*) "  STB formula: floor/ceiling of (coord * scale)"
        write(*,*) "  Pure formula: floor/ceiling of (coord * scale) with Y-flip"

        ! Show manual calculations
        write(*,*) "Manual calculations for Pure Fortran:"
        write(*,*) "  ix0 = floor(", pure_char_x0, " * ", scale, ") =", floor(real(pure_char_x0) * scale)
        write(*,*) "  iy0 = floor(", -pure_char_y1, " * ", scale, ") =", floor(real(-pure_char_y1) * scale)  ! Y-flip
        write(*,*) "  ix1 = ceiling(", pure_char_x1, " * ", scale, ") =", ceiling(real(pure_char_x1) * scale)
        write(*,*) "  iy1 = ceiling(", -pure_char_y0, " * ", scale, ") =", ceiling(real(-pure_char_y0) * scale) ! Y-flip

        ! Cleanup
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)

    end subroutine debug_bbox_calculations

end program test_forttf_bbox_comparison
