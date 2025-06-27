module fortplot_truetype_reader
    !! Contains low-level functions for reading data from the font file using proper C unsigned types
    use, intrinsic :: iso_fortran_env, only: int8, int16, int32
    use, intrinsic :: iso_c_binding, only: c_int8_t, c_int16_t, c_int32_t
    implicit none

    private

    public :: read_uint8, read_uint16_be, read_uint32_be, read_int16_be

contains

    function read_uint8(data, offset) result(value)
        !! Read unsigned 8-bit integer using C types
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value
        
        ! Convert signed byte to unsigned using C semantics
        value = int(data(offset), c_int8_t)
        if (value < 0) value = value + 256
    end function read_uint8

    function read_uint16_be(data, offset) result(value)
        !! Read big-endian 16-bit unsigned integer using C types
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value
        integer :: b0, b1
        
        ! Read bytes as unsigned
        b0 = int(data(offset), c_int8_t)
        if (b0 < 0) b0 = b0 + 256
        
        b1 = int(data(offset + 1), c_int8_t) 
        if (b1 < 0) b1 = b1 + 256
        
        ! Combine in big-endian order - equivalent to C uint16_t behavior
        value = ior(ishft(b0, 8), b1)
    end function read_uint16_be

    function read_uint32_be(data, offset) result(value)
        !! Read big-endian 32-bit unsigned integer using C types
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value
        integer :: b0, b1, b2, b3

        ! Read all bytes as unsigned using C semantics
        b0 = int(data(offset), c_int8_t)
        if (b0 < 0) b0 = b0 + 256
        
        b1 = int(data(offset + 1), c_int8_t)
        if (b1 < 0) b1 = b1 + 256
        
        b2 = int(data(offset + 2), c_int8_t)
        if (b2 < 0) b2 = b2 + 256
        
        b3 = int(data(offset + 3), c_int8_t)
        if (b3 < 0) b3 = b3 + 256

        ! Combine in big-endian order - equivalent to C uint32_t behavior
        value = ior(ior(ishft(b0, 24), ishft(b1, 16)), ior(ishft(b2, 8), b3))
    end function read_uint32_be

    function read_int16_be(data, offset) result(value)
        !! Read big-endian 16-bit signed integer using proper C semantics
        integer(int8), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer(int16) :: value
        integer :: unsigned_val
        
        if (offset + 1 > size(data)) then
            value = 0_int16
            return
        end if
        
        ! Read as unsigned first
        unsigned_val = read_uint16_be(data, offset)
        
        ! Convert to signed int16 using proper two's complement conversion
        if (unsigned_val > 32767) then
            value = int(unsigned_val - 65536, int16)
        else
            value = int(unsigned_val, int16)
        end if
    end function read_int16_be

end module fortplot_truetype_reader
