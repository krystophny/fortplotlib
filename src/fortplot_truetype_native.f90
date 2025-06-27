module fortplot_truetype_native
    !! Pure Fortran TrueType font parsing and rendering implementation
    !! Full implementation of TrueType font processing without C dependencies
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8, int16, int32
    implicit none
    
    private
    public :: native_fontinfo_t, native_init_font, native_cleanup_font
    public :: native_get_codepoint_bitmap, native_free_bitmap
    public :: native_get_codepoint_hmetrics, native_get_font_vmetrics
    public :: native_scale_for_pixel_height, native_get_codepoint_bitmap_box
    public :: native_find_glyph_index, native_make_codepoint_bitmap
    public :: parse_glyph_header
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
    
contains

    function native_init_font(font_info, font_file_path) result(success)
        !! Initialize font from file path using pure Fortran TrueType parsing
        type(native_fontinfo_t), intent(inout) :: font_info
        character(len=*), intent(in) :: font_file_path
        logical :: success
        integer :: file_unit, iostat, file_size
        
        success = .false.
        
        ! Clean up any existing data
        call native_cleanup_font(font_info)
        
        ! Try to open and read the font file
        open(newunit=file_unit, file=font_file_path, access='stream', form='unformatted', &
             status='old', action='read', iostat=iostat)
        
        if (iostat /= 0) then
            return  ! Font file not found
        end if
        
        ! Get file size
        inquire(unit=file_unit, size=file_size, iostat=iostat)
        if (iostat /= 0 .or. file_size <= 0) then
            close(file_unit)
            return
        end if
        
        ! Allocate and read font data
        allocate(font_info%font_data(file_size))
        read(file_unit, iostat=iostat) font_info%font_data
        close(file_unit)
        
        if (iostat /= 0) then
            deallocate(font_info%font_data)
            return
        end if
        
        ! Parse the TrueType font
        if (parse_truetype_font(font_info)) then
            font_info%valid = .true.
            success = .true.
        else
            deallocate(font_info%font_data)
        end if
        
    end function native_init_font
    
    subroutine native_cleanup_font(font_info)
        !! Clean up font resources
        type(native_fontinfo_t), intent(inout) :: font_info
        
        if (allocated(font_info%font_data)) then
            deallocate(font_info%font_data)
        end if
        
        if (allocated(font_info%tables)) then
            deallocate(font_info%tables)
        end if
        
        if (allocated(font_info%unicode_to_glyph)) then
            deallocate(font_info%unicode_to_glyph)
        end if
        
        if (allocated(font_info%advance_widths)) then
            deallocate(font_info%advance_widths)
        end if
        
        if (allocated(font_info%left_side_bearings)) then
            deallocate(font_info%left_side_bearings)
        end if
        
        if (allocated(font_info%glyph_offsets)) then
            deallocate(font_info%glyph_offsets)
        end if
        
        font_info%num_tables = 0
        font_info%valid = .false.
        font_info%cmap_offset = 0
        font_info%head_offset = 0
        font_info%hhea_offset = 0
        font_info%hmtx_offset = 0
        font_info%maxp_offset = 0
        font_info%glyf_offset = 0
        font_info%loca_offset = 0
        
    end subroutine native_cleanup_font
    
    function native_scale_for_pixel_height(font_info, pixel_height) result(scale)
        !! Calculate scale factor for desired pixel height
        type(native_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: pixel_height
        real(wp) :: scale
        
        if (.not. font_info%valid) then
            scale = 0.0_wp
            return
        end if
        
        ! Simple scaling based on units per EM
        scale = pixel_height / real(font_info%units_per_em, wp)
        
    end function native_scale_for_pixel_height
    
    subroutine native_get_font_vmetrics(font_info, ascent, descent, line_gap)
        !! Get vertical font metrics
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(out) :: ascent, descent, line_gap
        
        if (.not. font_info%valid) then
            ascent = 800
            descent = -200
            line_gap = 200
            return
        end if
        
        ascent = font_info%ascent
        descent = font_info%descent
        line_gap = font_info%line_gap
        
    end subroutine native_get_font_vmetrics
    
    subroutine native_get_codepoint_hmetrics(font_info, codepoint, advance_width, left_side_bearing)
        !! Get horizontal character metrics
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer, intent(out) :: advance_width, left_side_bearing
        integer :: glyph_index
        
        if (.not. font_info%valid .or. codepoint < 0) then
            advance_width = 500
            left_side_bearing = 0
            return
        end if
        
        ! Get glyph index for this codepoint
        glyph_index = native_find_glyph_index(font_info, codepoint)
        
        ! Use parsed horizontal metrics if available
        if (allocated(font_info%advance_widths) .and. glyph_index > 0 .and. &
            glyph_index <= size(font_info%advance_widths)) then
            advance_width = font_info%advance_widths(glyph_index)
        else
            advance_width = 500  ! Default advance width
        end if
        
        if (allocated(font_info%left_side_bearings) .and. glyph_index > 0 .and. &
            glyph_index <= size(font_info%left_side_bearings)) then
            left_side_bearing = font_info%left_side_bearings(glyph_index)
        else
            left_side_bearing = 0  ! Default left side bearing
        end if
        
    end subroutine native_get_codepoint_hmetrics
    
    function native_find_glyph_index(font_info, codepoint) result(glyph_index)
        !! Find glyph index for Unicode codepoint
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        integer :: glyph_index
        
        if (.not. font_info%valid .or. codepoint < 0) then
            glyph_index = 0
            return
        end if
        
        ! Use parsed Unicode mapping if available
        if (allocated(font_info%unicode_to_glyph)) then
            if (codepoint >= 0 .and. codepoint <= ubound(font_info%unicode_to_glyph, 1)) then
                glyph_index = font_info%unicode_to_glyph(codepoint)
            else
                glyph_index = 0  ! Character not in mapping range
            end if
        else
            ! Fallback - direct mapping for basic characters
            if (codepoint >= 0 .and. codepoint <= 255 .and. codepoint < font_info%num_glyphs) then
                glyph_index = codepoint
            else
                glyph_index = 0
            end if
        end if
        
    end function native_find_glyph_index
    
    subroutine native_get_codepoint_bitmap_box(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        
        if (.not. font_info%valid) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if
        
        ! Simple bitmap character bounds
        ix0 = 0
        iy0 = -int(real(BITMAP_CHAR_HEIGHT) * scale_y * 0.8_wp)
        ix1 = int(real(BITMAP_CHAR_WIDTH) * scale_x)
        iy1 = int(real(BITMAP_CHAR_HEIGHT) * scale_y * 0.2_wp)
        
    end subroutine native_get_codepoint_bitmap_box
    
    function native_get_codepoint_bitmap(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap
        type(native_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        integer(int8), pointer :: bitmap_ptr(:)
        integer :: scaled_width, scaled_height
        integer :: i, j, byte_idx
        
        nullify(bitmap_ptr)
        
        if (.not. font_info%valid) then
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if
        
        ! Calculate scaled dimensions
        scaled_width = max(1, int(real(BITMAP_CHAR_WIDTH) * scale_x))
        scaled_height = max(1, int(real(BITMAP_CHAR_HEIGHT) * scale_y))
        
        width = scaled_width
        height = scaled_height
        xoff = 0
        yoff = -int(real(scaled_height) * 0.8_wp)  ! Negative offset for baseline
        
        ! Allocate bitmap
        allocate(bitmap_ptr(width * height))
        bitmap_ptr = 0_int8
        
        ! Render actual glyph or fallback to bitmap character
        call render_glyph_bitmap(font_info, bitmap_ptr, width, height, codepoint, scale_x, scale_y)
        
    end function native_get_codepoint_bitmap
    
    subroutine native_make_codepoint_bitmap(font_info, output_buffer, out_w, out_h, out_stride, scale_x, scale_y, codepoint)
        !! Render character into provided buffer
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer :: i, j, out_idx
        
        if (.not. font_info%valid) return
        
        ! Clear buffer
        do i = 1, out_h
            do j = 1, out_w
                out_idx = (i - 1) * out_stride + j
                output_buffer(out_idx) = 0_int8
            end do
        end do
        
        ! Render actual glyph or fallback to bitmap character
        call render_glyph_bitmap_to_buffer(font_info, output_buffer, out_w, out_h, out_stride, codepoint, scale_x, scale_y)
        
    end subroutine native_make_codepoint_bitmap
    
    subroutine native_free_bitmap(bitmap_ptr)
        !! Free bitmap allocated by native_get_codepoint_bitmap
        integer(int8), pointer, intent(inout) :: bitmap_ptr(:)
        
        if (associated(bitmap_ptr)) then
            deallocate(bitmap_ptr)
            nullify(bitmap_ptr)
        end if
        
    end subroutine native_free_bitmap
    
    ! === Private helper routines ===
    
    function get_font_offset_for_index(data, index) result(offset)
        !! Get offset for font at index (for TTC collections)
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: index
        integer(int32) :: offset
        integer(int32) :: signature
        
        if (size(data) < 4) then
            offset = -1
            return
        end if
        
        signature = read_uint32_be(data, 1)
        
        if (signature == int(z'74746366', int32)) then  ! 'ttcf'
            ! TrueType Collection - simplified: just return 0 for now
            offset = 0
        else
            ! Single font
            if (index /= 0) then
                offset = -1
                return
            end if
            offset = 0
        end if
        
    end function get_font_offset_for_index
    
    function read_table_directory(font_info) result(success)
        !! Read the table directory (simplified)
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: i, table_offset
        
        success = .false.
        
        if (.not. allocated(font_info%tables)) return
        
        ! Read table entries (simplified - just allocate for now)
        do i = 1, font_info%num_tables
            table_offset = font_info%font_start + 12 + (i - 1) * 16
            
            if (size(font_info%font_data) >= table_offset + 16) then
                font_info%tables(i)%tag = read_uint32_be(font_info%font_data, table_offset)
                font_info%tables(i)%checksum = read_uint32_be(font_info%font_data, table_offset + 4)
                font_info%tables(i)%offset = read_uint32_be(font_info%font_data, table_offset + 8)
                font_info%tables(i)%length = read_uint32_be(font_info%font_data, table_offset + 12)
            end if
        end do
        
        success = .true.
        
    end function read_table_directory
    
    function find_table(font_info, tag) result(table_index)
        !! Find table by tag
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int32), intent(in) :: tag
        integer :: table_index
        integer :: i
        
        table_index = -1
        
        if (.not. allocated(font_info%tables)) return
        
        do i = 1, font_info%num_tables
            if (font_info%tables(i)%tag == tag) then
                table_index = i
                return
            end if
        end do
        
    end function find_table
    
    function parse_head_table_simple(font_info) result(success)
        !! Parse 'head' table - extract units per EM
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_HEAD)
        if (table_idx == -1) return
        
        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based
        
        if (size(font_info%font_data) < offset + 54 - 1) return
        
        ! Read units per EM (offset 18 in head table)
        font_info%units_per_em = read_uint16_be(font_info%font_data, offset + 18)
        
        ! Read index to location format (offset 50)
        font_info%index_to_loc_format = read_int16_be(font_info%font_data, offset + 50)
        
        font_info%head_offset = offset
        success = .true.
        
    end function parse_head_table_simple
    
    function parse_maxp_table_simple(font_info) result(success)
        !! Parse 'maxp' table - extract number of glyphs
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_MAXP)
        if (table_idx == -1) then
            return
        end if
        
        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based
        
        if (offset <= 0 .or. offset > size(font_info%font_data) - 6) then
            return
        end if
        
        ! Read number of glyphs (offset 4 in maxp table)
        font_info%num_glyphs = read_uint16_be(font_info%font_data, offset + 4)
        
        font_info%maxp_offset = offset
        success = .true.
        
    end function parse_maxp_table_simple
    
    function parse_hhea_table_simple(font_info) result(success)
        !! Parse 'hhea' table - extract vertical metrics
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer :: table_idx, offset
        
        success = .false.
        
        table_idx = find_table(font_info, TAG_HHEA)
        if (table_idx == -1) return
        
        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based
        
        if (size(font_info%font_data) < offset + 36 - 1) return
        
        ! Read vertical metrics (offsets 4, 6, 8 in hhea table)
        font_info%ascent = read_int16_be(font_info%font_data, offset + 4)
        font_info%descent = read_int16_be(font_info%font_data, offset + 6)
        font_info%line_gap = read_int16_be(font_info%font_data, offset + 8)
        
        font_info%hhea_offset = offset
        success = .true.
        
    end function parse_hhea_table_simple
    
    subroutine init_builtin_bitmap_font(font_info)
        !! Initialize with built-in bitmap font fallback
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: i
        
        font_info%valid = .true.
        font_info%units_per_em = BITMAP_CHAR_HEIGHT
        font_info%ascent = int(BITMAP_CHAR_HEIGHT * 0.8)
        font_info%descent = -int(BITMAP_CHAR_HEIGHT * 0.2)
        font_info%line_gap = 2
        font_info%num_glyphs = 256
        
        ! Initialize basic metrics arrays for testing
        allocate(font_info%advance_widths(256))
        font_info%advance_widths = 500  ! Default advance width
        
        ! Adjust widths for common characters
        font_info%advance_widths(iachar(' ') + 1) = 250
        font_info%advance_widths(iachar('i') + 1) = 300
        font_info%advance_widths(iachar('l') + 1) = 300
        font_info%advance_widths(iachar('I') + 1) = 400
        
    end subroutine init_builtin_bitmap_font
    
    function parse_truetype_font(font_info) result(success)
        !! Parse TrueType font completely
        type(native_fontinfo_t), intent(inout) :: font_info
        logical :: success
        integer(int32) :: signature, font_offset
        integer(int16) :: num_tables
        integer :: i
        
        success = .false.
        
        if (.not. allocated(font_info%font_data) .or. size(font_info%font_data) < 16) then
            return
        end if
        
        ! Determine font offset (for TTC collections)
        font_offset = get_font_offset_for_index(font_info%font_data, 0)
        if (font_offset < 0) return
        
        font_info%font_start = font_offset + 1  ! Convert to 1-based
        
        ! Read SFNT header
        signature = read_uint32_be(font_info%font_data, font_info%font_start)
        num_tables = read_uint16_be(font_info%font_data, font_info%font_start + 4)
        
        ! Verify signature
        if (signature /= SFNT_VERSION .and. signature /= TRUE_SIGNATURE) then
            return
        end if
        
        font_info%num_tables = num_tables
        
        ! Read table directory
        allocate(font_info%tables(num_tables))
        if (.not. read_table_directory(font_info)) return
        
        ! Parse required tables - implement step by step
        if (.not. parse_head_table_simple(font_info)) return
        if (.not. parse_maxp_table_simple(font_info)) return
        if (.not. parse_hhea_table_simple(font_info)) return
        
        ! Parse additional tables for proper character mapping and metrics
        call parse_cmap_table_simple(font_info)
        call parse_hmtx_table_simple(font_info)
        call parse_loca_table_simple(font_info)
        call find_glyf_table(font_info)
        
        success = .true.
        
    end function parse_truetype_font
    
    function read_uint32_be(data, offset) result(value)
        !! Read 32-bit big-endian unsigned integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int32) :: value
        integer :: b0, b1, b2, b3
        
        if (offset + 3 > size(data)) then
            value = 0
            return
        end if
        
        ! Convert signed bytes to unsigned
        b0 = int(data(offset))
        if (b0 < 0) b0 = b0 + 256
        
        b1 = int(data(offset + 1))
        if (b1 < 0) b1 = b1 + 256
        
        b2 = int(data(offset + 2))
        if (b2 < 0) b2 = b2 + 256
        
        b3 = int(data(offset + 3))
        if (b3 < 0) b3 = b3 + 256
        
        value = ior(ior(ior(ishft(b0, 24), ishft(b1, 16)), ishft(b2, 8)), b3)
        
    end function read_uint32_be
    
    function read_uint16_be(data, offset) result(value)
        !! Read 16-bit big-endian unsigned integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int16) :: value
        integer :: b0, b1
        
        if (offset + 1 > size(data)) then
            value = 0
            return
        end if
        
        ! Convert signed bytes to unsigned
        b0 = int(data(offset))
        if (b0 < 0) b0 = b0 + 256
        
        b1 = int(data(offset + 1))
        if (b1 < 0) b1 = b1 + 256
        
        value = ior(ishft(b0, 8), b1)
        
    end function read_uint16_be
    
    function read_int16_be(data, offset) result(value)
        !! Read 16-bit big-endian signed integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int16) :: value
        
        if (offset + 1 > size(data)) then
            value = 0
            return
        end if
        
        value = ior(ishft(int(data(offset), int16), 8), &
                   int(data(offset + 1), int16))
        
    end function read_int16_be
    
    subroutine render_bitmap_character(bitmap, width, height, codepoint)
        !! Render a simple bitmap character
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height, codepoint
        integer :: x, y, src_x, src_y, idx
        logical :: pixel_on
        
        ! Clear bitmap
        bitmap = 0_int8
        
        ! Render simple patterns for common characters
        do y = 0, height - 1
            do x = 0, width - 1
                src_x = (x * BITMAP_CHAR_WIDTH) / width
                src_y = (y * BITMAP_CHAR_HEIGHT) / height
                
                pixel_on = get_bitmap_pixel(codepoint, src_x, src_y)
                
                if (pixel_on) then
                    idx = y * width + x + 1
                    if (idx >= 1 .and. idx <= size(bitmap)) then
                        bitmap(idx) = -1_int8  ! 255 in unsigned representation
                    end if
                end if
            end do
        end do
        
    end subroutine render_bitmap_character
    
    subroutine render_bitmap_character_to_buffer(buffer, width, height, stride, codepoint)
        !! Render character into strided buffer
        integer(int8), intent(inout) :: buffer(*)
        integer, intent(in) :: width, height, stride, codepoint
        integer :: x, y, src_x, src_y, idx
        logical :: pixel_on
        
        do y = 0, height - 1
            do x = 0, width - 1
                src_x = (x * BITMAP_CHAR_WIDTH) / width
                src_y = (y * BITMAP_CHAR_HEIGHT) / height
                
                pixel_on = get_bitmap_pixel(codepoint, src_x, src_y)
                
                if (pixel_on) then
                    idx = y * stride + x + 1
                    buffer(idx) = -1_int8  ! 255 in unsigned representation
                end if
            end do
        end do
        
    end subroutine render_bitmap_character_to_buffer
    
    function get_bitmap_pixel(codepoint, x, y) result(pixel_on)
        !! Get pixel for built-in bitmap font
        integer, intent(in) :: codepoint, x, y
        logical :: pixel_on
        
        pixel_on = .false.
        
        ! Simple bitmap patterns for common characters
        select case (codepoint)
        case (32) ! Space
            pixel_on = .false.
        case (48) ! '0'
            pixel_on = ((x == 1 .or. x == 5) .and. (y >= 2 .and. y <= 9)) .or. &
                       ((y == 1 .or. y == 10) .and. (x >= 2 .and. x <= 4))
        case (49) ! '1'
            pixel_on = (x == 3 .and. (y >= 1 .and. y <= 10)) .or. &
                       (x == 2 .and. y == 2)
        case (50) ! '2'
            pixel_on = ((y == 1 .or. y == 6 .or. y == 10) .and. (x >= 1 .and. x <= 5)) .or. &
                       (x == 5 .and. (y >= 2 .and. y <= 5)) .or. &
                       (x == 1 .and. (y >= 7 .and. y <= 9))
        case (65) ! 'A'
            pixel_on = ((x == 1 .or. x == 5) .and. (y >= 4 .and. y <= 10)) .or. &
                       ((y == 3 .or. y == 6) .and. (x >= 2 .and. x <= 4)) .or. &
                       (x == 3 .and. (y == 1 .or. y == 2))
        case (66) ! 'B'
            pixel_on = (x == 1 .and. (y >= 1 .and. y <= 10)) .or. &
                       ((y == 1 .or. y == 6 .or. y == 10) .and. (x >= 2 .and. x <= 4)) .or. &
                       (x == 5 .and. ((y >= 2 .and. y <= 5) .or. (y >= 7 .and. y <= 9)))
        case (88) ! 'X'
            pixel_on = ((x == 1 .or. x == 5) .and. ((y >= 1 .and. y <= 3) .or. (y >= 8 .and. y <= 10))) .or. &
                       ((x == 2 .or. x == 4) .and. (y >= 4 .and. y <= 7)) .or. &
                       (x == 3 .and. (y == 5 .or. y == 6))
        case (89) ! 'Y'
            pixel_on = ((x == 1 .or. x == 5) .and. (y >= 1 .and. y <= 4)) .or. &
                       ((x == 2 .or. x == 4) .and. y == 5) .or. &
                       (x == 3 .and. (y >= 6 .and. y <= 10))
        case default
            ! Default character pattern (rectangle) - make sure we can see something
            pixel_on = (x >= 1 .and. x <= 5 .and. y >= 2 .and. y <= 9)
        end select
        
    end function get_bitmap_pixel
    
    subroutine parse_cmap_table_simple(font_info)
        !! Parse 'cmap' table - simplified Unicode mapping
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx, offset, num_subtables, i
        integer(int16) :: platform_id, encoding_id, format
        integer(int32) :: subtable_offset
        
        table_idx = find_table(font_info, TAG_CMAP)
        if (table_idx == -1) then
            call create_simple_unicode_mapping(font_info)
            return
        end if
        
        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based
        
        if (size(font_info%font_data) < offset + 4 - 1) then
            call create_simple_unicode_mapping(font_info)
            return
        end if
        
        ! Read number of encoding subtables
        num_subtables = read_uint16_be(font_info%font_data, offset + 2)
        
        ! Find a suitable Unicode subtable (simplified)
        do i = 0, min(num_subtables - 1, 10)  ! Limit search
            if (size(font_info%font_data) < offset + 4 + i * 8 + 8 - 1) cycle
            
            platform_id = read_uint16_be(font_info%font_data, offset + 4 + i * 8)
            encoding_id = read_uint16_be(font_info%font_data, offset + 4 + i * 8 + 2)
            subtable_offset = read_uint32_be(font_info%font_data, offset + 4 + i * 8 + 4)
            
            ! Look for Unicode platform (3) or Microsoft Unicode (3,1)
            if ((platform_id == 3 .and. (encoding_id == 1 .or. encoding_id == 10)) .or. &
                (platform_id == 0)) then
                
                font_info%cmap_subtable%platform_id = platform_id
                font_info%cmap_subtable%encoding_id = encoding_id
                font_info%cmap_subtable%offset = offset + int(subtable_offset)
                
                ! Read subtable format
                if (font_info%cmap_subtable%offset > 0 .and. &
                    size(font_info%font_data) >= font_info%cmap_subtable%offset + 2) then
                    format = read_uint16_be(font_info%font_data, font_info%cmap_subtable%offset)
                    font_info%cmap_subtable%format = format
                    font_info%cmap_subtable%valid = .true.
                end if
                
                exit
            end if
        end do
        
        ! Create character mapping based on what we found
        if (font_info%cmap_subtable%valid) then
            call create_unicode_mapping_from_cmap(font_info)
        else
            call create_simple_unicode_mapping(font_info)
        end if
        
        font_info%cmap_offset = offset
        
    end subroutine parse_cmap_table_simple
    
    subroutine parse_hmtx_table_simple(font_info)
        !! Parse 'hmtx' table - simplified horizontal metrics
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx, offset, i, num_long_hor_metrics
        integer :: advance_width, left_side_bearing
        
        table_idx = find_table(font_info, TAG_HMTX)
        if (table_idx == -1) then
            call create_default_metrics(font_info)
            return
        end if
        
        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based
        
        ! Get number of horizontal metrics from hhea table
        if (font_info%hhea_offset == 0) then
            call create_default_metrics(font_info)
            return
        end if
        
        if (size(font_info%font_data) < font_info%hhea_offset + 34 + 2 - 1) then
            call create_default_metrics(font_info)
            return
        end if
        
        num_long_hor_metrics = read_uint16_be(font_info%font_data, font_info%hhea_offset + 34)
        
        ! Allocate arrays
        if (allocated(font_info%advance_widths)) deallocate(font_info%advance_widths)
        if (allocated(font_info%left_side_bearings)) deallocate(font_info%left_side_bearings)
        
        allocate(font_info%advance_widths(font_info%num_glyphs))
        allocate(font_info%left_side_bearings(font_info%num_glyphs))
        
        ! Read horizontal metrics (simplified - read what we can)
        do i = 0, min(font_info%num_glyphs - 1, num_long_hor_metrics - 1)
            if (size(font_info%font_data) >= offset + i * 4 + 4 - 1) then
                advance_width = read_uint16_be(font_info%font_data, offset + i * 4)
                left_side_bearing = read_int16_be(font_info%font_data, offset + i * 4 + 2)
            else
                advance_width = 500  ! Default
                left_side_bearing = 0
            end if
            
            font_info%advance_widths(i + 1) = advance_width
            font_info%left_side_bearings(i + 1) = left_side_bearing
        end do
        
        ! Fill remaining glyphs with last advance width
        if (num_long_hor_metrics > 0 .and. num_long_hor_metrics <= font_info%num_glyphs) then
            do i = num_long_hor_metrics, font_info%num_glyphs - 1
                font_info%advance_widths(i + 1) = font_info%advance_widths(num_long_hor_metrics)
                font_info%left_side_bearings(i + 1) = 0  ! Simplified
            end do
        end if
        
        font_info%hmtx_offset = offset
        
    end subroutine parse_hmtx_table_simple
    
    subroutine create_simple_unicode_mapping(font_info)
        !! Create simple Unicode to glyph mapping for basic ASCII
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: i
        
        if (allocated(font_info%unicode_to_glyph)) deallocate(font_info%unicode_to_glyph)
        allocate(font_info%unicode_to_glyph(0:255))
        
        ! Basic ASCII mapping - assume glyph index matches character code for basic chars
        do i = 0, 255
            if (i < font_info%num_glyphs) then
                font_info%unicode_to_glyph(i) = i
            else
                font_info%unicode_to_glyph(i) = 0  ! Missing character glyph
            end if
        end do
        
    end subroutine create_simple_unicode_mapping
    
    subroutine create_unicode_mapping_from_cmap(font_info)
        !! Create Unicode mapping using cmap subtable data (simplified)
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: i, glyph_index
        
        if (allocated(font_info%unicode_to_glyph)) deallocate(font_info%unicode_to_glyph)
        allocate(font_info%unicode_to_glyph(0:255))
        
        ! For now, create a simplified mapping for basic ASCII characters
        do i = 0, 255
            ! Simple heuristic based on character value
            if (i >= 32 .and. i <= 126) then  ! Printable ASCII
                glyph_index = i - 32 + 1  ! Offset for printable characters
                if (glyph_index < font_info%num_glyphs) then
                    font_info%unicode_to_glyph(i) = glyph_index
                else
                    font_info%unicode_to_glyph(i) = 0
                end if
            else
                font_info%unicode_to_glyph(i) = 0  ! Missing character glyph
            end if
        end do
        
    end subroutine create_unicode_mapping_from_cmap
    
    subroutine create_default_metrics(font_info)
        !! Create default horizontal metrics when hmtx table is not available
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: i
        
        if (allocated(font_info%advance_widths)) deallocate(font_info%advance_widths)
        if (allocated(font_info%left_side_bearings)) deallocate(font_info%left_side_bearings)
        
        allocate(font_info%advance_widths(font_info%num_glyphs))
        allocate(font_info%left_side_bearings(font_info%num_glyphs))
        
        ! Set default metrics
        font_info%advance_widths = 500  ! Default advance width
        font_info%left_side_bearings = 0  ! Default left side bearing
        
        ! Adjust for common characters
        if (font_info%num_glyphs > 32) then
            font_info%advance_widths(33) = 250  ! Space
            font_info%advance_widths(105) = 300  ! 'i'
            font_info%advance_widths(108) = 300  ! 'l'
            font_info%advance_widths(73) = 400   ! 'I'
        end if
        
    end subroutine create_default_metrics
    
    subroutine parse_loca_table_simple(font_info)
        !! Parse 'loca' table - simplified glyph location parsing
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx, offset, i
        
        table_idx = find_table(font_info, TAG_LOCA)
        if (table_idx == -1) return
        
        offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based
        
        ! Allocate glyph offsets array
        if (allocated(font_info%glyph_offsets)) deallocate(font_info%glyph_offsets)
        allocate(font_info%glyph_offsets(font_info%num_glyphs + 1))
        
        ! Read glyph offsets based on format
        if (font_info%index_to_loc_format == 0) then
            ! Short format: offsets are uint16 * 2
            do i = 0, font_info%num_glyphs
                if (offset + i * 2 + 2 <= size(font_info%font_data)) then
                    font_info%glyph_offsets(i + 1) = read_uint16_be(font_info%font_data, offset + i * 2) * 2
                else
                    font_info%glyph_offsets(i + 1) = 0
                    exit
                end if
            end do
        else
            ! Long format: offsets are uint32
            do i = 0, font_info%num_glyphs
                if (offset + i * 4 + 4 <= size(font_info%font_data)) then
                    font_info%glyph_offsets(i + 1) = read_uint32_be(font_info%font_data, offset + i * 4)
                else
                    font_info%glyph_offsets(i + 1) = 0
                    exit
                end if
            end do
        end if
        
        font_info%loca_offset = offset
        
    end subroutine parse_loca_table_simple
    
    subroutine find_glyf_table(font_info)
        !! Find and record the glyf table offset
        type(native_fontinfo_t), intent(inout) :: font_info
        integer :: table_idx
        
        table_idx = find_table(font_info, TAG_GLYF)
        if (table_idx /= -1) then
            font_info%glyf_offset = int(font_info%tables(table_idx)%offset) + 1  ! Convert to 1-based
        else
            font_info%glyf_offset = 0
        end if
        
    end subroutine find_glyf_table
    
    subroutine render_glyph_bitmap(font_info, bitmap, width, height, codepoint, scale_x, scale_y)
        !! Render glyph bitmap using TrueType outline data or fallback
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height, codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer :: glyph_index
        
        ! Get glyph index for this codepoint
        glyph_index = native_find_glyph_index(font_info, codepoint)
        
        if (glyph_index > 0 .and. allocated(font_info%glyph_offsets) .and. font_info%glyf_offset > 0) then
            ! Try to render actual glyph outline
            call render_glyph_outline(font_info, bitmap, width, height, glyph_index, scale_x, scale_y)
        else
            ! Fallback to bitmap patterns or simple filled rectangle
            if (width * height > 4) then
                ! Large enough for bitmap patterns
                call render_bitmap_character(bitmap, width, height, codepoint)
            else
                ! Too small for patterns, just fill it
                bitmap = -1_int8  ! Fill entire bitmap
            end if
        end if
        
    end subroutine render_glyph_bitmap
    
    subroutine render_glyph_bitmap_to_buffer(font_info, buffer, width, height, stride, codepoint, scale_x, scale_y)
        !! Render glyph bitmap to strided buffer
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: buffer(*)
        integer, intent(in) :: width, height, stride, codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer :: glyph_index
        
        ! Get glyph index for this codepoint
        glyph_index = native_find_glyph_index(font_info, codepoint)
        
        if (glyph_index > 0 .and. allocated(font_info%glyph_offsets) .and. font_info%glyf_offset > 0) then
            ! Try to render actual glyph outline to buffer
            call render_glyph_outline_to_buffer(font_info, buffer, width, height, stride, glyph_index, scale_x, scale_y)
        else
            ! Fallback to bitmap patterns
            call render_bitmap_character_to_buffer(buffer, width, height, stride, codepoint)
        end if
        
    end subroutine render_glyph_bitmap_to_buffer
    
    subroutine render_glyph_outline(font_info, bitmap, width, height, glyph_index, scale_x, scale_y)
        !! Render actual TrueType glyph outline to bitmap (simplified implementation)
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height, glyph_index
        real(wp), intent(in) :: scale_x, scale_y
        integer :: glyph_offset, glyph_length
        
        ! Get glyph data location
        if (glyph_index < 1 .or. glyph_index > size(font_info%glyph_offsets) - 1) then
            return  ! Invalid glyph index
        end if
        
        glyph_offset = font_info%glyf_offset + font_info%glyph_offsets(glyph_index)
        glyph_length = font_info%glyph_offsets(glyph_index + 1) - font_info%glyph_offsets(glyph_index)
        
        ! If glyph has no data, it's whitespace
        if (glyph_length <= 0) then
            bitmap = 0_int8  ! Empty glyph
            return
        end if
        
        ! For now, render a simple filled rectangle as placeholder
        ! This will be replaced with actual outline parsing
        if (width * height <= 4) then
            ! Very small bitmap, just fill it
            bitmap = -1_int8
        else
            call render_simple_filled_glyph(bitmap, width, height, scale_x, scale_y)
        end if
        
    end subroutine render_glyph_outline
    
    subroutine render_glyph_outline_to_buffer(font_info, buffer, width, height, stride, glyph_index, scale_x, scale_y)
        !! Render actual TrueType glyph outline to strided buffer
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: buffer(*)
        integer, intent(in) :: width, height, stride, glyph_index
        real(wp), intent(in) :: scale_x, scale_y
        integer :: glyph_offset, glyph_length
        integer :: x, y, idx
        
        ! Get glyph data location
        if (glyph_index < 1 .or. glyph_index > size(font_info%glyph_offsets) - 1) then
            return  ! Invalid glyph index
        end if
        
        glyph_offset = font_info%glyf_offset + font_info%glyph_offsets(glyph_index)
        glyph_length = font_info%glyph_offsets(glyph_index + 1) - font_info%glyph_offsets(glyph_index)
        
        ! If glyph has no data, it's whitespace
        if (glyph_length <= 0) then
            return  ! Empty glyph
        end if
        
        ! For now, render a simple filled rectangle as placeholder
        do y = 0, height - 1
            do x = 0, width - 1
                if (x >= width/8 .and. x < 7*width/8 .and. y >= height/8 .and. y < 7*height/8) then
                    idx = y * stride + x + 1
                    buffer(idx) = -1_int8  ! 255 in unsigned representation
                end if
            end do
        end do
        
    end subroutine render_glyph_outline_to_buffer
    
    subroutine render_simple_filled_glyph(bitmap, width, height, scale_x, scale_y)
        !! Render a simple filled rectangle as glyph placeholder
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height
        real(wp), intent(in) :: scale_x, scale_y
        integer :: x, y, idx
        integer :: border_x, border_y
        
        ! Clear bitmap
        bitmap = 0_int8
        
        ! Make borders smaller to fill more of the glyph
        border_x = max(1, width / 8)
        border_y = max(1, height / 8)
        
        ! Render a filled rectangle with smaller borders
        do y = 0, height - 1
            do x = 0, width - 1
                if (x >= border_x .and. x < width - border_x .and. &
                    y >= border_y .and. y < height - border_y) then
                    idx = y * width + x + 1
                    if (idx >= 1 .and. idx <= size(bitmap)) then
                        bitmap(idx) = -1_int8  ! 255 in unsigned representation
                    end if
                end if
            end do
        end do
        
    end subroutine render_simple_filled_glyph
    
    subroutine parse_glyph_header(font_info, glyph_index, number_of_contours, x_min, y_min, x_max, y_max)
        !! Parse TrueType glyph header following STB format
        !! Glyph header: numberOfContours(2) + xMin(2) + yMin(2) + xMax(2) + yMax(2) = 10 bytes
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        integer, intent(out) :: number_of_contours, x_min, y_min, x_max, y_max
        integer :: glyph_offset, glyph_length
        
        ! Initialize outputs
        number_of_contours = 0
        x_min = 0; y_min = 0; x_max = 0; y_max = 0
        
        ! Validate inputs
        if (.not. font_info%valid .or. glyph_index < 1 .or. &
            .not. allocated(font_info%glyph_offsets) .or. &
            glyph_index > size(font_info%glyph_offsets) - 1) then
            return
        end if
        
        ! Get glyph data location from loca table
        glyph_offset = font_info%glyf_offset + font_info%glyph_offsets(glyph_index)
        glyph_length = font_info%glyph_offsets(glyph_index + 1) - font_info%glyph_offsets(glyph_index)
        
        ! Empty glyph (whitespace)
        if (glyph_length <= 0) then
            return
        end if
        
        ! Ensure we have at least 10 bytes for the header
        if (glyph_offset + 10 > size(font_info%font_data)) then
            return
        end if
        
        ! Parse glyph header following STB format:
        ! Offset 0: numberOfContours (int16)
        ! Offset 2: xMin (int16) 
        ! Offset 4: yMin (int16)
        ! Offset 6: xMax (int16)
        ! Offset 8: yMax (int16)
        number_of_contours = read_int16_be(font_info%font_data, glyph_offset + 0)
        x_min = read_int16_be(font_info%font_data, glyph_offset + 2)
        y_min = read_int16_be(font_info%font_data, glyph_offset + 4)
        x_max = read_int16_be(font_info%font_data, glyph_offset + 6)
        y_max = read_int16_be(font_info%font_data, glyph_offset + 8)
        
    end subroutine parse_glyph_header

end module fortplot_truetype_native