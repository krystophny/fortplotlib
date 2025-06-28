module forttf_parser
    !! Wrapper module that re-exports all TrueType parsing functionality
    !! This module provides a unified interface to all TrueType parsing functions
    !! that are now organized across specialized modules:
    !! - forttf_types: Type definitions
    !! - forttf_file_io: File I/O and header parsing
    !! - forttf_table_parser: Table parsing functions
    !! - forttf_glyph_parser: Glyph-specific parsing
    use forttf_types
    use forttf_file_io
    use forttf_table_parser
    use forttf_glyph_parser
    implicit none

    ! Re-export types from types module
    public :: ttf_table_entry_t, ttf_header_t, ttf_head_table_t
    public :: ttf_hhea_table_t, ttf_maxp_table_t, ttf_cmap_table_t
    public :: ttf_cmap_subtable_t, ttc_header_t, stb_fontinfo_pure_t
    public :: ttf_kern_entry_t, ttf_kern_table_t
    public :: ttf_loca_table_t, ttf_glyf_header_t

    ! Re-export file I/O functions
    public :: read_truetype_file, parse_ttf_header, parse_table_directory
    public :: parse_ttf_header_at_offset, parse_table_directory_at_offset
    public :: has_table, find_table
    public :: is_ttc_file, parse_ttc_header, get_ttc_font_offset
    public :: read_be_uint32, read_be_uint16, read_be_int16, read_tag

    ! Re-export table parsing functions
    public :: parse_head_table, parse_hhea_table, parse_maxp_table
    public :: parse_cmap_table, parse_cmap_format4, find_table_offset, find_table_index
    public :: parse_kern_table, find_kerning_advance, parse_kern_table_if_available

    ! Re-export glyph parsing functions
    public :: parse_loca_table, parse_glyf_header

end module forttf_parser