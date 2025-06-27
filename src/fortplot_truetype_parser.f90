module fortplot_truetype_parser
    !! TrueType font table parsing implementation
    !! Contains all the table parsing logic for the native TrueType implementation
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8, int16, int32
    use fortplot_truetype_types
    use fortplot_truetype_reader
    implicit none

    private
    public :: parse_truetype_font, parse_glyph_header, parse_simple_glyph_endpoints, parse_simple_glyph_points

contains

    function parse_truetype_font(font_info) result(success)
        !! Parse TrueType font completely
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer(int32) :: signature, font_offset
        integer(int16) :: num_tables
        integer :: i

        success = .false.

        if (.not. allocated(font_info%font_data) .or. size(font_info%font_data) < 16) then
            return
        end if

        ! Determine font offset (for TTC collections)
        font_offset = get_font_offset_for_index(font_info%font_data, 0)
        if (font_offset < 0) return

        font_info%font_start = font_offset + 1  ! Convert to 1-based

        ! Read SFNT header
        signature = read_uint32_be(font_info%font_data, font_info%font_start)
        num_tables = read_uint16_be(font_info%font_data, font_info%font_start + 4)

        ! Verify signature
        if (signature /= SFNT_VERSION .and. signature /= TRUE_SIGNATURE) then
            return
        end if

        font_info%num_tables = num_tables

        ! Read table directory
        allocate(font_info%tables(num_tables))
        if (.not. read_table_directory(font_info)) return

        ! Parse required tables - implement step by step
        if (.not. parse_head_table_simple(font_info)) return
        if (.not. parse_maxp_table_simple(font_info)) return
        if (.not. parse_hhea_table_simple(font_info)) return

        ! Parse additional tables for proper character mapping and metrics
        call parse_cmap_table_simple(font_info)
        call parse_hmtx_table_simple(font_info)
        call parse_loca_table_simple(font_info)
        call find_glyf_table(font_info)

        success = .true.

    end function parse_truetype_font

    function get_font_offset_for_index(data, index) result(offset)
        !! Get offset for font at index (for TTC collections)
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: index
        integer(int32) :: offset
        integer(int32) :: signature

        if (size(data) < 4) then
            offset = -1
            return
        end if

        signature = read_uint32_be(data, 1)

        if (signature == TTCF_SIGNATURE) then  ! 'ttcf'
            ! TrueType Collection - simplified: just return 0 for now
            offset = 0
        else
            ! Single font
            if (index /= 0) then
                offset = -1
                return
            end if
            offset = 0
        end if

    end function get_font_offset_for_index

    function read_table_directory(font_info) result(success)
        !! Read the table directory (simplified)
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: i, table_offset

        success = .false.

        if (.not. allocated(font_info%tables)) return

        ! Read table entries (simplified - just allocate for now)
        do i = 1, font_info%num_tables
            table_offset = font_info%font_start + 12 + (i - 1) * 16

            if (size(font_info%font_data) >= table_offset + 16) then
                font_info%tables(i)%tag = read_uint32_be(font_info%font_data, table_offset)
                font_info%tables(i)%checksum = read_uint32_be(font_info%font_data, table_offset + 4)
                font_info%tables(i)%offset = read_uint32_be(font_info%font_data, table_offset + 8)
                font_info%tables(i)%length = read_uint32_be(font_info%font_data, table_offset + 12)
            end if
        end do

        success = .true.

    end function read_table_directory

    function find_table(font_info, tag) result(table_index)
        !! Find table by tag
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int32), intent(in) :: tag
        integer :: table_index
        integer :: i

        table_index = -1

        if (.not. allocated(font_info%tables)) return

        do i = 1, font_info%num_tables
            if (font_info%tables(i)%tag == tag) then
                table_index = i
                return
            end if
        end do

    end function find_table

    function parse_head_table_simple(font_info) result(success)
        !! Parse 'head' table - extract units per EM
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset

        success = .false.

        table_idx = find_table(font_info, TAG_HEAD)
        if (table_idx == -1) return

        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based

        if (size(font_info%font_data) < offset + 54 - 1) return

        ! Read units per EM (offset 18 in head table)
        font_info%units_per_em = read_uint16_be(font_info%font_data, offset + 18)

        ! Read index to location format (offset 50)
        font_info%index_to_loc_format = read_int16_be(font_info%font_data, offset + 50)

        font_info%head_offset = offset
        success = .true.

    end function parse_head_table_simple

    function parse_maxp_table_simple(font_info) result(success)
        !! Parse 'maxp' table - extract number of glyphs
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset

        success = .false.

        table_idx = find_table(font_info, TAG_MAXP)
        if (table_idx == -1) then
            return
        end if

        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based

        if (offset <= 0 .or. offset > size(font_info%font_data) - 6) then
            return
        end if

        ! Read number of glyphs (offset 4 in maxp table)
        font_info%num_glyphs = read_uint16_be(font_info%font_data, offset + 4)

        font_info%maxp_offset = offset
        success = .true.

    end function parse_maxp_table_simple

    function parse_hhea_table_simple(font_info) result(success)
        !! Parse 'hhea' table - extract vertical metrics
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset

        success = .false.

        table_idx = find_table(font_info, TAG_HHEA)
        if (table_idx == -1) return

        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based

        if (size(font_info%font_data) < offset + 36 - 1) return

        ! Read vertical metrics (offsets 4, 6, 8 in hhea table)
        font_info%ascent = read_int16_be(font_info%font_data, offset + 4)
        font_info%descent = read_int16_be(font_info%font_data, offset + 6)
        font_info%line_gap = read_int16_be(font_info%font_data, offset + 8)

        font_info%hhea_offset = offset
        success = .true.

    end function parse_hhea_table_simple

    subroutine parse_cmap_table_simple(font_info)
        !! Parse 'cmap' table - simplified Unicode mapping
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx, offset, num_subtables, i
        integer(int16) :: platform_id, encoding_id, format
        integer(int32) :: subtable_offset

        table_idx = find_table(font_info, TAG_CMAP)
        if (table_idx == -1) then
            call create_simple_unicode_mapping(font_info)
            return
        end if

        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based

        if (size(font_info%font_data) < offset + 4 - 1) then
            call create_simple_unicode_mapping(font_info)
            return
        end if

        ! Read number of encoding subtables
        num_subtables = read_uint16_be(font_info%font_data, offset + 2)

        ! Find a suitable Unicode subtable (simplified)
        do i = 0, min(num_subtables - 1, 10)  ! Limit search
            if (size(font_info%font_data) < offset + 4 + i * 8 + 8 - 1) cycle

            platform_id = read_uint16_be(font_info%font_data, offset + 4 + i * 8)
            encoding_id = read_uint16_be(font_info%font_data, offset + 4 + i * 8 + 2)
            subtable_offset = read_uint32_be(font_info%font_data, offset + 4 + i * 8 + 4)

            ! Look for Unicode platform (3) or Microsoft Unicode (3,1)
            if ((platform_id == 3 .and. (encoding_id == 1 .or. encoding_id == 10)) .or. &
                (platform_id == 0)) then

                font_info%cmap_subtable%platform_id = platform_id
                font_info%cmap_subtable%encoding_id = encoding_id
                font_info%cmap_subtable%offset = offset + int(subtable_offset)

                ! Read subtable format
                if (font_info%cmap_subtable%offset > 0 .and. &
                    size(font_info%font_data) >= font_info%cmap_subtable%offset + 2) then
                    format = read_uint16_be(font_info%font_data, font_info%cmap_subtable%offset)
                    font_info%cmap_subtable%format = format
                    font_info%cmap_subtable%valid = .true.
                end if

                exit
            end if
        end do

        ! Create character mapping based on what we found
        if (font_info%cmap_subtable%valid) then
            call create_unicode_mapping_from_cmap(font_info)
        else
            call create_simple_unicode_mapping(font_info)
        end if

        font_info%cmap_offset = offset

    end subroutine parse_cmap_table_simple

    subroutine parse_hmtx_table_simple(font_info)
        !! Parse 'hmtx' table - simplified horizontal metrics
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx, offset, i, num_long_hor_metrics
        integer :: advance_width, left_side_bearing

        table_idx = find_table(font_info, TAG_HMTX)
        if (table_idx == -1) then
            call create_default_metrics(font_info)
            return
        end if

        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based

        ! Get number of horizontal metrics from hhea table
        if (font_info%hhea_offset == 0) then
            call create_default_metrics(font_info)
            return
        end if

        if (size(font_info%font_data) < font_info%hhea_offset + 34 + 2 - 1) then
            call create_default_metrics(font_info)
            return
        end if

        num_long_hor_metrics = read_uint16_be(font_info%font_data, font_info%hhea_offset + 34)

        ! Allocate arrays
        if (allocated(font_info%advance_widths)) deallocate(font_info%advance_widths)
        if (allocated(font_info%left_side_bearings)) deallocate(font_info%left_side_bearings)

        allocate(font_info%advance_widths(font_info%num_glyphs))
        allocate(font_info%left_side_bearings(font_info%num_glyphs))

        ! Read horizontal metrics (simplified - read what we can)
        do i = 0, min(font_info%num_glyphs - 1, num_long_hor_metrics - 1)
            if (size(font_info%font_data) >= offset + i * 4 + 4 - 1) then
                advance_width = read_uint16_be(font_info%font_data, offset + i * 4)
                left_side_bearing = read_int16_be(font_info%font_data, offset + i * 4 + 2)
            else
                advance_width = 500  ! Default
                left_side_bearing = 0
            end if

            font_info%advance_widths(i + 1) = advance_width
            font_info%left_side_bearings(i + 1) = left_side_bearing
        end do

        ! Propagate last advance width for remaining glyphs
        if (num_long_hor_metrics < font_info%num_glyphs) then
            advance_width = font_info%advance_widths(num_long_hor_metrics)
            do i = num_long_hor_metrics, font_info%num_glyphs - 1
                font_info%advance_widths(i + 1) = advance_width
            end do
        end if

        font_info%hmtx_offset = offset

    end subroutine parse_hmtx_table_simple

    subroutine parse_loca_table_simple(font_info)
        !! Parse 'loca' table - get glyph offsets
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx, offset, i

        table_idx = find_table(font_info, TAG_LOCA)
        if (table_idx == -1) return

        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based

        if (allocated(font_info%glyph_offsets)) deallocate(font_info%glyph_offsets)
        allocate(font_info%glyph_offsets(font_info%num_glyphs + 1))

        if (font_info%index_to_loc_format == 0) then ! short format
            do i = 0, font_info%num_glyphs
                font_info%glyph_offsets(i + 1) = int(read_uint16_be(font_info%font_data, offset + i * 2)) * 2
            end do
        else ! long format
            do i = 0, font_info%num_glyphs
                font_info%glyph_offsets(i + 1) = read_uint32_be(font_info%font_data, offset + i * 4)
            end do
        end if

        font_info%loca_offset = offset

    end subroutine parse_loca_table_simple

    subroutine find_glyf_table(font_info)
        !! Find 'glyf' table offset
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx

        table_idx = find_table(font_info, TAG_GLYF)
        if (table_idx /= -1) then
            font_info%glyf_offset = int(font_info%tables(table_idx)%offset) + 1
        end if

    end subroutine find_glyf_table

    subroutine parse_glyph_header(font_info, glyph_index, number_of_contours, x_min, y_min, x_max, y_max)
        !! Parse glyph header to get bounding box
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: number_of_contours, x_min, y_min, x_max, y_max
        integer :: glyph_offset

        number_of_contours = 0
        x_min = 0; y_min = 0; x_max = 0; y_max = 0

        if (glyph_index <= 0 .or. glyph_index > font_info%num_glyphs) return
        if (.not. allocated(font_info%glyph_offsets)) return

        glyph_offset = font_info%glyf_offset + font_info%glyph_offsets(glyph_index)

        if (glyph_offset <= 0 .or. glyph_offset > size(font_info%font_data) - 10) return

        number_of_contours = read_int16_be(font_info%font_data, glyph_offset)
        x_min = read_int16_be(font_info%font_data, glyph_offset + 2)
        y_min = read_int16_be(font_info%font_data, glyph_offset + 4)
        x_max = read_int16_be(font_info%font_data, glyph_offset + 6)
        y_max = read_int16_be(font_info%font_data, glyph_offset + 8)

    end subroutine parse_glyph_header

    subroutine parse_simple_glyph_endpoints(font_info, glyph_index, endpoints, success)
        !! Parse endpoints of contours for a simple glyph
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, allocatable, intent(out) :: endpoints(:)
        logical, intent(out) :: success
        integer :: glyph_offset, number_of_contours, i

        success = .false.

        if (glyph_index <= 0 .or. glyph_index > font_info%num_glyphs) return
        if (.not. allocated(font_info%glyph_offsets)) return

        glyph_offset = font_info%glyf_offset + font_info%glyph_offsets(glyph_index)

        if (glyph_offset <= 0 .or. glyph_offset > size(font_info%font_data) - 10) return

        number_of_contours = read_int16_be(font_info%font_data, glyph_offset)

        if (number_of_contours <= 0) then
            if (number_of_contours == 0) success = .true.
            return
        end if

        allocate(endpoints(number_of_contours))

        ! Endpoints are after the glyph header (10 bytes)
        do i = 1, number_of_contours
            endpoints(i) = read_uint16_be(font_info%font_data, glyph_offset + 10 + (i-1)*2)
        end do
        success = .true.

    end subroutine parse_simple_glyph_endpoints

    subroutine parse_simple_glyph_points(font_info, glyph_index, points, num_points, success)
        !! Parse points for a simple glyph
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        type(glyph_point_t), allocatable, intent(out) :: points(:)
        integer, intent(out) :: num_points
        logical, intent(out) :: success

        integer :: glyph_offset, number_of_contours, instruction_length, flags_offset, x_offset, y_offset
        integer :: i, flag, repeat_count, x_val, y_val, val
        integer, allocatable :: endpoints(:)

        success = .false.
        num_points = 0

        if (glyph_index <= 0 .or. glyph_index > font_info%num_glyphs) return
        if (.not. allocated(font_info%glyph_offsets)) return

        glyph_offset = font_info%glyf_offset + font_info%glyph_offsets(glyph_index)

        if (glyph_offset <= 0 .or. glyph_offset > size(font_info%font_data) - 10) return

        number_of_contours = read_int16_be(font_info%font_data, glyph_offset)

        if (number_of_contours <= 0) then
            if (number_of_contours == 0) success = .true.
            return
        end if

        allocate(endpoints(number_of_contours))
        do i = 1, number_of_contours
            endpoints(i) = read_uint16_be(font_info%font_data, glyph_offset + 10 + (i-1)*2)
        end do

        if (number_of_contours > 0) then
            num_points = endpoints(number_of_contours) + 1
        else
            num_points = 0
        end if

        if (num_points == 0) then
            deallocate(endpoints)
            success = .true.
            return
        end if

        allocate(points(num_points))

        instruction_length = read_uint16_be(font_info%font_data, glyph_offset + 10 + number_of_contours * 2)
        flags_offset = glyph_offset + 10 + number_of_contours * 2 + 2 + instruction_length

        ! Parse flags
        i = 1
        do while (i <= num_points)
            if (flags_offset > size(font_info%font_data)) then; deallocate(endpoints, points); success=.false.; return; end if
            flag = read_uint8(font_info%font_data, flags_offset)
            flags_offset = flags_offset + 1
            points(i)%flags = int(flag, int8)

            if (btest(flag, 3)) then ! repeat flag
                if (flags_offset > size(font_info%font_data)) then; deallocate(endpoints, points); success=.false.; return; end if
                repeat_count = read_uint8(font_info%font_data, flags_offset)
                flags_offset = flags_offset + 1
                do while (repeat_count > 0 .and. i < num_points)
                    i = i + 1
                    points(i)%flags = int(flag, int8)
                    repeat_count = repeat_count - 1
                end do
            end if
            i = i + 1
        end do

        ! Parse x-coordinates
        x_offset = flags_offset
        x_val = 0
        do i = 1, num_points
            flag = int(points(i)%flags)
            if (btest(flag, 1)) then ! x-short vector
                if (x_offset > size(font_info%font_data)) then; deallocate(endpoints, points); success=.false.; return; end if
                val = read_uint8(font_info%font_data, x_offset)
                if (btest(flag, 4)) then ! This bit means the sign is positive
                    x_val = x_val + val
                else ! sign is negative
                    x_val = x_val - val
                end if
                x_offset = x_offset + 1
            else
                if (.not. btest(flag, 4)) then ! not x-is-same
                    if (x_offset > size(font_info%font_data) - 1) then; deallocate(endpoints, points); success=.false.; return; end if
                    x_val = x_val + read_int16_be(font_info%font_data, x_offset)
                    x_offset = x_offset + 2
                end if
            end if
            points(i)%x = int(x_val, int16)
        end do

        ! Parse y-coordinates
        y_offset = x_offset
        y_val = 0
        do i = 1, num_points
            flag = int(points(i)%flags)
            if (btest(flag, 2)) then ! y-short vector
                if (y_offset > size(font_info%font_data)) then; deallocate(endpoints, points); success=.false.; return; end if
                val = read_uint8(font_info%font_data, y_offset)
                if (btest(flag, 5)) then ! This bit means the sign is positive
                    y_val = y_val + val
                else ! sign is negative
                    y_val = y_val - val
                end if
                y_offset = y_offset + 1
            else
                if (.not. btest(flag, 5)) then ! not y-is-same
                    if (y_offset > size(font_info%font_data) - 1) then; deallocate(endpoints, points); success=.false.; return; end if
                    y_val = y_val + read_int16_be(font_info%font_data, y_offset)
                    y_offset = y_offset + 2
                end if
            end if
            points(i)%y = int(y_val, int16)
        end do

        deallocate(endpoints)
        success = .true.

    end subroutine parse_simple_glyph_points

    subroutine create_simple_unicode_mapping(font_info)
        !! Create a simple 1-to-1 mapping for basic characters
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: i

        if (allocated(font_info%unicode_to_glyph)) deallocate(font_info%unicode_to_glyph)
        allocate(font_info%unicode_to_glyph(0:255))

        do i = 0, 255
            if (i < font_info%num_glyphs) then
                font_info%unicode_to_glyph(i) = i
            else
                font_info%unicode_to_glyph(i) = 0
            end if
        end do

    end subroutine create_simple_unicode_mapping

    subroutine create_unicode_mapping_from_cmap(font_info)
        !! Create mapping from cmap subtable (simplified format 4)
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: offset, length, seg_count_x2, search_range, entry_selector, range_shift, i
        integer :: end_code_offset, start_code_offset, id_delta_offset, id_range_offset_offset
        integer :: start_code, end_code, id_delta, id_range_offset, c, glyph_id, p

        if (.not. font_info%cmap_subtable%valid .or. font_info%cmap_subtable%format /= 4) then
            call create_simple_unicode_mapping(font_info)
            return
        end if

        offset = font_info%cmap_subtable%offset
        length = read_uint16_be(font_info%font_data, offset + 2)
        seg_count_x2 = read_uint16_be(font_info%font_data, offset + 6)

        if (allocated(font_info%unicode_to_glyph)) deallocate(font_info%unicode_to_glyph)
        allocate(font_info%unicode_to_glyph(0:65535))
        font_info%unicode_to_glyph = 0

        end_code_offset = offset + 14
        start_code_offset = end_code_offset + seg_count_x2 + 2
        id_delta_offset = start_code_offset + seg_count_x2
        id_range_offset_offset = id_delta_offset + seg_count_x2

        do i = 0, (seg_count_x2 / 2) - 1
            start_code = read_uint16_be(font_info%font_data, start_code_offset + i * 2)
            end_code = read_uint16_be(font_info%font_data, end_code_offset + i * 2)
            id_delta = read_int16_be(font_info%font_data, id_delta_offset + i * 2)
            id_range_offset = read_uint16_be(font_info%font_data, id_range_offset_offset + i * 2)

            do c = start_code, end_code
                if (id_range_offset == 0) then
                    glyph_id = mod(c + id_delta, 65536)
                else
                    p = id_range_offset_offset + i * 2 + id_range_offset + (c - start_code) * 2
                    glyph_id = read_uint16_be(font_info%font_data, p)
                    if (glyph_id /= 0) then
                        glyph_id = mod(glyph_id + id_delta, 65536)
                    end if
                end if
                if (c >= 0 .and. c <= 65535) then
                    font_info%unicode_to_glyph(c) = glyph_id
                end if
            end do
        end do

    end subroutine create_unicode_mapping_from_cmap

    subroutine create_default_metrics(font_info)
        !! Create default horizontal metrics
        type(native_fontinfo_t), intent(inout) :: font_info

        if (allocated(font_info%advance_widths)) deallocate(font_info%advance_widths)
        if (allocated(font_info%left_side_bearings)) deallocate(font_info%left_side_bearings)

        allocate(font_info%advance_widths(font_info%num_glyphs))
        allocate(font_info%left_side_bearings(font_info%num_glyphs))

        font_info%advance_widths = 500
        font_info%left_side_bearings = 0

    end subroutine create_default_metrics

end module fortplot_truetype_parser
