program debug_bit_position
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=100) :: filename = "debug_position.dat"
    
    call stream_open_write(filename)
    print *, "Initial bit_position after open: (should be 7)"
    
    call stream_put_bit(1)
    print *, "After 1st bit: position =", stream_tell_write()
    
    call stream_put_bit(0)  
    print *, "After 2nd bit: position =", stream_tell_write()
    
    call stream_put_bit(1)
    print *, "After 3rd bit: position =", stream_tell_write()
    print *, "Internal bit_position should be 4 now"
    
    ! Now test seek
    print *, ""
    print *, "About to seek to position 1..."
    call stream_seek_write(1_c_long)
    print *, "After seek: position =", stream_tell_write()
    
    call stream_close_write()
    
end program debug_bit_position