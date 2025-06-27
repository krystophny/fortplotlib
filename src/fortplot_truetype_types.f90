module fortplot_truetype_types
    !! Contains type definitions and constants for the TrueType font parser
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8, int16, int32
    implicit none

    private

    public :: table_entry_t, vertex_t, glyph_point_t, cmap_subtable_t, native_fontinfo_t
    public :: TAG_CMAP, TAG_HEAD, TAG_HHEA, TAG_HMTX, TAG_MAXP, TAG_GLYF, TAG_LOCA, TAG_NAME, TAG_POST, TAG_OS2
    public :: TTCF_SIGNATURE, TRUE_SIGNATURE, SFNT_VERSION
    public :: GLYPH_SIMPLE, GLYPH_COMPOUND
    public :: CURVE_LINE, CURVE_QUAD
    public :: BITMAP_CHAR_WIDTH, BITMAP_CHAR_HEIGHT
    public :: NATIVE_SUCCESS, NATIVE_ERROR

    ! Constants
    integer, parameter :: NATIVE_SUCCESS = 1
    integer, parameter :: NATIVE_ERROR = 0

    ! TrueType table tags (as 32-bit integers)
    integer(int32), parameter :: TAG_CMAP = int(z'636D6170', int32)  ! 'cmap'
    integer(int32), parameter :: TAG_HEAD = int(z'68656164', int32)  ! 'head'
    integer(int32), parameter :: TAG_HHEA = int(z'68686561', int32)  ! 'hhea'
    integer(int32), parameter :: TAG_HMTX = int(z'686D7478', int32)  ! 'hmtx'
    integer(int32), parameter :: TAG_MAXP = int(z'6D617870', int32)  ! 'maxp'
    integer(int32), parameter :: TAG_GLYF = int(z'676C7966', int32)  ! 'glyf'
    integer(int32), parameter :: TAG_LOCA = int(z'6C6F6361', int32)  ! 'loca'
    integer(int32), parameter :: TAG_NAME = int(z'6E616D65', int32)  ! 'name'
    integer(int32), parameter :: TAG_POST = int(z'706F7374', int32)  ! 'post'
    integer(int32), parameter :: TAG_OS2  = int(z'4F532F32', int32)  ! 'OS/2'

    ! TrueType magic numbers
    integer(int32), parameter :: TTCF_SIGNATURE = int(z'74746366', int32)  ! 'ttcf'
    integer(int32), parameter :: TRUE_SIGNATURE = int(z'74727565', int32)  ! 'true'
    integer(int32), parameter :: SFNT_VERSION = int(z'00010000', int32)

    ! Glyph types
    integer, parameter :: GLYPH_SIMPLE = 0
    integer, parameter :: GLYPH_COMPOUND = 1

    ! Curve types
    integer, parameter :: CURVE_LINE = 1
    integer, parameter :: CURVE_QUAD = 2

    ! Simple bitmap font fallback constants
    integer, parameter :: BITMAP_CHAR_WIDTH = 8
    integer, parameter :: BITMAP_CHAR_HEIGHT = 12

    ! TrueType table directory entry
    type :: table_entry_t
        integer(int32) :: tag
        integer(int32) :: checksum
        integer(int32) :: offset
        integer(int32) :: length
    end type table_entry_t

    ! Glyph vertex for outline
    type :: vertex_t
        real(wp) :: x, y
        real(wp) :: cx, cy  ! Control point for curves
        integer :: type     ! CURVE_LINE or CURVE_QUAD
    end type vertex_t

    ! Point in a simple glyph outline
    type :: glyph_point_t
        integer(int16) :: x, y
        integer(int8) :: flags
    end type glyph_point_t

    ! Character mapping subtable
    type :: cmap_subtable_t
        integer(int16) :: platform_id
        integer(int16) :: encoding_id
        integer(int32) :: offset
        integer(int16) :: format
        logical :: valid = .false.
    end type cmap_subtable_t

    ! Native font info structure
    type :: native_fontinfo_t
        integer(int8), allocatable :: font_data(:)
        integer :: font_start = 0
        integer :: num_tables = 0
        integer :: units_per_em = 1000
        integer :: ascent = 800
        integer :: descent = -200
        integer :: line_gap = 200
        integer :: num_glyphs = 0
        integer :: index_to_loc_format = 0
        logical :: valid = .false.

        ! Table directory
        type(table_entry_t), allocatable :: tables(:)

        ! Table offsets
        integer :: cmap_offset = 0
        integer :: head_offset = 0
        integer :: hhea_offset = 0
        integer :: hmtx_offset = 0
        integer :: maxp_offset = 0
        integer :: glyf_offset = 0
        integer :: loca_offset = 0

        ! Character mapping
        type(cmap_subtable_t) :: cmap_subtable
        integer, allocatable :: unicode_to_glyph(:)  ! Unicode to glyph index mapping

        ! Horizontal metrics
        integer, allocatable :: advance_widths(:)
        integer, allocatable :: left_side_bearings(:)

        ! Glyph locations
        integer, allocatable :: glyph_offsets(:)
    end type native_fontinfo_t

end module fortplot_truetype_types
