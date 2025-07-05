program debug_mpeg_seek
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=1) :: byte_val
    integer :: i
    
    print *, "Testing MPEG seek behavior..."
    
    ! Write 3 bits: 101
    call stream_open_write("debug_seek.dat")
    print *, "Writing bits: 1 0 1"
    call stream_put_bit(1)
    call stream_put_bit(0) 
    call stream_put_bit(1)
    print *, "Position after 3 bits:", stream_tell_write()
    
    ! Force flush to see what's in the buffer
    call stream_flush_write_zeros()
    call stream_close_write()
    
    ! Read back to see what was written
    open(unit=10, file="debug_seek.dat", access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    print *, "After writing 101 and flushing:", to_binary(iachar(byte_val))
    
    ! Now test the seek operation
    call stream_open_write("debug_seek2.dat")
    print *, ""
    print *, "Writing bits: 1 0 1"
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(1)
    
    ! Read file to see what was written
    call stream_close_write()
    open(unit=10, file="debug_seek2.dat", access='stream', form='unformatted')
    read(10, iostat=i) byte_val
    close(10)
    if (i == 0) then
        print *, "After 3 bits (before seek):", to_binary(iachar(byte_val))
    else
        print *, "No byte written yet (expected)"
    end if
    
    ! Reopen and seek
    call stream_open_write("debug_seek2.dat")
    print *, "Seeking back to position 1..."
    call stream_seek_write(1_c_long)
    
    ! Debug: check position after seek
    print *, "Position after seek:", stream_tell_write()
    
    print *, "Writing bits: 1 1 0 0 1 1 1"
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_put_bit(1)
    
    call stream_close_write()
    
    ! Read back final result
    open(unit=10, file="debug_seek2.dat", access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    print *, "Final result:", to_binary(iachar(byte_val))
    print *, "Expected:    11100111"
    
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
    
end program debug_mpeg_seek