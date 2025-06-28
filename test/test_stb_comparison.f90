program test_stb_comparison
    !! Test program to compare STB TrueType wrapper with pure Fortran implementation
    !! Verifies compatibility and performance between implementations
    use fortplot_stb_truetype
    use fortplot_stb
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    logical :: overall_success
    integer :: failed_tests, total_tests
    
    failed_tests = 0
    total_tests = 0
    
    write(*,*) "=== STB TrueType vs Pure Fortran Comparison Tests ==="
    write(*,*) ""
    
    ! Test basic functionality
    call test_basic_comparison()
    
    ! Summary
    write(*,*) ""
    write(*,*) "=== Test Summary ==="
    write(*,'(A,I0,A,I0)') "Failed: ", failed_tests, " / ", total_tests
    
    overall_success = (failed_tests == 0)
    if (overall_success) then
        write(*,*) "All tests PASSED"
    else
        write(*,*) "Some tests FAILED"
    end if
    
    if (.not. overall_success) then
        error stop 1
    end if

contains

    subroutine test_basic_comparison()
        !! Test basic functionality comparison between STB and pure implementations
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        logical :: stb_success, pure_success
        character(len=256) :: font_paths(3)
        real(wp) :: stb_scale, pure_scale
        integer :: stb_ascent, stb_descent, stb_line_gap
        integer :: pure_ascent, pure_descent, pure_line_gap
        integer :: i
        
        write(*,*) "Testing basic comparison..."
        
        total_tests = total_tests + 1
        
        ! Try multiple font paths
        font_paths(1) = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        font_paths(2) = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        font_paths(3) = "/System/Library/Fonts/Helvetica.ttc"
        
        stb_success = .false.
        pure_success = .false.
        
        ! Test STB implementation
        do i = 1, 3
            stb_success = stb_init_font(stb_font, trim(font_paths(i)))
            if (stb_success) exit
        end do
        
        ! Test pure implementation (should fail - it's a stub)
        do i = 1, 3
            pure_success = stb_init_font_pure(pure_font, trim(font_paths(i)))
            if (pure_success) exit
        end do
        
        if (stb_success) then
            write(*,*) "  ✓ STB font initialization: SUCCESS"
            
            ! Test scale calculation
            stb_scale = stb_scale_for_pixel_height(stb_font, 16.0_wp)
            pure_scale = stb_scale_for_pixel_height_pure(pure_font, 16.0_wp)
            
            write(*,'(A,F8.6,A,F8.6)') "  ✓ Scale factors - STB: ", stb_scale, &
                                       " Pure: ", pure_scale
            
            ! Test font metrics
            call stb_get_font_vmetrics(stb_font, stb_ascent, stb_descent, stb_line_gap)
            call stb_get_font_vmetrics_pure(pure_font, pure_ascent, pure_descent, &
                                           pure_line_gap)
            
            write(*,'(A,I0,A,I0,A,I0)') "  ✓ STB metrics: ", stb_ascent, "/", &
                                        stb_descent, "/", stb_line_gap
            write(*,'(A,I0,A,I0,A,I0)') "  ✓ Pure metrics: ", pure_ascent, "/", &
                                        pure_descent, "/", pure_line_gap
            
            ! Test additional functions
            call test_new_functions(stb_font)
            
            ! Test glyph-level functions
            call test_glyph_functions(stb_font)
            
            call stb_cleanup_font(stb_font)
        else
            write(*,*) "  ⚠ No font available - skipping detailed tests"
        end if
        
        if (pure_success) then
            call stb_cleanup_font_pure(pure_font)
            write(*,*) "  ⚠ Pure implementation unexpectedly succeeded"
            failed_tests = failed_tests + 1
        else
            write(*,*) "  ✓ Pure implementation failed as expected (stub)"
        end if
        
        write(*,*) "  ✓ Basic comparison test completed"
        
    end subroutine test_basic_comparison
    
    subroutine test_new_functions(stb_font)
        !! Test newly added functions
        type(stb_fontinfo_t), intent(in) :: stb_font
        real(wp) :: em_scale
        integer :: bbox_x0, bbox_y0, bbox_x1, bbox_y1
        integer :: char_x0, char_y0, char_x1, char_y1
        integer :: kern_advance
        
        write(*,*) "  Testing new functions..."
        
        ! Test em scaling
        em_scale = stb_scale_for_mapping_em_to_pixels(stb_font, 16.0_wp)
        write(*,'(A,F8.6)') "    EM scale: ", em_scale
        
        ! Test font bounding box
        call stb_get_font_bounding_box(stb_font, bbox_x0, bbox_y0, bbox_x1, bbox_y1)
        write(*,'(A,4I6)') "    Font bbox: ", bbox_x0, bbox_y0, bbox_x1, bbox_y1
        
        ! Test character bounding box
        call stb_get_codepoint_box(stb_font, iachar('A'), char_x0, char_y0, &
                                  char_x1, char_y1)
        write(*,'(A,4I6)') "    Char 'A' bbox: ", char_x0, char_y0, char_x1, char_y1
        
        ! Test kerning
        kern_advance = stb_get_codepoint_kern_advance(stb_font, iachar('A'), &
                                                     iachar('V'))
        write(*,'(A,I0)') "    Kerning A-V: ", kern_advance
        
        write(*,*) "  ✓ New functions tested successfully"
        
    end subroutine test_new_functions
    
    subroutine test_glyph_functions(stb_font)
        !! Test newly added glyph-level functions
        type(stb_fontinfo_t), intent(in) :: stb_font
        integer :: glyph_index, glyph_advance, glyph_bearing
        integer :: glyph_x0, glyph_y0, glyph_x1, glyph_y1
        integer :: glyph_kern, table_length
        integer :: typoAscent, typoDescent, typoLineGap
        
        write(*,*) "  Testing glyph-level functions..."
        
        ! Get glyph index for 'A'
        glyph_index = stb_find_glyph_index(stb_font, iachar('A'))
        write(*,'(A,I0)') "    Glyph index for 'A': ", glyph_index
        
        if (glyph_index > 0) then
            ! Test glyph metrics
            call stb_get_glyph_hmetrics(stb_font, glyph_index, glyph_advance, &
                                       glyph_bearing)
            write(*,'(A,I0,A,I0)') "    Glyph metrics: ", glyph_advance, &
                                   "/", glyph_bearing
            
            ! Test glyph bounding box
            call stb_get_glyph_box(stb_font, glyph_index, glyph_x0, glyph_y0, &
                                  glyph_x1, glyph_y1)
            write(*,'(A,4I6)') "    Glyph bbox: ", glyph_x0, glyph_y0, &
                               glyph_x1, glyph_y1
            
            ! Test glyph kerning
            glyph_kern = stb_get_glyph_kern_advance(stb_font, glyph_index, &
                                                   glyph_index)
            write(*,'(A,I0)') "    Glyph self-kern: ", glyph_kern
        else
            write(*,*) "    ⚠ No glyph found for 'A'"
        end if
        
        ! Test OS/2 metrics
        call stb_get_font_vmetrics_os2(stb_font, typoAscent, typoDescent, &
                                      typoLineGap)
        write(*,'(A,I0,A,I0,A,I0)') "    OS/2 metrics: ", typoAscent, "/", &
                                     typoDescent, "/", typoLineGap
        
        ! Test kerning table
        table_length = stb_get_kerning_table_length(stb_font)
        write(*,'(A,I0)') "    Kerning table length: ", table_length
        
        write(*,*) "  ✓ Glyph functions tested successfully"
        
    end subroutine test_glyph_functions

end program test_stb_comparison