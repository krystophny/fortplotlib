module forttf_glyph_parser
    !! Glyph-specific parsing for loca and glyf tables
    !! Handles glyph location indexing and glyph outline data parsing
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_file_io
    implicit none

    private

    ! Public glyph parsing functions
    public :: parse_loca_table, parse_glyf_header

contains

    function parse_loca_table(font_data, tables, head_table, loca_table) result(success)
        !! Parse loca (glyph location) table
        integer(c_int8_t), intent(in) :: font_data(:)
        type(ttf_table_entry_t), intent(in) :: tables(:)
        type(ttf_head_table_t), intent(in) :: head_table
        type(ttf_loca_table_t), intent(out) :: loca_table
        logical :: success
        integer :: loca_table_idx, loca_offset, loca_length
        integer :: i, num_glyphs, offset_pos

        success = .false.

        ! Find loca table
        loca_table_idx = 0
        do i = 1, size(tables)
            if (tables(i)%tag == 'loca') then
                loca_table_idx = i
                exit
            end if
        end do

        if (loca_table_idx == 0) return

        loca_offset = tables(loca_table_idx)%offset
        loca_length = tables(loca_table_idx)%length

        ! Determine format from head table index_to_loc_format
        loca_table%is_long_format = (head_table%index_to_loc_format == 1)

        ! Calculate number of glyphs from table length
        if (loca_table%is_long_format) then
            num_glyphs = loca_length / 4 - 1  ! 32-bit offsets, minus 1 for final entry
        else
            num_glyphs = loca_length / 2 - 1  ! 16-bit offsets, minus 1 for final entry
        end if

        ! Allocate offsets array (need num_glyphs + 1 entries)
        allocate(loca_table%offsets(num_glyphs + 1))

        ! Read offsets based on format
        do i = 1, num_glyphs + 1
            offset_pos = loca_offset + (i - 1) * merge(4, 2, loca_table%is_long_format)
            
            if (loca_table%is_long_format) then
                loca_table%offsets(i) = read_be_uint32(font_data, offset_pos)
            else
                ! Short format: multiply by 2 (offsets are divided by 2 in short format)
                loca_table%offsets(i) = read_be_uint16(font_data, offset_pos) * 2
            end if
        end do

        success = .true.

    end function parse_loca_table

    function parse_glyf_header(font_data, glyf_table_offset, glyph_offset, glyf_header) result(success)
        !! Parse glyph header from glyf table
        integer(c_int8_t), intent(in) :: font_data(:)
        integer, intent(in) :: glyf_table_offset, glyph_offset
        type(ttf_glyf_header_t), intent(out) :: glyf_header
        logical :: success
        integer :: glyph_pos

        success = .false.

        ! Calculate absolute position in font data
        glyph_pos = glyf_table_offset + glyph_offset

        ! Check bounds
        if (glyph_pos < 1 .or. glyph_pos + 9 > size(font_data)) return

        ! Parse glyph header (10 bytes)
        glyf_header%num_contours = read_be_int16(font_data, glyph_pos)
        glyf_header%x_min = read_be_int16(font_data, glyph_pos + 2)
        glyf_header%y_min = read_be_int16(font_data, glyph_pos + 4)
        glyf_header%x_max = read_be_int16(font_data, glyph_pos + 6)
        glyf_header%y_max = read_be_int16(font_data, glyph_pos + 8)

        success = .true.

    end function parse_glyf_header

end module forttf_glyph_parser
