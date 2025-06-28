module fortplot_stb_bitmap
    !! Pure Fortran implementation of TrueType font bitmap rendering functionality
    !! Handles bitmap rendering, subpixel rendering, and bounding box calculations
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_truetype_types
    use fortplot_truetype_parser
    use fortplot_stb_mapping
    use fortplot_stb_metrics
    implicit none

    private

    ! Public interface
    public :: stb_get_codepoint_bitmap_box_pure
    public :: stb_get_codepoint_bitmap_pure
    public :: stb_make_codepoint_bitmap_pure
    public :: stb_free_bitmap_pure
    public :: stb_get_glyph_bitmap_pure
    public :: stb_get_glyph_bitmap_box_pure
    public :: stb_make_glyph_bitmap_pure
    public :: stb_get_codepoint_bitmap_subpixel_pure
    public :: stb_get_glyph_bitmap_subpixel_pure
    public :: stb_make_glyph_bitmap_subpixel_pure
    public :: stb_make_codepoint_bitmap_subpixel_pure
    public :: stb_get_glyph_bitmap_box_subpixel_pure
    public :: stb_get_codepoint_bitmap_box_subpixel_pure

contains

    subroutine stb_get_codepoint_bitmap_box_pure(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer :: char_x0, char_y0, char_x1, char_y1
        integer :: success

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Get character bounding box from glyf/head tables
        call stb_get_codepoint_box_pure(font_info, codepoint, &
                                       char_x0, char_y0, char_x1, char_y1)

        if (char_x0 == 0 .and. char_y0 == 0 .and. char_x1 == 0 .and. char_y1 == 0) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Scale the bounding box to bitmap coordinates
        ! Note: Y coordinates are flipped in bitmap space (top-down vs bottom-up)
        ix0 = floor(real(char_x0) * scale_x)
        iy0 = floor(real(-char_y1) * scale_y)  ! Flip Y and swap y0<->y1
        ix1 = ceiling(real(char_x1) * scale_x)
        iy1 = ceiling(real(-char_y0) * scale_y) ! Flip Y and swap y0<->y1

    end subroutine stb_get_codepoint_bitmap_box_pure

    function stb_get_codepoint_bitmap_pure(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Get bitmap bounding box
        call stb_get_codepoint_bitmap_box_pure(font_info, codepoint, scale_x, scale_y, &
                                              ix0, iy0, ix1, iy1)

        ! Calculate dimensions and offset
        width = ix1 - ix0
        height = iy1 - iy0
        xoff = ix0
        yoff = iy0

        ! Return null pointer for now (no actual rendering yet)
        bitmap_ptr = c_null_ptr

        ! TODO: Implement actual bitmap rendering
        ! TODO: Parse glyf table for outline data
        ! TODO: Implement curve-to-bitmap conversion with antialiasing

    end function stb_get_codepoint_bitmap_pure

    subroutine stb_make_codepoint_bitmap_pure(font_info, output_buffer, out_w, out_h, out_stride, scale_x, scale_y, codepoint)
        !! Render character into provided buffer (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint

        if (.not. font_info%initialized) return

        ! STUB: Do nothing

        ! TODO: Implement bitmap rendering into user buffer

    end subroutine stb_make_codepoint_bitmap_pure

    subroutine stb_free_bitmap_pure(bitmap_ptr)
        !! Free bitmap allocated by stb_get_codepoint_bitmap_pure (STUB)
        type(c_ptr), intent(in) :: bitmap_ptr

        ! STUB: Do nothing as we don't allocate real bitmaps yet

        ! TODO: Implement bitmap memory freeing

    end subroutine stb_free_bitmap_pure

    function stb_get_glyph_bitmap_pure(font_info, scale_x, scale_y, glyph, &
                                      width, height, xoff, yoff) &
             result(bitmap_ptr)
        !! Allocate and render glyph bitmap by glyph index (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: glyph
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! STUB: Return null pointer
        bitmap_ptr = c_null_ptr
        width = 0; height = 0; xoff = 0; yoff = 0

        ! TODO: Implement glyph bitmap rendering by index

    end function stb_get_glyph_bitmap_pure

    subroutine stb_get_glyph_bitmap_box_pure(font_info, glyph, scale_x, &
                                            scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for glyph bitmap (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! STUB: Return placeholder values
        ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0

        ! TODO: Implement glyph bitmap bounding box calculation

    end subroutine stb_get_glyph_bitmap_box_pure

    subroutine stb_make_glyph_bitmap_pure(font_info, output_buffer, out_w, &
                                         out_h, out_stride, scale_x, scale_y, &
                                         glyph)
        !! Render glyph into provided buffer (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: glyph

        if (.not. font_info%initialized) return

        ! STUB: Do nothing

        ! TODO: Implement glyph bitmap rendering into user buffer

    end subroutine stb_make_glyph_bitmap_pure

    function stb_get_codepoint_bitmap_subpixel_pure(font_info, scale_x, &
                                                   scale_y, shift_x, &
                                                   shift_y, codepoint, &
                                                   width, height, xoff, &
                                                   yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap with subpixel positioning (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! STUB: Return null pointer
        bitmap_ptr = c_null_ptr
        width = 0; height = 0; xoff = 0; yoff = 0

        ! TODO: Implement subpixel positioned bitmap rendering

    end function stb_get_codepoint_bitmap_subpixel_pure

    function stb_get_glyph_bitmap_subpixel_pure(font_info, scale_x, scale_y, &
                                               shift_x, shift_y, glyph, &
                                               width, height, xoff, yoff) &
             result(bitmap_ptr)
        !! Allocate and render glyph bitmap with subpixel positioning (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: glyph
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! STUB: Return null pointer
        bitmap_ptr = c_null_ptr
        width = 0; height = 0; xoff = 0; yoff = 0

        ! TODO: Implement subpixel positioned glyph bitmap rendering

    end function stb_get_glyph_bitmap_subpixel_pure

    subroutine stb_make_glyph_bitmap_subpixel_pure(font_info, output_buffer, &
                                                  out_w, out_h, out_stride, &
                                                  scale_x, scale_y, shift_x, &
                                                  shift_y, glyph)
        !! Render glyph into provided buffer with subpixel positioning (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: glyph

        if (.not. font_info%initialized) return

        ! STUB: Do nothing

        ! TODO: Implement subpixel positioned glyph bitmap rendering

    end subroutine stb_make_glyph_bitmap_subpixel_pure

    subroutine stb_make_codepoint_bitmap_subpixel_pure(font_info, &
                                                      output_buffer, out_w, &
                                                      out_h, out_stride, &
                                                      scale_x, scale_y, &
                                                      shift_x, shift_y, &
                                                      codepoint)
        !! Render character into provided buffer with subpixel positioning (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: codepoint

        if (.not. font_info%initialized) return

        ! STUB: Do nothing

        ! TODO: Implement subpixel positioned character bitmap rendering

    end subroutine stb_make_codepoint_bitmap_subpixel_pure

    subroutine stb_get_glyph_bitmap_box_subpixel_pure(font_info, glyph, &
                                                     scale_x, scale_y, &
                                                     shift_x, shift_y, &
                                                     ix0, iy0, ix1, iy1)
        !! Get bounding box for glyph bitmap with subpixel positioning (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(out) :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! STUB: Return placeholder values
        ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0

        ! TODO: Implement subpixel positioned glyph bitmap bounding box

    end subroutine stb_get_glyph_bitmap_box_subpixel_pure

    subroutine stb_get_codepoint_bitmap_box_subpixel_pure(font_info, &
                                                         codepoint, &
                                                         scale_x, scale_y, &
                                                         shift_x, shift_y, &
                                                         ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap with subpixel positioning (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(out) :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! STUB: Return placeholder values
        ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0

        ! TODO: Implement subpixel positioned character bitmap bounding box

    end subroutine stb_get_codepoint_bitmap_box_subpixel_pure

end module fortplot_stb_bitmap