program test_debug_dollar_character
    !! Debug ForTTF vs STB edge processing for character '$' Row 5 Col 8
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_stb_raster
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call debug_dollar_character_edges()

contains

    subroutine debug_dollar_character_edges()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        ! Character '$' edges from debug output
        type(stb_active_edge_t), target :: edge1, edge2
        real(wp), allocatable :: scanline(:), fill(:)
        integer, parameter :: width = 20
        real(wp), parameter :: y_top = -2.0_wp, y_bottom = -1.0_wp
        real(wp) :: sum_val, k_val
        integer :: final_val
        
        write(*,*) '=== DEBUGGING DOLLAR CHARACTER EDGES ==='
        write(*,*) 'Focus: Why ForTTF produces k=-1.175 instead of STB k≈0.447'
        write(*,*)
        
        ! Find and initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*)
        
        ! Set up edges from debug output for character '$' Row 5
        edge1%fx = 8.827_wp
        edge1%fdx = -0.003_wp  
        edge1%fdy = -301.000_wp
        edge1%direction = -1.000_wp
        edge1%sy = -6.020_wp
        edge1%ey = 0.000_wp
        edge1%next => edge2
        
        edge2%fx = 10.840_wp
        edge2%fdx = 0.000_wp
        edge2%fdy = 1.0e30_wp  ! Infinity
        edge2%direction = 1.000_wp  
        edge2%sy = -6.020_wp
        edge2%ey = 0.040_wp
        edge2%next => null()
        
        allocate(scanline(width), fill(width + 1))
        
        write(*,*) 'EDGE PARAMETERS:'
        write(*,'(A,F8.3,A,F8.3,A,F8.3,A,F8.3)') 'Edge 1: fx=', edge1%fx, ' fdx=', edge1%fdx, &
            ' dir=', edge1%direction, ' sy=', edge1%sy
        write(*,'(A,F8.3,A,F8.3,A,F8.3,A,F8.3)') 'Edge 2: fx=', edge2%fx, ' fdx=', edge2%fdx, &
            ' dir=', edge2%direction, ' sy=', edge2%sy
        write(*,*)
        
        ! Test 1: Process edges individually 
        write(*,*) 'TEST 1: Individual edge processing'
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        
        sum_val = fill(9)  ! Column 8 (1-based indexing)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Edge 1 only: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val  
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Edge 2 only: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        ! Test 2: Process both edges together
        write(*,*) 'TEST 2: Both edges together (ForTTF approach)'
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Both edges: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        write(*,*) 'ANALYSIS:'
        write(*,'(A,I3)') 'ForTTF produces final=', final_val
        write(*,*) 'STB produces final=114'
        write(*,'(A,I3)') 'Difference=', abs(final_val - 114)
        write(*,*)
        
        if (final_val == 114) then
            write(*,*) 'SUCCESS: ForTTF matches STB!'
        else
            write(*,*) 'ISSUE: ForTTF differs from STB'
            write(*,*) 'Next: Check if edge parameters are wrong or processing differs'
        end if
        
        deallocate(scanline, fill)
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine debug_dollar_character_edges

end program test_debug_dollar_character