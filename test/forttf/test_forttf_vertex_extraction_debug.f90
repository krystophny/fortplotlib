program test_forttf_vertex_extraction_debug
    !! Debug ForTTF vertex extraction for character '$' to understand extra vertices
    use test_forttf_utils
    use fortplot_stb_truetype  ! For stb_fontinfo_t
    use forttf
    use forttf_outline
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call debug_vertex_extraction()

contains

    subroutine debug_vertex_extraction()
        type(stb_fontinfo_t) :: stb_font  ! Dummy declaration for find_and_init_test_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        ! Test parameters
        integer, parameter :: codepoint = 36  ! '$'
        
        write(*,*) '=== DEBUGGING ForTTF VERTEX EXTRACTION ==='
        write(*,*) 'Character: $ (codepoint=36)'
        write(*,*) 'Goal: Understand why ForTTF extracts 41 vertices vs STB 39'
        write(*,*)
        
        ! Initialize only ForTTF font (don't need STB for this test)
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*)
        
        ! Get ForTTF vertices with detailed debug
        write(*,*) '=== DETAILED ForTTF VERTEX EXTRACTION ==='
        block
            type(ttf_vertex_t), allocatable :: vertices(:)
            integer :: num_vertices, i
            
            ! This will show debug output from glyph parsing
            num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint, vertices)
            
            if (num_vertices > 0) then
                write(*,'(A,I0,A)') 'ForTTF extracted ', num_vertices, ' vertices (STB extracts 39)'
                write(*,*)
                
                ! Show ALL vertices for detailed analysis
                write(*,*) 'ALL ForTTF vertices:'
                do i = 1, num_vertices
                    write(*,'(A,I2,A,I0,A,I0,A,I0,A,I0,A,I0)') 'Vertex ', i, &
                        ': type=', vertices(i)%type, ' x=', vertices(i)%x, ' y=', vertices(i)%y, &
                        ' cx=', vertices(i)%cx, ' cy=', vertices(i)%cy
                end do
                
                write(*,*)
                write(*,*) 'ANALYSIS:'
                write(*,'(A,I0,A)') 'ForTTF has ', num_vertices - 39, ' extra vertices compared to STB'
                write(*,*) 'Look for duplicate vertices or incorrect parsing:'
                write(*,*) '1. Are there duplicate move-to commands?'
                write(*,*) '2. Are curves being split incorrectly?'
                write(*,*) '3. Are contour endings being handled wrong?'
                write(*,*) '4. Are there phantom vertices added?'
                
                deallocate(vertices)
            else
                write(*,*) 'ForTTF: Failed to get vertices'
            end if
        end block
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine debug_vertex_extraction

end program test_forttf_vertex_extraction_debug