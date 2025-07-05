program debug_seek_final
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=1) :: byte_val
    integer :: ios
    
    print *, "=== Final Seek Debug ==="
    
    ! Step by step reproduction
    print *, "Step 1: Write 101 and close"
    call stream_open_write("step1.dat")
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_close_write()
    
    open(unit=10, file="step1.dat", access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    print *, "  Result:", to_binary(iachar(byte_val))
    print *, "  Expected: 10111111 (flushed with 1s)"
    
    ! Step 2: Reopen and seek
    print *, ""
    print *, "Step 2: Reopen, seek to 1, write one bit"
    call stream_open_write("step1.dat")
    call stream_seek_write(1_c_long)
    call stream_put_bit(1)  ! Write just one bit
    call stream_close_write()
    
    open(unit=10, file="step1.dat", access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    print *, "  Result:", to_binary(iachar(byte_val))
    print *, "  Expected: 11111111 (bit 1 changed from 0 to 1)"
    
    ! Step 3: Full test
    print *, ""
    print *, "Step 3: Full test - write 101, seek to 1, write 1100111"
    call stream_open_write("step3.dat")
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
    
    open(unit=10, file="step3.dat", access='stream', form='unformatted')
    read(10, iostat=ios) byte_val
    if (ios == 0) then
        print *, "  First byte:", to_binary(iachar(byte_val))
        print *, "  Expected: 11100111"
    end if
    
    ! Check if there's a second byte
    read(10, iostat=ios) byte_val
    if (ios == 0) then
        print *, "  Second byte found!:", to_binary(iachar(byte_val))
        print *, "  This is wrong - should only be one byte!"
    else
        print *, "  Only one byte (correct)"
    end if
    close(10)
    
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
    
end program debug_seek_final