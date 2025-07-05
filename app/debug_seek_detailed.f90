program debug_seek_detailed
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=1) :: byte_val
    integer :: i
    character(len=100) :: cmd
    
    print *, "=== Detailed Seek Debug ==="
    
    ! Test 1: Write 3 bits without seek
    print *, ""
    print *, "Test 1: Writing 8 bits normally (10100111)"
    call stream_open_write("test_normal.dat")
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_close_write()
    
    open(unit=10, file="test_normal.dat", access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    print *, "Result:", to_binary(iachar(byte_val))
    print *, "Expected: 10100111"
    
    ! Test 2: Write with seek
    print *, ""
    print *, "Test 2: Write 3 bits, seek to 1, write 7 more"
    call stream_open_write("test_seek.dat")
    
    print *, "Writing bits 1 0 1 at positions 0,1,2"
    call stream_put_bit(1)
    print *, "  Position after bit 0:", stream_tell_write()
    call stream_put_bit(0)
    print *, "  Position after bit 1:", stream_tell_write()
    call stream_put_bit(1)
    print *, "  Position after bit 2:", stream_tell_write()
    
    print *, "Seeking to position 1..."
    call stream_seek_write(1_c_long)
    print *, "  Position after seek:", stream_tell_write()
    
    print *, "Writing 1 1 0 0 1 1 1 starting at position 1"
    call stream_put_bit(1)
    print *, "  Position after first bit:", stream_tell_write()
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(0)
    call stream_put_bit(1)
    call stream_put_bit(1)
    call stream_put_bit(1)
    print *, "  Position after last bit:", stream_tell_write()
    
    call stream_close_write()
    
    open(unit=10, file="test_seek.dat", access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    print *, "Result:", to_binary(iachar(byte_val))
    print *, "Expected: 11100111"
    
    ! Hex dump for verification
    print *, ""
    print *, "Hex dumps:"
    call execute_command_line("od -t x1 test_normal.dat", wait=.true.)
    call execute_command_line("od -t x1 test_seek.dat", wait=.true.)
    
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
    
end program debug_seek_detailed