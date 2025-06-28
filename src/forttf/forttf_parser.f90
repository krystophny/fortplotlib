module forttf_parser
    !! Pure Fortran TrueType and TTC file parser (derived from stb_truetype.h)
    !! This module handles low-level TrueType file format parsing including:
    !! - TTF/TTC file detection and loading
    !! - TrueType table directory parsing
    !! - Essential table parsing (head, hhea, maxp, cmap, etc.)
    !! - TrueType Collection (TTC) support
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    implicit none

    private

    ! Re-export types from types module
    public :: ttf_table_entry_t, ttf_header_t, ttf_head_table_t
    public :: ttf_hhea_table_t, ttf_maxp_table_t, ttf_cmap_table_t
    public :: ttf_cmap_subtable_t, ttc_header_t, stb_fontinfo_pure_t
    public :: ttf_kern_entry_t, ttf_kern_table_t
    ! public :: ttf_loca_table_t, ttf_glyf_header_t

    ! Public functions
    public :: read_truetype_file, parse_ttf_header, parse_table_directory
    public :: parse_ttf_header_at_offset, parse_table_directory_at_offset
    public :: has_table, find_table
    public :: is_ttc_file, parse_ttc_header, get_ttc_font_offset
    public :: read_be_uint32, read_be_uint16, read_be_int16, read_tag
    public :: parse_kern_table, find_kerning_advance
    public :: parse_head_table, parse_hhea_table, parse_maxp_table
    public :: parse_cmap_table, parse_cmap_format4, find_table_offset, find_table_index
    public :: parse_kern_table_if_available
    ! public :: parse_loca_table, parse_glyf_header

