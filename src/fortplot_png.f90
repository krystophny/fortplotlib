module fortplot_png
    use iso_c_binding
    use fortplot_context, only: setup_canvas
    use fortplot_raster, only: raster_context, create_raster_canvas, draw_axes_and_labels, draw_rotated_ylabel_raster
    use fortplot_zlib, only: zlib_compress, crc32_calculate
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8, int32
    implicit none

    private
    public :: png_context, create_png_canvas, draw_axes_and_labels, write_png_file, save_grayscale_array_as_png

    ! PNG plotting context - extends raster context and adds PNG file I/O
    type, extends(raster_context) :: png_context
    contains
        procedure :: save => png_finalize
    end type png_context

contains

    function create_png_canvas(width, height) result(ctx)
        integer, intent(in) :: width, height
        type(png_context) :: ctx
        type(raster_context) :: raster_base

        ! Create raster canvas and copy components to PNG context
        raster_base = create_raster_canvas(width, height)
        
        ! Initialize PNG context with same data as raster context
        call setup_canvas(ctx, width, height)
        ctx%raster = raster_base%raster
        ctx%margins = raster_base%margins
        ctx%plot_area = raster_base%plot_area
    end function create_png_canvas

    ! All drawing methods are inherited from raster_context

    subroutine png_finalize(this, filename)
        class(png_context), intent(inout) :: this
        character(len=*), intent(in) :: filename

        call write_png_file(filename, this%width, this%height, this%raster%image_data)
    end subroutine png_finalize

    ! PNG file writing functionality
    subroutine write_png_file(filename, width, height, image_data)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: width, height
        integer(1), intent(in) :: image_data(:)

        integer(1) :: png_signature(8) = &
            [int(-119,1), int(80,1), int(78,1), int(71,1), int(13,1), int(10,1), int(26,1), int(10,1)]
        integer, parameter :: bit_depth = 8, color_type = 2
        integer :: png_unit = 10
        integer(int8), allocatable :: compressed_data(:)
        integer :: compressed_size, data_size

        open(unit=png_unit, file=filename, access='stream', form='unformatted', status='replace')

        write(png_unit) png_signature
        call write_ihdr_chunk(png_unit, width, height, bit_depth, color_type)

        data_size = size(image_data)
        compressed_data = zlib_compress(image_data, data_size, compressed_size)
        
        if (.not. allocated(compressed_data) .or. compressed_size <= 0) then
            print *, "Compression failed"
            close(png_unit)
            stop
        end if

        call write_idat_chunk(png_unit, compressed_data, compressed_size)
        call write_iend_chunk(png_unit)

        close(png_unit)
        
        ! Free allocated memory
        deallocate(compressed_data)

        print *, "PNG file '", trim(filename), "' created successfully!"
    end subroutine write_png_file

    ! PNG chunk writing functions (simplified versions)
    subroutine write_ihdr_chunk(unit, w, h, bd, ct)
        integer, intent(in) :: unit, w, h, bd, ct
        integer(1) :: ihdr_data(13)
        integer :: w_be, h_be

        w_be = to_big_endian(w)
        h_be = to_big_endian(h)

        ihdr_data(1:4) = transfer(w_be, ihdr_data(1:4))
        ihdr_data(5:8) = transfer(h_be, ihdr_data(5:8))
        ihdr_data(9) = int(bd, 1)
        ihdr_data(10) = int(ct, 1)
        ihdr_data(11) = 0_1
        ihdr_data(12) = 0_1
        ihdr_data(13) = 0_1

        call write_chunk(unit, "IHDR", ihdr_data, 13)
    end subroutine write_ihdr_chunk

    subroutine write_idat_chunk(unit, data, size)
        integer, intent(in) :: unit, size
        integer(1), intent(in) :: data(size)
        call write_chunk(unit, "IDAT", data, size)
    end subroutine write_idat_chunk

    subroutine write_iend_chunk(unit)
        integer, intent(in) :: unit
        integer(1) :: dummy(1)
        call write_chunk(unit, "IEND", dummy, 0)
    end subroutine write_iend_chunk

    subroutine write_chunk(unit, chunk_type, chunk_data, data_size)
        integer, intent(in) :: unit
        character(len=4), intent(in) :: chunk_type
        integer(1), intent(in) :: chunk_data(*)
        integer, intent(in) :: data_size

        integer :: length_be
        integer(1) :: type_bytes(4)
        integer(1), allocatable, target :: full_data(:)
        integer(c_int32_t) :: crc_value
        integer :: crc_be
        integer :: i

        length_be = to_big_endian(data_size)

        do i = 1, 4
            type_bytes(i) = int(iachar(chunk_type(i:i)), 1)
        end do

        allocate(full_data(4 + data_size))
        full_data(1:4) = type_bytes
        if (data_size > 0) then
            full_data(5:4+data_size) = chunk_data(1:data_size)
        end if

        crc_value = calculate_crc32(full_data, 4 + data_size)
        crc_be = to_big_endian(int(crc_value))

        write(unit) length_be
        write(unit) type_bytes
        if (data_size > 0) then
            write(unit) chunk_data(1:data_size)
        end if
        write(unit) crc_be

        deallocate(full_data)
    end subroutine write_chunk

    function to_big_endian(value) result(be_value)
        integer, intent(in) :: value
        integer :: be_value
        integer(1) :: bytes(4)

        bytes(1) = int(ibits(value, 24, 8), 1)
        bytes(2) = int(ibits(value, 16, 8), 1)
        bytes(3) = int(ibits(value, 8, 8), 1)
        bytes(4) = int(ibits(value, 0, 8), 1)

        be_value = transfer(bytes, be_value)
    end function to_big_endian


    function calculate_crc32(data, len) result(crc)
        integer(1), intent(in) :: data(*)
        integer, intent(in) :: len
        integer(int32) :: crc

        crc = crc32_calculate(data, len)
    end function calculate_crc32

    subroutine save_grayscale_array_as_png(filename, array, width, height)
        !! Save grayscale array as PNG file
        character(len=*), intent(in) :: filename
        integer(int8), intent(in) :: array(:)
        integer, intent(in) :: width, height
        integer :: i, j, idx
        integer(int8), allocatable :: rgb_data(:)
        
        ! Convert grayscale to RGB (3 bytes per pixel)
        allocate(rgb_data(width * height * 3))
        
        do j = 1, height
            do i = 1, width
                idx = (j - 1) * width + i
                if (idx <= size(array)) then
                    ! Convert grayscale to RGB by replicating value
                    rgb_data((idx - 1) * 3 + 1) = array(idx)  ! R
                    rgb_data((idx - 1) * 3 + 2) = array(idx)  ! G
                    rgb_data((idx - 1) * 3 + 3) = array(idx)  ! B
                else
                    rgb_data((idx - 1) * 3 + 1) = 0_int8
                    rgb_data((idx - 1) * 3 + 2) = 0_int8
                    rgb_data((idx - 1) * 3 + 3) = 0_int8
                end if
            end do
        end do
        
        call write_png_file(filename, width, height, rgb_data)
        deallocate(rgb_data)
        
    end subroutine save_grayscale_array_as_png

end module fortplot_png
