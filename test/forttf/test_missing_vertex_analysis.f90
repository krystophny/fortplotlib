program test_missing_vertex_analysis
    !! Analyze what type of vertex is missing - ForTTF=38 vs STB=39
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_outline
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call analyze_missing_vertex()

contains

    subroutine analyze_missing_vertex()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint = 36  ! '$'
        
        write(*,*) '=== ANALYZING MISSING VERTEX ==='
        write(*,*) 'Character: $ (codepoint=36)'
        write(*,*) 'Current: ForTTF=38 vertices, STB=39 vertices'
        write(*,*) 'Goal: Find what type of vertex ForTTF is missing'
        write(*,*)
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*)
        
        ! Analyze ForTTF vertices by type
        write(*,*) '=== ForTTF VERTEX TYPE ANALYSIS ==='
        block
            type(ttf_vertex_t), allocatable :: vertices(:)
            integer :: num_vertices, i
            integer :: move_count, line_count, curve_count
            
            num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint, vertices)
            
            move_count = 0
            line_count = 0  
            curve_count = 0
            
            do i = 1, num_vertices
                select case (vertices(i)%type)
                case (TTF_VERTEX_MOVE)
                    move_count = move_count + 1
                case (TTF_VERTEX_LINE)
                    line_count = line_count + 1
                case (TTF_VERTEX_CURVE)
                    curve_count = curve_count + 1
                end select
            end do
            
            write(*,'(A,I0,A)') 'ForTTF total vertices: ', num_vertices, ' (should be 39)'
            write(*,'(A,I0)') 'Move vertices: ', move_count
            write(*,'(A,I0)') 'Line vertices: ', line_count  
            write(*,'(A,I0)') 'Curve vertices: ', curve_count
            write(*,*)
            
            deallocate(vertices)
        end block
        
        write(*,*) 'ANALYSIS:'
        write(*,*) 'The character $ has 3 contours (num_contours=3 from debug)'
        write(*,*) 'Each contour typically needs:'
        write(*,*) '1. One MOVE vertex to start the contour'
        write(*,*) '2. Multiple LINE/CURVE vertices for the path'
        write(*,*) '3. Potentially a closing vertex (but we disabled explicit closing)'
        write(*,*)
        write(*,*) 'HYPOTHESES for missing vertex:'
        write(*,*) '1. Missing implicit closing vertex on one contour'
        write(*,*) '2. Missing move vertex for one contour'
        write(*,*) '3. STB adds phantom/hint vertices that ForTTF doesnt'
        write(*,*) '4. Different curve flattening creates extra vertex'
        write(*,*)
        write(*,*) 'SOLUTION:'
        write(*,*) 'Need to compare STB vs ForTTF vertex extraction step by step'
        write(*,*) 'to identify exactly which vertex type/location is missing'
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine analyze_missing_vertex

end program test_missing_vertex_analysis