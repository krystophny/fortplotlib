module fortplot_stb
    !! Pure Fortran implementation of TrueType font functionality (STUB MODULE)
    !! This module provides stubs for a future pure Fortran port that can replace stb_truetype.h dependency
    !! Currently returns placeholder/error values - implementation is planned for future development
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_truetype_types
    use fortplot_truetype_parser
    implicit none

    private

    ! Re-export types from types module
    public :: stb_fontinfo_pure_t
    public :: ttf_table_entry_t, ttf_header_t, ttf_head_table_t
    public :: ttf_hhea_table_t, ttf_maxp_table_t, ttf_cmap_table_t
    public :: ttf_cmap_subtable_t, ttc_header_t
    public :: stb_fontinfo_pure_t, stb_init_font_pure, stb_cleanup_font_pure
    public :: stb_get_codepoint_bitmap_pure, stb_free_bitmap_pure
    public :: stb_get_codepoint_hmetrics_pure, stb_get_font_vmetrics_pure
    public :: stb_scale_for_pixel_height_pure, stb_get_codepoint_bitmap_box_pure
    public :: stb_find_glyph_index_pure, stb_make_codepoint_bitmap_pure
    public :: stb_get_number_of_fonts_pure, stb_get_font_offset_for_index_pure
    public :: stb_scale_for_mapping_em_to_pixels_pure, stb_get_font_bounding_box_pure
    public :: stb_get_codepoint_box_pure, stb_get_codepoint_kern_advance_pure
    public :: stb_get_font_vmetrics_os2_pure, stb_get_glyph_hmetrics_pure
    public :: stb_get_glyph_box_pure, stb_get_glyph_kern_advance_pure
    public :: stb_get_kerning_table_length_pure, stb_get_kerning_table_pure
    public :: stb_get_glyph_bitmap_pure, stb_get_glyph_bitmap_box_pure
    public :: stb_get_codepoint_bitmap_subpixel_pure, stb_make_glyph_bitmap_pure
    public :: stb_get_glyph_bitmap_subpixel_pure, stb_make_glyph_bitmap_subpixel_pure
    public :: stb_make_codepoint_bitmap_subpixel_pure
    public :: stb_get_glyph_bitmap_box_subpixel_pure
    public :: stb_get_codepoint_bitmap_box_subpixel_pure
    public :: STB_PURE_SUCCESS, STB_PURE_ERROR, STB_PURE_NOT_IMPLEMENTED

    ! Constants
    integer, parameter :: STB_PURE_SUCCESS = 1
    integer, parameter :: STB_PURE_ERROR = 0
    integer, parameter :: STB_PURE_NOT_IMPLEMENTED = -1

