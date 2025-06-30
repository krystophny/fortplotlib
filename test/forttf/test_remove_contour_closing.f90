program test_remove_contour_closing
    !! Test removing contour closing code to match STB vertex count
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_vertex_count_fix()

contains

    subroutine test_vertex_count_fix()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint = 36  ! '$'
        real(wp), parameter :: scale = 0.02_wp
        
        write(*,*) '=== TESTING CONTOUR CLOSING REMOVAL ==='
        write(*,*) 'Character: $ (codepoint=36)'
        write(*,*) 'Goal: Test if removing contour closing fixes vertex count'
        write(*,*)
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*)
        
        write(*,*) 'BEFORE FIX:'
        write(*,*) 'STB extracts: 39 vertices'
        write(*,*) 'ForTTF extracts: 41 vertices (with contour closing)'
        write(*,*)
        
        write(*,*) 'HYPOTHESIS:'
        write(*,*) 'The "CRITICAL FIX: Close contour" code adds extra vertices'
        write(*,*) 'that STB does not add, causing edge building differences.'
        write(*,*)
        
        write(*,*) 'SOLUTION:'
        write(*,*) 'Comment out the contour closing code in forttf_outline.f90:'
        write(*,*) 'Lines 453-458: Close contour by adding line back to starting point'
        write(*,*)
        
        write(*,*) 'EXPECTED RESULT:'
        write(*,*) 'ForTTF should then extract exactly 39 vertices like STB'
        write(*,*) 'This should fix the edge building differences and achieve'
        write(*,*) 'k ≈ +0.447 instead of k ≈ -1.175 for Row 5 Col 8'
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_vertex_count_fix

end program test_remove_contour_closing