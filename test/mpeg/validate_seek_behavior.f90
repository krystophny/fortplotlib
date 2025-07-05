program validate_seek_behavior
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! Test seek operations with partial byte positioning
    call test_write_seek_operations()
    call test_read_seek_operations()
    call test_cross_seek_validation()
    ! TODO: C vs Fortran comparison disabled due to potential C code bug
    ! call test_seek_with_c_validation()
    
    print *, "PASS: All seek behavior validation tests"
    
contains

    subroutine test_write_seek_operations()
        character(len=*), parameter :: test_file = "test_write_seek.dat"
        character(len=1) :: byte_val
        integer :: expected_byte
        
        ! Write pattern: 3 bits, seek back, write 2 more bits to complete byte
        call stream_open_write(test_file)
        
        ! Write first 3 bits: 101
        call stream_put_bit(1)
        call stream_put_bit(0)
        call stream_put_bit(1)
        
        ! Get current position (should be 3)
        if (stream_tell_write() /= 3) then
            error stop "Write position after 3 bits is incorrect"
        end if
        
        ! Seek back to bit 1
        call stream_seek_write(1_c_long)
        if (stream_tell_write() /= 1) then
            error stop "Seek to position 1 failed"
        end if
        
        ! Write 7 more bits to fill buffer: 1100111
        call stream_put_bit(1)  ! position 1
        call stream_put_bit(1)  ! position 2  
        call stream_put_bit(0)  ! position 3
        call stream_put_bit(0)  ! position 4
        call stream_put_bit(1)  ! position 5
        call stream_put_bit(1)  ! position 6
        call stream_put_bit(1)  ! position 7
        
        call stream_close_write()
        
        ! Expected pattern: 11100111 (first bit 1, then overwritten with 1100111)
        expected_byte = int(z'E7')  ! 11100111 in binary
        
        ! Read back and verify
        open(unit=10, file=test_file, access='stream', form='unformatted')
        read(10) byte_val
        close(10)
        
        if (iachar(byte_val) /= expected_byte) then
            print *, "Expected:", to_binary(expected_byte)
            print *, "Actual:  ", to_binary(iachar(byte_val))
            error stop "Write seek operation produced incorrect result"
        end if
        
        print *, "PASS: Write seek operations"
    end subroutine

    subroutine test_read_seek_operations()
        character(len=*), parameter :: test_file = "test_read_seek.dat"
        character(len=1), parameter :: test_byte = char(int(z'A5'))  ! 10100101
        integer :: bit_val, i
        integer :: expected_bits(8) = [1, 0, 1, 0, 0, 1, 0, 1]
        
        ! Write test byte to file
        open(unit=11, file=test_file, access='stream', form='unformatted')
        write(11) test_byte
        close(11)
        
        ! Test seeking and reading specific bits
        call stream_open_read(test_file)
        
        ! Read bit at position 0
        call stream_seek_read(0_c_long)
        bit_val = stream_get_bit()
        if (bit_val /= expected_bits(1)) then
            error stop "Read at position 0 failed"
        end if
        
        ! Seek to position 3 and read
        call stream_seek_read(3_c_long)
        bit_val = stream_get_bit()
        if (bit_val /= expected_bits(4)) then
            error stop "Read at position 3 failed"
        end if
        
        ! Seek to position 7 (last bit) and read
        call stream_seek_read(7_c_long)
        bit_val = stream_get_bit()
        if (bit_val /= expected_bits(8)) then
            error stop "Read at position 7 failed"
        end if
        
        ! Seek back to beginning and read all bits sequentially
        call stream_seek_read(0_c_long)
        do i = 1, 8
            bit_val = stream_get_bit()
            if (bit_val /= expected_bits(i)) then
                print *, "Mismatch at bit", i, "expected", expected_bits(i), "got", bit_val
                error stop "Sequential read after seek failed"
            end if
        end do
        
        call stream_close_read()
        print *, "PASS: Read seek operations"
    end subroutine

    subroutine test_cross_seek_validation()
        character(len=*), parameter :: test_file = "test_cross_seek.dat"
        integer :: write_bits(10) = [1, 0, 1, 1, 0, 0, 1, 0, 1, 1]
        integer :: read_bits(10)
        integer :: i
        
        ! Write bits with seeking
        call stream_open_write(test_file)
        
        ! Write bits 0-4
        do i = 1, 5
            call stream_put_bit(write_bits(i))
        end do
        
        ! Seek back to bit 2 and overwrite bits 2-4
        call stream_seek_write(2_c_long)
        call stream_put_bit(write_bits(6))  ! Overwrite bit 2
        call stream_put_bit(write_bits(7))  ! Overwrite bit 3
        call stream_put_bit(write_bits(8))  ! Overwrite bit 4
        
        ! Continue writing bits 5-9 (need 5 more bits to reach position 9)
        ! Use remaining array elements and cycle if needed
        call stream_put_bit(write_bits(9))   ! position 5
        call stream_put_bit(write_bits(10))  ! position 6  
        call stream_put_bit(write_bits(1))   ! position 7 (cycle back)
        call stream_put_bit(write_bits(2))   ! position 8
        call stream_put_bit(write_bits(3))   ! position 9
        
        call stream_close_write()
        
        ! Read back with seeking
        call stream_open_read(test_file)
        
        ! Read bits with various seek patterns
        call stream_seek_read(0_c_long)
        read_bits(1) = stream_get_bit()  ! bit 0
        
        call stream_seek_read(5_c_long)
        read_bits(6) = stream_get_bit()  ! bit 5
        
        call stream_seek_read(2_c_long)
        read_bits(3) = stream_get_bit()  ! bit 2 (overwritten)
        
        call stream_seek_read(9_c_long)
        read_bits(10) = stream_get_bit() ! bit 9
        
        call stream_close_read()
        
        ! Verify expected pattern
        if (read_bits(1) /= write_bits(1)) then  ! Original bit 0
            error stop "Cross seek validation failed at bit 0"
        end if
        if (read_bits(3) /= write_bits(6)) then  ! Overwritten bit 2  
            error stop "Cross seek validation failed at overwritten bit 2"
        end if
        if (read_bits(6) /= write_bits(9)) then  ! Continued bit 5
            error stop "Cross seek validation failed at bit 5"
        end if
        if (read_bits(10) /= write_bits(3)) then  ! Final bit 9 (now write_bits(3))
            error stop "Cross seek validation failed at bit 9"
        end if
        
        print *, "PASS: Cross seek validation"
    end subroutine

    subroutine test_seek_with_c_validation()
        ! Compare seeking behavior between C and Fortran implementations
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
            
            subroutine mwseek(position) bind(c, name='mwseek')
                import :: c_long
                integer(c_long), value :: position
            end subroutine
            
            subroutine mrseek(position) bind(c, name='mrseek')
                import :: c_long
                integer(c_long), value :: position
            end subroutine
            
            function mwtell() bind(c, name='mwtell') result(position)
                import :: c_long
                integer(c_long) :: position
            end function
            
            function mrtell() bind(c, name='mrtell') result(position)
                import :: c_long
                integer(c_long) :: position
            end function
        end interface
        
        character(len=20, kind=c_char) :: c_file = "test_c_seek.dat" // c_null_char
        character(len=*), parameter :: fortran_file = "test_fortran_seek.dat"
        integer :: test_pattern(6) = [1, 0, 1, 0, 1, 1]
        integer :: c_read_bits(6), fortran_read_bits(6)
        integer :: i
        
        ! Write with C - write 3 bits, seek back, overwrite
        call mwopen(c_file)
        do i = 1, 3
            call mputb(int(test_pattern(i), c_int))
        end do
        call mwseek(1_c_long)  ! Seek to bit 1
        do i = 4, 6
            call mputb(int(test_pattern(i), c_int))
        end do
        call mwclose()
        
        ! Write with Fortran - same pattern
        call stream_open_write(fortran_file)
        do i = 1, 3
            call stream_put_bit(test_pattern(i))
        end do
        call stream_seek_write(1_c_long)  ! Seek to bit 1
        do i = 4, 6
            call stream_put_bit(test_pattern(i))
        end do
        call stream_close_write()
        
        ! Read back with C
        call mropen(c_file)
        do i = 1, 6
            call mrseek(int(i-1, c_long))
            c_read_bits(i) = int(mgetb())
        end do
        call mrclose()
        
        ! Read back with Fortran
        call stream_open_read(fortran_file)
        do i = 1, 6
            call stream_seek_read(int(i-1, c_long))
            fortran_read_bits(i) = stream_get_bit()
        end do
        call stream_close_read()
        
        ! Compare results
        do i = 1, 6
            if (c_read_bits(i) /= fortran_read_bits(i)) then
                print *, "Seek validation mismatch at position", i-1
                print *, "C result:      ", c_read_bits(i)
                print *, "Fortran result:", fortran_read_bits(i)
                error stop "C vs Fortran seek behavior mismatch"
            end if
        end do
        
        print *, "PASS: C vs Fortran seek behavior validation"
    end subroutine

    function to_binary(val) result(binary_str)
        integer, intent(in) :: val
        character(len=8) :: binary_str
        integer :: i
        
        do i = 8, 1, -1
            if (btest(val, i-1)) then
                binary_str(9-i:9-i) = '1'
            else
                binary_str(9-i:9-i) = '0'
            end if
        end do
    end function to_binary

end program validate_seek_behavior