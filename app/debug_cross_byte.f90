program debug_cross_byte
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=*), parameter :: test_file = "debug_cross_byte.dat"
    integer :: write_bits(10) = [1, 0, 1, 1, 0, 0, 1, 0, 1, 1]
    integer :: read_bit, i
    
    print *, "=== Cross-Byte Debug ==="
    
    ! Write pattern that crosses byte boundary
    call stream_open_write(test_file)
    
    ! Write all 10 bits sequentially first
    do i = 1, 10
        call stream_put_bit(write_bits(i))
        print *, "Wrote bit", i-1, "value", write_bits(i), "position =", stream_tell_write()
    end do
    
    call stream_close_write()
    
    ! Now read back bit 9 (which should be in the second byte)
    call stream_open_read(test_file)
    
    print *, ""
    print *, "Reading bit 9 (should be", write_bits(10), ")..."
    call stream_seek_read(9_c_long)
    read_bit = stream_get_bit()
    print *, "Read bit 9: expected =", write_bits(10), "actual =", read_bit
    
    if (read_bit == write_bits(10)) then
        print *, "SUCCESS: Cross-byte read works"
    else
        print *, "FAILED: Cross-byte read broken"
    end if
    
    call stream_close_read()
    
    ! Also check the file contents manually
    call debug_file_contents()
    
contains
    subroutine debug_file_contents()
        character(len=1) :: byte_val
        integer :: ios, i, file_size
        
        print *, ""
        print *, "File contents:"
        open(unit=10, file=test_file, access='stream', form='unformatted')
        inquire(unit=10, size=file_size)
        print *, "File size:", file_size, "bytes"
        
        do i = 1, file_size
            read(10, pos=i, iostat=ios) byte_val
            if (ios == 0) then
                print *, "Byte", i, ":", to_binary(iachar(byte_val)), "(", iachar(byte_val), ")"
            end if
        end do
        close(10)
        
        print *, ""
        print *, "Expected bit pattern: 1011001011"
        print *, "Byte 1 should be: 10110010 (", int(b'10110010'), ")"
        print *, "Byte 2 should be: 11xxxxxx (at least 11 in top bits)"
    end subroutine
    
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
    
end program debug_cross_byte