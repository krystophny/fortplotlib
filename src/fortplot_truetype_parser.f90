module fortplot_truetype_parser
    !! TrueType font table parsing implementation
    !! Contains all the table parsing logic for the native TrueType implementation
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8, int16, int32
    use fortplot_truetype_native, only: native_fontinfo_t, table_entry_t, cmap_subtable_t
    implicit none
    
    private
    public :: get_font_offset_for_index, read_table_directory
    public :: parse_head_table, parse_maxp_table, parse_hhea_table
    public :: parse_hmtx_table, parse_loca_table, parse_cmap_table
    public :: find_table, read_uint32_be, read_uint16_be, read_int16_be
    
    ! TrueType constants
    integer(int32), parameter :: TTCF_SIGNATURE = int(z'74746366', int32)  ! 'ttcf'
    integer(int32), parameter :: TRUE_SIGNATURE = int(z'74727565', int32)  ! 'true'
    integer(int32), parameter :: SFNT_VERSION = int(z'00010000', int32)
    
    ! Table tags
    integer(int32), parameter :: TAG_CMAP = int(z'636D6170', int32)  ! 'cmap'
    integer(int32), parameter :: TAG_HEAD = int(z'68656164', int32)  ! 'head'
    integer(int32), parameter :: TAG_HHEA = int(z'68686561', int32)  ! 'hhea'
    integer(int32), parameter :: TAG_HMTX = int(z'686D7478', int32)  ! 'hmtx'
    integer(int32), parameter :: TAG_MAXP = int(z'6D617870', int32)  ! 'maxp'
    integer(int32), parameter :: TAG_GLYF = int(z'676C7966', int32)  ! 'glyf'
    integer(int32), parameter :: TAG_LOCA = int(z'6C6F6361', int32)  ! 'loca'
    
