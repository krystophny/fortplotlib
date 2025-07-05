program validate_stream_fortran_complete
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! Complete Fortran stream validation using our implementation
    call test_bit_operations()
    call test_variable_length_operations() 
    call test_alignment_operations()
    call test_seek_and_overwrite()
    
    print *, "PASS: Complete Fortran stream validation"
    
contains

    subroutine test_bit_operations()
        character(len=*), parameter :: test_file = "test_fortran_bits.dat"
        integer :: test_bits(8) = [1, 0, 1, 1, 0, 0, 1, 0]
        integer :: read_bit, i
        
        ! Write test bits
        call stream_open_write(test_file)
        do i = 1, 8
            call stream_put_bit(test_bits(i))
        end do
        call stream_close_write()
        
        ! Read back and verify
        call stream_open_read(test_file)
        do i = 1, 8
            read_bit = stream_get_bit()
            if (read_bit /= test_bits(i)) then
                print *, "Bit mismatch at position", i, "expected", test_bits(i), "got", read_bit
                error stop "Fortran bit operation failed"
            end if
        end do
        call stream_close_read()
        
        print *, "PASS: Fortran bit operations"
    end subroutine

    subroutine test_variable_length_operations()
        character(len=*), parameter :: test_file = "test_fortran_varlen.dat"
        integer :: test_values(4) = [42, 255, 15, 7]
        integer :: bit_lengths(4) = [6, 8, 4, 3]
        integer :: read_value, i, expected_masked
        
        ! Test each value/length combination
        do i = 1, 4
            ! Write variable length value
            call stream_open_write(test_file)
            call stream_put_variable(test_values(i), bit_lengths(i))
            call stream_close_write()
            
            ! Read back and verify
            call stream_open_read(test_file)
            read_value = stream_get_variable(bit_lengths(i))
            call stream_close_read()
            
            ! Mask expected value to bit length for comparison
            expected_masked = iand(test_values(i), ishft(1, bit_lengths(i)) - 1)
            
            if (read_value /= expected_masked) then
                print *, "Variable length mismatch:"
                print *, "  Test", i, ": value=", test_values(i), "bits=", bit_lengths(i)
                print *, "  Expected=", expected_masked, "Got=", read_value
                error stop "Fortran variable length operation failed"
            end if
        end do
        
        print *, "PASS: Fortran variable length operations"
    end subroutine

    subroutine test_alignment_operations()
        character(len=*), parameter :: test_file = "test_fortran_align.dat"
        integer(c_long) :: pos_before, pos_after
        integer :: read_bit
        
        ! Write some bits to misalign
        call stream_open_write(test_file)
        call stream_put_bit(1)
        call stream_put_bit(0)
        call stream_put_bit(1)
        ! Position should be 3 (not byte-aligned)
        call stream_close_write()
        
        ! Test read alignment
        call stream_open_read(test_file)
        ! Read 2 bits to get to position 2
        read_bit = stream_get_bit()
        read_bit = stream_get_bit()
        pos_before = stream_tell_read()
        
        call stream_align_read()
        pos_after = stream_tell_read()
        call stream_close_read()
        
        ! After alignment, position should be on byte boundary
        if (mod(pos_after, 8_c_long) /= 0) then
            print *, "Alignment failed: position", pos_after, "not on byte boundary"
            error stop "Fortran alignment operation failed"
        end if
        
        if (pos_after <= pos_before) then
            print *, "Alignment didn't advance: before=", pos_before, "after=", pos_after
            error stop "Fortran alignment operation failed"
        end if
        
        print *, "PASS: Fortran alignment operations"
    end subroutine

    subroutine test_seek_and_overwrite()
        character(len=*), parameter :: test_file = "test_fortran_seek_overwrite.dat"
        integer :: pattern1(5) = [1, 0, 1, 1, 0]
        integer :: pattern2(3) = [0, 1, 0]
        integer :: read_bits(5)
        integer :: i
        
        ! Write initial pattern
        call stream_open_write(test_file)
        do i = 1, 5
            call stream_put_bit(pattern1(i))
        end do
        
        ! Seek back and overwrite middle bits
        call stream_seek_write(2_c_long)  ! Seek to position 2
        do i = 1, 3
            call stream_put_bit(pattern2(i))  ! Overwrite positions 2, 3, 4
        end do
        call stream_close_write()
        
        ! Read back and verify
        call stream_open_read(test_file)
        do i = 1, 5
            read_bits(i) = stream_get_bit()
        end do
        call stream_close_read()
        
        ! Expected: pattern1(1), pattern1(2), pattern2(1), pattern2(2), pattern2(3)
        if (read_bits(1) /= pattern1(1) .or. read_bits(2) /= pattern1(2)) then
            error stop "Seek overwrite failed: original bits not preserved"
        end if
        
        if (read_bits(3) /= pattern2(1) .or. read_bits(4) /= pattern2(2) .or. read_bits(5) /= pattern2(3)) then
            print *, "Expected overwrite: ", pattern2(1), pattern2(2), pattern2(3)
            print *, "Got: ", read_bits(3), read_bits(4), read_bits(5)
            error stop "Seek overwrite failed: overwritten bits incorrect"
        end if
        
        print *, "PASS: Fortran seek and overwrite operations"
    end subroutine

end program validate_stream_fortran_complete