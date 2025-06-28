module fortplot_truetype_types
    !! Pure Fortran TrueType data types and structures
    !! This module contains all TrueType file format types used across
    !! the parser and main STB modules to avoid duplication (DRY principle)
    use iso_c_binding
    implicit none

    private

    ! Public types - all TrueType structures
    public :: ttf_table_entry_t, ttf_header_t, ttf_head_table_t
    public :: ttf_hhea_table_t, ttf_maxp_table_t, ttf_cmap_table_t
    public :: ttf_cmap_subtable_t, ttc_header_t, stb_fontinfo_pure_t

    ! TrueType table directory entry
    type :: ttf_table_entry_t
        character(len=4) :: tag = ""
        integer :: checksum = 0
        integer :: offset = 0
        integer :: length = 0
    end type ttf_table_entry_t

    ! TrueType font header
    type :: ttf_header_t
        integer :: sfnt_version = 0
        integer :: num_tables = 0
        integer :: search_range = 0
        integer :: entry_selector = 0
        integer :: range_shift = 0
    end type ttf_header_t

    ! TrueType head table
    type :: ttf_head_table_t
        integer :: major_version = 0
        integer :: minor_version = 0
        integer :: font_revision = 0
        integer :: checksum_adjustment = 0
        integer :: magic_number = 0
        integer :: flags = 0
        integer :: units_per_em = 0
        integer :: created_high = 0
        integer :: created_low = 0
        integer :: modified_high = 0
        integer :: modified_low = 0
        integer :: x_min = 0
        integer :: y_min = 0
        integer :: x_max = 0
        integer :: y_max = 0
        integer :: mac_style = 0
        integer :: lowest_rec_ppem = 0
        integer :: font_direction_hint = 0
        integer :: index_to_loc_format = 0
        integer :: glyph_data_format = 0
    end type ttf_head_table_t

    ! TrueType hhea table
    type :: ttf_hhea_table_t
        integer :: major_version = 0
        integer :: minor_version = 0
        integer :: ascender = 0
        integer :: descender = 0
        integer :: line_gap = 0
        integer :: advance_width_max = 0
        integer :: min_left_side_bearing = 0
        integer :: min_right_side_bearing = 0
        integer :: x_max_extent = 0
        integer :: caret_slope_rise = 0
        integer :: caret_slope_run = 0
        integer :: caret_offset = 0
        integer :: reserved1 = 0
        integer :: reserved2 = 0
        integer :: reserved3 = 0
        integer :: reserved4 = 0
        integer :: metric_data_format = 0
        integer :: number_of_hmetrics = 0
    end type ttf_hhea_table_t

    ! TrueType maxp table (complete version with all fields)
    type :: ttf_maxp_table_t
        integer :: version = 0
        integer :: num_glyphs = 0
        ! Version 1.0 additional fields
        integer :: max_points = 0
        integer :: max_contours = 0
        integer :: max_composite_points = 0
        integer :: max_composite_contours = 0
        integer :: max_zones = 0
        integer :: max_twilight_points = 0
        integer :: max_storage = 0
        integer :: max_function_defs = 0
        integer :: max_instruction_defs = 0
        integer :: max_stack_elements = 0
        integer :: max_size_of_instructions = 0
        integer :: max_component_elements = 0
        integer :: max_component_depth = 0
    end type ttf_maxp_table_t

    ! TrueType Collection (TTC) header
    type :: ttc_header_t
        character(len=4) :: ttcTag = ""      ! 'ttcf'
        integer :: majorVersion = 0
        integer :: minorVersion = 0
        integer :: numFonts = 0
        integer, allocatable :: offsetTable(:)  ! Offsets to each font
    end type ttc_header_t

    ! Character mapping table structures
    type :: ttf_cmap_subtable_t
        integer :: platform_id = 0
        integer :: encoding_id = 0
        integer :: offset = 0
        integer :: format = 0
        integer :: length = 0
        integer :: language = 0
        ! Format 4 specific fields
        integer :: seg_count_x2 = 0
        integer :: search_range = 0
        integer :: entry_selector = 0
        integer :: range_shift = 0
        integer :: seg_count = 0  ! Convenience field: seg_count_x2 / 2
        integer, allocatable :: end_code(:)
        integer, allocatable :: start_code(:)
        integer, allocatable :: id_delta(:)
        integer, allocatable :: id_range_offset(:)
        integer, allocatable :: glyph_id_array(:)
    end type ttf_cmap_subtable_t

    type :: ttf_cmap_table_t
        integer :: version = 0
        integer :: num_tables = 0
        type(ttf_cmap_subtable_t), allocatable :: subtables(:)
        integer :: preferred_subtable = 0  ! Index of preferred subtable
    end type ttf_cmap_table_t

    ! Main font information structure (pure Fortran implementation)
    type :: stb_fontinfo_pure_t
        logical :: initialized = .false.
        character(len=256) :: font_file_path = ""
        integer :: num_glyphs = 0

        ! Font data
        integer(c_int8_t), allocatable :: font_data(:)
        integer :: data_size = 0

        ! Parsed structures
        type(ttf_header_t) :: header
        type(ttf_table_entry_t), allocatable :: tables(:)

        ! TTC support
        logical :: is_ttc = .false.
        type(ttc_header_t) :: ttc_header
        integer :: font_index = 0   ! Font index within TTC (0-based)
        integer :: font_offset = 0  ! Byte offset to this font within TTC

        ! Parsed table data
        type(ttf_head_table_t) :: head_table
        type(ttf_hhea_table_t) :: hhea_table
        type(ttf_maxp_table_t) :: maxp_table
        type(ttf_cmap_table_t) :: cmap_table
        logical :: head_parsed = .false.
        logical :: hhea_parsed = .false.
        logical :: maxp_parsed = .false.
        logical :: cmap_parsed = .false.

        ! Future: Glyph outline data
        ! Future: Character mapping tables
    end type stb_fontinfo_pure_t

end module fortplot_truetype_types
