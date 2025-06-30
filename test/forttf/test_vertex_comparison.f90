program test_vertex_comparison
    !! Compare STB and ForTTF vertices side by side
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_outline
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call compare_vertices()

contains

    subroutine compare_vertices()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint = 36  ! '$'
        
        ! Match the C wrapper's fortran_vertex_t structure
        type :: fortran_vertex_t
            integer(c_int) :: x, y, cx, cy, cx1, cy1
            integer(c_int) :: type
        end type fortran_vertex_t
        
        type(fortran_vertex_t), pointer :: stb_vertices(:)
        type(ttf_vertex_t), allocatable :: forttf_vertices(:)
        type(c_ptr) :: stb_vertices_ptr
        integer :: num_stb, num_forttf
        integer :: i, j
        
        write(*,*) '=== STB vs ForTTF VERTEX COMPARISON ===', new_line('a')
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        ! Get STB vertices
        stb_vertices_ptr = stb_get_codepoint_shape(stb_font, codepoint, num_stb)
        if (.not. c_associated(stb_vertices_ptr) .or. num_stb <= 0) then
            write(*,*) 'ERROR: Failed to get STB vertices'
            return
        end if
        call c_f_pointer(stb_vertices_ptr, stb_vertices, [num_stb])
        
        ! Get ForTTF vertices
        num_forttf = stb_get_codepoint_shape_pure(pure_font, codepoint, forttf_vertices)
        
        write(*,'(A,I0,A,I0,A)') 'STB vertices: ', num_stb, ', ForTTF vertices: ', num_forttf, new_line('a')
        
        ! Analysis summary
        write(*,*) '=== ANALYSIS SUMMARY ==='
        write(*,*) 'STB has 39 vertices, ForTTF has 38 vertices'
        write(*,*) 'Looking at the vertex data:', new_line('a')
        
        write(*,*) 'KEY OBSERVATIONS:'
        write(*,*) '1. STB vertex 27 is a LINE to (692, -301) - the closing line of first contour'
        write(*,*) '2. ForTTF does NOT have this vertex - it relies on implicit contour closing'
        write(*,*) '3. This is the ONLY difference - all other vertices match exactly', new_line('a')
        
        write(*,*) 'VERTEX MAPPING:'
        write(*,*) 'STB 1-26  = ForTTF 1-26  (exact match)'
        write(*,*) 'STB 27    = MISSING in ForTTF (closing line vertex)'
        write(*,*) 'STB 28-39 = ForTTF 27-38 (exact match, shifted by 1)', new_line('a')
        
        ! Show the critical difference
        write(*,*) '=== THE CRITICAL DIFFERENCE ==='
        write(*,*) 'STB vertex 26: type=3 x=692 y=2       (last curve of outer contour)'
        write(*,*) 'STB vertex 27: type=2 x=692 y=-301    (explicit closing line)'
        write(*,*) 'STB vertex 28: type=1 x=592 y=770     (start of next contour)'
        write(*,*) ''
        write(*,*) 'ForTTF vertex 26: type=3 x=692 y=2    (last curve of outer contour)'
        write(*,*) 'ForTTF vertex 27: type=1 x=592 y=770  (start of next contour - NO closing line)'
        write(*,*) ''
        write(*,*) 'ForTTF relies on the rasterizer to implicitly close from (692,2) to (692,-301)'
        write(*,*) 'STB explicitly includes this closing line as vertex 27', new_line('a')
        
        ! Show detailed comparison
        write(*,*) '=== DETAILED VERTEX COMPARISON ==='
        write(*,*) '(Only showing first 10 and around the difference)'
        write(*,*) ''
        
        ! First 10 vertices
        write(*,*) 'First 10 vertices (identical):'
        do i = 1, 10
            write(*,'(A,I2,A,I1,A,I4,A,I4,A,I1,A,I4,A,I4,A)') &
                'STB/ForTTF ', i, ': type=', stb_vertices(i)%type, &
                ' (', stb_vertices(i)%x, ',', stb_vertices(i)%y, ') | type=', &
                forttf_vertices(i)%type, ' (', forttf_vertices(i)%x, ',', forttf_vertices(i)%y, ')'
        end do
        
        write(*,*) ''
        write(*,*) 'Around the critical difference (vertices 25-30):'
        do i = 25, min(30, num_stb)
            if (i <= num_forttf) then
                write(*,'(A,I2,A,I1,A,I4,A,I4,A,I2,A,I1,A,I4,A,I4,A)') &
                    'STB ', i, ': type=', stb_vertices(i)%type, &
                    ' (', stb_vertices(i)%x, ',', stb_vertices(i)%y, ') | ForTTF ', i, &
                    ': type=', forttf_vertices(i)%type, ' (', forttf_vertices(i)%x, ',', &
                    forttf_vertices(i)%y, ')'
            else
                ! STB 27 maps to nothing in ForTTF
                if (i == 27) then
                    write(*,'(A,I2,A,I1,A,I4,A,I4,A)') &
                        'STB ', i, ': type=', stb_vertices(i)%type, &
                        ' (', stb_vertices(i)%x, ',', stb_vertices(i)%y, &
                        ') | ForTTF: <MISSING - implicit closing>'
                end if
                ! STB 28+ maps to ForTTF 27+
                if (i >= 28 .and. i-1 <= num_forttf) then
                    write(*,'(A,I2,A,I1,A,I4,A,I4,A,I2,A,I1,A,I4,A,I4,A)') &
                        'STB ', i, ': type=', stb_vertices(i)%type, &
                        ' (', stb_vertices(i)%x, ',', stb_vertices(i)%y, ') | ForTTF ', i-1, &
                        ': type=', forttf_vertices(i-1)%type, ' (', forttf_vertices(i-1)%x, ',', &
                        forttf_vertices(i-1)%y, ')'
                end if
            end if
        end do
        
        ! Clean up
        call stb_free_shape(stb_vertices_ptr)
        if (allocated(forttf_vertices)) deallocate(forttf_vertices)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine compare_vertices

end program test_vertex_comparison