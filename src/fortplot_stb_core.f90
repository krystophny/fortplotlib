module fortplot_stb_core
    !! Core font initialization and cleanup functionality
    !! This module handles font initialization, cleanup, and TTC support
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_truetype_types
    use fortplot_truetype_parser
    implicit none

    private

    ! Public functions
    public :: stb_init_font_pure, stb_init_font_pure_with_index, stb_cleanup_font_pure
    public :: stb_get_number_of_fonts_pure, stb_get_font_offset_for_index_pure

contains

    function stb_init_font_pure(font_info, font_file_path) result(success)
        !! Initialize font from file path (uses font index 0 for TTC files)
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        character(len=*), intent(in) :: font_file_path
        logical :: success

        ! Call the main implementation with font index 0
        success = stb_init_font_pure_with_index(font_info, font_file_path, 0)

    end function stb_init_font_pure

    function stb_init_font_pure_with_index(font_info, font_file_path, font_index) result(success)
        !! Initialize font from file path with specific font index for TTC files
        type(stb_fontinfo_pure_t), intent(inout) :: font_info
        character(len=*), intent(in) :: font_file_path
        integer, intent(in) :: font_index
        logical :: success
        integer :: font_offset

        ! Initialize structure
        font_info%initialized = .false.
        font_info%font_file_path = font_file_path
        font_info%num_glyphs = 0
        font_info%font_index = font_index
        font_info%font_offset = 0
        success = .false.

        ! Read font file
        if (.not. read_truetype_file(font_file_path, font_info%font_data, &
                                   font_info%data_size)) then
            return
        end if

        ! Check if this is a TTC file and handle accordingly
        if (is_ttc_file(font_info%font_data)) then
            font_info%is_ttc = .true.

            ! Parse TTC header
            if (.not. parse_ttc_header(font_info%font_data, font_info%ttc_header)) then
                return
            end if

            ! Get font offset for the requested index
            font_offset = get_ttc_font_offset(font_info%ttc_header, font_index)
            if (font_offset <= 0) then
                return  ! Invalid font index
            end if

            font_info%font_offset = font_offset

            ! Parse TTF header at the font offset
            if (.not. parse_ttf_header_at_offset(font_info%font_data, font_offset, &
                                               font_info%header)) then
                return
            end if

            ! Parse table directory at the font offset
            if (.not. parse_table_directory_at_offset(font_info%font_data, font_offset, &
                                                    font_info%header, font_info%tables)) then
                return
            end if
        else
            font_info%is_ttc = .false.

            ! For TTF files, font_index must be 0
            if (font_index /= 0) then
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

    end function stb_init_font_pure_with_index

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

    function stb_get_number_of_fonts_pure(font_data, data_size) result(num_fonts)
        !! Get number of fonts in font file/data (C pointer interface for compatibility)
        type(c_ptr), intent(in) :: font_data
        integer, intent(in) :: data_size
        integer :: num_fonts
        integer(c_int8_t), pointer :: font_array(:)
        type(ttc_header_t) :: ttc_header

        num_fonts = 1  ! Default for TTF files

        if (.not. c_associated(font_data) .or. data_size <= 0) then
            num_fonts = 0
            return
        end if

        ! Convert C pointer to Fortran array
        call c_f_pointer(font_data, font_array, [data_size])

        ! Check if this is a TTC file
        if (is_ttc_file(font_array)) then
            ! Parse TTC header to get number of fonts
            if (parse_ttc_header(font_array, ttc_header)) then
                num_fonts = ttc_header%numFonts
            else
                num_fonts = 0  ! Error parsing TTC
            end if
        end if
        ! For TTF files, return 1 (default set above)

    end function stb_get_number_of_fonts_pure

    function stb_get_font_offset_for_index_pure(font_data, index) result(offset)
        !! Get font offset for multi-font files (C pointer interface for compatibility)
        type(c_ptr), intent(in) :: font_data
        integer, intent(in) :: index
        integer :: offset
        integer(c_int8_t), pointer :: font_array(:)
        type(ttc_header_t) :: ttc_header

        offset = 0  ! Default for TTF files (start at beginning)

        if (.not. c_associated(font_data)) then
            offset = -1
            return
        end if

        ! Convert C pointer to Fortran array (we need size, so use a large value)
        call c_f_pointer(font_data, font_array, [100000])  ! Assume large enough for header

        ! Check if this is a TTC file
        if (is_ttc_file(font_array)) then
            ! Parse TTC header to get font offset
            if (parse_ttc_header(font_array, ttc_header)) then
                offset = get_ttc_font_offset(ttc_header, index)
                if (offset == 0) then
                    offset = -1  ! Invalid index
                end if
            else
                offset = -1  ! Error parsing TTC
            end if
        else
            ! For TTF files, only index 0 is valid
            if (index == 0) then
                offset = 0
            else
                offset = -1
            end if
        end if

    end function stb_get_font_offset_for_index_pure

end module fortplot_stb_core