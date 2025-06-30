program test_forttf_selective_contour_closing
    !! Test selective contour closing to match STB exactly
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_selective_closing()

contains

    subroutine test_selective_closing()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint = 36  ! '$'
        
        write(*,*) '=== TESTING SELECTIVE CONTOUR CLOSING ==='
        write(*,*) 'Character: $ (codepoint=36)'
        write(*,*) 'Goal: Add exactly 1 vertex to reach STB count of 39'
        write(*,*)
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*)
        
        write(*,*) 'ANALYSIS OF CONTOUR ENDINGS:'
        write(*,*) 'Looking at the vertex list from previous test:'
        write(*,*) 'Contour 1: starts at vertex 1 (692,-301), ends at vertex 26 (692,2)'
        write(*,*) 'Contour 2: starts at vertex 27 (592,770), ends at vertex 32 (592,770)' 
        write(*,*) 'Contour 3: starts at vertex 33 (692,578), ends at vertex 38 (692,578)'
        write(*,*)
        write(*,*) 'OBSERVATION:'
        write(*,*) 'Contour 1: Does NOT end at starting point (needs closing line?)'
        write(*,*) 'Contour 2: Ends at same point as start (already closed)'
        write(*,*) 'Contour 3: Ends at same point as start (already closed)'
        write(*,*)
        write(*,*) 'HYPOTHESIS:'
        write(*,*) 'STB adds a closing line vertex for Contour 1 from (692,2) back to (692,-301)'
        write(*,*) 'This would add exactly 1 vertex: 38 + 1 = 39 ✓'
        write(*,*)
        write(*,*) 'SOLUTION:'
        write(*,*) 'Modify forttf_outline.f90 to add closing vertex only for contours'
        write(*,*) 'that dont already end at their starting point'
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_selective_closing

end program test_forttf_selective_contour_closing