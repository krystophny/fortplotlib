module fortplot_bmp
    implicit none

    private

    public :: write_bmp_file, save_grayscale_bmp

    contains

    subroutine write_bmp_file(filename, bitmap, width, height)
        !! Write RGB bitmap as simple 24-bit BMP file
        character(len=*), intent(in) :: filename
        integer(1), intent(in) :: bitmap(:,:,:)
        integer, intent(in) :: width, height

        integer :: unit, i, j, row_padding, file_size, pixel_data_size
        integer(1) :: bmp_header(54), padding_bytes(3)
        integer(1) :: r, g, b

        ! Calculate row padding (BMP rows must be multiple of 4 bytes)
        row_padding = mod(4 - mod(width * 3, 4), 4)
        pixel_data_size = height * (width * 3 + row_padding)
        file_size = 54 + pixel_data_size

        ! Initialize padding bytes
        padding_bytes = 0_1

        ! BMP header (54 bytes total)
        bmp_header = 0_1

        ! File header (14 bytes)
        bmp_header(1:2) = [66_1, 77_1]  ! "BM" signature
        call write_int32_le(bmp_header(3:6), file_size)     ! File size
        ! Reserved fields (4 bytes) already zero
        call write_int32_le(bmp_header(11:14), 54)          ! Pixel data offset

        ! Info header (40 bytes)
        call write_int32_le(bmp_header(15:18), 40)          ! Info header size
        call write_int32_le(bmp_header(19:22), width)       ! Width
        call write_int32_le(bmp_header(23:26), height)      ! Height
        call write_int16_le(bmp_header(27:28), 1)           ! Planes
        call write_int16_le(bmp_header(29:30), 24)          ! Bits per pixel
        ! Compression, image size, resolution fields already zero

        ! Write BMP file
        open(newunit=unit, file=filename, access="stream", form="unformatted", status="replace")

        write(unit) bmp_header

        ! Write pixel data (BMP stores rows bottom-to-top)
        do j = height, 1, -1
            do i = 1, width
                ! Convert signed byte to unsigned and write as BGR
                r = bitmap(i, j, 1)
                g = bitmap(i, j, 2)
                b = bitmap(i, j, 3)
                write(unit) b, g, r  ! BMP uses BGR order
            end do
            ! Write row padding
            if (row_padding > 0) then
                write(unit) padding_bytes(1:row_padding)
            end if
        end do

        close(unit)
    end subroutine write_bmp_file

    subroutine write_int32_le(bytes, value)
        !! Write 32-bit integer in little-endian format
        integer(1), intent(out) :: bytes(4)
        integer, intent(in) :: value

        bytes(1) = int(iand(value, 255), 1)
        bytes(2) = int(iand(ishft(value, -8), 255), 1)
        bytes(3) = int(iand(ishft(value, -16), 255), 1)
        bytes(4) = int(iand(ishft(value, -24), 255), 1)
    end subroutine write_int32_le

    subroutine write_int16_le(bytes, value)
        !! Write 16-bit integer in little-endian format
        integer(1), intent(out) :: bytes(2)
        integer, intent(in) :: value

        bytes(1) = int(iand(value, 255), 1)
        bytes(2) = int(iand(ishft(value, -8), 255), 1)
    end subroutine write_int16_le

    subroutine save_grayscale_bmp(filename, bitmap, width, height)
        !! Write grayscale bitmap as 8-bit BMP file
        use, intrinsic :: iso_fortran_env, only: int8
        character(len=*), intent(in) :: filename
        integer(int8), intent(in) :: bitmap(:)
        integer, intent(in) :: width, height

        integer :: unit, i, j, row_padding, file_size, pixel_data_size, idx
        integer(1) :: bmp_header(54), padding_bytes(3)
        integer(1) :: gray_val
        integer(1) :: color_table(1024)  ! 256 colors * 4 bytes each (BGRA)

        ! Calculate row padding (BMP rows must be multiple of 4 bytes)
        row_padding = mod(4 - mod(width, 4), 4)
        pixel_data_size = height * (width + row_padding)
        file_size = 54 + 1024 + pixel_data_size  ! Header + color table + pixels

        ! Initialize padding bytes
        padding_bytes = 0_1

        ! BMP header (54 bytes total)
        bmp_header = 0_1

        ! File header (14 bytes)
        bmp_header(1:2) = [66_1, 77_1]  ! "BM" signature
        call write_int32_le(bmp_header(3:6), file_size)     ! File size
        ! Reserved fields (4 bytes) already zero
        call write_int32_le(bmp_header(11:14), 54 + 1024)   ! Pixel data offset (after header + color table)

        ! Info header (40 bytes)
        call write_int32_le(bmp_header(15:18), 40)          ! Info header size
        call write_int32_le(bmp_header(19:22), width)       ! Width
        call write_int32_le(bmp_header(23:26), height)      ! Height
        call write_int16_le(bmp_header(27:28), 1)           ! Planes
        call write_int16_le(bmp_header(29:30), 8)           ! Bits per pixel (8-bit grayscale)
        call write_int32_le(bmp_header(35:38), pixel_data_size)  ! Image size
        call write_int32_le(bmp_header(47:50), 256)         ! Colors used
        call write_int32_le(bmp_header(51:54), 256)         ! Important colors

        ! Create grayscale color table (256 entries, 4 bytes each: BGRA)
        do i = 0, 255
            color_table(i*4 + 1) = int(i, 1)  ! Blue
            color_table(i*4 + 2) = int(i, 1)  ! Green
            color_table(i*4 + 3) = int(i, 1)  ! Red
            color_table(i*4 + 4) = 0_1         ! Alpha (reserved)
        end do

        ! Write BMP file
        open(newunit=unit, file=filename, access="stream", form="unformatted", status="replace")

        write(unit) bmp_header
        write(unit) color_table

        ! Write pixel data (BMP stores rows bottom-to-top)
        do j = height, 1, -1
            do i = 1, width
                idx = (j - 1) * width + i
                if (idx <= size(bitmap)) then
                    ! Convert signed int8 to unsigned byte (0-255 range)
                    if (bitmap(idx) >= 0) then
                        gray_val = bitmap(idx)
                    else
                        gray_val = int(256 + bitmap(idx), 1)  ! Convert negative to 128-255 range
                    end if
                else
                    gray_val = 0_1
                end if
                write(unit) gray_val
            end do
            ! Write row padding
            if (row_padding > 0) then
                write(unit) padding_bytes(1:row_padding)
            end if
        end do

        close(unit)
    end subroutine save_grayscale_bmp

end module fortplot_bmp
