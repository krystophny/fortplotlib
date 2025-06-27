module fortplot_truetype_reader
    !! Contains low-level functions for reading data from the font file
    use, intrinsic :: iso_fortran_env, only: int8, int16, int32
    implicit none

    private

    public :: read_uint8, read_uint16_be, read_uint32_be, read_int16_be

contains

    function read_uint32_be(data, offset) result(value)
        !! Read big-endian 32-bit unsigned integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int32) :: value
        integer(int32) :: b0, b1, b2, b3

        b0 = int(data(offset))
        if (b0 < 0) b0 = b0 + 256
        b1 = int(data(offset + 1))
        if (b1 < 0) b1 = b1 + 256
        b2 = int(data(offset + 2))
        if (b2 < 0) b2 = b2 + 256
        b3 = int(data(offset + 3))
        if (b3 < 0) b3 = b3 + 256
        value = ior(ior(ishft(b0, 24), ishft(b1, 16)), ior(ishft(b2, 8), b3))

    end function read_uint32_be

    function read_uint16_be(data, offset) result(value)
        !! Read big-endian 16-bit unsigned integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int16) :: value
        integer(int32) :: b0, b1

        b0 = int(data(offset))
        b1 = int(data(offset + 1))
        value = int(ior(ishft(b0, 8), b1), int16)

    end function read_uint16_be

    function read_uint8(data, offset) result(value)
        !! Read 8-bit unsigned integer
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int8) :: value

        value = data(offset)

    end function read_uint8

    function read_int16_be(data, offset) result(value)
        !! Read big-endian 16-bit signed integer
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

end module fortplot_truetype_reader
