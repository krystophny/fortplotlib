program validate_stream_bits
    use iso_c_binding
    implicit none
    
    ! Test bit-level stream operations
    call test_bit_operations()
    call test_variable_length_operations()
    call test_alignment_operations()
    
    print *, "PASS: stream bit operations validation"
    
contains

    subroutine test_bit_operations()
        use fortplot_mpeg_stream
        
        integer :: test_bit, read_bit
        character(len=*), parameter :: test_file = "test_bits.dat"
        
        ! Test single bit write/read using Fortran implementation
        test_bit = 1
        
        ! Write using Fortran stream functions
        call stream_open_write(test_file)
        call stream_put_bit(test_bit)
        call stream_close_write()
        
        ! Read using Fortran stream functions
        call stream_open_read(test_file)
        read_bit = stream_get_bit()
        call stream_close_read()
        
        if (read_bit /= test_bit) then
            error stop "Bit read/write mismatch"
        end if
        
        print *, "PASS: single bit operations"
    end subroutine

    subroutine test_variable_length_operations()
        use fortplot_mpeg_stream
        
        integer :: test_value, read_value, num_bits
        character(len=*), parameter :: test_file = "test_varlen.dat"
        
        ! Test variable length operations using Fortran implementation
        test_value = 42
        num_bits = 8
        
        ! Write using Fortran stream functions
        call stream_open_write(test_file)
        call stream_put_variable(test_value, num_bits)
        call stream_close_write()
        
        ! Read using Fortran stream functions
        call stream_open_read(test_file)
        read_value = stream_get_variable(num_bits)
        call stream_close_read()
        
        if (read_value /= test_value) then
            error stop "Variable length read/write mismatch"
        end if
        
        print *, "PASS: variable length operations"
    end subroutine

    subroutine test_alignment_operations()
        use fortplot_mpeg_stream
        
        character(len=*), parameter :: test_file = "test_align.dat"
        integer(c_long) :: pos_before, pos_after
        integer :: read_bit
        
        ! Test alignment functions using Fortran implementation
        ! Write some bits to create misalignment
        call stream_open_write(test_file)
        call stream_put_bit(1)
        call stream_put_bit(0)
        call stream_put_bit(1)
        call stream_flush_write_zeros()  ! Fortran equivalent of zeroflush
        call stream_close_write()
        
        ! Test read alignment
        call stream_open_read(test_file)
        read_bit = stream_get_bit()  ! Read one bit to create misalignment
        pos_before = stream_tell_read()
        call stream_align_read()  ! Fortran equivalent of readalign
        pos_after = stream_tell_read()
        call stream_close_read()
        
        ! Verify alignment worked (position should advance to byte boundary)
        if (pos_after <= pos_before) then
            error stop "Alignment operation failed"
        end if
        
        print *, "PASS: alignment operations"
    end subroutine

end program validate_stream_bits