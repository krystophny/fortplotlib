program validate_stream_roundtrip
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! Test actual file I/O with bit-level roundtrip
    call test_bit_roundtrip()
    call test_variable_roundtrip()
    call test_mixed_operations()
    call test_byte_alignment()
    
    print *, "PASS: Stream roundtrip validation"
    
contains

    subroutine test_bit_roundtrip()
        character(len=*), parameter :: test_file = "test_bit_roundtrip.dat"
        integer, parameter :: num_bits = 16
        integer :: test_bits(num_bits) = [1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1]
        integer :: read_bits(num_bits)
        integer :: i
        
        ! Write bits
        call stream_open_write(test_file)
        do i = 1, num_bits
            call stream_put_bit(test_bits(i))
        end do
        call stream_close_write()
        
        ! Read bits back
        call stream_open_read(test_file)
        do i = 1, num_bits
            read_bits(i) = stream_get_bit()
        end do
        call stream_close_read()
        
        ! Verify roundtrip
        do i = 1, num_bits
            if (read_bits(i) /= test_bits(i)) then
                print *, "Bit mismatch at position", i, "expected", test_bits(i), "got", read_bits(i)
                error stop "Bit roundtrip failed"
            end if
        end do
        
        print *, "PASS: Bit-level roundtrip"
    end subroutine

    subroutine test_variable_roundtrip()
        character(len=*), parameter :: test_file = "test_var_roundtrip.dat"
        integer, parameter :: num_values = 5
        integer :: test_values(num_values) = [42, 255, 1, 127, 200]
        integer :: test_bits(num_values) = [8, 8, 1, 7, 8]
        integer :: read_values(num_values)
        integer :: i
        
        ! Write variable length values
        call stream_open_write(test_file)
        do i = 1, num_values
            call stream_put_variable(test_values(i), test_bits(i))
        end do
        call stream_close_write()
        
        ! Read values back
        call stream_open_read(test_file)
        do i = 1, num_values
            read_values(i) = stream_get_variable(test_bits(i))
        end do
        call stream_close_read()
        
        ! Verify roundtrip
        do i = 1, num_values
            if (read_values(i) /= test_values(i)) then
                print *, "Variable mismatch at position", i, "expected", test_values(i), "got", read_values(i)
                error stop "Variable length roundtrip failed"
            end if
        end do
        
        print *, "PASS: Variable length roundtrip"
    end subroutine

    subroutine test_mixed_operations()
        character(len=*), parameter :: test_file = "test_mixed.dat"
        integer :: bit1, bit2, var1, var2
        integer :: read_bit1, read_bit2, read_var1, read_var2
        
        bit1 = 1
        var1 = 170  ! 10101010 in binary
        bit2 = 0
        var2 = 85   ! 01010101 in binary
        
        ! Write mixed data
        call stream_open_write(test_file)
        call stream_put_bit(bit1)
        call stream_put_variable(var1, 8)
        call stream_put_bit(bit2)
        call stream_put_variable(var2, 8)
        call stream_close_write()
        
        ! Read mixed data back
        call stream_open_read(test_file)
        read_bit1 = stream_get_bit()
        read_var1 = stream_get_variable(8)
        read_bit2 = stream_get_bit()
        read_var2 = stream_get_variable(8)
        call stream_close_read()
        
        ! Verify mixed operations
        if (read_bit1 /= bit1) error stop "Mixed: bit1 mismatch"
        if (read_var1 /= var1) error stop "Mixed: var1 mismatch"
        if (read_bit2 /= bit2) error stop "Mixed: bit2 mismatch"
        if (read_var2 /= var2) error stop "Mixed: var2 mismatch"
        
        print *, "PASS: Mixed bit/variable operations"
    end subroutine

    subroutine test_byte_alignment()
        character(len=*), parameter :: test_file = "test_alignment.dat"
        integer :: i
        integer(c_long) :: pos1, pos2
        
        ! Write 7 bits (not byte-aligned)
        call stream_open_write(test_file)
        do i = 1, 7
            call stream_put_bit(1)
        end do
        pos1 = stream_tell_write()
        call stream_flush_write()  ! Force byte alignment
        pos2 = stream_tell_write()
        call stream_close_write()
        
        ! Position should advance to next byte boundary
        if (pos2 <= pos1) then
            error stop "Flush should advance position"
        end if
        
        print *, "PASS: Byte alignment and flush"
    end subroutine

end program validate_stream_roundtrip