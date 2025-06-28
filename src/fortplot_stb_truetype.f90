module fortplot_stb_truetype
    !! Backend-agnostic text rendering using STB TrueType
    !! Provides iso_c_binding interface to stb_truetype.h functions
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    private
    public :: stb_fontinfo_t, stb_init_font, stb_cleanup_font
    public :: stb_get_codepoint_bitmap, stb_free_bitmap
    public :: stb_get_codepoint_hmetrics, stb_get_font_vmetrics
    public :: stb_scale_for_pixel_height, stb_get_codepoint_bitmap_box
    public :: stb_find_glyph_index, stb_make_codepoint_bitmap
    public :: stb_get_number_of_fonts, stb_get_font_offset_for_index
    public :: stb_scale_for_mapping_em_to_pixels, stb_get_font_bounding_box
    public :: stb_get_codepoint_box, stb_get_codepoint_kern_advance
    public :: stb_get_font_vmetrics_os2, stb_get_glyph_hmetrics, stb_get_glyph_box
    public :: stb_get_glyph_kern_advance, stb_get_kerning_table_length
    public :: stb_get_kerning_table
    public :: stb_get_glyph_bitmap, stb_get_glyph_bitmap_box
    public :: stb_get_codepoint_bitmap_subpixel, stb_make_glyph_bitmap
    public :: stb_get_glyph_bitmap_subpixel, stb_make_glyph_bitmap_subpixel
    public :: stb_make_codepoint_bitmap_subpixel
    public :: stb_get_glyph_bitmap_box_subpixel
    public :: stb_get_codepoint_bitmap_box_subpixel
    public :: STB_SUCCESS, STB_ERROR
    
    ! Constants
    integer, parameter :: STB_SUCCESS = 1
    integer, parameter :: STB_ERROR = 0
    
    ! Font info structure - opaque handle to C fontinfo
    type, bind(C) :: stb_fontinfo_t
        type(c_ptr) :: data_ptr = c_null_ptr
        integer(c_int) :: fontstart = 0
        integer(c_int) :: numGlyphs = 0
        ! Additional implementation-specific fields managed by C layer
        type(c_ptr) :: private_data = c_null_ptr
    end type stb_fontinfo_t
    
    ! C wrapper interfaces
    interface
        ! Font initialization from file
        function stb_wrapper_load_font_from_file(font_info, filename) bind(C, name="stb_wrapper_load_font_from_file")
            import :: c_int, c_char, stb_fontinfo_t
            type(stb_fontinfo_t), intent(inout) :: font_info
            character(c_char), intent(in) :: filename(*)
            integer(c_int) :: stb_wrapper_load_font_from_file
        end function stb_wrapper_load_font_from_file
        
        ! Font initialization from memory
        function stb_wrapper_init_font(font_info, font_data, data_size) bind(C, name="stb_wrapper_init_font")
            import :: c_int, c_ptr, stb_fontinfo_t
            type(stb_fontinfo_t), intent(inout) :: font_info
            type(c_ptr), value :: font_data
            integer(c_int), value :: data_size
            integer(c_int) :: stb_wrapper_init_font
        end function stb_wrapper_init_font
        
        ! Font cleanup
        subroutine stb_wrapper_cleanup_font(font_info) bind(C, name="stb_wrapper_cleanup_font")
            import :: stb_fontinfo_t
            type(stb_fontinfo_t), intent(inout) :: font_info
        end subroutine stb_wrapper_cleanup_font
        
        ! Scale calculation
        function stb_wrapper_scale_for_pixel_height(font_info, height) bind(C, name="stb_wrapper_scale_for_pixel_height")
            import :: c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            real(c_float), value :: height
            real(c_float) :: stb_wrapper_scale_for_pixel_height
        end function stb_wrapper_scale_for_pixel_height
        
        ! Font metrics
        subroutine stb_wrapper_get_font_vmetrics(font_info, ascent, descent, line_gap) bind(C, name="stb_wrapper_get_font_vmetrics")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), intent(out) :: ascent, descent, line_gap
        end subroutine stb_wrapper_get_font_vmetrics
        
        ! Character metrics
        subroutine stb_wrapper_get_codepoint_hmetrics(font_info, codepoint, advance_width, left_side_bearing) &
                                                     bind(C, name="stb_wrapper_get_codepoint_hmetrics")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: codepoint
            integer(c_int), intent(out) :: advance_width, left_side_bearing
        end subroutine stb_wrapper_get_codepoint_hmetrics
        
        ! Glyph lookup
        function stb_wrapper_find_glyph_index(font_info, codepoint) bind(C, name="stb_wrapper_find_glyph_index")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: codepoint
            integer(c_int) :: stb_wrapper_find_glyph_index
        end function stb_wrapper_find_glyph_index
        
        ! Bitmap bounding box
        subroutine stb_wrapper_get_codepoint_bitmap_box(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1) &
                                                       bind(C, name="stb_wrapper_get_codepoint_bitmap_box")
            import :: c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: codepoint
            real(c_float), value :: scale_x, scale_y
            integer(c_int), intent(out) :: ix0, iy0, ix1, iy1
        end subroutine stb_wrapper_get_codepoint_bitmap_box
        
        ! Bitmap rendering - allocating version
        function stb_wrapper_get_codepoint_bitmap(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) &
                                                 bind(C, name="stb_wrapper_get_codepoint_bitmap")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            real(c_float), value :: scale_x, scale_y
            integer(c_int), value :: codepoint
            integer(c_int), intent(out) :: width, height, xoff, yoff
            type(c_ptr) :: stb_wrapper_get_codepoint_bitmap
        end function stb_wrapper_get_codepoint_bitmap
        
        ! Bitmap rendering - user buffer version
        subroutine stb_wrapper_make_codepoint_bitmap(font_info, output, out_w, out_h, out_stride, scale_x, scale_y, codepoint) &
                                                    bind(C, name="stb_wrapper_make_codepoint_bitmap")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            type(c_ptr), value :: output
            integer(c_int), value :: out_w, out_h, out_stride
            real(c_float), value :: scale_x, scale_y
            integer(c_int), value :: codepoint
        end subroutine stb_wrapper_make_codepoint_bitmap
        
        ! Memory management
        subroutine stb_wrapper_free_bitmap(bitmap) bind(C, name="stb_wrapper_free_bitmap")
            import :: c_ptr
            type(c_ptr), value :: bitmap
        end subroutine stb_wrapper_free_bitmap
        
        ! Additional core functions
        function stb_wrapper_get_number_of_fonts(data, data_size) bind(C, name="stb_wrapper_get_number_of_fonts")
            import :: c_int, c_ptr
            type(c_ptr), value :: data
            integer(c_int), value :: data_size
            integer(c_int) :: stb_wrapper_get_number_of_fonts
        end function stb_wrapper_get_number_of_fonts
        
        function stb_wrapper_get_font_offset_for_index(data, index) bind(C, name="stb_wrapper_get_font_offset_for_index")
            import :: c_int, c_ptr
            type(c_ptr), value :: data
            integer(c_int), value :: index
            integer(c_int) :: stb_wrapper_get_font_offset_for_index
        end function stb_wrapper_get_font_offset_for_index
        
        function stb_wrapper_scale_for_mapping_em_to_pixels(font_info, pixels) &
                 bind(C, name="stb_wrapper_scale_for_mapping_em_to_pixels")
            import :: c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            real(c_float), value :: pixels
            real(c_float) :: stb_wrapper_scale_for_mapping_em_to_pixels
        end function stb_wrapper_scale_for_mapping_em_to_pixels
        
        subroutine stb_wrapper_get_font_bounding_box(font_info, x0, y0, x1, y1) &
                   bind(C, name="stb_wrapper_get_font_bounding_box")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), intent(out) :: x0, y0, x1, y1
        end subroutine stb_wrapper_get_font_bounding_box
        
        subroutine stb_wrapper_get_codepoint_box(font_info, codepoint, x0, y0, x1, y1) &
                   bind(C, name="stb_wrapper_get_codepoint_box")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: codepoint
            integer(c_int), intent(out) :: x0, y0, x1, y1
        end subroutine stb_wrapper_get_codepoint_box
        
        function stb_wrapper_get_codepoint_kern_advance(font_info, ch1, ch2) &
                 bind(C, name="stb_wrapper_get_codepoint_kern_advance")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: ch1, ch2
            integer(c_int) :: stb_wrapper_get_codepoint_kern_advance
        end function stb_wrapper_get_codepoint_kern_advance
        
        ! Extended font metrics
        subroutine stb_wrapper_get_font_vmetrics_os2(font_info, typoAscent, &
                   typoDescent, typoLineGap) &
                   bind(C, name="stb_wrapper_get_font_vmetrics_os2")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), intent(out) :: typoAscent, typoDescent, typoLineGap
        end subroutine stb_wrapper_get_font_vmetrics_os2
        
        ! Glyph-level functions
        subroutine stb_wrapper_get_glyph_hmetrics(font_info, glyph_index, &
                   advanceWidth, leftSideBearing) &
                   bind(C, name="stb_wrapper_get_glyph_hmetrics")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: glyph_index
            integer(c_int), intent(out) :: advanceWidth, leftSideBearing
        end subroutine stb_wrapper_get_glyph_hmetrics
        
        subroutine stb_wrapper_get_glyph_box(font_info, glyph_index, x0, y0, &
                   x1, y1) bind(C, name="stb_wrapper_get_glyph_box")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: glyph_index
            integer(c_int), intent(out) :: x0, y0, x1, y1
        end subroutine stb_wrapper_get_glyph_box
        
        function stb_wrapper_get_glyph_kern_advance(font_info, glyph1, glyph2) &
                 bind(C, name="stb_wrapper_get_glyph_kern_advance")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: glyph1, glyph2
            integer(c_int) :: stb_wrapper_get_glyph_kern_advance
        end function stb_wrapper_get_glyph_kern_advance
        
        function stb_wrapper_get_kerning_table_length(font_info) &
                 bind(C, name="stb_wrapper_get_kerning_table_length")
            import :: c_int, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int) :: stb_wrapper_get_kerning_table_length
        end function stb_wrapper_get_kerning_table_length
        
        function stb_wrapper_get_kerning_table(font_info, table, table_length) &
                 bind(C, name="stb_wrapper_get_kerning_table")
            import :: c_int, c_ptr, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            type(c_ptr), value :: table
            integer(c_int), value :: table_length
            integer(c_int) :: stb_wrapper_get_kerning_table
        end function stb_wrapper_get_kerning_table
        
        ! Advanced bitmap functions
        function stb_wrapper_get_glyph_bitmap(font_info, scale_x, scale_y, &
                 glyph, width, height, xoff, yoff) &
                 bind(C, name="stb_wrapper_get_glyph_bitmap")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            real(c_float), value :: scale_x, scale_y
            integer(c_int), value :: glyph
            integer(c_int), intent(out) :: width, height, xoff, yoff
            type(c_ptr) :: stb_wrapper_get_glyph_bitmap
        end function stb_wrapper_get_glyph_bitmap
        
        subroutine stb_wrapper_get_glyph_bitmap_box(font_info, glyph, &
                   scale_x, scale_y, ix0, iy0, ix1, iy1) &
                   bind(C, name="stb_wrapper_get_glyph_bitmap_box")
            import :: c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: glyph
            real(c_float), value :: scale_x, scale_y
            integer(c_int), intent(out) :: ix0, iy0, ix1, iy1
        end subroutine stb_wrapper_get_glyph_bitmap_box
        
        function stb_wrapper_get_codepoint_bitmap_subpixel(font_info, &
                 scale_x, scale_y, shift_x, shift_y, codepoint, &
                 width, height, xoff, yoff) &
                 bind(C, name="stb_wrapper_get_codepoint_bitmap_subpixel")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            integer(c_int), value :: codepoint
            integer(c_int), intent(out) :: width, height, xoff, yoff
            type(c_ptr) :: stb_wrapper_get_codepoint_bitmap_subpixel
        end function stb_wrapper_get_codepoint_bitmap_subpixel
        
        subroutine stb_wrapper_make_glyph_bitmap(font_info, output, out_w, &
                   out_h, out_stride, scale_x, scale_y, glyph) &
                   bind(C, name="stb_wrapper_make_glyph_bitmap")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            type(c_ptr), value :: output
            integer(c_int), value :: out_w, out_h, out_stride
            real(c_float), value :: scale_x, scale_y
            integer(c_int), value :: glyph
        end subroutine stb_wrapper_make_glyph_bitmap
        
        ! Additional subpixel bitmap functions
        function stb_wrapper_get_glyph_bitmap_subpixel(font_info, scale_x, &
                 scale_y, shift_x, shift_y, glyph, width, height, xoff, yoff) &
                 bind(C, name="stb_wrapper_get_glyph_bitmap_subpixel")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            integer(c_int), value :: glyph
            integer(c_int), intent(out) :: width, height, xoff, yoff
            type(c_ptr) :: stb_wrapper_get_glyph_bitmap_subpixel
        end function stb_wrapper_get_glyph_bitmap_subpixel
        
        subroutine stb_wrapper_make_glyph_bitmap_subpixel(font_info, output, &
                   out_w, out_h, out_stride, scale_x, scale_y, shift_x, &
                   shift_y, glyph) &
                   bind(C, name="stb_wrapper_make_glyph_bitmap_subpixel")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            type(c_ptr), value :: output
            integer(c_int), value :: out_w, out_h, out_stride
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            integer(c_int), value :: glyph
        end subroutine stb_wrapper_make_glyph_bitmap_subpixel
        
        subroutine stb_wrapper_make_codepoint_bitmap_subpixel(font_info, &
                   output, out_w, out_h, out_stride, scale_x, scale_y, &
                   shift_x, shift_y, codepoint) &
                   bind(C, name="stb_wrapper_make_codepoint_bitmap_subpixel")
            import :: c_ptr, c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            type(c_ptr), value :: output
            integer(c_int), value :: out_w, out_h, out_stride
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            integer(c_int), value :: codepoint
        end subroutine stb_wrapper_make_codepoint_bitmap_subpixel
        
        subroutine stb_wrapper_get_glyph_bitmap_box_subpixel(font_info, &
                   glyph, scale_x, scale_y, shift_x, shift_y, ix0, iy0, &
                   ix1, iy1) &
                   bind(C, name="stb_wrapper_get_glyph_bitmap_box_subpixel")
            import :: c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: glyph
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            integer(c_int), intent(out) :: ix0, iy0, ix1, iy1
        end subroutine stb_wrapper_get_glyph_bitmap_box_subpixel
        
        subroutine stb_wrapper_get_codepoint_bitmap_box_subpixel(font_info, &
                   codepoint, scale_x, scale_y, shift_x, shift_y, ix0, iy0, &
                   ix1, iy1) &
                   bind(C, name="stb_wrapper_get_codepoint_bitmap_box_subpixel")
            import :: c_int, c_float, stb_fontinfo_t
            type(stb_fontinfo_t), intent(in) :: font_info
            integer(c_int), value :: codepoint
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            integer(c_int), intent(out) :: ix0, iy0, ix1, iy1
        end subroutine stb_wrapper_get_codepoint_bitmap_box_subpixel
        
    end interface
    
