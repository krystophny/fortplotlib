module fortplot_truetype_bitmap
    !! Bitmap character rendering for fallback when TrueType glyphs unavailable
    use, intrinsic :: iso_fortran_env, only: int8, wp => real64
    use fortplot_truetype_types, only: BITMAP_CHAR_WIDTH, BITMAP_CHAR_HEIGHT
    implicit none

    private
    public :: render_bitmap_character, render_bitmap_character_to_buffer

contains

    subroutine render_bitmap_character(bitmap, width, height, codepoint)
        !! Render a simple bitmap character
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height, codepoint
        integer :: x, y, src_x, src_y, idx
        logical :: pixel_on

        bitmap = 0_int8

        do y = 0, height - 1
            do x = 0, width - 1
                src_x = (x * BITMAP_CHAR_WIDTH) / width
                src_y = (y * BITMAP_CHAR_HEIGHT) / height

                pixel_on = get_bitmap_pixel(codepoint, src_x, src_y)

                if (pixel_on) then
                    idx = y * width + x + 1
                    if (idx >= 1 .and. idx <= size(bitmap)) then
                        bitmap(idx) = 127_int8  ! Use positive value for better STB compatibility
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
                    buffer(idx) = 127_int8  ! Use positive value for better STB compatibility
                end if
            end do
        end do

    end subroutine render_bitmap_character_to_buffer

    function get_bitmap_pixel(codepoint, x, y) result(pixel_on)
        !! Get pixel for built-in bitmap font
        integer, intent(in) :: codepoint, x, y
        logical :: pixel_on

        pixel_on = .false.

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
            pixel_on = (x >= 1 .and. x <= 5 .and. y >= 2 .and. y <= 9)
        end select

    end function get_bitmap_pixel

end module fortplot_truetype_bitmap