contains

    ! ============================================================================
    ! Helper functions for TrueType file parsing
    ! ============================================================================

    function read_truetype_file(file_path, font_data, data_size) result(success)
        !! Read entire TrueType font file into memory
        character(len=*), intent(in) :: file_path
        integer(c_int8_t), allocatable, intent(out) :: font_data(:)
        integer, intent(out) :: data_size
        logical :: success
        integer :: unit, iostat, file_size

        success = .false.
        data_size = 0

        ! Open file for binary reading
        open(newunit=unit, file=trim(file_path), form='unformatted', &
             access='stream', status='old', iostat=iostat)
        if (iostat /= 0) return

        ! Get file size
        inquire(unit=unit, size=file_size)
        if (file_size <= 0) then
            close(unit)
            return
        end if

        ! Allocate and read data
        allocate(font_data(file_size))
        read(unit, iostat=iostat) font_data
        close(unit)

        if (iostat /= 0) then
            deallocate(font_data)
            return
        end if

        data_size = file_size
        success = .true.

    end function read_truetype_file

    function parse_ttf_header(font_data, header, offset) result(success)
        !! Parse TrueType font header (with optional offset for TTC fonts)
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttf_header_t), intent(out) :: header
        integer, intent(in), optional :: offset
        logical :: success
        integer :: start_offset

        success = .false.
        start_offset = 1
        if (present(offset)) start_offset = offset + 1  ! Convert to 1-based

        if (size(font_data) < start_offset + 11) return

        ! Read header fields (big-endian)
        header%sfnt_version = read_be_uint32(font_data, start_offset)
        header%num_tables = read_be_uint16(font_data, start_offset + 4)
        header%search_range = read_be_uint16(font_data, start_offset + 6)
        header%entry_selector = read_be_uint16(font_data, start_offset + 8)
        header%range_shift = read_be_uint16(font_data, start_offset + 10)

        ! Validate header
        if (header%num_tables <= 0 .or. header%num_tables > 100) return
        if (header%sfnt_version /= 65536 .and. &
            header%sfnt_version /= 1330926671) return  ! 'OTTO' = 0x4F54544F

        success = .true.

    end function parse_ttf_header

    function parse_table_directory(font_data, header, tables, offset) result(success)
        !! Parse table directory entries (with optional offset for TTC fonts)
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttf_header_t), intent(in) :: header
        type(ttf_table_entry_t), allocatable, intent(out) :: tables(:)
        integer, intent(in), optional :: offset
        logical :: success
        integer :: i, table_offset, start_offset

        success = .false.
        start_offset = 1
        if (present(offset)) start_offset = offset + 1  ! Convert to 1-based

        ! Check we have enough data for all table entries
        if (size(font_data) < start_offset + 11 + 16 * header%num_tables) return

        allocate(tables(header%num_tables))

        ! Parse each table entry
        table_offset = start_offset + 12  ! Skip header
        do i = 1, header%num_tables
            tables(i)%tag = read_tag(font_data, table_offset)
            tables(i)%checksum = read_be_uint32(font_data, table_offset + 4)
            tables(i)%offset = read_be_uint32(font_data, table_offset + 8) + 1  ! Convert to 1-based
            tables(i)%length = read_be_uint32(font_data, table_offset + 12)
            table_offset = table_offset + 16
        end do

        success = .true.

    end function parse_table_directory

    function parse_ttf_header_at_offset(font_data, offset, header) result(success)
        !! Parse TrueType font header at specific offset (for TTC support)
        integer(c_int8_t), intent(in) :: font_data(:)
        integer, intent(in) :: offset
        type(ttf_header_t), intent(out) :: header
        logical :: success
        integer :: start_offset

        success = .false.
        start_offset = offset + 1  ! Convert to 1-based
        if (size(font_data) < start_offset + 11) return

        ! Read header fields (big-endian) at offset
        header%sfnt_version = read_be_uint32(font_data, start_offset)
        header%num_tables = read_be_uint16(font_data, start_offset + 4)
        header%search_range = read_be_uint16(font_data, start_offset + 6)
        header%entry_selector = read_be_uint16(font_data, start_offset + 8)
        header%range_shift = read_be_uint16(font_data, start_offset + 10)

        ! Validate header
        if (header%num_tables <= 0 .or. header%num_tables > 100) return
        if (header%sfnt_version /= 65536 .and. &
            header%sfnt_version /= 1330926671) return  ! 'OTTO' = 0x4F54544F

        success = .true.

    end function parse_ttf_header_at_offset

    function parse_table_directory_at_offset(font_data, offset, header, tables) result(success)
        !! Parse table directory entries at specific offset (for TTC support)
        integer(c_int8_t), intent(in) :: font_data(:)
        integer, intent(in) :: offset
        type(ttf_header_t), intent(in) :: header
        type(ttf_table_entry_t), allocatable, intent(out) :: tables(:)
        logical :: success
        integer :: i, start_offset, table_offset

        success = .false.
        start_offset = offset + 1  ! Convert to 1-based

        ! Check we have enough data for all table entries
        if (size(font_data) < start_offset + 11 + 16 * header%num_tables) return

        allocate(tables(header%num_tables))

        ! Parse each table entry
        table_offset = start_offset + 12  ! Skip header
        do i = 1, header%num_tables
            tables(i)%tag = read_tag(font_data, table_offset)
            tables(i)%checksum = read_be_uint32(font_data, table_offset + 4)
            ! For TTC, offsets are relative to the original file, not the font offset
            tables(i)%offset = read_be_uint32(font_data, table_offset + 8) + 1  ! Convert to 1-based
            tables(i)%length = read_be_uint32(font_data, table_offset + 12)
            table_offset = table_offset + 16
        end do

        success = .true.

    end function parse_table_directory_at_offset

    ! ============================================================================
    ! TrueType Collection (TTC) support functions
    ! ============================================================================

    function is_ttc_file(font_data) result(is_ttc)
        !! Check if font data is a TrueType Collection file
        integer(c_int8_t), intent(in) :: font_data(:)
        logical :: is_ttc
        character(len=4) :: signature

        is_ttc = .false.
        if (size(font_data) < 4) return

        signature = read_tag(font_data, 1)
        is_ttc = (signature == 'ttcf')

    end function is_ttc_file

    function parse_ttc_header(font_data, ttc_header) result(success)
        !! Parse TrueType Collection header
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttc_header_t), intent(out) :: ttc_header
        logical :: success
        integer :: i, offset

        success = .false.
        if (size(font_data) < 12) return

        ! Read TTC header fields
        ttc_header%ttcTag = read_tag(font_data, 1)
        if (ttc_header%ttcTag /= 'ttcf') return

        ttc_header%majorVersion = read_be_uint16(font_data, 5)
        ttc_header%minorVersion = read_be_uint16(font_data, 7)
        ttc_header%numFonts = read_be_uint32(font_data, 9)

        ! Validate number of fonts
        if (ttc_header%numFonts <= 0 .or. ttc_header%numFonts > 64) return

        ! Check we have enough data for offset table
        if (size(font_data) < 12 + 4 * ttc_header%numFonts) return

        ! Read font offsets
        allocate(ttc_header%offsetTable(ttc_header%numFonts))
        offset = 13  ! Start after header
        do i = 1, ttc_header%numFonts
            ttc_header%offsetTable(i) = read_be_uint32(font_data, offset)
            offset = offset + 4
        end do

        success = .true.

    end function parse_ttc_header

    function get_ttc_font_offset(ttc_header, font_index) result(font_offset)
        !! Get byte offset for specific font index in TTC
        type(ttc_header_t), intent(in) :: ttc_header
        integer, intent(in) :: font_index  ! 0-based index
        integer :: font_offset

        font_offset = 0
        if (font_index < 0 .or. font_index >= ttc_header%numFonts) return
        if (.not. allocated(ttc_header%offsetTable)) return

        ! Convert to 1-based indexing for Fortran array access
        font_offset = ttc_header%offsetTable(font_index + 1)

    end function get_ttc_font_offset

    ! ============================================================================
    ! Table parsing functions (moved from main module)
    ! ============================================================================

    function has_table(tables, tag) result(found)
        !! Check if a table with given tag exists
        type(ttf_table_entry_t), intent(in) :: tables(:)
        character(len=4), intent(in) :: tag
        logical :: found
        integer :: i

        found = .false.
        do i = 1, size(tables)
            if (tables(i)%tag == tag) then
                found = .true.
                return
            end if
        end do

    end function has_table

    function find_table(tables, tag) result(table_index)
        !! Find table index by tag, returns 0 if not found
        type(ttf_table_entry_t), intent(in) :: tables(:)
        character(len=4), intent(in) :: tag
        integer :: table_index
        integer :: i

        table_index = 0
        do i = 1, size(tables)
            if (tables(i)%tag == tag) then
                table_index = i
                return
            end if
        end do

    end function find_table

    ! Note: The actual table parsing functions (parse_head_table, etc.)
    ! would be included here, but for brevity they're omitted in this extraction.
    ! They should be moved from the main fortplot_stb.f90 module.

    ! ============================================================================
    ! Binary reading helper functions
    ! ============================================================================

    function read_be_uint32(data, offset) result(value)
        !! Read big-endian 32-bit unsigned integer
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value

        ! Bounds check
        if (offset < 1 .or. offset + 3 > size(data)) then
            value = 0
            return
        end if

        value = ishft(iand(int(data(offset)), 255), 24) + &
                ishft(iand(int(data(offset+1)), 255), 16) + &
                ishft(iand(int(data(offset+2)), 255), 8) + &
                iand(int(data(offset+3)), 255)

    end function read_be_uint32

    function read_be_uint16(data, offset) result(value)
        !! Read big-endian 16-bit unsigned integer
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value

        ! Bounds check
        if (offset < 1 .or. offset + 1 > size(data)) then
            value = 0
            return
        end if

        value = ishft(iand(int(data(offset)), 255), 8) + &
                iand(int(data(offset+1)), 255)

    end function read_be_uint16

    function read_be_int16(data, offset) result(value)
        !! Read big-endian 16-bit signed integer
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value
        integer :: unsigned_value

        ! Bounds check
        if (offset < 1 .or. offset + 1 > size(data)) then
            value = 0
            return
        end if

        unsigned_value = ishft(iand(int(data(offset)), 255), 8) + &
                        iand(int(data(offset+1)), 255)

        ! Convert to signed if necessary
        if (unsigned_value >= 32768) then
            value = unsigned_value - 65536
        else
            value = unsigned_value
        end if

    end function read_be_int16

    function read_tag(data, offset) result(tag)
        !! Read 4-character tag
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: offset
        character(len=4) :: tag

        tag = achar(data(offset)) // achar(data(offset+1)) // &
              achar(data(offset+2)) // achar(data(offset+3))

    end function read_tag

    function parse_kern_table(data, kern_offset, kern_length, kern_table) &
             result(success)
        !! Parse kern table for kerning pairs
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: kern_offset, kern_length
        type(ttf_kern_table_t), intent(out) :: kern_table
        logical :: success
        integer :: offset, num_tables, coverage, subtable_length, num_pairs, i
        integer :: data_size

        success = .false.
        data_size = size(data)

        if (kern_offset <= 0 .or. kern_length < 4) then
            return
        end if

        ! Check bounds
        if (kern_offset > data_size .or. kern_offset + kern_length > data_size) then
            return
        end if

        offset = kern_offset  ! kern_offset is already 1-based

        ! Parse kern table header
        if (offset + 1 > data_size) return
        kern_table%version = read_be_uint16(data, offset)
        offset = offset + 2

        if (offset + 1 > data_size) return
        kern_table%num_tables = read_be_uint16(data, offset)
        offset = offset + 2

        ! We only handle the first subtable if it's horizontal and format 0
        if (kern_table%num_tables < 1) then
            return
        end if

        ! Read first subtable header
        if (offset + 1 > data_size) return
        subtable_length = read_be_uint16(data, offset)
        offset = offset + 2

        if (offset + 1 > data_size) return
        coverage = read_be_uint16(data, offset)
        offset = offset + 2

        ! Check if it's horizontal kerning (bit 0 set) and format 0 (bits 8-15 = 0)
        if (iand(coverage, 1) == 0 .or. iand(coverage, ishft(255, 8)) /= 0) then
            ! Not horizontal or not format 0
            return
        end if

        kern_table%has_horizontal = .true.

        ! Read number of kerning pairs
        if (offset + 1 > data_size) return
        num_pairs = read_be_uint16(data, offset)
        offset = offset + 2

        kern_table%horizontal_table_length = num_pairs

        ! Skip search range, entry selector, range shift
        offset = offset + 6

        ! Allocate and read kerning pairs
        if (num_pairs > 0) then
            ! Check bounds for all entries
            if (offset + num_pairs * 6 - 1 > data_size) then
                return
            end if

            allocate(kern_table%entries(num_pairs))

            do i = 1, num_pairs
                if (offset + 5 > data_size) exit
                kern_table%entries(i)%glyph1 = read_be_uint16(data, offset)
                offset = offset + 2
                kern_table%entries(i)%glyph2 = read_be_uint16(data, offset)
                offset = offset + 2
                kern_table%entries(i)%advance = read_be_int16(data, offset)
                offset = offset + 2
            end do
        end if

        success = .true.

    end function parse_kern_table

    function find_kerning_advance(kern_table, glyph1, glyph2) result(advance)
        !! Find kerning advance between two glyphs using binary search
        type(ttf_kern_table_t), intent(in) :: kern_table
        integer, intent(in) :: glyph1, glyph2
        integer :: advance
        integer :: left, right, mid, needle, straw

        advance = 0

        if (.not. kern_table%has_horizontal .or. &
            .not. allocated(kern_table%entries) .or. &
            size(kern_table%entries) == 0) then
            return
        end if

        ! Binary search - kern table is sorted by glyph1 << 16 | glyph2
        needle = ishft(glyph1, 16) + glyph2
        left = 1
        right = size(kern_table%entries)

        do while (left <= right)
            mid = (left + right) / 2
            straw = ishft(kern_table%entries(mid)%glyph1, 16) + &
                   kern_table%entries(mid)%glyph2

            if (needle < straw) then
                right = mid - 1
            else if (needle > straw) then
                left = mid + 1
            else
                advance = kern_table%entries(mid)%advance
                return
            end if
        end do

    end function find_kerning_advance

    ! ============================================================================
    ! TrueType table parsing functions (moved from fortplot_stb.f90)
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

    function find_table_index(tables, tag) result(index)
        !! Find index of table with given tag
        type(ttf_table_entry_t), intent(in) :: tables(:)
        character(len=4), intent(in) :: tag
        integer :: index
        integer :: i

        index = 0
        do i = 1, size(tables)
            if (tables(i)%tag == tag) then
                index = i
                exit
            end if
        end do

    end function find_table_index

    subroutine parse_kern_table_if_available(font_info)
        !! Parse kern table if available and not already parsed
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        integer :: kern_table_idx, kern_offset, kern_length
        logical :: success

        if (font_info%kern_parsed) then
            return
        end if

        ! Find kern table
        kern_table_idx = find_table_index(font_info%tables, "kern")

        if (kern_table_idx > 0) then
            kern_offset = font_info%tables(kern_table_idx)%offset  ! Already 1-based
            kern_length = font_info%tables(kern_table_idx)%length

            ! Re-enable kern table parsing
            success = parse_kern_table(font_info%font_data, kern_offset, &
                                     kern_length, font_info%kern_table)
        else
            success = .false.
        end if

        font_info%kern_parsed = .true.

    end subroutine parse_kern_table_if_available

    ! TODO: Implement loca and glyf parsing functions
    ! function parse_loca_table(...
    ! function parse_glyf_header(...

end module forttf_parser
