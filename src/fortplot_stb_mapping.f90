module fortplot_stb_mapping
    !! Pure Fortran implementation of TrueType font character mapping functionality
    !! Handles character-to-glyph mapping and glyph index lookups
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_truetype_types
    use fortplot_truetype_parser
    implicit none

    private

    ! Public interface
    public :: stb_find_glyph_index_pure
    public :: lookup_format4

contains

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

end module fortplot_stb_mapping