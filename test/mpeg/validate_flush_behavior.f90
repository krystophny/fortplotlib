program validate_flush_behavior
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! Test both flush behaviors against C implementation
    call test_ones_flush_compatibility()
    call test_zeros_flush_compatibility()
    call test_partial_byte_flush_patterns()
    
    print *, "PASS: All flush behavior validation tests"
    
contains

    subroutine test_ones_flush_compatibility()
        ! C interface declarations
        interface
            subroutine mwopen(filename) bind(c, name='mwopen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
            
            subroutine mputb(bit) bind(c, name='mputb')
                import :: c_int
                integer(c_int), value :: bit
            end subroutine
        end interface
        
        character(len=20, kind=c_char) :: c_file = "test_c_flush.dat" // c_null_char
        character(len=*), parameter :: fortran_file = "test_fortran_flush.dat"
        integer, parameter :: num_bits = 5  ! Partial byte to test flush
        integer :: test_bits(num_bits) = [1, 0, 1, 1, 0]
        character(len=1) :: c_byte, fortran_byte
        integer :: i
        
        ! Write partial byte with C implementation and let mwclose() flush
        call mwopen(c_file)
        do i = 1, num_bits
            call mputb(int(test_bits(i), c_int))
        end do
        call mwclose()  ! This should flush with 1s
        
        ! Write same partial byte with Fortran and let close flush
        call stream_open_write(fortran_file)
        do i = 1, num_bits
            call stream_put_bit(test_bits(i))
        end do
        call stream_close_write()  ! This should also flush with 1s
        
        ! Read back both files and compare
        open(unit=10, file="test_c_flush.dat", access='stream', form='unformatted')
        read(10) c_byte
        close(10)
        
        open(unit=11, file="test_fortran_flush.dat", access='stream', form='unformatted')
        read(11) fortran_byte
        close(11)
        
        if (c_byte /= fortran_byte) then
            print *, "C byte:      ", iachar(c_byte), " (binary: ", to_binary(iachar(c_byte)), ")"
            print *, "Fortran byte:", iachar(fortran_byte), " (binary: ", to_binary(iachar(fortran_byte)), ")"
            error stop "C vs Fortran ones flush mismatch"
        end if
        
        print *, "PASS: C vs Fortran ones flush behavior matches"
        print *, "  Input bits: 10110 -> Output byte: ", to_binary(iachar(c_byte))
    end subroutine

    subroutine test_zeros_flush_compatibility()
        ! C interface for zeroflush
        interface
            subroutine mwopen(filename) bind(c, name='mwopen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine zeroflush() bind(c, name='zeroflush')
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
            
            subroutine mputb(bit) bind(c, name='mputb')
                import :: c_int
                integer(c_int), value :: bit
            end subroutine
        end interface
        
        character(len=22, kind=c_char) :: c_file = "test_c_zeroflush.dat" // c_null_char
        character(len=*), parameter :: fortran_file = "test_fortran_zeroflush.dat"
        integer, parameter :: num_bits = 3  ! Partial byte to test zero flush
        integer :: test_bits(num_bits) = [1, 0, 1]
        character(len=1) :: c_byte, fortran_byte
        integer :: i
        
        ! Write partial byte with C implementation and use zeroflush
        call mwopen(c_file)
        do i = 1, num_bits
            call mputb(int(test_bits(i), c_int))
        end do
        call zeroflush()  ! This should flush with 0s
        call mwclose()
        
        ! Write same partial byte with Fortran and use zero flush
        call stream_open_write(fortran_file)
        do i = 1, num_bits
            call stream_put_bit(test_bits(i))
        end do
        call stream_flush_write_zeros()  ! This should flush with 0s
        call stream_close_write()
        
        ! Read back both files and compare
        open(unit=12, file="test_c_zeroflush.dat", access='stream', form='unformatted')
        read(12) c_byte
        close(12)
        
        open(unit=13, file="test_fortran_zeroflush.dat", access='stream', form='unformatted')
        read(13) fortran_byte
        close(13)
        
        if (c_byte /= fortran_byte) then
            print *, "C byte:      ", iachar(c_byte), " (binary: ", to_binary(iachar(c_byte)), ")"
            print *, "Fortran byte:", iachar(fortran_byte), " (binary: ", to_binary(iachar(fortran_byte)), ")"
            error stop "C vs Fortran zeros flush mismatch"
        end if
        
        print *, "PASS: C vs Fortran zeros flush behavior matches"
        print *, "  Input bits: 101 -> Output byte: ", to_binary(iachar(c_byte))
    end subroutine

    subroutine test_partial_byte_flush_patterns()
        ! Test different partial byte patterns to ensure flush behavior is consistent
        integer, parameter :: num_patterns = 7
        integer :: pattern_sizes(num_patterns) = [1, 2, 3, 4, 5, 6, 7]
        integer :: patterns(num_patterns, 7) = reshape([ &
            1, 0, 0, 0, 0, 0, 0, &  ! 1 bit
            1, 1, 0, 0, 0, 0, 0, &  ! 2 bits
            0, 1, 0, 0, 0, 0, 0, &  ! 3 bits
            1, 0, 1, 0, 0, 0, 0, &  ! 4 bits
            0, 0, 1, 1, 1, 0, 0, &  ! 5 bits
            1, 1, 0, 0, 1, 1, 0, &  ! 6 bits
            0, 1, 0, 1, 0, 1, 0  &  ! 7 bits
        ], [num_patterns, 7])
        
        character(len=30) :: c_filename, fortran_filename
        character(len=1) :: c_byte, fortran_byte
        integer :: i, j
        
        interface
            subroutine mwopen(filename) bind(c, name='mwopen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
            
            subroutine mputb(bit) bind(c, name='mputb')
                import :: c_int
                integer(c_int), value :: bit
            end subroutine
        end interface
        
        do i = 1, num_patterns
            write(c_filename, '("test_c_pattern_", I0, ".dat", A1)') i, c_null_char
            write(fortran_filename, '("test_fortran_pattern_", I0, ".dat")') i
            
            ! Test with C
            call mwopen(c_filename)
            do j = 1, pattern_sizes(i)
                call mputb(int(patterns(i, j), c_int))
            end do
            call mwclose()
            
            ! Test with Fortran  
            call stream_open_write(fortran_filename)
            do j = 1, pattern_sizes(i)
                call stream_put_bit(patterns(i, j))
            end do
            call stream_close_write()
            
            ! Compare results
            open(unit=20, file=c_filename, access='stream', form='unformatted')
            read(20) c_byte
            close(20)
            
            open(unit=21, file=fortran_filename, access='stream', form='unformatted')
            read(21) fortran_byte
            close(21)
            
            if (c_byte /= fortran_byte) then
                print *, "Pattern", i, "mismatch:"
                print *, "  Size:", pattern_sizes(i)
                print *, "  Bits:", patterns(i, 1:pattern_sizes(i))
                print *, "  C byte:      ", iachar(c_byte), " (binary: ", to_binary(iachar(c_byte)), ")"
                print *, "  Fortran byte:", iachar(fortran_byte), " (binary: ", to_binary(iachar(fortran_byte)), ")"
                error stop "Pattern flush behavior mismatch"
            end if
        end do
        
        print *, "PASS: All partial byte flush patterns match between C and Fortran"
    end subroutine

    function to_binary(val) result(binary_str)
        integer, intent(in) :: val
        character(len=8) :: binary_str
        integer :: i, bit_val
        
        bit_val = val
        do i = 8, 1, -1
            if (btest(bit_val, i-1)) then
                binary_str(9-i:9-i) = '1'
            else
                binary_str(9-i:9-i) = '0'
            end if
        end do
    end function to_binary

end program validate_flush_behavior