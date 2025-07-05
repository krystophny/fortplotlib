program debug_seek_two_bytes
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=1) :: byte_val
    integer :: ios, i, file_size
    character(len=100) :: filename = "debug_two_bytes.dat"
    
    print *, "=== Debug Two Bytes Issue ==="
    
    ! Reproduce the exact failing sequence
    call stream_open_write(filename)
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_seek_write(1_c_long)
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_close_write()
    
    ! Check file size
    open(unit=10, file=filename, access='stream', form='unformatted')
    inquire(unit=10, size=file_size)
    print *, "File size:", file_size, "bytes"
    
    ! Read all bytes
    do i = 1, file_size
        read(10, pos=i, iostat=ios) byte_val
        if (ios == 0) then
            print *, "Byte", i, ":", to_binary(iachar(byte_val)), "(", iachar(byte_val), ")"
        else
            print *, "Error reading byte", i
            exit
        end if
    end do
    close(10)
    
    print *, ""
    print *, "Expected: Only 1 byte with value 11100111"
    print *, "Problem: We're getting 2 bytes instead of overwriting the first one!"
    
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
    
end program debug_seek_two_bytes