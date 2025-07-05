program debug_simple_cross_byte
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=*), parameter :: test_file = "debug_simple_cross.dat"
    integer :: i, read_bit
    
    print *, "=== Simple Cross-Byte Test ==="
    
    ! Write exactly 10 bits to ensure we cross byte boundary
    call stream_open_write(test_file)
    
    do i = 0, 9
        call stream_put_bit(mod(i, 2))  ! Alternating 0,1,0,1,0,1,0,1,0,1
        print *, "Wrote bit", i, "value", mod(i, 2), "position =", stream_tell_write()
    end do
    
    call stream_close_write()
    
    ! Test reading at various positions
    call stream_open_read(test_file)
    
    print *, ""
    print *, "Reading back:"
    
    ! Test positions in first byte (0-7)
    do i = 0, 7
        call stream_seek_read(int(i, c_long))
        read_bit = stream_get_bit()
        print *, "Position", i, ": expected =", mod(i, 2), "actual =", read_bit
        if (read_bit /= mod(i, 2)) then
            print *, "  ERROR: Mismatch at position", i
        end if
    end do
    
    ! Test positions in second byte (8-9)
    do i = 8, 9
        call stream_seek_read(int(i, c_long))
        read_bit = stream_get_bit()
        print *, "Position", i, ": expected =", mod(i, 2), "actual =", read_bit
        if (read_bit /= mod(i, 2)) then
            print *, "  ERROR: Mismatch at position", i
        end if
    end do
    
    call stream_close_read()
    
    ! Show file contents
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
        print *, "Expected pattern: 0101010101"
        print *, "Byte 1: 01010101 =", int(b'01010101')
        print *, "Byte 2: 01xxxxxx (at least 01 in top bits)"
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
    
end program debug_simple_cross_byte