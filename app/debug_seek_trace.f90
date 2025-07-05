program debug_seek_trace
    use fortplot_mpeg_stream
    use fortplot_mpeg_c_io
    use iso_c_binding
    implicit none
    
    character(len=100) :: filename = "debug_trace.dat"
    integer(c_long) :: pos
    
    print *, "=== Seek Trace Debug ==="
    print *, ""
    
    call stream_open_write(filename)
    print *, "1. Opened file"
    
    call stream_put_bit(1)
    pos = stream_tell_write()
    print *, "2. After put_bit(1), position =", pos
    
    call stream_put_bit(0) 
    pos = stream_tell_write()
    print *, "3. After put_bit(0), position =", pos
    
    call stream_put_bit(1)
    pos = stream_tell_write()
    print *, "4. After put_bit(1), position =", pos
    print *, "   Current state: 101xxxxx, bit_position should be 4"
    
    print *, ""
    print *, "5. Now seeking to position 1..."
    call stream_seek_write(1_c_long)
    pos = stream_tell_write()
    print *, "6. After seek to 1, position =", pos
    print *, "   Should be able to overwrite from bit position 6"
    
    call stream_put_bit(1)
    pos = stream_tell_write()
    print *, "7. After put_bit(1), position =", pos
    
    call stream_put_bit(1)
    pos = stream_tell_write()
    print *, "8. After put_bit(1), position =", pos
    
    call stream_put_bit(0)
    pos = stream_tell_write()
    print *, "9. After put_bit(0), position =", pos
    
    call stream_put_bit(0)
    pos = stream_tell_write()
    print *, "10. After put_bit(0), position =", pos
    
    call stream_put_bit(1)
    pos = stream_tell_write()
    print *, "11. After put_bit(1), position =", pos
    
    call stream_put_bit(1)
    pos = stream_tell_write()
    print *, "12. After put_bit(1), position =", pos
    
    call stream_put_bit(1)
    pos = stream_tell_write()
    print *, "13. After put_bit(1), position =", pos
    print *, "    Expected final byte: 11100111"
    
    call stream_close_write()
    print *, "14. Closed file"
    
    ! Read back and display
    call read_and_display_file(filename)
    
contains
    subroutine read_and_display_file(filename)
        character(len=*), intent(in) :: filename
        character(len=1) :: byte_val
        integer :: ios, i, file_size
        
        open(unit=10, file=filename, access='stream', form='unformatted')
        inquire(unit=10, size=file_size)
        print *, ""
        print *, "File size:", file_size, "bytes"
        
        do i = 1, file_size
            read(10, pos=i, iostat=ios) byte_val
            if (ios == 0) then
                print *, "Byte", i, ":", to_binary(iachar(byte_val)), "(", iachar(byte_val), ")"
            end if
        end do
        close(10)
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
    
end program debug_seek_trace