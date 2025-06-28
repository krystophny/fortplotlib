module forttf
    !! Pure Fortran TrueType font implementation (derived from stb_truetype.h)
    !! This module provides a pure Fortran port of TrueType functionality
    !! Compatible API with STB TrueType for drop-in replacement
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_core
    use forttf_metrics
    use forttf_mapping
    use forttf_bitmap
    use forttf_outline
    implicit none

    private

    ! Re-export types from types module
    public :: stb_fontinfo_pure_t
    public :: ttf_table_entry_t, ttf_header_t, ttf_head_table_t
    public :: ttf_hhea_table_t, ttf_maxp_table_t, ttf_cmap_table_t
    public :: ttf_cmap_subtable_t, ttc_header_t
    public :: ttf_kern_entry_t, ttf_kern_table_t
    public :: ttf_loca_table_t, ttf_glyf_header_t
    public :: ttf_vertex_t
    public :: TTF_VERTEX_MOVE, TTF_VERTEX_LINE, TTF_VERTEX_CURVE, TTF_VERTEX_CUBIC
    public :: stb_fontinfo_pure_t, stb_init_font_pure, stb_init_font_pure_with_index, stb_cleanup_font_pure
    public :: stb_get_codepoint_bitmap_pure, stb_free_bitmap_pure
    public :: stb_get_codepoint_hmetrics_pure, stb_get_font_vmetrics_pure
    public :: stb_scale_for_pixel_height_pure, stb_get_codepoint_bitmap_box_pure
    public :: stb_find_glyph_index_pure, stb_make_codepoint_bitmap_pure
    public :: stb_get_number_of_fonts_pure, stb_get_font_offset_for_index_pure
    public :: stb_scale_for_mapping_em_to_pixels_pure, stb_get_font_bounding_box_pure
    public :: stb_get_codepoint_box_pure, stb_get_codepoint_kern_advance_pure
    public :: stb_get_font_vmetrics_os2_pure, stb_get_glyph_hmetrics_pure
    public :: stb_get_glyph_box_pure, stb_get_glyph_kern_advance_pure
    public :: stb_get_kerning_table_length_pure, stb_get_kerning_table_pure
    public :: stb_get_glyph_bitmap_pure, stb_get_glyph_bitmap_box_pure
    public :: stb_get_codepoint_bitmap_subpixel_pure, stb_make_glyph_bitmap_pure
    public :: stb_get_glyph_bitmap_subpixel_pure, stb_make_glyph_bitmap_subpixel_pure
    public :: stb_make_codepoint_bitmap_subpixel_pure
    public :: stb_get_glyph_bitmap_box_subpixel_pure
    public :: stb_get_codepoint_bitmap_box_subpixel_pure
    public :: stb_get_glyph_shape_pure, stb_get_codepoint_shape_pure, stb_free_shape_pure
    public :: STB_PURE_SUCCESS, STB_PURE_ERROR, STB_PURE_NOT_IMPLEMENTED

    ! Constants
    integer, parameter :: STB_PURE_SUCCESS = 1
    integer, parameter :: STB_PURE_ERROR = 0
    integer, parameter :: STB_PURE_NOT_IMPLEMENTED = -1

contains

end module forttf