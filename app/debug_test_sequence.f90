program debug_test_sequence
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=*), parameter :: test_file = "debug_test_sequence.dat"
    character(len=1) :: byte_val
    integer :: expected_byte
    
    print *, "=== Exact Test Sequence Debug ==="
    
    ! Replicate test_write_seek_operations exactly
    call stream_open_write(test_file)
    
    ! Write first 3 bits: 101
    call stream_put_bit(1)
    call stream_put_bit(0)
    call stream_put_bit(1)
    
    print *, "After writing 101, position =", stream_tell_write()
    
    ! Seek back to bit 1
    call stream_seek_write(1_c_long)
    print *, "After seek to 1, position =", stream_tell_write()
    
    ! Write 7 more bits: 1100111
    call stream_put_bit(1)  ! position 1
    call stream_put_bit(1)  ! position 2  
    call stream_put_bit(0)  ! position 3
    call stream_put_bit(0)  ! position 4
    call stream_put_bit(1)  ! position 5
    call stream_put_bit(1)  ! position 6
    call stream_put_bit(1)  ! position 7
    
    print *, "After writing 1100111, position =", stream_tell_write()
    
    call stream_close_write()
    
    ! Expected: 11100111
    expected_byte = int(z'E7')  ! 11100111 in binary
    
    ! Read back and verify
    open(unit=10, file=test_file, access='stream', form='unformatted')
    read(10) byte_val
    close(10)
    
    print *, ""
    print *, "Expected:", to_binary(expected_byte), "(", expected_byte, ")"
    print *, "Actual:  ", to_binary(iachar(byte_val)), "(", iachar(byte_val), ")"
    
    if (iachar(byte_val) == expected_byte) then
        print *, "SUCCESS: Bytes match!"
    else
        print *, "FAILED: Bytes don't match"
    end if
    
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
    
end program debug_test_sequence