program debug_exact_failing_test
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    character(len=*), parameter :: test_file = "debug_exact_failing.dat"
    integer :: write_bits(10) = [1, 0, 1, 1, 0, 0, 1, 0, 1, 1]
    integer :: read_bits(10)
    integer :: i
    
    print *, "=== Exact Failing Test Replication ==="
    
    ! Replicate test_cross_seek_validation exactly
    call stream_open_write(test_file)
    
    ! Write bits 0-4
    print *, "Writing bits 0-4:"
    do i = 1, 5
        call stream_put_bit(write_bits(i))
        print *, "  Bit", i-1, "=", write_bits(i), "position =", stream_tell_write()
    end do
    
    ! Seek back to bit 2 and overwrite bits 2-4
    print *, ""
    print *, "Seeking to bit 2 and overwriting bits 2-4:"
    call stream_seek_write(2_c_long)
    print *, "  After seek to 2, position =", stream_tell_write()
    
    call stream_put_bit(write_bits(6))  ! Overwrite bit 2
    print *, "  Overwrote bit 2 with", write_bits(6), "position =", stream_tell_write()
    call stream_put_bit(write_bits(7))  ! Overwrite bit 3
    print *, "  Overwrote bit 3 with", write_bits(7), "position =", stream_tell_write()
    call stream_put_bit(write_bits(8))  ! Overwrite bit 4
    print *, "  Overwrote bit 4 with", write_bits(8), "position =", stream_tell_write()
    
    ! Continue writing bits 5-9
    print *, ""
    print *, "Writing bits 5-9:"
    do i = 9, 10
        call stream_put_bit(write_bits(i))
        print *, "  Bit", i+3, "=", write_bits(i), "position =", stream_tell_write()
    end do
    
    call stream_close_write()
    
    ! Read back with seeking
    call stream_open_read(test_file)
    
    print *, ""
    print *, "Reading back with seeks:"
    
    ! Read bits with various seek patterns
    call stream_seek_read(0_c_long)
    read_bits(1) = stream_get_bit()  ! bit 0
    print *, "  Read bit 0: expected =", write_bits(1), "actual =", read_bits(1)
    
    call stream_seek_read(5_c_long)
    read_bits(6) = stream_get_bit()  ! bit 5
    print *, "  Read bit 5: expected =", write_bits(9), "actual =", read_bits(6)
    
    call stream_seek_read(2_c_long)
    read_bits(3) = stream_get_bit()  ! bit 2 (overwritten)
    print *, "  Read bit 2: expected =", write_bits(6), "actual =", read_bits(3)
    
    call stream_seek_read(9_c_long)
    read_bits(10) = stream_get_bit() ! bit 9
    print *, "  Read bit 9: expected =", write_bits(10), "actual =", read_bits(10)
    
    call stream_close_read()
    
    ! Show file contents
    call debug_file_contents()
    
    ! Verify expected pattern
    print *, ""
    print *, "Validation:"
    if (read_bits(1) /= write_bits(1)) then  ! Original bit 0
        print *, "FAILED: Cross seek validation failed at bit 0"
    else
        print *, "PASS: Bit 0 validation"
    end if
    
    if (read_bits(3) /= write_bits(6)) then  ! Overwritten bit 2  
        print *, "FAILED: Cross seek validation failed at overwritten bit 2"
    else
        print *, "PASS: Bit 2 validation"
    end if
    
    if (read_bits(6) /= write_bits(9)) then  ! Continued bit 5
        print *, "FAILED: Cross seek validation failed at bit 5"
    else
        print *, "PASS: Bit 5 validation"
    end if
    
    if (read_bits(10) /= write_bits(10)) then  ! Final bit 9
        print *, "FAILED: Cross seek validation failed at bit 9"
        print *, "  Expected:", write_bits(10), "Got:", read_bits(10)
    else
        print *, "PASS: Bit 9 validation"
    end if
    
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
    
end program debug_exact_failing_test