contains

    function stb_init_font_pure(font_info, font_file_path) result(success)
        !! Initialize font from file path
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        character(len=*), intent(in) :: font_file_path
        logical :: success

        ! Initialize structure
        font_info%initialized = .false.
        font_info%font_file_path = font_file_path
        font_info%num_glyphs = 0
        success = .false.

        ! Read font file
        if (.not. read_truetype_file(font_file_path, font_info%font_data, &
                                   font_info%data_size)) then
            return
        end if

        ! Parse TTF header
        if (.not. parse_ttf_header(font_info%font_data, font_info%header)) then
            return
        end if

        ! Parse table directory
        if (.not. parse_table_directory(font_info%font_data, font_info%header, &
                                      font_info%tables)) then
            return
        end if

        ! Basic validation - must have required tables
        if (.not. (has_table(font_info%tables, 'head') .and. &
                   has_table(font_info%tables, 'hhea') .and. &
                   has_table(font_info%tables, 'hmtx') .and. &
                   has_table(font_info%tables, 'cmap'))) then
            return
        end if

        ! Parse essential tables
        if (.not. parse_head_table(font_info%font_data, font_info%tables, &
                                 font_info%head_table)) then
            return
        end if
        font_info%head_parsed = .true.

        if (.not. parse_hhea_table(font_info%font_data, font_info%tables, &
                                 font_info%hhea_table)) then
            return
        end if
        font_info%hhea_parsed = .true.

        if (.not. parse_maxp_table(font_info%font_data, font_info%tables, &
                                 font_info%maxp_table)) then
            return
        end if
        font_info%maxp_parsed = .true.
        font_info%num_glyphs = font_info%maxp_table%num_glyphs

        if (.not. parse_cmap_table(font_info%font_data, font_info%tables, &
                                 font_info%cmap_table)) then
            return
        end if
        font_info%cmap_parsed = .true.

        font_info%initialized = .true.
        success = .true.

    end function stb_init_font_pure

    subroutine stb_cleanup_font_pure(font_info)
        !! Clean up font resources
        type(stb_fontinfo_pure_t), intent(inout) :: font_info

        font_info%initialized = .false.
        font_info%font_file_path = ""
        font_info%num_glyphs = 0

        ! Reset table parsing flags
        font_info%head_parsed = .false.
        font_info%hhea_parsed = .false.
        font_info%maxp_parsed = .false.

        ! Free allocated memory
        if (allocated(font_info%font_data)) deallocate(font_info%font_data)
        if (allocated(font_info%tables)) deallocate(font_info%tables)
        font_info%data_size = 0

    end subroutine stb_cleanup_font_pure

    function stb_scale_for_pixel_height_pure(font_info, pixel_height) result(scale)
        !! Calculate scale factor for desired pixel height using hhea metrics
        !! Uses ascent - descent (total visible height) like STB
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: pixel_height
        real(wp) :: scale
        integer :: font_height

        if (.not. font_info%initialized .or. .not. font_info%hhea_parsed) then
            scale = 0.0_wp
            return
        end if

        ! Calculate font height as ascender - descender (STB approach)
        font_height = font_info%hhea_table%ascender - font_info%hhea_table%descender
        scale = pixel_height / real(font_height, wp)

    end function stb_scale_for_pixel_height_pure

    subroutine stb_get_font_vmetrics_pure(font_info, ascent, descent, line_gap)
        !! Get vertical font metrics from hhea table
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(out) :: ascent, descent, line_gap

        if (.not. font_info%initialized .or. .not. font_info%hhea_parsed) then
            ascent = 0
            descent = 0
            line_gap = 0
            return
        end if

        ! Return metrics from hhea table
        ascent = font_info%hhea_table%ascender
        descent = font_info%hhea_table%descender
        line_gap = font_info%hhea_table%line_gap

    end subroutine stb_get_font_vmetrics_pure

    subroutine stb_get_codepoint_hmetrics_pure(font_info, codepoint, advance_width, left_side_bearing)
        !! Get horizontal character metrics (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: advance_width, left_side_bearing

        if (.not. font_info%initialized) then
            advance_width = 0
            left_side_bearing = 0
            return
        end if

        ! STUB: Return placeholder values
        advance_width = 0
        left_side_bearing = 0

        ! TODO: Implement using cmap + hmtx tables
        ! TODO: Map Unicode codepoint to glyph index
        ! TODO: Look up glyph metrics in hmtx table

    end subroutine stb_get_codepoint_hmetrics_pure

    function stb_find_glyph_index_pure(font_info, codepoint) result(glyph_index)
        !! Find glyph index for Unicode codepoint using cmap table
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer :: glyph_index
        integer :: i, subtable_idx
        type(ttf_cmap_subtable_t) :: subtable

        glyph_index = 0

        if (.not. font_info%initialized .or. .not. font_info%cmap_parsed) then
            return
        end if

        ! Use preferred subtable
        subtable_idx = font_info%cmap_table%preferred_subtable
        if (subtable_idx <= 0) return

        subtable = font_info%cmap_table%subtables(subtable_idx)

        ! Handle format 4 (segment mapping)
        if (subtable%format == 4) then
            glyph_index = lookup_format4(subtable, codepoint)
        end if

    end function stb_find_glyph_index_pure

    function lookup_format4(subtable, codepoint) result(glyph_index)
        !! Lookup glyph index in format 4 cmap subtable
        type(ttf_cmap_subtable_t), intent(in) :: subtable
        integer, intent(in) :: codepoint
        integer :: glyph_index
        integer :: i

        glyph_index = 0

        ! Search for segment containing codepoint
        do i = 1, subtable%seg_count
            if (codepoint <= subtable%end_code(i)) then
                if (codepoint >= subtable%start_code(i)) then
                    ! Found segment - calculate glyph index
                    if (subtable%id_range_offset(i) == 0) then
                        ! Direct mapping using delta
                        glyph_index = codepoint + subtable%id_delta(i)
                        ! Handle 16-bit modulo arithmetic properly
                        glyph_index = iand(glyph_index, 65535)  ! Keep only lower 16 bits
                    else
                        ! Indirect mapping through glyph array (not implemented yet)
                        glyph_index = 0
                    end if
                end if
                exit
            end if
        end do

    end function lookup_format4

    subroutine stb_get_codepoint_bitmap_box_pure(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! STUB: Return placeholder values
        ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0

        ! TODO: Implement glyph outline parsing and bounding box calculation

    end subroutine stb_get_codepoint_bitmap_box_pure

    function stb_get_codepoint_bitmap_pure(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
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

        ! TODO: Implement glyph outline rasterization
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

        ! STUB: Do nothing since we don't allocate anything yet

        ! TODO: Implement memory deallocation

    end subroutine stb_free_bitmap_pure

    function stb_get_number_of_fonts_pure(font_data, data_size) result(num_fonts)
        !! Get number of fonts in font file/data (STUB)
        type(c_ptr), intent(in) :: font_data
        integer, intent(in) :: data_size
        integer :: num_fonts

        ! STUB: Return placeholder
        num_fonts = 0

        ! TODO: Parse TTC header if applicable

    end function stb_get_number_of_fonts_pure

    function stb_get_font_offset_for_index_pure(font_data, index) result(offset)
        !! Get font offset for multi-font files (STUB)
        type(c_ptr), intent(in) :: font_data
        integer, intent(in) :: index
        integer :: offset

        ! STUB: Return error
        offset = -1

        ! TODO: Parse TTC directory

    end function stb_get_font_offset_for_index_pure

    function stb_scale_for_mapping_em_to_pixels_pure(font_info, pixels) result(scale)
        !! Calculate scale factor for desired em size (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: pixels
        real(wp) :: scale

        if (.not. font_info%initialized) then
            scale = 0.0_wp
            return
        end if

        ! STUB: Return placeholder
        scale = 0.0_wp

        ! TODO: Implement using font head table

    end function stb_scale_for_mapping_em_to_pixels_pure

    subroutine stb_get_font_bounding_box_pure(font_info, x0, y0, x1, y1)
        !! Get font bounding box (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(out) :: x0, y0, x1, y1

        if (.not. font_info%initialized) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! STUB: Return placeholder values
        x0 = 0; y0 = 0; x1 = 0; y1 = 0

        ! TODO: Implement using head table bounding box

    end subroutine stb_get_font_bounding_box_pure

    subroutine stb_get_codepoint_box_pure(font_info, codepoint, x0, y0, x1, y1)
        !! Get character bounding box (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: x0, y0, x1, y1

        if (.not. font_info%initialized) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! STUB: Return placeholder values
        x0 = 0; y0 = 0; x1 = 0; y1 = 0

        ! TODO: Implement glyph bounding box calculation

    end subroutine stb_get_codepoint_box_pure

    function stb_get_codepoint_kern_advance_pure(font_info, ch1, ch2) result(kern_advance)
        !! Get kerning advance between two characters (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: ch1, ch2
        integer :: kern_advance

        if (.not. font_info%initialized) then
            kern_advance = 0
            return
        end if

        ! STUB: Return no kerning
        kern_advance = 0

        ! TODO: Implement kern table parsing

    end function stb_get_codepoint_kern_advance_pure

    subroutine stb_get_font_vmetrics_os2_pure(font_info, typoAscent, typoDescent, &
                                             typoLineGap)
        !! Get OS/2 table vertical metrics (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(out) :: typoAscent, typoDescent, typoLineGap

        if (.not. font_info%initialized) then
            typoAscent = 0
            typoDescent = 0
            typoLineGap = 0
            return
        end if

        ! STUB: Return placeholder values
        typoAscent = 0
        typoDescent = 0
        typoLineGap = 0

        ! TODO: Implement using OS/2 table

    end subroutine stb_get_font_vmetrics_os2_pure

    subroutine stb_get_glyph_hmetrics_pure(font_info, glyph_index, advanceWidth, &
                                          leftSideBearing)
        !! Get horizontal glyph metrics by glyph index (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: advanceWidth, leftSideBearing

        if (.not. font_info%initialized) then
            advanceWidth = 0
            leftSideBearing = 0
            return
        end if

        ! STUB: Return placeholder values
        advanceWidth = 0
        leftSideBearing = 0

        ! TODO: Implement using hmtx table and glyph index

    end subroutine stb_get_glyph_hmetrics_pure

    subroutine stb_get_glyph_box_pure(font_info, glyph_index, x0, y0, x1, y1)
        !! Get glyph bounding box by glyph index (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: x0, y0, x1, y1

        if (.not. font_info%initialized) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! STUB: Return placeholder values
        x0 = 0; y0 = 0; x1 = 0; y1 = 0

        ! TODO: Implement glyph outline parsing and bounding box calculation

    end subroutine stb_get_glyph_box_pure

    function stb_get_glyph_kern_advance_pure(font_info, glyph1, glyph2) &
             result(kern_advance)
        !! Get kerning advance between two glyphs by glyph indices (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph1, glyph2
        integer :: kern_advance

        if (.not. font_info%initialized) then
            kern_advance = 0
            return
        end if

        ! STUB: Return no kerning
        kern_advance = 0

        ! TODO: Implement kern table parsing for glyph indices

    end function stb_get_glyph_kern_advance_pure

    function stb_get_kerning_table_length_pure(font_info) result(table_length)
        !! Get length of kerning table (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer :: table_length

        if (.not. font_info%initialized) then
            table_length = 0
            return
        end if

        ! STUB: Return no kerning table
        table_length = 0

        ! TODO: Implement kern table parsing

    end function stb_get_kerning_table_length_pure

    function stb_get_kerning_table_pure(font_info, table, table_length) &
             result(count)
        !! Get kerning table entries (STUB)
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        type(c_ptr), intent(in) :: table
        integer, intent(in) :: table_length
        integer :: count

        if (.not. font_info%initialized .or. .not. c_associated(table) &
            .or. table_length <= 0) then
            count = 0
            return
        end if

        ! STUB: Return no entries
        count = 0

        ! TODO: Implement kern table extraction

    end function stb_get_kerning_table_pure

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

    ! ============================================================================
    ! TrueType table parsing functions
    ! ============================================================================

    function parse_head_table(font_data, tables, head_table) result(success)
        !! Parse TrueType head table
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttf_table_entry_t), intent(in) :: tables(:)
        type(ttf_head_table_t), intent(out) :: head_table
        logical :: success
        integer :: table_offset, i

        success = .false.

        ! Find head table
        do i = 1, size(tables)
            if (tables(i)%tag == 'head') then
                table_offset = tables(i)%offset
                exit
            end if
            if (i == size(tables)) return  ! Table not found
        end do

        ! Check table size
        if (size(font_data) < table_offset + 53) return

        ! Parse head table fields
        head_table%major_version = read_be_uint16(font_data, table_offset)
        head_table%minor_version = read_be_uint16(font_data, table_offset + 2)
        head_table%font_revision = read_be_uint32(font_data, table_offset + 4)
        head_table%checksum_adjustment = read_be_uint32(font_data, table_offset + 8)
        head_table%magic_number = read_be_uint32(font_data, table_offset + 12)
        head_table%flags = read_be_uint16(font_data, table_offset + 16)
        head_table%units_per_em = read_be_uint16(font_data, table_offset + 18)
        head_table%created_high = read_be_uint32(font_data, table_offset + 20)
        head_table%created_low = read_be_uint32(font_data, table_offset + 24)
        head_table%modified_high = read_be_uint32(font_data, table_offset + 28)
        head_table%modified_low = read_be_uint32(font_data, table_offset + 32)
        head_table%x_min = read_be_int16(font_data, table_offset + 36)
        head_table%y_min = read_be_int16(font_data, table_offset + 38)
        head_table%x_max = read_be_int16(font_data, table_offset + 40)
        head_table%y_max = read_be_int16(font_data, table_offset + 42)
        head_table%mac_style = read_be_uint16(font_data, table_offset + 44)
        head_table%lowest_rec_ppem = read_be_uint16(font_data, table_offset + 46)
        head_table%font_direction_hint = read_be_int16(font_data, table_offset + 48)
        head_table%index_to_loc_format = read_be_int16(font_data, table_offset + 50)
        head_table%glyph_data_format = read_be_int16(font_data, table_offset + 52)

        ! Validate magic number
        if (head_table%magic_number /= 1594834165) return  ! 0x5F0F3CF5

        success = .true.

    end function parse_head_table

    function parse_hhea_table(font_data, tables, hhea_table) result(success)
        !! Parse TrueType hhea table
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttf_table_entry_t), intent(in) :: tables(:)
        type(ttf_hhea_table_t), intent(out) :: hhea_table
        logical :: success
        integer :: table_offset, i

        success = .false.

        ! Find hhea table
        do i = 1, size(tables)
            if (tables(i)%tag == 'hhea') then
                table_offset = tables(i)%offset
                exit
            end if
            if (i == size(tables)) return  ! Table not found
        end do

        ! Check table size
        if (size(font_data) < table_offset + 35) return

        ! Parse hhea table fields
        hhea_table%major_version = read_be_uint16(font_data, table_offset)
        hhea_table%minor_version = read_be_uint16(font_data, table_offset + 2)
        hhea_table%ascender = read_be_int16(font_data, table_offset + 4)
        hhea_table%descender = read_be_int16(font_data, table_offset + 6)
        hhea_table%line_gap = read_be_int16(font_data, table_offset + 8)
        hhea_table%advance_width_max = read_be_uint16(font_data, table_offset + 10)
        hhea_table%min_left_side_bearing = read_be_int16(font_data, table_offset + 12)
        hhea_table%min_right_side_bearing = read_be_int16(font_data, table_offset + 14)
        hhea_table%x_max_extent = read_be_int16(font_data, table_offset + 16)
        hhea_table%caret_slope_rise = read_be_int16(font_data, table_offset + 18)
        hhea_table%caret_slope_run = read_be_int16(font_data, table_offset + 20)
        hhea_table%caret_offset = read_be_int16(font_data, table_offset + 22)
        hhea_table%reserved1 = read_be_int16(font_data, table_offset + 24)
        hhea_table%reserved2 = read_be_int16(font_data, table_offset + 26)
        hhea_table%reserved3 = read_be_int16(font_data, table_offset + 28)
        hhea_table%reserved4 = read_be_int16(font_data, table_offset + 30)
        hhea_table%metric_data_format = read_be_int16(font_data, table_offset + 32)
        hhea_table%number_of_hmetrics = read_be_uint16(font_data, table_offset + 34)

        success = .true.

    end function parse_hhea_table

    function parse_maxp_table(font_data, tables, maxp_table) result(success)
        !! Parse TrueType maxp table
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttf_table_entry_t), intent(in) :: tables(:)
        type(ttf_maxp_table_t), intent(out) :: maxp_table
        logical :: success
        integer :: table_offset, i

        success = .false.

        ! Find maxp table
        do i = 1, size(tables)
            if (tables(i)%tag == 'maxp') then
                table_offset = tables(i)%offset
                exit
            end if
            if (i == size(tables)) return  ! Table not found
        end do

        ! Check minimum table size
        if (size(font_data) < table_offset + 5) return

        ! Parse maxp table fields
        maxp_table%version = read_be_uint32(font_data, table_offset)
        maxp_table%num_glyphs = read_be_uint16(font_data, table_offset + 4)

        ! If this is version 1.0, read additional fields
        if (maxp_table%version == 65536 .and. &
            size(font_data) >= table_offset + 31) then
            maxp_table%max_points = read_be_uint16(font_data, table_offset + 6)
            maxp_table%max_contours = read_be_uint16(font_data, table_offset + 8)
            maxp_table%max_composite_points = read_be_uint16(font_data, table_offset + 10)
            maxp_table%max_composite_contours = read_be_uint16(font_data, table_offset + 12)
            maxp_table%max_zones = read_be_uint16(font_data, table_offset + 14)
            maxp_table%max_twilight_points = read_be_uint16(font_data, table_offset + 16)
            maxp_table%max_storage = read_be_uint16(font_data, table_offset + 18)
            maxp_table%max_function_defs = read_be_uint16(font_data, table_offset + 20)
            maxp_table%max_instruction_defs = read_be_uint16(font_data, table_offset + 22)
            maxp_table%max_stack_elements = read_be_uint16(font_data, table_offset + 24)
            maxp_table%max_size_of_instructions = read_be_uint16(font_data, table_offset + 26)
            maxp_table%max_component_elements = read_be_uint16(font_data, table_offset + 28)
            maxp_table%max_component_depth = read_be_uint16(font_data, table_offset + 30)
        end if

        success = .true.

    end function parse_maxp_table

    function parse_cmap_table(font_data, tables, cmap_table) result(success)
        !! Parse cmap (Character Map) table for Unicode to glyph mapping
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttf_table_entry_t), intent(in) :: tables(:)
        type(ttf_cmap_table_t), intent(out) :: cmap_table
        logical :: success
        integer :: table_offset, i, subtable_offset, record_offset
        integer :: platform_id, encoding_id, format

        success = .false.

        ! Find cmap table
        table_offset = find_table_offset(tables, 'cmap')
        if (table_offset == 0) return

        ! Read cmap header
        cmap_table%version = read_be_uint16(font_data, table_offset)
        cmap_table%num_tables = read_be_uint16(font_data, table_offset + 2)

        if (cmap_table%num_tables <= 0 .or. cmap_table%num_tables > 20) return

        allocate(cmap_table%subtables(cmap_table%num_tables))

        ! Read subtable directory
        do i = 1, cmap_table%num_tables
            record_offset = table_offset + 4 + (i - 1) * 8

            cmap_table%subtables(i)%platform_id = read_be_uint16(font_data, record_offset)
            cmap_table%subtables(i)%encoding_id = read_be_uint16(font_data, record_offset + 2)
            cmap_table%subtables(i)%offset = table_offset + &
                                           read_be_uint32(font_data, record_offset + 4)
        end do

        ! Find preferred subtable (Unicode platform preferred)
        cmap_table%preferred_subtable = 0
        do i = 1, cmap_table%num_tables
            platform_id = cmap_table%subtables(i)%platform_id
            encoding_id = cmap_table%subtables(i)%encoding_id

            ! Prefer Unicode platform (3) with any encoding, or platform 0
            if (platform_id == 3 .or. platform_id == 0) then
                cmap_table%preferred_subtable = i
                exit
            end if
        end do

        ! If no Unicode table found, use first table
        if (cmap_table%preferred_subtable == 0) then
            cmap_table%preferred_subtable = 1
        end if

        ! Parse preferred subtable format
        i = cmap_table%preferred_subtable
        subtable_offset = cmap_table%subtables(i)%offset
        format = read_be_uint16(font_data, subtable_offset)
        cmap_table%subtables(i)%format = format

        ! For now, only implement format 4 (most common)
        if (format == 4) then
            if (.not. parse_cmap_format4(font_data, subtable_offset, &
                                       cmap_table%subtables(i))) then
                return
            end if
        end if

        success = .true.

    end function parse_cmap_table

    function parse_cmap_format4(font_data, offset, subtable) result(success)
        !! Parse cmap format 4 subtable (segment mapping to delta values)
        integer(c_int8_t), intent(in) :: font_data(:)
        integer, intent(in) :: offset
        type(ttf_cmap_subtable_t), intent(inout) :: subtable
        logical :: success
        integer :: length, seg_count_x2, i
        integer :: start_code_offset, id_delta_offset, id_range_offset_base

        success = .false.

        ! Read format 4 header
        subtable%length = read_be_uint16(font_data, offset + 2)
        ! Skip language field at offset + 4
        seg_count_x2 = read_be_uint16(font_data, offset + 6)
        subtable%seg_count = seg_count_x2 / 2

        if (subtable%seg_count <= 0 .or. subtable%seg_count > 1000) return

        ! Allocate arrays for segment data
        allocate(subtable%end_code(subtable%seg_count))
        allocate(subtable%start_code(subtable%seg_count))
        allocate(subtable%id_delta(subtable%seg_count))
        allocate(subtable%id_range_offset(subtable%seg_count))

        ! Read endCode array
        do i = 1, subtable%seg_count
            subtable%end_code(i) = read_be_uint16(font_data, offset + 14 + (i-1) * 2)
        end do

        ! Skip reserved pad (2 bytes after endCode)
        start_code_offset = offset + 14 + subtable%seg_count * 2 + 2

        ! Read startCode array
        do i = 1, subtable%seg_count
            subtable%start_code(i) = read_be_uint16(font_data, start_code_offset + (i-1) * 2)
        end do

        ! Read idDelta array
        id_delta_offset = start_code_offset + subtable%seg_count * 2
        do i = 1, subtable%seg_count
            subtable%id_delta(i) = read_be_int16(font_data, id_delta_offset + (i-1) * 2)
        end do

        ! Read idRangeOffset array
        id_range_offset_base = id_delta_offset + subtable%seg_count * 2
        do i = 1, subtable%seg_count
            subtable%id_range_offset(i) = read_be_uint16(font_data, &
                                                        id_range_offset_base + (i-1) * 2)
        end do

        success = .true.

    end function parse_cmap_format4

    function find_table_offset(tables, tag) result(offset)
        !! Find offset of table with given tag
        type(ttf_table_entry_t), intent(in) :: tables(:)
        character(len=4), intent(in) :: tag
        integer :: offset
        integer :: i

        offset = 0
        do i = 1, size(tables)
            if (tables(i)%tag == tag) then
                offset = tables(i)%offset
                exit
            end if
        end do

    end function find_table_offset

end module fortplot_stb
