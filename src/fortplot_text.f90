module fortplot_text
    use iso_c_binding
    use fortplot_stb_truetype
    use fortplot_truetype_native
    use fortplot_truetype_types
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    implicit none

    private
    public :: init_text_system, cleanup_text_system, render_text_to_image, calculate_text_width, calculate_text_height
    public :: render_rotated_text_to_image

    ! Constants for text rendering
    integer, parameter :: DEFAULT_FONT_SIZE = 16
    real(wp), parameter :: PI = 3.14159265359_wp

    ! Module state
    type(stb_fontinfo_t) :: global_font
    type(native_fontinfo_t) :: global_native_font
    logical :: font_initialized = .false.
    logical :: native_font_initialized = .false.
    real(wp) :: font_scale = 0.0_wp


contains

    function init_text_system() result(success)
        !! Initialize TrueType font system (STB + Native)
        logical :: success
        character(len=256) :: font_paths(3)
        integer :: i

        success = .false.

        if (font_initialized .and. native_font_initialized) then
            success = .true.
            return
        end if

        ! Try multiple common font paths
        font_paths(1) = "/System/Library/Fonts/Monaco.ttf"            ! macOS monospace font
        font_paths(2) = "/System/Library/Fonts/Geneva.ttf"            ! macOS fallback
        font_paths(3) = "/usr/share/fonts/TTF/DejaVuSans.ttf"        ! Linux path

        do i = 1, 3
            if (stb_init_font(global_font, trim(font_paths(i)))) then
                font_scale = stb_scale_for_pixel_height(global_font, real(DEFAULT_FONT_SIZE, wp))
                font_initialized = .true.

                ! Also initialize native font for better rendering
                if (native_init_font(global_native_font, trim(font_paths(i)))) then
                    native_font_initialized = .true.
                end if

                success = .true.
                exit
            end if
        end do

        if (.not. success) then
            print *, "Error: Could not initialize STB TrueType - no fonts found"
        end if

    end function init_text_system

    subroutine cleanup_text_system()
        !! Clean up TrueType font system
        if (font_initialized) then
            call stb_cleanup_font(global_font)
            font_initialized = .false.
        end if

        if (native_font_initialized) then
            call native_cleanup_font(global_native_font)
            native_font_initialized = .false.
        end if

        font_scale = 0.0_wp
    end subroutine cleanup_text_system

    function calculate_text_width(text) result(width)
        !! Calculate the pixel width of text using TrueType (Native preferred)
        character(len=*), intent(in) :: text
        integer :: width
        integer :: i, char_code, advance_width, left_side_bearing
        real(wp) :: native_scale

        ! Initialize text system if not already done
        if (.not. font_initialized .and. .not. native_font_initialized) then
            if (.not. init_text_system()) then
                print *, "ERROR: TrueType initialization failed in calculate_text_width"
                width = len_trim(text) * 8  ! Fallback estimate
                return
            end if
        end if

        width = 0

        ! Use native implementation if available (more accurate)
        if (native_font_initialized) then
            native_scale = native_scale_for_pixel_height(global_native_font, real(DEFAULT_FONT_SIZE, wp))
            do i = 1, len_trim(text)
                char_code = iachar(text(i:i))
                call native_get_codepoint_hmetrics(global_native_font, char_code, advance_width, left_side_bearing)
                width = width + int(real(advance_width) * native_scale)
            end do
        else if (font_initialized) then
            ! Fallback to STB
            do i = 1, len_trim(text)
                char_code = iachar(text(i:i))
                call stb_get_codepoint_hmetrics(global_font, char_code, advance_width, left_side_bearing)
                width = width + int(real(advance_width) * font_scale)
            end do
        else
            width = len_trim(text) * 8  ! Last resort
        end if

    end function calculate_text_width

    function calculate_text_height(text) result(height)
        !! Calculate the pixel height of text using TrueType (Native preferred)
        character(len=*), intent(in) :: text
        integer :: height
        integer :: ascent, descent, line_gap
        real(wp) :: native_scale

        if (.not. font_initialized .and. .not. native_font_initialized) then
            if (.not. init_text_system()) then
                height = DEFAULT_FONT_SIZE  ! Fallback
                return
            end if
        end if

        ! Use native implementation if available
        if (native_font_initialized) then
            native_scale = native_scale_for_pixel_height(global_native_font, real(DEFAULT_FONT_SIZE, wp))
            call native_get_font_vmetrics(global_native_font, ascent, descent, line_gap)
            height = int(real(ascent - descent) * native_scale)
        else if (font_initialized) then
            ! Fallback to STB
            call stb_get_font_vmetrics(global_font, ascent, descent, line_gap)
            height = int(real(ascent - descent) * font_scale)
        else
            height = DEFAULT_FONT_SIZE
        end if

        ! Ensure minimum reasonable height
        if (height <= 0) height = DEFAULT_FONT_SIZE

    end function calculate_text_height

    subroutine render_text_to_image(image_data, width, height, x, y, text, r, g, b)
        !! Render text to image using TrueType (Native preferred, STB fallback)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        character(len=*), intent(in) :: text
        integer(1), intent(in) :: r, g, b
        integer :: pen_x, pen_y, i, char_code
        integer :: advance_width, left_side_bearing
        type(c_ptr) :: stb_bitmap_ptr
        integer(int8), pointer :: native_bitmap(:)
        integer :: bmp_width, bmp_height, xoff, yoff
        real(wp) :: native_scale

        if (.not. font_initialized .and. .not. native_font_initialized) then
            if (.not. init_text_system()) then
                call render_simple_placeholder(image_data, width, height, x, y, r, g, b)
                return
            end if
        end if

        pen_x = x
        pen_y = y

        do i = 1, len_trim(text)
            char_code = iachar(text(i:i))

            ! Try native implementation first (better quality)
            if (native_font_initialized) then
                native_scale = native_scale_for_pixel_height(global_native_font, real(DEFAULT_FONT_SIZE, wp))
                native_bitmap => native_get_codepoint_bitmap(global_native_font, native_scale, native_scale, char_code, &
                                                             bmp_width, bmp_height, xoff, yoff)

                if (associated(native_bitmap)) then
                    call render_native_glyph(image_data, width, height, pen_x, pen_y, &
                                             native_bitmap, bmp_width, bmp_height, xoff, yoff, r, g, b)
                    call native_free_bitmap(native_bitmap)

                    ! Advance pen position using native metrics
                    call native_get_codepoint_hmetrics(global_native_font, char_code, advance_width, left_side_bearing)
                    pen_x = pen_x + int(real(advance_width) * native_scale)
                    cycle  ! Successfully rendered with native, continue to next character
                end if
            end if

            ! Fallback to STB implementation
            if (font_initialized) then
                stb_bitmap_ptr = stb_get_codepoint_bitmap(global_font, font_scale, font_scale, char_code, &
                                                         bmp_width, bmp_height, xoff, yoff)

                if (c_associated(stb_bitmap_ptr)) then
                    call render_stb_glyph(image_data, width, height, pen_x, pen_y, &
                                         stb_bitmap_ptr, bmp_width, bmp_height, xoff, yoff, r, g, b)
                    call stb_free_bitmap(stb_bitmap_ptr)

                    ! Advance pen position
                    call stb_get_codepoint_hmetrics(global_font, char_code, advance_width, left_side_bearing)
                    pen_x = pen_x + int(real(advance_width) * font_scale)
                    cycle  ! Successfully rendered with STB, continue to next character
                end if
            end if

            ! Last resort: simple character fallback
            call render_character_bitmap(image_data, width, height, pen_x, pen_y, text(i:i), r, g, b)
            pen_x = pen_x + 8  ! Fixed-width fallback
        end do
    end subroutine render_text_to_image

    subroutine render_stb_glyph(image_data, width, height, pen_x, pen_y, bitmap_ptr, &
                               bmp_width, bmp_height, xoff, yoff, r, g, b)
        !! Render STB TrueType glyph bitmap to image
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, pen_x, pen_y
        type(c_ptr), intent(in) :: bitmap_ptr
        integer, intent(in) :: bmp_width, bmp_height, xoff, yoff
        integer(1), intent(in) :: r, g, b
        integer(c_int8_t), pointer :: bitmap_buffer(:)
        integer :: glyph_x, glyph_y, img_x, img_y, row, col, pixel_idx
        integer :: alpha_int
        real :: alpha_f, bg_r, bg_g, bg_b

        if (bmp_width <= 0 .or. bmp_height <= 0) then
            return
        end if

        call c_f_pointer(bitmap_ptr, bitmap_buffer, [bmp_width * bmp_height])

        glyph_x = pen_x + xoff
        glyph_y = pen_y + yoff  ! STB yoff is negative for characters above baseline

        do row = 0, bmp_height - 1
            do col = 0, bmp_width - 1
                img_x = glyph_x + col
                img_y = glyph_y + row

                if (img_x >= 0 .and. img_x < width .and. img_y >= 0 .and. img_y < height) then
                    ! Convert signed int8 to unsigned (0-255 range)
                    alpha_int = int(bitmap_buffer(row * bmp_width + col + 1))
                    if (alpha_int < 0) alpha_int = alpha_int + 256

                    if (alpha_int > 0) then  ! Only render non-transparent pixels
                        pixel_idx = img_y * (1 + width * 3) + 1 + img_x * 3 + 1

                        alpha_f = real(alpha_int) / 255.0
                        bg_r = real(int(image_data(pixel_idx), &
                            kind=selected_int_kind(2)) + merge(256, 0, image_data(pixel_idx) < 0))
                        bg_g = real(int(image_data(pixel_idx + 1), &
                            kind=selected_int_kind(2)) + merge(256, 0, image_data(pixel_idx + 1) < 0))
                        bg_b = real(int(image_data(pixel_idx + 2), &
                            kind=selected_int_kind(2)) + merge(256, 0, image_data(pixel_idx + 2) < 0))

                        ! Alpha blending
                        image_data(pixel_idx) = int(bg_r * (1.0 - alpha_f) + real(int(r) + merge(256, 0, r < 0)) * alpha_f, 1)
                        image_data(pixel_idx + 1) = int(bg_g * (1.0 - alpha_f) + real(int(g) + merge(256, 0, g < 0)) * alpha_f, 1)
                        image_data(pixel_idx + 2) = int(bg_b * (1.0 - alpha_f) + real(int(b) + merge(256, 0, b < 0)) * alpha_f, 1)
                    end if
                end if
            end do
        end do
    end subroutine render_stb_glyph

    subroutine render_native_glyph(image_data, width, height, pen_x, pen_y, bitmap, &
                                   bmp_width, bmp_height, xoff, yoff, r, g, b)
        !! Render Native TrueType glyph bitmap to image
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, pen_x, pen_y
        integer(int8), intent(in) :: bitmap(:)
        integer, intent(in) :: bmp_width, bmp_height, xoff, yoff
        integer(1), intent(in) :: r, g, b
        integer :: img_x, img_y, bmp_x, bmp_y, pixel_idx, bmp_idx
        integer :: final_x, final_y
        real :: alpha

        do bmp_y = 0, bmp_height - 1
            do bmp_x = 0, bmp_width - 1
                final_x = pen_x + bmp_x + xoff
                final_y = pen_y + bmp_y + yoff

                ! Check bounds
                if (final_x >= 0 .and. final_x < width .and. final_y >= 0 .and. final_y < height) then
                    bmp_idx = bmp_y * bmp_width + bmp_x + 1

                    if (bmp_idx <= size(bitmap)) then
                        ! Convert signed int8 to alpha (bitmap uses -1 for 255)
                        if (bitmap(bmp_idx) /= 0) then
                            alpha = abs(real(bitmap(bmp_idx))) / 255.0

                            ! Blend glyph with background
                            pixel_idx = final_y * (1 + width * 3) + 1 + final_x * 3 + 1
                            if (pixel_idx > 0 .and. pixel_idx <= width * height * 3) then
                                image_data(pixel_idx) = int(real(image_data(pixel_idx)) * (1.0 - alpha) + real(r) * alpha, kind=1)
                                image_data(pixel_idx + 1) = int(real(image_data(pixel_idx + 1)) * (1.0 - alpha) + &
                                                                 real(g) * alpha, kind=1)
                                image_data(pixel_idx + 2) = int(real(image_data(pixel_idx + 2)) * (1.0 - alpha) + &
                                                                 real(b) * alpha, kind=1)
                            end if
                        end if
                    end if
                end if
            end do
        end do
    end subroutine render_native_glyph


    subroutine render_simple_character_block(image_data, width, height, x, y, r, g, b)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        integer(1), intent(in) :: r, g, b
        integer :: img_x, img_y, pixel_idx
        integer(1) :: black_r, black_g, black_b

        black_r = 0_1
        black_g = 0_1
        black_b = 0_1

        do img_y = y, min(y + 5, height - 1)
            do img_x = x, min(x + 3, width - 1)
                if (img_x >= 0 .and. img_y >= 0) then
                    pixel_idx = img_y * (1 + width * 3) + 1 + img_x * 3 + 1
                    if (pixel_idx > 0 .and. pixel_idx <= height * (1 + width * 3) - 2) then
                        image_data(pixel_idx) = black_r
                        image_data(pixel_idx + 1) = black_g
                        image_data(pixel_idx + 2) = black_b
                    end if
                end if
            end do
        end do
    end subroutine render_simple_character_block

    subroutine render_simple_placeholder(image_data, width, height, x, y, r, g, b)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        integer(1), intent(in) :: r, g, b
        integer :: pixel_idx, img_x, img_y, max_idx

        max_idx = height * (1 + width * 3)


        do img_y = y, min(y + 6, height - 1)
            do img_x = x, min(x + 4, width - 1)
                if (img_x >= 0 .and. img_y >= 0) then
                    pixel_idx = img_y * (1 + width * 3) + 1 + img_x * 3 + 1
                    if (pixel_idx > 0 .and. pixel_idx <= max_idx - 2) then
                        image_data(pixel_idx) = r
                        image_data(pixel_idx + 1) = g
                        image_data(pixel_idx + 2) = b
                    end if
                end if
            end do
        end do
    end subroutine render_simple_placeholder


    subroutine render_character_bitmap(image_data, width, height, x, y, char, r, g, b)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        character(len=1), intent(in) :: char
        integer(1), intent(in) :: r, g, b
        integer :: img_x, img_y, pixel_idx, char_code
        integer(1) :: black_r, black_g, black_b
        logical :: pixel_set

        black_r = 0_1
        black_g = 0_1
        black_b = 0_1

        char_code = iachar(char)

        do img_y = y, min(y + 7, height - 1)
            do img_x = x, min(x + 5, width - 1)
                if (img_x >= 0 .and. img_y >= 0) then
                    pixel_set = get_character_pixel(char_code, img_x - x, img_y - y)
                    if (pixel_set) then
                        pixel_idx = img_y * (1 + width * 3) + 1 + img_x * 3 + 1
                        if (pixel_idx > 0 .and. pixel_idx <= height * (1 + width * 3) - 2) then
                            image_data(pixel_idx) = black_r
                            image_data(pixel_idx + 1) = black_g
                            image_data(pixel_idx + 2) = black_b
                        end if
                    end if
                end if
            end do
        end do
    end subroutine render_character_bitmap

    function get_character_pixel(char_code, x, y) result(pixel_set)
        integer, intent(in) :: char_code, x, y
        logical :: pixel_set

        pixel_set = .false.

        select case (char_code)
        case (48) ! '0'
            pixel_set = (x == 0 .or. x == 3) .and. (y >= 1 .and. y <= 6) .or. &
                       (y == 0 .or. y == 7) .and. (x >= 1 .and. x <= 2)
        case (49) ! '1'
            pixel_set = x == 2 .and. (y >= 0 .and. y <= 7)
        case (50) ! '2'
            pixel_set = (y == 0 .or. y == 3 .or. y == 7) .and. (x >= 0 .and. x <= 3) .or. &
                       x == 3 .and. (y >= 1 .and. y <= 2) .or. &
                       x == 0 .and. (y >= 4 .and. y <= 6)
        case (51) ! '3'
            pixel_set = (y == 0 .or. y == 3 .or. y == 7) .and. (x >= 0 .and. x <= 3) .or. &
                       x == 3 .and. ((y >= 1 .and. y <= 2) .or. (y >= 4 .and. y <= 6))
        case (53) ! '5'
            pixel_set = (y == 0 .or. y == 3 .or. y == 7) .and. (x >= 0 .and. x <= 3) .or. &
                       x == 0 .and. (y >= 1 .and. y <= 2) .or. &
                       x == 3 .and. (y >= 4 .and. y <= 6)
        case (55) ! '7'
            pixel_set = y == 0 .and. (x >= 0 .and. x <= 3) .or. &
                       x == 3 .and. (y >= 1 .and. y <= 7)
        case (45) ! '-'
            pixel_set = y == 3 .and. (x >= 0 .and. x <= 3)
        case (46) ! '.'
            pixel_set = y == 7 .and. x == 1
        case default
            pixel_set = (x >= 1 .and. x <= 2) .and. (y >= 2 .and. y <= 5)
        end select
    end function get_character_pixel

    subroutine render_rotated_text_to_image(image_data, width, height, x, y, text, r, g, b, angle)
        !! Render rotated text to PNG image using STB TrueType (simplified rotation)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        character(len=*), intent(in) :: text
        integer(1), intent(in) :: r, g, b
        real(wp), intent(in) :: angle  ! Rotation angle in degrees

        integer :: i, char_code, pen_x, pen_y
        integer :: advance_width, left_side_bearing
        type(c_ptr) :: bitmap_ptr
        integer :: bmp_width, bmp_height, xoff, yoff
        real(wp) :: cos_a, sin_a

        if (.not. font_initialized) then
            if (.not. init_text_system()) then
                return
            end if
        end if

        pen_x = x
        pen_y = y
        cos_a = cos(angle * PI / 180.0_wp)
        sin_a = sin(angle * PI / 180.0_wp)

        ! For now, render text normally (STB doesn't have built-in rotation)
        ! TODO: Implement proper bitmap rotation if needed
        do i = 1, len_trim(text)
            char_code = iachar(text(i:i))

            bitmap_ptr = stb_get_codepoint_bitmap(global_font, font_scale, font_scale, char_code, &
                                                 bmp_width, bmp_height, xoff, yoff)

            if (c_associated(bitmap_ptr)) then
                call render_stb_glyph(image_data, width, height, pen_x, pen_y, &
                                     bitmap_ptr, bmp_width, bmp_height, xoff, yoff, r, g, b)
                call stb_free_bitmap(bitmap_ptr)
            end if

            ! Advance with rotation
            call stb_get_codepoint_hmetrics(global_font, char_code, advance_width, left_side_bearing)
            pen_x = pen_x + int(real(advance_width) * font_scale * cos_a)
            pen_y = pen_y + int(real(advance_width) * font_scale * sin_a)
        end do
    end subroutine render_rotated_text_to_image

end module fortplot_text
