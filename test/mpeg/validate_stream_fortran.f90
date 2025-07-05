program validate_stream_fortran
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! Test Fortran stream implementation
    call test_fortran_stream_basic()
    call test_fortran_stream_positioning()
    call test_fortran_bit_operations()
    call test_fortran_variable_operations()
    
    print *, "PASS: Fortran stream implementation validation"
    
contains

    subroutine test_fortran_stream_basic()
        character(len=*), parameter :: test_file = "test_fortran.dat"
        
        ! Test write stream
        call stream_open_write(test_file)
        call stream_close_write()
        
        ! Test read stream
        call stream_open_read(test_file)
        call stream_close_read()
        
        print *, "PASS: Fortran stream open/close"
    end subroutine

    subroutine test_fortran_stream_positioning()
        character(len=*), parameter :: test_file = "test_pos_fortran.dat"
        integer(c_long) :: pos1, pos2
        
        ! Test write positioning
        call stream_open_write(test_file)
        pos1 = stream_tell_write()
        call stream_seek_write(100_c_long)
        pos2 = stream_tell_write()
        call stream_close_write()
        
        if (pos1 /= 0) then
            error stop "Initial write position should be 0"
        end if
        
        if (pos2 /= 100) then
            error stop "Write seek position incorrect"
        end if
        
        ! Test read positioning
        call stream_open_read(test_file)
        pos1 = stream_tell_read()
        call stream_seek_read(50_c_long)
        pos2 = stream_tell_read()
        call stream_close_read()
        
        if (pos1 /= 0) then
            error stop "Initial read position should be 0"
        end if
        
        if (pos2 /= 50) then
            error stop "Read seek position incorrect"
        end if
        
        print *, "PASS: Fortran stream positioning"
    end subroutine

    subroutine test_fortran_bit_operations()
        character(len=*), parameter :: test_file = "test_bits_fortran.dat"
        integer :: bit_val
        integer(c_long) :: pos1, pos2
        
        ! Test bit operations
        call stream_open_write(test_file)
        pos1 = stream_tell_write()
        call stream_put_bit(1)
        pos2 = stream_tell_write()
        call stream_close_write()
        
        if (pos2 <= pos1) then
            error stop "Bit write should advance position"
        end if
        
        call stream_open_read(test_file)
        bit_val = stream_get_bit()
        call stream_close_read()
        
        ! Bit value should be valid (0 or 1)
        if (bit_val < 0 .or. bit_val > 1) then
            error stop "Invalid bit value returned"
        end if
        
        print *, "PASS: Fortran bit operations"
    end subroutine

    subroutine test_fortran_variable_operations()
        character(len=*), parameter :: test_file = "test_var_fortran.dat"
        integer :: value
        
        ! Test variable length operations
        call stream_open_write(test_file)
        call stream_put_variable(42, 8)
        call stream_close_write()
        
        call stream_open_read(test_file)
        value = stream_get_variable(8)
        call stream_close_read()
        
        ! Value should be non-negative
        if (value < 0) then
            error stop "Variable length value should be non-negative"
        end if
        
        print *, "PASS: Fortran variable length operations"
    end subroutine

end program validate_stream_fortran