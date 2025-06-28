module forttf_file_io
    !! File I/O and binary data reading utilities for TrueType parsing
    !! Handles file reading and binary data conversion functions
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    implicit none

    private

    ! Public file I/O functions
    public :: read_truetype_file
    public :: read_be_uint32, read_be_uint16, read_be_int16, read_tag
    public :: is_ttc_file, parse_ttc_header, get_ttc_font_offset
    public :: parse_ttf_header, parse_table_directory
    public :: parse_ttf_header_at_offset, parse_table_directory_at_offset
    public :: has_table, find_table

contains

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

    function read_be_uint32(data, offset) result(value)
        !! Read big-endian unsigned 32-bit integer
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value

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
        !! Read big-endian unsigned 16-bit integer
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value

        if (offset < 1 .or. offset + 1 > size(data)) then
            value = 0
            return
        end if

        value = ishft(iand(int(data(offset)), 255), 8) + &
                iand(int(data(offset+1)), 255)

    end function read_be_uint16

    function read_be_int16(data, offset) result(value)
        !! Read big-endian signed 16-bit integer
        integer(c_int8_t), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value, unsigned_value

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
    ! TTF header and table directory parsing functions
    ! ============================================================================

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
    ! Table helper functions
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

end module forttf_file_io
