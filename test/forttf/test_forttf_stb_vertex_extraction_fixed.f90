program test_forttf_stb_vertex_extraction_fixed
    !! Extract actual STB vertices with correct structure alignment
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
        
        write(*,*) '=== EXTRACTING STB VERTICES WITH CORRECT ALIGNMENT ===', new_line('a'), &
                   'Character: $ (codepoint=36)', new_line('a'), &
                   'Goal: Get actual STB vertices with proper structure alignment', new_line('a')
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path), new_line('a')
        
        ! Extract STB vertices
        write(*,*) '=== STB VERTICES (FIXED ALIGNMENT) ==='
        block
            type(c_ptr) :: stb_vertices
            integer :: num_stb_vertices
            
            stb_vertices = stb_get_codepoint_shape(stb_font, codepoint, num_stb_vertices)
            write(*,'(A,I0,A)') 'STB extracted ', num_stb_vertices, ' vertices'
            
            if (c_associated(stb_vertices) .and. num_stb_vertices > 0) then
                call print_stb_vertices_fixed(stb_vertices, num_stb_vertices)
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
        write(*,*) 'The C wrapper converts STB vertices to int (4 bytes) per field'
        write(*,*) 'This matches the fortran_vertex_t structure in the C code'
        write(*,*) 'We need to use integer(c_int) in Fortran to match'
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine extract_stb_vertices
    
    subroutine print_stb_vertices_fixed(vertices_ptr, num_vertices)
        type(c_ptr), intent(in) :: vertices_ptr
        integer, intent(in) :: num_vertices
        
        ! Match the C wrapper's fortran_vertex_t structure:
        ! typedef struct {
        !     int x, y, cx, cy, cx1, cy1;  /* Use int to match Fortran integer */
        !     int type;                    /* Use int to match Fortran integer */
        ! } fortran_vertex_t;
        type :: fortran_vertex_t
            integer(c_int) :: x, y, cx, cy, cx1, cy1
            integer(c_int) :: type
        end type fortran_vertex_t
        
        type(fortran_vertex_t), pointer :: vertices(:)
        integer :: i
        
        call c_f_pointer(vertices_ptr, vertices, [num_vertices])
        
        do i = 1, min(num_vertices, 50)  ! Show first 50 vertices
            write(*,'(A,I2,A,I0,A,I0,A,I0,A,I0,A,I0)') &
                'STB vertex ', i, ': type=', vertices(i)%type, &
                ' x=', vertices(i)%x, ' y=', vertices(i)%y, &
                ' cx=', vertices(i)%cx, ' cy=', vertices(i)%cy
        end do
        
    end subroutine print_stb_vertices_fixed

end program test_forttf_stb_vertex_extraction_fixed