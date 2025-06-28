module forttf_metrics
    !! Pure Fortran implementation of TrueType font metrics functionality (derived from stb_truetype.h)
    !! Handles horizontal metrics, vertical metrics, OS/2 metrics, and kerning
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_parser
    use forttf_mapping
    implicit none

    private

    ! Public interface
    public :: stb_scale_for_pixel_height_pure
    public :: stb_get_font_vmetrics_pure
    public :: stb_get_codepoint_hmetrics_pure
    public :: stb_scale_for_mapping_em_to_pixels_pure
    public :: stb_get_font_bounding_box_pure
    public :: stb_get_codepoint_box_pure
    public :: stb_get_glyph_hmetrics_pure
    public :: stb_get_glyph_box_pure
    public :: stb_get_font_vmetrics_os2_pure
    public :: stb_get_codepoint_kern_advance_pure
    public :: stb_get_glyph_kern_advance_pure
    public :: stb_get_kerning_table_length_pure
    public :: stb_get_kerning_table_pure

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
            x0 = 0
            y0 = 0
            x1 = 0
            y1 = 0
            return
        end if

        ! Map Unicode codepoint to glyph index
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)

        ! Get glyph bounding box
        call stb_get_glyph_box_pure(font_info, glyph_index, x0, y0, x1, y1)

    end subroutine stb_get_codepoint_box_pure

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

end module forttf_metrics