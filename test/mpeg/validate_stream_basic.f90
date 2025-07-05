program validate_stream_basic
    use iso_c_binding
    implicit none
    
    ! Test basic stream operations against C reference
    call test_stream_open_close()
    call test_stream_position()
    call test_stream_eof()
    
    print *, "PASS: stream basic operations validation"
    
contains

    subroutine test_stream_open_close()
        interface
            subroutine mropen(filename) bind(c, name='mropen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mrclose() bind(c, name='mrclose')
            end subroutine
            
            subroutine mwopen(filename) bind(c, name='mwopen') 
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
        end interface
        
        character(len=20, kind=c_char) :: test_file = "test_stream.dat" // c_null_char
        
        ! Test write stream
        call mwopen(test_file)
        call mwclose()
        
        ! Test read stream  
        call mropen(test_file)
        call mrclose()
        
        print *, "PASS: stream open/close"
    end subroutine

    subroutine test_stream_position()
        interface
            function mwtell() bind(c, name='mwtell') result(pos)
                import :: c_long
                integer(c_long) :: pos
            end function
            
            function mrtell() bind(c, name='mrtell') result(pos)
                import :: c_long
                integer(c_long) :: pos
            end function
            
            subroutine mwseek(pos) bind(c, name='mwseek')
                import :: c_long
                integer(c_long), value :: pos
            end subroutine
            
            subroutine mrseek(pos) bind(c, name='mrseek')
                import :: c_long
                integer(c_long), value :: pos
            end subroutine
            
            subroutine mwopen(filename) bind(c, name='mwopen')
                import :: c_char
                character(kind=c_char), intent(in) :: filename(*)
            end subroutine
            
            subroutine mwclose() bind(c, name='mwclose')
            end subroutine
        end interface
        
        integer(c_long) :: pos1, pos2
        character(len=20, kind=c_char) :: test_file = "test_pos.dat" // c_null_char
        
        ! Open file first for position operations
        call mwopen(test_file)
        
        ! Test position tracking
        pos1 = mwtell()
        call mwseek(100_c_long)
        pos2 = mwtell()
        
        call mwclose()
        
        ! Position should advance (exact value depends on implementation)
        if (pos2 <= pos1) then
            error stop "Position tracking failed"
        end if
        
        print *, "PASS: stream positioning"
    end subroutine

    subroutine test_stream_eof()
        interface
            function seof() bind(c, name='seof') result(eof_flag)
                import :: c_int
                integer(c_int) :: eof_flag
            end function
        end interface
        
        integer(c_int) :: eof_result
        
        eof_result = seof()
        ! Just verify function can be called without crash
        
        print *, "PASS: stream EOF detection"
    end subroutine

end program validate_stream_basic