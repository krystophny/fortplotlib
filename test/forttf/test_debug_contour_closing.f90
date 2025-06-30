program test_debug_contour_closing
    !! Debug which contours are being closed
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_outline
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call debug_contour_closing()

contains

    subroutine debug_contour_closing()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint = 36  ! '$'
        
        write(*,*) '=== DEBUGGING CONTOUR CLOSING ===', new_line('a'), &
                   'Character: $ (codepoint=36)', new_line('a'), &
                   'Goal: See which contours are closed by selective logic', new_line('a')
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path), new_line('a')
        
        ! Add debug output to forttf_outline conversion to see contour processing
        block
            type(ttf_vertex_t), allocatable :: vertices(:)
            integer :: num_vertices
            
            num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint, vertices)
            
            write(*,'(A,I0,A)') 'ForTTF extracted ', num_vertices, ' vertices'
            write(*,*) 'Expected: exactly 39 vertices'
            
            if (num_vertices /= 39) then
                write(*,*) 'ERROR: Vertex count mismatch!'
                write(*,*) 'The selective contour closing logic needs adjustment'
                write(*,*) 'Check forttf_outline.f90 debug output for contour closing decisions'
            else
                write(*,*) 'SUCCESS: Vertex count matches STB!'
            end if
            
            deallocate(vertices)
        end block
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine debug_contour_closing

end program test_debug_contour_closing