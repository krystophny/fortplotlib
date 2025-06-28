module forttf_types
    !! Pure Fortran TrueType data types and structures (derived from stb_truetype.h)
    !! This module contains all TrueType file format types used across
    !! the parser and main forttf modules to avoid duplication (DRY principle)
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    private

    ! Public types - all TrueType structures
    public :: ttf_table_entry_t, ttf_header_t, ttf_head_table_t
    public :: ttf_hhea_table_t, ttf_maxp_table_t, ttf_cmap_table_t
    public :: ttf_cmap_subtable_t, ttc_header_t, stb_fontinfo_pure_t
    public :: ttf_kern_entry_t, ttf_kern_table_t
    public :: ttf_loca_table_t, ttf_glyf_header_t
    public :: ttf_vertex_t
    public :: TTF_VERTEX_MOVE, TTF_VERTEX_LINE, TTF_VERTEX_CURVE, TTF_VERTEX_CUBIC
    ! STB rasterization data structures
    public :: stb_point_t, stb_edge_t, stb_active_edge_t, stb_bitmap_t
    public :: TTF_FLATNESS_IN_PIXELS, TTF_MAX_RECURSION_DEPTH, TTF_COVERAGE_SCALE, TTF_STACK_BUFFER_SIZE

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

    ! TrueType kerning entry (matches stbtt_kerningentry)
    type :: ttf_kern_entry_t
        integer :: glyph1 = 0     ! First glyph index
        integer :: glyph2 = 0     ! Second glyph index
        integer :: advance = 0    ! Kerning advance value
    end type ttf_kern_entry_t

    ! TrueType kern table
    type :: ttf_kern_table_t
        integer :: version = 0
        integer :: num_tables = 0
        logical :: has_horizontal = .false.
        integer :: horizontal_table_length = 0
        type(ttf_kern_entry_t), allocatable :: entries(:)
    end type ttf_kern_table_t

    ! Loca table - glyph location index
    type :: ttf_loca_table_t
        integer, allocatable :: offsets(:)  ! Glyph offsets into glyf table
        logical :: is_long_format = .false.  ! True for 32-bit offsets, false for 16-bit
    end type ttf_loca_table_t

    ! Glyph header (simple or composite)
    type :: ttf_glyf_header_t
        integer :: num_contours = 0    ! Negative for composite glyphs
        integer :: x_min = 0
        integer :: y_min = 0
        integer :: x_max = 0
        integer :: y_max = 0
        ! Glyph data follows (simple or composite)
    end type ttf_glyf_header_t

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
        type(ttf_kern_table_t) :: kern_table
        type(ttf_loca_table_t) :: loca_table
        logical :: head_parsed = .false.
        logical :: hhea_parsed = .false.
        logical :: maxp_parsed = .false.
        logical :: cmap_parsed = .false.
        logical :: kern_parsed = .false.
        logical :: loca_parsed = .false.

        ! Glyph outline data parsing capability
        logical :: glyf_table_available = .false.
    end type stb_fontinfo_pure_t

    ! Vertex type constants matching STB TrueType exactly
    ! These MUST match stb_truetype.h definitions:
    ! STBTT_vmove=1, STBTT_vline=2, STBTT_vcurve=3, STBTT_vcubic=4
    integer, parameter :: TTF_VERTEX_MOVE = 1   ! STBTT_vmove - Move to point
    integer, parameter :: TTF_VERTEX_LINE = 2   ! STBTT_vline - Line to point
    integer, parameter :: TTF_VERTEX_CURVE = 3  ! STBTT_vcurve - Quadratic curve to point  
    integer, parameter :: TTF_VERTEX_CUBIC = 4  ! STBTT_vcubic - Cubic curve to point
    
    ! STB rasterization constants - MUST match stb_truetype.h exactly
    real(wp), parameter :: TTF_FLATNESS_IN_PIXELS = 0.35_wp  ! Default flatness
    integer, parameter :: TTF_MAX_RECURSION_DEPTH = 16       ! Max curve tessellation depth
    integer, parameter :: TTF_COVERAGE_SCALE = 255           ! Pixel coverage scale
    integer, parameter :: TTF_STACK_BUFFER_SIZE = 64         ! Stack vs heap threshold

    ! TrueType glyph vertex for outline paths
    type :: ttf_vertex_t
        integer :: x = 0, y = 0                 ! Primary coordinates
        integer :: cx = 0, cy = 0               ! Control point 1 (for quadratic/cubic curves)
        integer :: cx1 = 0, cy1 = 0             ! Control point 2 (for cubic curves)
        integer :: type = 0                     ! Vertex type (MOVE, LINE, CURVE, CUBIC)
    end type ttf_vertex_t

    ! ===============================================
    ! STB Rasterization Data Structures (exact matching)
    ! ===============================================
    
    ! Point structure for flattened curves (matches stbtt__point)
    type :: stb_point_t
        real(wp) :: x = 0.0_wp  ! X coordinate (floating point)
        real(wp) :: y = 0.0_wp  ! Y coordinate (floating point)
    end type stb_point_t
    
    ! Edge structure for rasterization (matches stbtt__edge)
    type :: stb_edge_t
        real(wp) :: x0 = 0.0_wp, y0 = 0.0_wp    ! Start point
        real(wp) :: x1 = 0.0_wp, y1 = 0.0_wp    ! End point
        integer :: invert = 0                   ! Winding direction flag
    end type stb_edge_t
    
    ! Active edge structure for scanline rasterization (matches stbtt__active_edge)
    type :: stb_active_edge_t
        type(stb_active_edge_t), pointer :: next => null()  ! Linked list pointer
        real(wp) :: fx = 0.0_wp        ! Current X position
        real(wp) :: fdx = 0.0_wp       ! X derivative (slope)
        real(wp) :: fdy = 0.0_wp       ! Y derivative (inverse slope)
        real(wp) :: direction = 0.0_wp ! Winding direction
        real(wp) :: sy = 0.0_wp        ! Start Y coordinate
        real(wp) :: ey = 0.0_wp        ! End Y coordinate
    end type stb_active_edge_t
    
    ! Bitmap structure for rasterization output (matches stbtt__bitmap)
    type :: stb_bitmap_t
        integer :: w = 0, h = 0, stride = 0                ! Width, height, stride
        integer(c_int8_t), pointer :: pixels(:) => null()  ! Pixel data
    end type stb_bitmap_t

end module forttf_types
