program test_stb_vertex_extraction
    !! Extract actual STB vertices to compare with ForTTF step by step
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_outline
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call extract_stb_vertices()

contains

    subroutine extract_stb_vertices()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint = 36  ! '$'
        
        write(*,*) '=== EXTRACTING STB VERTICES ===', new_line('a'), &
                   'Character: $ (codepoint=36)', new_line('a'), &
                   'Goal: Get actual STB vertices to compare with ForTTF', new_line('a')
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path), new_line('a')
        
        ! Extract STB vertices
        write(*,*) '=== STB VERTICES ==='
        block
            type(c_ptr) :: stb_vertices
            integer :: num_stb_vertices
            
            stb_vertices = stb_get_codepoint_shape(stb_font, codepoint, num_stb_vertices)
            write(*,'(A,I0,A)') 'STB extracted ', num_stb_vertices, ' vertices'
            
            if (c_associated(stb_vertices) .and. num_stb_vertices > 0) then
                call print_stb_vertices(stb_vertices, num_stb_vertices)
                call stb_free_shape(stb_vertices)
            end if
        end block
        
        write(*,*) new_line('a'), '=== ForTTF VERTICES ==='
        block
            type(ttf_vertex_t), allocatable :: vertices(:)
            integer :: num_vertices, i
            
            num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint, vertices)
            write(*,'(A,I0,A)') 'ForTTF extracted ', num_vertices, ' vertices'
            
            if (num_vertices > 0) then
                do i = 1, min(num_vertices, 50)  ! Show first 50 vertices
                    write(*,'(A,I2,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0)') &
                        'ForTTF vertex ', i, ': type=', vertices(i)%type, &
                        ' x=', vertices(i)%x, ' y=', vertices(i)%y, &
                        ' cx=', vertices(i)%cx, ' cy=', vertices(i)%cy
                end do
                deallocate(vertices)
            end if
        end block
        
        write(*,*) new_line('a'), 'ANALYSIS:'
        write(*,*) 'Compare STB and ForTTF vertices side by side'
        write(*,*) 'Look for differences in:'
        write(*,*) '1. Vertex count (STB=39, ForTTF=41)'
        write(*,*) '2. Vertex types (move=1, line=2, curve=3)'
        write(*,*) '3. Coordinates (x,y,cx,cy)'
        write(*,*) '4. Which vertices are missing or extra in ForTTF'
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine extract_stb_vertices
    
    subroutine print_stb_vertices(vertices_ptr, num_vertices)
        type(c_ptr), intent(in) :: vertices_ptr
        integer, intent(in) :: num_vertices
        
        type :: stb_vertex_t
            integer(c_short) :: x, y, cx, cy
            integer(c_signed_char) :: type
        end type stb_vertex_t
        
        type(stb_vertex_t), pointer :: vertices(:)
        integer :: i
        
        call c_f_pointer(vertices_ptr, vertices, [num_vertices])
        
        do i = 1, min(num_vertices, 50)  ! Show first 50 vertices
            write(*,'(A,I2,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0)') &
                'STB vertex ', i, ': type=', int(vertices(i)%type), &
                ' x=', int(vertices(i)%x), ' y=', int(vertices(i)%y), &
                ' cx=', int(vertices(i)%cx), ' cy=', int(vertices(i)%cy)
        end do
        
    end subroutine print_stb_vertices

end program test_stb_vertex_extraction