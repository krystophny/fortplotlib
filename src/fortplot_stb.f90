module fortplot_stb
    !! Pure Fortran implementation of TrueType font functionality (STUB MODULE)
    !! This module provides stubs for a future pure Fortran port that can replace stb_truetype.h dependency
    !! Currently returns placeholder/error values - implementation is planned for future development
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_truetype_types
    use fortplot_truetype_parser
    use fortplot_stb_core
    implicit none

    private

    ! Re-export types from types module
    public :: stb_fontinfo_pure_t
    public :: ttf_table_entry_t, ttf_header_t, ttf_head_table_t
    public :: ttf_hhea_table_t, ttf_maxp_table_t, ttf_cmap_table_t
    public :: ttf_cmap_subtable_t, ttc_header_t
    public :: stb_fontinfo_pure_t, stb_init_font_pure, stb_init_font_pure_with_index, stb_cleanup_font_pure
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
        !! Get horizontal character metrics
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: advance_width, left_side_bearing
        integer :: glyph_index

        if (.not. font_info%initialized) then
            advance_width = 0
            left_side_bearing = 0
            return
        end if

        ! Map Unicode codepoint to glyph index
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)

        ! Get glyph horizontal metrics
        call stb_get_glyph_hmetrics_pure(font_info, glyph_index, advance_width, left_side_bearing)

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

        ! STUB: Do nothing since we don't allocate anything yet

        ! TODO: Implement memory deallocation

    end subroutine stb_free_bitmap_pure


    function stb_scale_for_mapping_em_to_pixels_pure(font_info, pixels) result(scale)
        !! Calculate scale factor for desired em size
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: pixels
        real(wp) :: scale
        integer :: units_per_em, head_table_idx, head_offset

        if (.not. font_info%initialized) then
            scale = 0.0_wp
            return
        end if

        ! Find head table
        head_table_idx = find_table(font_info%tables, 'head')
        if (head_table_idx == 0) then
            scale = 0.0_wp
            return
        end if

        head_offset = font_info%tables(head_table_idx)%offset

        ! Get unitsPerEm from head table at offset 18 (2-byte unsigned short)
        units_per_em = read_be_uint16(font_info%font_data, head_offset + 18)

        if (units_per_em > 0) then
            scale = pixels / real(units_per_em, wp)
        else
            scale = 0.0_wp
        end if

    end function stb_scale_for_mapping_em_to_pixels_pure

    subroutine stb_get_font_bounding_box_pure(font_info, x0, y0, x1, y1)
        !! Get font bounding box
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(out) :: x0, y0, x1, y1
        integer :: head_table_idx, head_offset

        if (.not. font_info%initialized) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! Find head table
        head_table_idx = find_table(font_info%tables, 'head')
        if (head_table_idx == 0) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        head_offset = font_info%tables(head_table_idx)%offset

        ! Read font bounding box from head table at offsets 36, 38, 40, 42
        x0 = read_be_int16(font_info%font_data, head_offset + 36)
        y0 = read_be_int16(font_info%font_data, head_offset + 38)
        x1 = read_be_int16(font_info%font_data, head_offset + 40)
        y1 = read_be_int16(font_info%font_data, head_offset + 42)

    end subroutine stb_get_font_bounding_box_pure

    subroutine stb_get_codepoint_box_pure(font_info, codepoint, x0, y0, x1, y1)
        !! Get character bounding box
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: x0, y0, x1, y1
        integer :: glyph_index

        if (.not. font_info%initialized) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! Map Unicode codepoint to glyph index
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)

        ! Get glyph bounding box
        call stb_get_glyph_box_pure(font_info, glyph_index, x0, y0, x1, y1)

    end subroutine stb_get_codepoint_box_pure

    function stb_get_codepoint_kern_advance_pure(font_info, ch1, ch2) result(kern_advance)
        !! Get kerning advance between two characters
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        integer, intent(in) :: ch1, ch2
        integer :: kern_advance
        integer :: glyph1, glyph2

        if (.not. font_info%initialized) then
            kern_advance = 0
            return
        end if

        ! Parse kern table if not already done
        if (.not. font_info%kern_parsed) then
            call parse_kern_table_if_available(font_info)
        end if

        ! If no kern table, return 0
        if (.not. font_info%kern_table%has_horizontal) then
            kern_advance = 0
            return
        end if

        ! Find glyph indices for the codepoints
        glyph1 = stb_find_glyph_index_pure(font_info, ch1)
        glyph2 = stb_find_glyph_index_pure(font_info, ch2)

        if (glyph1 <= 0 .or. glyph2 <= 0) then
            kern_advance = 0
            return
        end if

        ! Look up kerning in parsed table
        kern_advance = find_kerning_advance(font_info%kern_table, glyph1, glyph2)

    end function stb_get_codepoint_kern_advance_pure

    function stb_get_font_vmetrics_os2_pure(font_info, typoAscent, typoDescent, &
                                           typoLineGap) result(success)
        !! Get OS/2 table vertical metrics
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(out) :: typoAscent, typoDescent, typoLineGap
        integer :: success
        integer :: os2_table_idx, os2_offset

        if (.not. font_info%initialized) then
            typoAscent = 0
            typoDescent = 0
            typoLineGap = 0
            success = 0
            return
        end if

        ! Find OS/2 table
        os2_table_idx = find_table(font_info%tables, 'OS/2')
        if (os2_table_idx == 0) then
            typoAscent = 0
            typoDescent = 0
            typoLineGap = 0
            success = 0
            return
        end if

        os2_offset = font_info%tables(os2_table_idx)%offset

        ! Read OS/2 typo metrics from table at offsets 68, 70, 72
        typoAscent = read_be_int16(font_info%font_data, os2_offset + 68)
        typoDescent = read_be_int16(font_info%font_data, os2_offset + 70)
        typoLineGap = read_be_int16(font_info%font_data, os2_offset + 72)

        success = 1

    end function stb_get_font_vmetrics_os2_pure

    subroutine stb_get_glyph_hmetrics_pure(font_info, glyph_index, advanceWidth, &
                                          leftSideBearing)
        !! Get horizontal glyph metrics by glyph index
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: advanceWidth, leftSideBearing
        integer :: hmtx_table_idx, hmtx_offset, num_hmetrics

        if (.not. font_info%initialized) then
            advanceWidth = 0
            leftSideBearing = 0
            return
        end if

        ! Find hmtx table
        hmtx_table_idx = find_table(font_info%tables, 'hmtx')
        if (hmtx_table_idx == 0) then
            ! No hmtx table found
            advanceWidth = 0
            leftSideBearing = 0
            return
        end if

        hmtx_offset = font_info%tables(hmtx_table_idx)%offset

        ! Get number of horizontal metrics from hhea table
        num_hmetrics = font_info%hhea_table%number_of_hmetrics

        if (glyph_index < num_hmetrics) then
            ! Read from longHorMetric entries (4 bytes each: 2-byte advance + 2-byte lsb)
            advanceWidth = read_be_uint16(font_info%font_data, hmtx_offset + 4 * glyph_index)
            leftSideBearing = read_be_int16(font_info%font_data, hmtx_offset + 4 * glyph_index + 2)
        else
            ! Read last advance width (reused for all remaining glyphs)
            advanceWidth = read_be_uint16(font_info%font_data, hmtx_offset + 4 * (num_hmetrics - 1))
            ! Read left side bearing from leftSideBearing array
            leftSideBearing = read_be_int16(font_info%font_data, &
                                          hmtx_offset + 4 * num_hmetrics + 2 * (glyph_index - num_hmetrics))
        end if

    end subroutine stb_get_glyph_hmetrics_pure

    subroutine stb_get_glyph_box_pure(font_info, glyph_index, x0, y0, x1, y1)
        !! Get glyph bounding box by glyph index
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: x0, y0, x1, y1
        integer :: glyf_table_idx, loca_table_idx, glyf_offset, loca_offset
        integer :: glyph_data_offset, glyph_data_length
        integer :: next_glyph_offset

        if (.not. font_info%initialized) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! Find glyf and loca tables
        glyf_table_idx = find_table(font_info%tables, 'glyf')
        loca_table_idx = find_table(font_info%tables, 'loca')

        if (glyf_table_idx == 0 .or. loca_table_idx == 0) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        glyf_offset = font_info%tables(glyf_table_idx)%offset
        loca_offset = font_info%tables(loca_table_idx)%offset

        ! TODO: This is a simplified implementation
        ! The real implementation needs to:
        ! 1. Check indexToLocFormat from head table (short vs long offsets)
        ! 2. Read the correct offset format from loca table
        ! 3. Parse the glyph data structure from glyf table

        ! For now, assume long format (4-byte offsets) and return placeholder
        if (glyph_index < 0 .or. glyph_index >= font_info%num_glyphs) then
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! Simplified glyph offset calculation (assumes long format)
        glyph_data_offset = read_be_uint32(font_info%font_data, loca_offset + 4 * glyph_index)
        next_glyph_offset = read_be_uint32(font_info%font_data, loca_offset + 4 * (glyph_index + 1))

        glyph_data_length = next_glyph_offset - glyph_data_offset

        if (glyph_data_length == 0) then
            ! Empty glyph
            x0 = 0; y0 = 0; x1 = 0; y1 = 0
            return
        end if

        ! Read glyph bounding box from glyph data (at offsets +2, +4, +6, +8)
        glyph_data_offset = glyf_offset + glyph_data_offset
        x0 = read_be_int16(font_info%font_data, glyph_data_offset + 2)
        y0 = read_be_int16(font_info%font_data, glyph_data_offset + 4)
        x1 = read_be_int16(font_info%font_data, glyph_data_offset + 6)
        y1 = read_be_int16(font_info%font_data, glyph_data_offset + 8)

    end subroutine stb_get_glyph_box_pure

    function stb_get_glyph_kern_advance_pure(font_info, glyph1, glyph2) &
             result(kern_advance)
        !! Get kerning advance between two glyphs by glyph indices
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        integer, intent(in) :: glyph1, glyph2
        integer :: kern_advance

        if (.not. font_info%initialized) then
            kern_advance = 0
            return
        end if

        ! Parse kern table if not already done
        if (.not. font_info%kern_parsed) then
            call parse_kern_table_if_available(font_info)
        end if

        ! If no kern table, return 0
        if (.not. font_info%kern_table%has_horizontal) then
            kern_advance = 0
            return
        end if

        ! Look up kerning in parsed table
        kern_advance = find_kerning_advance(font_info%kern_table, glyph1, glyph2)

    end function stb_get_glyph_kern_advance_pure

    function stb_get_kerning_table_length_pure(font_info) result(table_length)
        !! Get length of kerning table
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        integer :: table_length

        if (.not. font_info%initialized) then
            table_length = 0
            return
        end if

        ! Parse kern table if not already done
        if (.not. font_info%kern_parsed) then
            call parse_kern_table_if_available(font_info)
        end if

        ! Return length of horizontal kerning table
        if (font_info%kern_table%has_horizontal) then
            table_length = font_info%kern_table%horizontal_table_length
        else
            table_length = 0
        end if

    end function stb_get_kerning_table_length_pure

    function stb_get_kerning_table_pure(font_info, table, table_length) &
             result(count)
        !! Get kerning table entries
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        type(c_ptr), intent(in) :: table
        integer, intent(in) :: table_length
        integer :: count
        type(ttf_kern_entry_t), pointer :: entries(:)
        integer :: i, actual_length

        if (.not. font_info%initialized .or. .not. c_associated(table) &
            .or. table_length <= 0) then
            count = 0
            return
        end if

        ! Parse kern table if not already done
        if (.not. font_info%kern_parsed) then
            call parse_kern_table_if_available(font_info)
        end if

        ! If no kern table, return 0
        if (.not. font_info%kern_table%has_horizontal .or. &
            .not. allocated(font_info%kern_table%entries)) then
            count = 0
            return
        end if

        ! Convert C pointer to Fortran array
        call c_f_pointer(table, entries, [table_length])

        ! Copy kerning entries up to the limit
        actual_length = min(table_length, size(font_info%kern_table%entries))

        do i = 1, actual_length
            entries(i) = font_info%kern_table%entries(i)
        end do

        count = actual_length

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


end module fortplot_stb
