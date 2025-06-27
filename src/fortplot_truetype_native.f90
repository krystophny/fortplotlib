module fortplot_truetype_native
    !! Pure Fortran TrueType font parsing and rendering implementation
    !! Full implementation of TrueType font processing without C dependencies
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8, int16, int32
    use fortplot_truetype_types
    use fortplot_truetype_parser
    use fortplot_truetype_bitmap, only: render_bitmap_character, render_bitmap_character_to_buffer
    use fortplot_truetype_raster, only: rasterize_glyph_outline, rasterize_glyph_outline_to_buffer
    implicit none

    private
    public :: native_fontinfo_t, native_init_font, native_cleanup_font
    public :: native_get_codepoint_bitmap, native_free_bitmap
    public :: native_get_codepoint_hmetrics, native_get_font_vmetrics
    public :: native_scale_for_pixel_height, native_get_codepoint_bitmap_box
    public :: native_find_glyph_index, native_make_codepoint_bitmap

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
        !! Get bounding box for character bitmap using actual glyph metrics
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer :: glyph_index, number_of_contours, x_min, y_min, x_max, y_max

        ! Initialize to empty bounds
        ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0

        if (.not. font_info%valid) then
            return
        end if

        ! Get glyph index for this codepoint
        glyph_index = native_find_glyph_index(font_info, codepoint)

        if (glyph_index > 0 .and. allocated(font_info%glyph_offsets) .and. font_info%glyf_offset > 0) then
            ! Parse actual glyph header to get bounding box
            call parse_glyph_header(font_info, glyph_index, number_of_contours, &
                                    x_min, y_min, x_max, y_max)

            ! Scale the bounding box
            ix0 = int(real(x_min) * scale_x)
            iy0 = int(real(y_min) * scale_y)
            ix1 = int(real(x_max) * scale_x)
            iy1 = int(real(y_max) * scale_y)

            ! Ensure non-zero size for rendering
            if (ix1 <= ix0) ix1 = ix0 + 1
            if (iy1 <= iy0) iy1 = iy0 + 1
        else
            ! Fallback to simple bitmap character bounds
            ix0 = 0
            iy0 = -int(real(BITMAP_CHAR_HEIGHT) * scale_y * 0.8_wp)
            ix1 = int(real(BITMAP_CHAR_WIDTH) * scale_x)
            iy1 = int(real(BITMAP_CHAR_HEIGHT) * scale_y * 0.2_wp)
        end if

    end subroutine native_get_codepoint_bitmap_box

    function native_get_codepoint_bitmap(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap
        type(native_fontinfo_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        integer(int8), pointer :: bitmap_ptr(:)
        integer :: ix0, iy0, ix1, iy1

        nullify(bitmap_ptr)

        if (.not. font_info%valid) then
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Get proper bitmap bounding box based on glyph metrics
        call native_get_codepoint_bitmap_box(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)

        width = ix1 - ix0
        height = iy1 - iy0
        xoff = ix0
        yoff = iy0

        ! Ensure minimum size
        if (width <= 0) width = 1
        if (height <= 0) height = 1

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

    subroutine render_glyph_bitmap(font_info, bitmap, width, height, codepoint, scale_x, scale_y)
        !! Render a single glyph to a bitmap using actual TrueType outline data
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height, codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer :: glyph_index

        bitmap = 0_int8

        glyph_index = native_find_glyph_index(font_info, codepoint)

        if (glyph_index > 0 .and. allocated(font_info%glyph_offsets) .and. font_info%glyf_offset > 0) then
            call rasterize_glyph_outline(font_info, bitmap, width, height, glyph_index, scale_x, scale_y)
        else
            call render_bitmap_character(bitmap, width, height, codepoint)
        end if

    end subroutine render_glyph_bitmap

    subroutine render_glyph_bitmap_to_buffer(font_info, buffer, width, height, stride, codepoint, scale_x, scale_y)
        !! Render a single glyph to a strided buffer using actual TrueType outline data
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: buffer(*)
        integer, intent(in) :: width, height, stride, codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer :: glyph_index

        glyph_index = native_find_glyph_index(font_info, codepoint)

        if (glyph_index > 0 .and. allocated(font_info%glyph_offsets) .and. font_info%glyf_offset > 0) then
            call rasterize_glyph_outline_to_buffer(font_info, buffer, width, height, stride, glyph_index, scale_x, scale_y)
        else
            call render_bitmap_character_to_buffer(buffer, width, height, stride, codepoint)
        end if

    end subroutine render_glyph_bitmap_to_buffer

end module fortplot_truetype_native