contains

    function stb_init_font(font_info, font_file_path) result(success)
        !! Initialize font from file path
        type(stb_fontinfo_t), intent(inout) :: font_info
        character(len=*), intent(in) :: font_file_path
        logical :: success
        integer(c_int) :: result
        
        ! Initialize struct
        font_info%data_ptr = c_null_ptr
        font_info%fontstart = 0
        font_info%numGlyphs = 0
        font_info%private_data = c_null_ptr
        
        ! Call C wrapper to load font from file
        result = stb_wrapper_load_font_from_file(font_info, trim(font_file_path)//c_null_char)
        
        success = (result == STB_SUCCESS)
        
    end function stb_init_font
    
    subroutine stb_cleanup_font(font_info)
        !! Clean up font resources
        type(stb_fontinfo_t), intent(inout) :: font_info
        
        if (c_associated(font_info%private_data)) then
            call stb_wrapper_cleanup_font(font_info)
        end if
        
        font_info%data_ptr = c_null_ptr
        font_info%fontstart = 0
        font_info%numGlyphs = 0
        font_info%private_data = c_null_ptr
        
    end subroutine stb_cleanup_font
    
    function stb_scale_for_pixel_height(font_info, pixel_height) result(scale)
        !! Calculate scale factor for desired pixel height
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: pixel_height
        real(wp) :: scale
        
        if (.not. c_associated(font_info%private_data)) then
            scale = 0.0_wp
            return
        end if
        
        scale = real(stb_wrapper_scale_for_pixel_height(font_info, real(pixel_height, c_float)), wp)
        
    end function stb_scale_for_pixel_height
    
    subroutine stb_get_font_vmetrics(font_info, ascent, descent, line_gap)
        !! Get vertical font metrics in unscaled coordinates
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(out) :: ascent, descent, line_gap
        integer(c_int) :: c_ascent, c_descent, c_line_gap
        
        if (.not. c_associated(font_info%private_data)) then
            ascent = 0
            descent = 0
            line_gap = 0
            return
        end if
        
        call stb_wrapper_get_font_vmetrics(font_info, c_ascent, c_descent, c_line_gap)
        
        ascent = int(c_ascent)
        descent = int(c_descent)
        line_gap = int(c_line_gap)
        
    end subroutine stb_get_font_vmetrics
    
    subroutine stb_get_codepoint_hmetrics(font_info, codepoint, advance_width, left_side_bearing)
        !! Get horizontal character metrics in unscaled coordinates
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: advance_width, left_side_bearing
        integer(c_int) :: c_advance, c_bearing
        
        if (.not. c_associated(font_info%private_data)) then
            advance_width = 0
            left_side_bearing = 0
            return
        end if
        
        call stb_wrapper_get_codepoint_hmetrics(font_info, int(codepoint, c_int), c_advance, c_bearing)
        
        advance_width = int(c_advance)
        left_side_bearing = int(c_bearing)
        
    end subroutine stb_get_codepoint_hmetrics
    
    function stb_find_glyph_index(font_info, codepoint) result(glyph_index)
        !! Find glyph index for Unicode codepoint
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer :: glyph_index
        
        if (.not. c_associated(font_info%private_data)) then
            glyph_index = 0
            return
        end if
        
        glyph_index = int(stb_wrapper_find_glyph_index(font_info, int(codepoint, c_int)))
        
    end function stb_find_glyph_index
    
    subroutine stb_get_codepoint_bitmap_box(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap
        type(stb_fontinfo_t), intent(in) :: font_info  
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer(c_int) :: c_ix0, c_iy0, c_ix1, c_iy1
        
        if (.not. c_associated(font_info%private_data)) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if
        
        call stb_wrapper_get_codepoint_bitmap_box(font_info, int(codepoint, c_int), &
                                                 real(scale_x, c_float), real(scale_y, c_float), &
                                                 c_ix0, c_iy0, c_ix1, c_iy1)
        
        ix0 = int(c_ix0); iy0 = int(c_iy0)
        ix1 = int(c_ix1); iy1 = int(c_iy1)
        
    end subroutine stb_get_codepoint_bitmap_box
    
    function stb_get_codepoint_bitmap(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer(c_int) :: c_width, c_height, c_xoff, c_yoff
        
        if (.not. c_associated(font_info%private_data)) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if
        
        bitmap_ptr = stb_wrapper_get_codepoint_bitmap(font_info, &
                                                     real(scale_x, c_float), real(scale_y, c_float), &
                                                     int(codepoint, c_int), &
                                                     c_width, c_height, c_xoff, c_yoff)
        
        width = int(c_width); height = int(c_height)
        xoff = int(c_xoff); yoff = int(c_yoff)
        
    end function stb_get_codepoint_bitmap
    
    subroutine stb_make_codepoint_bitmap(font_info, output_buffer, out_w, out_h, out_stride, scale_x, scale_y, codepoint)
        !! Render character into provided buffer
        type(stb_fontinfo_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        
        if (.not. c_associated(font_info%private_data)) return
        
        call stb_wrapper_make_codepoint_bitmap(font_info, c_loc(output_buffer), &
                                              int(out_w, c_int), int(out_h, c_int), int(out_stride, c_int), &
                                              real(scale_x, c_float), real(scale_y, c_float), &
                                              int(codepoint, c_int))
        
    end subroutine stb_make_codepoint_bitmap
    
    subroutine stb_free_bitmap(bitmap_ptr)
        !! Free bitmap allocated by stb_get_codepoint_bitmap
        type(c_ptr), intent(in) :: bitmap_ptr
        
        if (c_associated(bitmap_ptr)) then
            call stb_wrapper_free_bitmap(bitmap_ptr)
        end if
        
    end subroutine stb_free_bitmap

    function stb_get_number_of_fonts(font_data, data_size) result(num_fonts)
        !! Get number of fonts in font file/data
        type(c_ptr), intent(in) :: font_data
        integer, intent(in) :: data_size
        integer :: num_fonts
        
        if (.not. c_associated(font_data) .or. data_size <= 0) then
            num_fonts = 0
            return
        end if
        
        num_fonts = int(stb_wrapper_get_number_of_fonts(font_data, int(data_size, c_int)))
        
    end function stb_get_number_of_fonts
    
    function stb_get_font_offset_for_index(font_data, index) result(offset)
        !! Get font offset for multi-font files
        type(c_ptr), intent(in) :: font_data
        integer, intent(in) :: index
        integer :: offset
        
        if (.not. c_associated(font_data)) then
            offset = -1
            return
        end if
        
        offset = int(stb_wrapper_get_font_offset_for_index(font_data, int(index, c_int)))
        
    end function stb_get_font_offset_for_index
    
    function stb_scale_for_mapping_em_to_pixels(font_info, pixels) result(scale)
        !! Calculate scale factor for desired em size
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: pixels
        real(wp) :: scale
        
        if (.not. c_associated(font_info%private_data)) then
            scale = 0.0_wp
            return
        end if
        
        scale = real(stb_wrapper_scale_for_mapping_em_to_pixels(font_info, &
                                                               real(pixels, c_float)), wp)
        
    end function stb_scale_for_mapping_em_to_pixels
    
    subroutine stb_get_font_bounding_box(font_info, x0, y0, x1, y1)
        !! Get font bounding box in unscaled coordinates
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(out) :: x0, y0, x1, y1
        integer(c_int) :: c_x0, c_y0, c_x1, c_y1
        
        if (.not. c_associated(font_info%private_data)) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if
        
        call stb_wrapper_get_font_bounding_box(font_info, c_x0, c_y0, c_x1, c_y1)
        
        x0 = int(c_x0); y0 = int(c_y0)
        x1 = int(c_x1); y1 = int(c_y1)
        
    end subroutine stb_get_font_bounding_box
    
    subroutine stb_get_codepoint_box(font_info, codepoint, x0, y0, x1, y1)
        !! Get character bounding box in unscaled coordinates
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: x0, y0, x1, y1
        integer(c_int) :: c_x0, c_y0, c_x1, c_y1
        
        if (.not. c_associated(font_info%private_data)) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if
        
        call stb_wrapper_get_codepoint_box(font_info, int(codepoint, c_int), &
                                           c_x0, c_y0, c_x1, c_y1)
        
        x0 = int(c_x0); y0 = int(c_y0)
        x1 = int(c_x1); y1 = int(c_y1)
        
    end subroutine stb_get_codepoint_box
    
    function stb_get_codepoint_kern_advance(font_info, ch1, ch2) result(kern_advance)
        !! Get kerning advance between two characters
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: ch1, ch2
        integer :: kern_advance
        
        if (.not. c_associated(font_info%private_data)) then
            kern_advance = 0
            return
        end if
        
        kern_advance = int(stb_wrapper_get_codepoint_kern_advance(font_info, &
                                                              int(ch1, c_int), int(ch2, c_int)))
        
    end function stb_get_codepoint_kern_advance

    subroutine stb_get_font_vmetrics_os2(font_info, typoAscent, typoDescent, &
                                        typoLineGap)
        !! Get OS/2 table vertical metrics
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(out) :: typoAscent, typoDescent, typoLineGap
        integer(c_int) :: c_typoAscent, c_typoDescent, c_typoLineGap
        
        if (.not. c_associated(font_info%private_data)) then
            typoAscent = 0
            typoDescent = 0
            typoLineGap = 0
            return
        end if
        
        call stb_wrapper_get_font_vmetrics_os2(font_info, c_typoAscent, &
                                              c_typoDescent, c_typoLineGap)
        
        typoAscent = int(c_typoAscent)
        typoDescent = int(c_typoDescent)
        typoLineGap = int(c_typoLineGap)
        
    end subroutine stb_get_font_vmetrics_os2
    
    subroutine stb_get_glyph_hmetrics(font_info, glyph_index, advanceWidth, &
                                     leftSideBearing)
        !! Get horizontal glyph metrics by glyph index
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: advanceWidth, leftSideBearing
        integer(c_int) :: c_advance, c_bearing
        
        if (.not. c_associated(font_info%private_data)) then
            advanceWidth = 0
            leftSideBearing = 0
            return
        end if
        
        call stb_wrapper_get_glyph_hmetrics(font_info, int(glyph_index, c_int), &
                                           c_advance, c_bearing)
        
        advanceWidth = int(c_advance)
        leftSideBearing = int(c_bearing)
        
    end subroutine stb_get_glyph_hmetrics
    
    subroutine stb_get_glyph_box(font_info, glyph_index, x0, y0, x1, y1)
        !! Get glyph bounding box by glyph index
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: x0, y0, x1, y1
        integer(c_int) :: c_x0, c_y0, c_x1, c_y1
        
        if (.not. c_associated(font_info%private_data)) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if
        
        call stb_wrapper_get_glyph_box(font_info, int(glyph_index, c_int), &
                                      c_x0, c_y0, c_x1, c_y1)
        
        x0 = int(c_x0); y0 = int(c_y0)
        x1 = int(c_x1); y1 = int(c_y1)
        
    end subroutine stb_get_glyph_box
    
    function stb_get_glyph_kern_advance(font_info, glyph1, glyph2) &
             result(kern_advance)
        !! Get kerning advance between two glyphs by glyph indices
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph1, glyph2
        integer :: kern_advance
        
        if (.not. c_associated(font_info%private_data)) then
            kern_advance = 0
            return
        end if
        
        kern_advance = int(stb_wrapper_get_glyph_kern_advance(font_info, &
                                                             int(glyph1, c_int), int(glyph2, c_int)))
        
    end function stb_get_glyph_kern_advance
    
    function stb_get_kerning_table_length(font_info) result(table_length)
        !! Get length of kerning table
        type(stb_fontinfo_t), intent(in) :: font_info
        integer :: table_length
        
        if (.not. c_associated(font_info%private_data)) then
            table_length = 0
            return
        end if
        
        table_length = int(stb_wrapper_get_kerning_table_length(font_info))
        
    end function stb_get_kerning_table_length
    
    function stb_get_kerning_table(font_info, table, table_length) result(count)
        !! Get kerning table entries
        type(stb_fontinfo_t), intent(in) :: font_info
        type(c_ptr), intent(in) :: table
        integer, intent(in) :: table_length
        integer :: count
        
        if (.not. c_associated(font_info%private_data) .or. &
            .not. c_associated(table) .or. table_length <= 0) then
            count = 0
            return
        end if
        
        count = int(stb_wrapper_get_kerning_table(font_info, table, &
                                                 int(table_length, c_int)))
        
    end function stb_get_kerning_table

    function stb_get_glyph_bitmap(font_info, scale_x, scale_y, glyph, &
                                 width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render glyph bitmap by glyph index
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: glyph
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer(c_int) :: c_width, c_height, c_xoff, c_yoff
        
        if (.not. c_associated(font_info%private_data)) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if
        
        bitmap_ptr = stb_wrapper_get_glyph_bitmap(font_info, &
                                                 real(scale_x, c_float), &
                                                 real(scale_y, c_float), &
                                                 int(glyph, c_int), &
                                                 c_width, c_height, c_xoff, c_yoff)
        
        width = int(c_width); height = int(c_height)
        xoff = int(c_xoff); yoff = int(c_yoff)
        
    end function stb_get_glyph_bitmap
    
    subroutine stb_get_glyph_bitmap_box(font_info, glyph, scale_x, scale_y, &
                                       ix0, iy0, ix1, iy1)
        !! Get bounding box for glyph bitmap
        type(stb_fontinfo_t), intent(in) :: font_info  
        integer, intent(in) :: glyph
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer(c_int) :: c_ix0, c_iy0, c_ix1, c_iy1
        
        if (.not. c_associated(font_info%private_data)) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if
        
        call stb_wrapper_get_glyph_bitmap_box(font_info, int(glyph, c_int), &
                                             real(scale_x, c_float), &
                                             real(scale_y, c_float), &
                                             c_ix0, c_iy0, c_ix1, c_iy1)
        
        ix0 = int(c_ix0); iy0 = int(c_iy0)
        ix1 = int(c_ix1); iy1 = int(c_iy1)
        
    end subroutine stb_get_glyph_bitmap_box
    
    function stb_get_codepoint_bitmap_subpixel(font_info, scale_x, scale_y, &
                                              shift_x, shift_y, codepoint, &
                                              width, height, xoff, yoff) &
             result(bitmap_ptr)
        !! Allocate and render character bitmap with subpixel positioning
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer(c_int) :: c_width, c_height, c_xoff, c_yoff
        
        if (.not. c_associated(font_info%private_data)) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if
        
        bitmap_ptr = stb_wrapper_get_codepoint_bitmap_subpixel(font_info, &
                                                              real(scale_x, c_float), &
                                                              real(scale_y, c_float), &
                                                              real(shift_x, c_float), &
                                                              real(shift_y, c_float), &
                                                              int(codepoint, c_int), &
                                                              c_width, c_height, &
                                                              c_xoff, c_yoff)
        
        width = int(c_width); height = int(c_height)
        xoff = int(c_xoff); yoff = int(c_yoff)
        
    end function stb_get_codepoint_bitmap_subpixel
    
    subroutine stb_make_glyph_bitmap(font_info, output_buffer, out_w, out_h, &
                                    out_stride, scale_x, scale_y, glyph)
        !! Render glyph into provided buffer
        type(stb_fontinfo_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: glyph
        
        if (.not. c_associated(font_info%private_data)) return
        
        call stb_wrapper_make_glyph_bitmap(font_info, c_loc(output_buffer), &
                                          int(out_w, c_int), int(out_h, c_int), &
                                          int(out_stride, c_int), &
                                          real(scale_x, c_float), &
                                          real(scale_y, c_float), &
                                          int(glyph, c_int))
        
    end subroutine stb_make_glyph_bitmap

    function stb_get_glyph_bitmap_subpixel(font_info, scale_x, scale_y, &
                                          shift_x, shift_y, glyph, width, &
                                          height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render glyph bitmap with subpixel positioning
        type(stb_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: glyph
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer(c_int) :: c_width, c_height, c_xoff, c_yoff
        
        if (.not. c_associated(font_info%private_data)) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if
        
        bitmap_ptr = stb_wrapper_get_glyph_bitmap_subpixel(font_info, &
                                                          real(scale_x, c_float), &
                                                          real(scale_y, c_float), &
                                                          real(shift_x, c_float), &
                                                          real(shift_y, c_float), &
                                                          int(glyph, c_int), &
                                                          c_width, c_height, &
                                                          c_xoff, c_yoff)
        
        width = int(c_width); height = int(c_height)
        xoff = int(c_xoff); yoff = int(c_yoff)
        
    end function stb_get_glyph_bitmap_subpixel
    
    subroutine stb_make_glyph_bitmap_subpixel(font_info, output_buffer, &
                                             out_w, out_h, out_stride, &
                                             scale_x, scale_y, shift_x, &
                                             shift_y, glyph)
        !! Render glyph into provided buffer with subpixel positioning
        type(stb_fontinfo_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: glyph
        
        if (.not. c_associated(font_info%private_data)) return
        
        call stb_wrapper_make_glyph_bitmap_subpixel(font_info, &
                                                   c_loc(output_buffer), &
                                                   int(out_w, c_int), &
                                                   int(out_h, c_int), &
                                                   int(out_stride, c_int), &
                                                   real(scale_x, c_float), &
                                                   real(scale_y, c_float), &
                                                   real(shift_x, c_float), &
                                                   real(shift_y, c_float), &
                                                   int(glyph, c_int))
        
    end subroutine stb_make_glyph_bitmap_subpixel
    
    subroutine stb_make_codepoint_bitmap_subpixel(font_info, output_buffer, &
                                                 out_w, out_h, out_stride, &
                                                 scale_x, scale_y, shift_x, &
                                                 shift_y, codepoint)
        !! Render character into provided buffer with subpixel positioning
        type(stb_fontinfo_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: codepoint
        
        if (.not. c_associated(font_info%private_data)) return
        
        call stb_wrapper_make_codepoint_bitmap_subpixel(font_info, &
                                                       c_loc(output_buffer), &
                                                       int(out_w, c_int), &
                                                       int(out_h, c_int), &
                                                       int(out_stride, c_int), &
                                                       real(scale_x, c_float), &
                                                       real(scale_y, c_float), &
                                                       real(shift_x, c_float), &
                                                       real(shift_y, c_float), &
                                                       int(codepoint, c_int))
        
    end subroutine stb_make_codepoint_bitmap_subpixel
    
    subroutine stb_get_glyph_bitmap_box_subpixel(font_info, glyph, scale_x, &
                                                scale_y, shift_x, shift_y, &
                                                ix0, iy0, ix1, iy1)
        !! Get bounding box for glyph bitmap with subpixel positioning
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer(c_int) :: c_ix0, c_iy0, c_ix1, c_iy1
        
        if (.not. c_associated(font_info%private_data)) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if
        
        call stb_wrapper_get_glyph_bitmap_box_subpixel(font_info, &
                                                      int(glyph, c_int), &
                                                      real(scale_x, c_float), &
                                                      real(scale_y, c_float), &
                                                      real(shift_x, c_float), &
                                                      real(shift_y, c_float), &
                                                      c_ix0, c_iy0, c_ix1, c_iy1)
        
        ix0 = int(c_ix0); iy0 = int(c_iy0)
        ix1 = int(c_ix1); iy1 = int(c_iy1)
        
    end subroutine stb_get_glyph_bitmap_box_subpixel
    
    subroutine stb_get_codepoint_bitmap_box_subpixel(font_info, codepoint, &
                                                    scale_x, scale_y, &
                                                    shift_x, shift_y, &
                                                    ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap with subpixel positioning
        type(stb_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer(c_int) :: c_ix0, c_iy0, c_ix1, c_iy1
        
        if (.not. c_associated(font_info%private_data)) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if
        
        call stb_wrapper_get_codepoint_bitmap_box_subpixel(font_info, &
                                                          int(codepoint, c_int), &
                                                          real(scale_x, c_float), &
                                                          real(scale_y, c_float), &
                                                          real(shift_x, c_float), &
                                                          real(shift_y, c_float), &
                                                          c_ix0, c_iy0, c_ix1, c_iy1)
        
        ix0 = int(c_ix0); iy0 = int(c_iy0)
        ix1 = int(c_ix1); iy1 = int(c_iy1)
        
    end subroutine stb_get_codepoint_bitmap_box_subpixel

end module fortplot_stb_truetype