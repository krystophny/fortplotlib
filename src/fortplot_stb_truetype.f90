module fortplot_stb_truetype
    !! Backend-agnostic text rendering using native Fortran TrueType implementation
    !! Provides compatibility interface that was previously backed by stb_truetype.h
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    use fortplot_truetype_native
    use fortplot_truetype_parser, only: parse_glyph_header
    implicit none

    private
    public :: stb_fontinfo_t, stb_init_font, stb_cleanup_font
    public :: stb_get_codepoint_bitmap, stb_free_bitmap
    public :: stb_get_codepoint_hmetrics, stb_get_font_vmetrics
    public :: stb_scale_for_pixel_height, stb_get_codepoint_bitmap_box
    public :: stb_find_glyph_index, stb_make_codepoint_bitmap
    public :: stb_get_glyph_box
    public :: STB_SUCCESS, STB_ERROR

    ! Constants
    integer, parameter :: STB_SUCCESS = 1
    integer, parameter :: STB_ERROR = 0

    ! Compatibility font info structure wrapping native implementation
    type :: stb_fontinfo_t
        type(native_fontinfo_t) :: native_font
        logical :: initialized = .false.
    end type stb_fontinfo_t

    ! Native Fortran bitmap wrapper for C pointer compatibility
    type :: bitmap_wrapper_t
        integer(int8), pointer :: data(:) => null()
    end type bitmap_wrapper_t

contains

    function stb_init_font(font_info, font_file_path) result(success)
        !! Initialize font from file path using native Fortran implementation
        type(stb_fontinfo_t), intent(inout) :: font_info
        character(len=*), intent(in) :: font_file_path
        logical :: success

        ! Clean up any existing font
        call stb_cleanup_font(font_info)

        ! Initialize using native Fortran implementation
        success = native_init_font(font_info%native_font, font_file_path)
        font_info%initialized = success

    end function stb_init_font

    subroutine stb_cleanup_font(font_info)
        !! Clean up font resources using native implementation
        type(stb_fontinfo_t), intent(inout) :: font_info

        if (font_info%initialized) then
            call native_cleanup_font(font_info%native_font)
            font_info%initialized = .false.
        end if

    end subroutine stb_cleanup_font

    function stb_scale_for_pixel_height(font_info, pixel_height) result(scale)
        !! Calculate scale factor for desired pixel height using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: pixel_height
        real(wp) :: scale

        if (.not. font_info%initialized) then
            scale = 0.0_wp
            return
        end if

        scale = native_scale_for_pixel_height(font_info%native_font, pixel_height)

    end function stb_scale_for_pixel_height

    subroutine stb_get_font_vmetrics(font_info, ascent, descent, line_gap)
        !! Get vertical font metrics using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(out) :: ascent, descent, line_gap

        if (.not. font_info%initialized) then
            ascent = 0
            descent = 0
            line_gap = 0
            return
        end if

        call native_get_font_vmetrics(font_info%native_font, ascent, descent, line_gap)

    end subroutine stb_get_font_vmetrics

    subroutine stb_get_codepoint_hmetrics(font_info, codepoint, advance_width, left_side_bearing)
        !! Get horizontal character metrics using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: advance_width, left_side_bearing

        if (.not. font_info%initialized) then
            advance_width = 0
            left_side_bearing = 0
            return
        end if

        call native_get_codepoint_hmetrics(font_info%native_font, codepoint, advance_width, left_side_bearing)

    end subroutine stb_get_codepoint_hmetrics

    function stb_find_glyph_index(font_info, codepoint) result(glyph_index)
        !! Find glyph index for Unicode codepoint using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer :: glyph_index

        if (.not. font_info%initialized) then
            glyph_index = 0
            return
        end if

        glyph_index = native_find_glyph_index(font_info%native_font, codepoint)

    end function stb_find_glyph_index

    subroutine stb_get_codepoint_bitmap_box(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        call native_get_codepoint_bitmap_box(font_info%native_font, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)

    end subroutine stb_get_codepoint_bitmap_box

    function stb_get_codepoint_bitmap(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer(int8), pointer :: native_bitmap(:)

        bitmap_ptr = c_null_ptr

        if (.not. font_info%initialized) then
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        native_bitmap => native_get_codepoint_bitmap(font_info%native_font, scale_x, scale_y, codepoint, width, height, xoff, yoff)

        if (associated(native_bitmap)) then
            bitmap_ptr = c_loc(native_bitmap(1))
        end if

    end function stb_get_codepoint_bitmap

    subroutine stb_make_codepoint_bitmap(font_info, output_buffer, out_w, out_h, out_stride, scale_x, scale_y, codepoint)
        !! Render character into provided buffer using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint

        if (.not. font_info%initialized) return

        call native_make_codepoint_bitmap(font_info%native_font, output_buffer, out_w, out_h, &
                                          out_stride, scale_x, scale_y, codepoint)

    end subroutine stb_make_codepoint_bitmap

    subroutine stb_free_bitmap(bitmap_ptr)
        !! Free bitmap allocated by stb_get_codepoint_bitmap using native implementation
        type(c_ptr), intent(in) :: bitmap_ptr
        integer(int8), pointer :: native_bitmap(:)

        if (c_associated(bitmap_ptr)) then
            call c_f_pointer(bitmap_ptr, native_bitmap, [1])
            call native_free_bitmap(native_bitmap)
        end if

    end subroutine stb_free_bitmap

    subroutine stb_get_glyph_box(font_info, glyph_index, x0, y0, x1, y1)
        !! Get glyph bounding box using native implementation
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: x0, y0, x1, y1
        integer :: contours

        if (.not. font_info%initialized) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! Use native glyph header parsing
        call parse_glyph_header(font_info%native_font, glyph_index, contours, x0, y0, x1, y1)

    end subroutine stb_get_glyph_box

end module fortplot_stb_truetype
