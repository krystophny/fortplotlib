program debug_seek_flush
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=1) :: byte_val
    
    print *, "=== Debug Seek and Flush ==="
    
    ! Test what happens with flush
    print *, "Test: Write 101, seek to 1, write 1, flush with zeros"
    call stream_open_write("test_flush.dat")
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_seek_write(1_c_long)
    call stream_put_bit(1)
    call stream_flush_write_zeros()  ! Flush with zeros instead of close
    call stream_close_write()
    
    open(unit=10, file="test_flush.dat", access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    print *, "  Result:", to_binary(iachar(byte_val))
    print *, "  Expected: 11000000 (first two bits 11, rest 0s)"
    
    ! Now check position tracking
    print *, ""
    print *, "Checking position during seek:"
    print *, "After writing 3 bits, position should be 3"
    print *, "After seek to 1, position should be 1"
    print *, "After writing 1 bit, position should be 2"
    print *, ""
    print *, "The problem might be:"
    print *, "1. The buffered bits from seek are lost during flush"
    print *, "2. The bit_position is not correctly set after seek"
    
contains
    function to_binary(byte) result(binary_str)
        integer, intent(in) :: byte
        character(len=8) :: binary_str
        integer :: i, bit_val
        
        do i = 1, 8
            bit_val = iand(ishft(byte, -(8-i)), 1)
            if (bit_val == 1) then
                binary_str(i:i) = '1'
            else
                binary_str(i:i) = '0'
            end if
        end do
    end function to_binary
    
end program debug_seek_flush