program validate_c_vs_fortran_stream
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! Compare C reference implementation with Fortran implementation
    call test_bit_operations_comparison()
    call test_variable_operations_comparison()
    call test_file_compatibility()
    
    print *, "PASS: C vs Fortran stream operations validation"
    
contains

    subroutine test_bit_operations_comparison()
        ! C interface declarations
        interface
            subroutine mwopen(filename) bind(c, name='mwopen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
            
            subroutine mropen(filename) bind(c, name='mropen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mrclose() bind(c, name='mrclose')
            end subroutine
            
            subroutine mputb(bit) bind(c, name='mputb')
                import :: c_int
                integer(c_int), value :: bit
            end subroutine
            
            function mgetb() bind(c, name='mgetb') result(bit)
                import :: c_int
                integer(c_int) :: bit
            end function
        end interface
        
        character(len=20, kind=c_char) :: c_file = "test_c_bits.dat" // c_null_char
        character(len=*), parameter :: fortran_file = "test_fortran_bits.dat"
        integer, parameter :: num_bits = 8
        integer :: test_bits(num_bits) = [1, 0, 1, 1, 0, 1, 0, 1]
        integer :: c_read_bits(num_bits), fortran_read_bits(num_bits)
        integer :: i
        
        ! Write with C implementation
        call mwopen(c_file)
        do i = 1, num_bits
            call mputb(int(test_bits(i), c_int))
        end do
        call mwclose()
        
        ! Write with Fortran implementation
        call stream_open_write(fortran_file)
        do i = 1, num_bits
            call stream_put_bit(test_bits(i))
        end do
        call stream_close_write()
        
        ! Read back with C implementation
        call mropen(c_file)
        do i = 1, num_bits
            c_read_bits(i) = int(mgetb())
        end do
        call mrclose()
        
        ! Read back with Fortran implementation
        call stream_open_read(fortran_file)
        do i = 1, num_bits
            fortran_read_bits(i) = stream_get_bit()
        end do
        call stream_close_read()
        
        ! Compare results
        do i = 1, num_bits
            if (c_read_bits(i) /= test_bits(i)) then
                error stop "C bit operation failed"
            end if
            if (fortran_read_bits(i) /= test_bits(i)) then
                error stop "Fortran bit operation failed"
            end if
            if (c_read_bits(i) /= fortran_read_bits(i)) then
                error stop "C vs Fortran bit operation mismatch"
            end if
        end do
        
        print *, "PASS: C vs Fortran bit operations match"
    end subroutine

    subroutine test_variable_operations_comparison()
        ! C interface declarations
        interface
            subroutine mwopen(filename) bind(c, name='mwopen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
            
            subroutine mropen(filename) bind(c, name='mropen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mrclose() bind(c, name='mrclose')
            end subroutine
            
            subroutine mputv(bits, value) bind(c, name='mputv')
                import :: c_int
                integer(c_int), value :: bits, value
            end subroutine
            
            function mgetv(bits) bind(c, name='mgetv') result(value)
                import :: c_int
                integer(c_int), value :: bits
                integer(c_int) :: value
            end function
        end interface
        
        character(len=20, kind=c_char) :: c_file = "test_c_vars.dat" // c_null_char
        character(len=*), parameter :: fortran_file = "test_fortran_vars.dat"
        integer, parameter :: num_values = 3
        integer :: test_values(num_values) = [42, 255, 15]
        integer :: test_bits(num_values) = [8, 8, 4]
        integer :: c_read_values(num_values), fortran_read_values(num_values)
        integer :: i
        
        ! Write with C implementation
        call mwopen(c_file)
        do i = 1, num_values
            call mputv(int(test_bits(i), c_int), int(test_values(i), c_int))
        end do
        call mwclose()
        
        ! Write with Fortran implementation
        call stream_open_write(fortran_file)
        do i = 1, num_values
            call stream_put_variable(test_values(i), test_bits(i))
        end do
        call stream_close_write()
        
        ! Read back with C implementation
        call mropen(c_file)
        do i = 1, num_values
            c_read_values(i) = int(mgetv(int(test_bits(i), c_int)))
        end do
        call mrclose()
        
        ! Read back with Fortran implementation
        call stream_open_read(fortran_file)
        do i = 1, num_values
            fortran_read_values(i) = stream_get_variable(test_bits(i))
        end do
        call stream_close_read()
        
        ! Compare results
        do i = 1, num_values
            if (c_read_values(i) /= test_values(i)) then
                error stop "C variable operation failed"
            end if
            if (fortran_read_values(i) /= test_values(i)) then
                error stop "Fortran variable operation failed"
            end if
            if (c_read_values(i) /= fortran_read_values(i)) then
                error stop "C vs Fortran variable operation mismatch"
            end if
        end do
        
        print *, "PASS: C vs Fortran variable operations match"
    end subroutine

    subroutine test_file_compatibility()
        ! Test cross-compatibility: write with C, read with Fortran and vice versa
        interface
            subroutine mwopen(filename) bind(c, name='mwopen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
            
            subroutine mropen(filename) bind(c, name='mropen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mrclose() bind(c, name='mrclose')
            end subroutine
            
            subroutine mputv(bits, value) bind(c, name='mputv')
                import :: c_int
                integer(c_int), value :: bits, value
            end subroutine
            
            function mgetv(bits) bind(c, name='mgetv') result(value)
                import :: c_int
                integer(c_int), value :: bits
                integer(c_int) :: value
            end function
        end interface
        
        character(len=20, kind=c_char) :: cross_file = "test_cross.dat" // c_null_char
        integer, parameter :: test_value = 170  ! 10101010
        integer, parameter :: test_bits = 8
        integer :: read_value
        
        ! Write with C, read with Fortran
        call mwopen(cross_file)
        call mputv(int(test_bits, c_int), int(test_value, c_int))
        call mwclose()
        
        call stream_open_read("test_cross.dat")
        read_value = stream_get_variable(test_bits)
        call stream_close_read()
        
        if (read_value /= test_value) then
            error stop "C write -> Fortran read failed"
        end if
        
        ! Write with Fortran, read with C
        call stream_open_write("test_cross.dat")
        call stream_put_variable(test_value, test_bits)
        call stream_close_write()
        
        call mropen(cross_file)
        read_value = int(mgetv(int(test_bits, c_int)))
        call mrclose()
        
        if (read_value /= test_value) then
            error stop "Fortran write -> C read failed"
        end if
        
        print *, "PASS: C-Fortran file format compatibility"
    end subroutine

end program validate_c_vs_fortran_stream