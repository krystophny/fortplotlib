program test_forttf_glyph_vertex_comparison
    !! Compare glyph vertices between STB and ForTTF for character '$'
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_outline
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call compare_glyph_vertices()

contains

    subroutine compare_glyph_vertices()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        ! Test parameters
        integer, parameter :: codepoint = 36  ! '$'
        real(wp), parameter :: scale = 0.02_wp
        
        write(*,*) '=== COMPARING GLYPH VERTICES: STB vs ForTTF ==='
        write(*,*) 'Character: $ (codepoint=36)'
        write(*,*) 'Goal: Verify if STB and ForTTF extract same vertices from font'
        write(*,*)
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*)
        
        ! Get STB vertices
        write(*,*) '=== STB VERTICES ==='
        block
            type(c_ptr) :: vertices_ptr
            integer :: num_vertices
            
            vertices_ptr = stb_get_codepoint_shape(stb_font, codepoint, num_vertices)
            
            if (c_associated(vertices_ptr)) then
                write(*,'(A,I0,A)') 'STB extracted ', num_vertices, ' vertices'
                ! Note: STB vertex structure is different, we'd need a wrapper to extract details
                call stb_free_shape(vertices_ptr)
            else
                write(*,*) 'STB: Failed to get vertices'
            end if
        end block
        write(*,*)
        
        ! Get ForTTF vertices  
        write(*,*) '=== ForTTF VERTICES ==='
        block
            type(ttf_vertex_t), allocatable :: vertices(:)
            integer :: num_vertices, i
            
            num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint, vertices)
            if (num_vertices > 0) then
                write(*,'(A,I0,A)') 'ForTTF extracted ', num_vertices, ' vertices'
                write(*,*)
                
                ! Show first 10 vertices for comparison
                write(*,*) 'First 10 ForTTF vertices:'
                do i = 1, min(10, num_vertices)
                    write(*,'(A,I2,A,I0,A,I0,A,I0,A,I0,A,I0)') 'Vertex ', i, &
                        ': type=', vertices(i)%type, ' x=', vertices(i)%x, ' y=', vertices(i)%y, &
                        ' cx=', vertices(i)%cx, ' cy=', vertices(i)%cy
                end do
                
                if (num_vertices > 10) then
                    write(*,'(A,I0,A)') '... and ', num_vertices - 10, ' more vertices'
                end if
                
                deallocate(vertices)
            else
                write(*,*) 'ForTTF: Failed to get vertices'
            end if
        end block
        
        write(*,*)
        write(*,*) 'ANALYSIS:'
        write(*,*) '1. Do STB and ForTTF extract the same number of vertices?'
        write(*,*) '2. Are the vertex coordinates identical?'
        write(*,*) '3. Are the vertex types (move, line, curve) identical?'
        write(*,*)
        write(*,*) 'If vertices differ, that could explain why edge building differs'
        write(*,*) 'and why STB produces k≈+0.447 while ForTTF produces k≈-1.175'
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine compare_glyph_vertices

end program test_forttf_glyph_vertex_comparison