contains

    function get_font_offset_for_index(data, index) result(offset)
        !! Get offset for font at index (for TTC collections)
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: index
        integer(int32) :: offset
        integer(int32) :: signature, num_fonts
        
        if (size(data) < 4) then
            offset = -1
            return
        end if
        
        signature = read_uint32_be(data, 1)
        
        if (signature == TTCF_SIGNATURE) then
            ! TrueType Collection
            if (size(data) < 16) then
                offset = -1
                return
            end if
            
            num_fonts = read_uint32_be(data, 9)
            if (index >= num_fonts .or. index < 0) then
                offset = -1
                return
            end if
            
            if (size(data) < 16 + (index + 1) * 4) then
                offset = -1
                return
            end if
            
            offset = read_uint32_be(data, 13 + index * 4)
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
        !! Read the table directory
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: i, table_offset
        
        success = .false.
        
        if (.not. allocated(font_info%tables)) return
        if (size(font_info%font_data) < font_info%font_start + 12 + font_info%num_tables * 16 - 1) return
        
        ! Read table entries
        do i = 1, font_info%num_tables
            table_offset = font_info%font_start + 12 + (i - 1) * 16
            
            font_info%tables(i)%tag = read_uint32_be(font_info%font_data, table_offset)
            font_info%tables(i)%checksum = read_uint32_be(font_info%font_data, table_offset + 4)
            font_info%tables(i)%offset = read_uint32_be(font_info%font_data, table_offset + 8)
            font_info%tables(i)%length = read_uint32_be(font_info%font_data, table_offset + 12)
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

    function parse_head_table(font_info) result(success)
        !! Parse 'head' table
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset
        integer(int16) :: index_to_loc_format
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_HEAD)
        if (table_idx == -1) return
        
        offset = font_info%tables(table_idx)%offset + 1  ! Convert to 1-based
        
        if (size(font_info%font_data) < offset + 54 - 1) return
        
        ! Read units per EM (offset 18)
        font_info%units_per_em = read_uint16_be(font_info%font_data, offset + 18)
        
        ! Read index to location format (offset 50)
        index_to_loc_format = read_int16_be(font_info%font_data, offset + 50)
        font_info%index_to_loc_format = index_to_loc_format
        
        font_info%head_offset = offset
        success = .true.
        
    end function parse_head_table

    function parse_maxp_table(font_info) result(success)
        !! Parse 'maxp' table
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_MAXP)
        if (table_idx == -1) return
        
        offset = font_info%tables(table_idx)%offset + 1  ! Convert to 1-based
        
        if (size(font_info%font_data) < offset + 6 - 1) return
        
        ! Read number of glyphs
        font_info%num_glyphs = read_uint16_be(font_info%font_data, offset + 4)
        
        font_info%maxp_offset = offset
        success = .true.
        
    end function parse_maxp_table

    function parse_hhea_table(font_info) result(success)
        !! Parse 'hhea' table
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_HHEA)
        if (table_idx == -1) return
        
        offset = font_info%tables(table_idx)%offset + 1  ! Convert to 1-based
        
        if (size(font_info%font_data) < offset + 36 - 1) return
        
        ! Read vertical metrics
        font_info%ascent = read_int16_be(font_info%font_data, offset + 4)
        font_info%descent = read_int16_be(font_info%font_data, offset + 6)
        font_info%line_gap = read_int16_be(font_info%font_data, offset + 8)
        
        font_info%hhea_offset = offset
        success = .true.
        
    end function parse_hhea_table

    function parse_hmtx_table(font_info) result(success)
        !! Parse 'hmtx' table
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset, i, num_long_hor_metrics
        integer :: advance_width, left_side_bearing
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_HMTX)
        if (table_idx == -1) return
        
        offset = font_info%tables(table_idx)%offset + 1  ! Convert to 1-based
        
        ! Get number of horizontal metrics from hhea table
        if (font_info%hhea_offset == 0) return
        num_long_hor_metrics = read_uint16_be(font_info%font_data, font_info%hhea_offset + 34)
        
        ! Allocate arrays
        allocate(font_info%advance_widths(font_info%num_glyphs))
        allocate(font_info%left_side_bearings(font_info%num_glyphs))
        
        ! Read horizontal metrics
        do i = 0, font_info%num_glyphs - 1
            if (i < num_long_hor_metrics) then
                advance_width = read_uint16_be(font_info%font_data, offset + i * 4)
                left_side_bearing = read_int16_be(font_info%font_data, offset + i * 4 + 2)
            else
                ! Use last advance width for remaining glyphs
                advance_width = font_info%advance_widths(num_long_hor_metrics)
                left_side_bearing = read_int16_be(font_info%font_data, &
                    offset + num_long_hor_metrics * 4 + (i - num_long_hor_metrics) * 2)
            end if
            
            font_info%advance_widths(i + 1) = advance_width
            font_info%left_side_bearings(i + 1) = left_side_bearing
        end do
        
        font_info%hmtx_offset = offset
        success = .true.
        
    end function parse_hmtx_table

    function parse_loca_table(font_info) result(success)
        !! Parse 'loca' table
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset, i
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_LOCA)
        if (table_idx == -1) return
        
        offset = font_info%tables(table_idx)%offset + 1  ! Convert to 1-based
        
        ! Allocate glyph offsets array
        allocate(font_info%glyph_offsets(font_info%num_glyphs + 1))
        
        ! Read glyph offsets based on format
        if (font_info%index_to_loc_format == 0) then
            ! Short format: offsets are uint16 * 2
            do i = 0, font_info%num_glyphs
                font_info%glyph_offsets(i + 1) = read_uint16_be(font_info%font_data, offset + i * 2) * 2
            end do
        else
            ! Long format: offsets are uint32
            do i = 0, font_info%num_glyphs
                font_info%glyph_offsets(i + 1) = read_uint32_be(font_info%font_data, offset + i * 4)
            end do
        end if
        
        font_info%loca_offset = offset
        success = .true.
        
    end function parse_loca_table

    function parse_cmap_table(font_info) result(success)
        !! Parse 'cmap' table
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset, num_subtables, i
        integer(int16) :: platform_id, encoding_id, format
        integer(int32) :: subtable_offset
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_CMAP)
        if (table_idx == -1) return
        
        offset = font_info%tables(table_idx)%offset + 1  ! Convert to 1-based
        
        if (size(font_info%font_data) < offset + 4 - 1) return
        
        ! Read number of encoding subtables
        num_subtables = read_uint16_be(font_info%font_data, offset + 2)
        
        ! Find a suitable Unicode subtable
        do i = 0, num_subtables - 1
            if (size(font_info%font_data) < offset + 4 + i * 8 + 8 - 1) cycle
            
            platform_id = read_uint16_be(font_info%font_data, offset + 4 + i * 8)
            encoding_id = read_uint16_be(font_info%font_data, offset + 4 + i * 8 + 2)
            subtable_offset = read_uint32_be(font_info%font_data, offset + 4 + i * 8 + 4)
            
            ! Look for Unicode platform (3) or Microsoft Unicode (3,1)
            if ((platform_id == 3 .and. (encoding_id == 1 .or. encoding_id == 10)) .or. &
                (platform_id == 0)) then
                
                font_info%cmap_subtable%platform_id = platform_id
                font_info%cmap_subtable%encoding_id = encoding_id
                font_info%cmap_subtable%offset = offset + subtable_offset
                
                ! Read subtable format
                format = read_uint16_be(font_info%font_data, font_info%cmap_subtable%offset)
                font_info%cmap_subtable%format = format
                font_info%cmap_subtable%valid = .true.
                
                exit
            end if
        end do
        
        if (.not. font_info%cmap_subtable%valid) return
        
        ! Parse the character mapping based on format
        if (.not. parse_cmap_subtable(font_info)) return
        
        font_info%cmap_offset = offset
        success = .true.
        
    end function parse_cmap_table

    function parse_cmap_subtable(font_info) result(success)
        !! Parse character mapping subtable
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        
        success = .false.
        
        select case (font_info%cmap_subtable%format)
        case (4)
            success = parse_cmap_format4(font_info)
        case (12)
            success = parse_cmap_format12(font_info)
        case default
            ! Unsupported format - create basic ASCII mapping
            call create_basic_unicode_mapping(font_info)
            success = .true.
        end select
        
    end function parse_cmap_subtable

    function parse_cmap_format4(font_info) result(success)
        !! Parse cmap format 4 (segment mapping to delta values)
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: offset, length, seg_count, i, unicode_char, glyph_index
        integer(int16), allocatable :: end_codes(:), start_codes(:), id_deltas(:), id_range_offsets(:)
        
        success = .false.
        offset = font_info%cmap_subtable%offset
        
        if (size(font_info%font_data) < offset + 14 - 1) return
        
        length = read_uint16_be(font_info%font_data, offset + 2)
        seg_count = read_uint16_be(font_info%font_data, offset + 6) / 2
        
        ! Allocate arrays for segment data
        allocate(end_codes(seg_count))
        allocate(start_codes(seg_count))
        allocate(id_deltas(seg_count))
        allocate(id_range_offsets(seg_count))
        
        ! Read segment arrays
        do i = 1, seg_count
            end_codes(i) = read_uint16_be(font_info%font_data, offset + 14 + (i - 1) * 2)
        end do
        
        do i = 1, seg_count
            start_codes(i) = read_uint16_be(font_info%font_data, offset + 16 + seg_count * 2 + (i - 1) * 2)
        end do
        
        do i = 1, seg_count
            id_deltas(i) = read_int16_be(font_info%font_data, offset + 16 + seg_count * 4 + (i - 1) * 2)
        end do
        
        do i = 1, seg_count
            id_range_offsets(i) = read_uint16_be(font_info%font_data, offset + 16 + seg_count * 6 + (i - 1) * 2)
        end do
        
        ! Create Unicode to glyph mapping for basic characters
        allocate(font_info%unicode_to_glyph(0:65535))
        font_info%unicode_to_glyph = 0  ! Default to glyph 0 (missing character)
        
        ! Map basic ASCII characters (0-255)
        do unicode_char = 0, 255
            glyph_index = map_unicode_to_glyph_format4(unicode_char, seg_count, &
                start_codes, end_codes, id_deltas, id_range_offsets, offset, font_info%font_data)
            if (glyph_index >= 0 .and. glyph_index < font_info%num_glyphs) then
                font_info%unicode_to_glyph(unicode_char) = glyph_index
            end if
        end do
        
        deallocate(end_codes, start_codes, id_deltas, id_range_offsets)
        success = .true.
        
    end function parse_cmap_format4

    function map_unicode_to_glyph_format4(unicode_char, seg_count, start_codes, end_codes, &
                                         id_deltas, id_range_offsets, cmap_offset, font_data) result(glyph_index)
        !! Map Unicode character to glyph index using format 4
        integer, intent(in) :: unicode_char, seg_count, cmap_offset
        integer(int16), intent(in) :: start_codes(:), end_codes(:), id_deltas(:), id_range_offsets(:)
        integer(int8), intent(in) :: font_data(:)
        integer :: glyph_index
        integer :: i
        
        glyph_index = 0  ! Default missing character glyph
        
        ! Find the segment containing this character
        do i = 1, seg_count
            if (unicode_char <= end_codes(i)) then
                if (unicode_char >= start_codes(i)) then
                    if (id_range_offsets(i) == 0) then
                        glyph_index = modulo(unicode_char + id_deltas(i), 65536)
                    else
                        ! Use glyph index array (simplified - assume glyph 0 for now)
                        glyph_index = 0
                    end if
                end if
                exit
            end if
        end do
        
    end function map_unicode_to_glyph_format4

    function parse_cmap_format12(font_info) result(success)
        !! Parse cmap format 12 (segmented coverage)
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        
        ! Simplified implementation - create basic mapping
        call create_basic_unicode_mapping(font_info)
        success = .true.
        
    end function parse_cmap_format12

    subroutine create_basic_unicode_mapping(font_info)
        !! Create basic Unicode to glyph mapping for unsupported formats
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: i
        
        allocate(font_info%unicode_to_glyph(0:255))
        
        ! Basic ASCII mapping - assume glyph index matches character code for basic chars
        do i = 0, 255
            if (i < font_info%num_glyphs) then
                font_info%unicode_to_glyph(i) = i
            else
                font_info%unicode_to_glyph(i) = 0  ! Missing character glyph
            end if
        end do
        
    end subroutine create_basic_unicode_mapping

    ! === Utility functions ===

    function read_uint32_be(data, offset) result(value)
        !! Read 32-bit big-endian unsigned integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int32) :: value
        
        if (offset + 3 > size(data)) then
            value = 0
            return
        end if
        
        value = ior(ior(ior(ishft(int(data(offset), int32), 24), &
                           ishft(int(data(offset + 1), int32), 16)), &
                       ishft(int(data(offset + 2), int32), 8)), &
                   int(data(offset + 3), int32))
        
        ! Handle sign extension properly
        if (value < 0) then
            value = value + 2_int32**32
        end if
        
    end function read_uint32_be
    
    function read_uint16_be(data, offset) result(value)
        !! Read 16-bit big-endian unsigned integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int16) :: value
        
        if (offset + 1 > size(data)) then
            value = 0
            return
        end if
        
        value = ior(ishft(int(data(offset), int16), 8), &
                   int(data(offset + 1), int16))
        
        ! Handle sign extension properly
        if (value < 0) then
            value = value + 2_int16**16
        end if
        
    end function read_uint16_be

    function read_int16_be(data, offset) result(value)
        !! Read 16-bit big-endian signed integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int16) :: value
        
        if (offset + 1 > size(data)) then
            value = 0
            return
        end if
        
        value = ior(ishft(int(data(offset), int16), 8), &
                   int(data(offset + 1), int16))
        
    end function read_int16_be

end module fortplot_truetype_parser