program test_debug_y_coordinates
    !! Test different y_top and y_bottom values for edge processing
    use forttf_stb_raster
    use forttf_types
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_y_coordinate_variations()

contains

    subroutine test_y_coordinate_variations()
        type(stb_active_edge_t), target :: edge1, edge2
        real(wp), allocatable :: scanline(:), fill(:)
        integer, parameter :: width = 20
        real(wp) :: y_top, y_bottom, sum_val, k_val
        integer :: final_val
        
        write(*,*) '=== TESTING Y-COORDINATE VARIATIONS ==='
        write(*,*) 'Target: STB k ≈ +0.447, final = 114'
        write(*,*) 'Testing different y_top and y_bottom values'
        write(*,*)
        
        allocate(scanline(width), fill(width + 1))
        
        ! Set up edge parameters (original directions)
        edge1%fx = 8.827_wp
        edge1%fdx = -0.003_wp
        edge1%fdy = -301.000_wp
        edge1%direction = -1.000_wp
        edge1%sy = -6.020_wp
        edge1%ey = 0.000_wp
        edge1%next => edge2
        
        edge2%fx = 10.840_wp
        edge2%fdx = 0.000_wp
        edge2%fdy = 1.0e30_wp
        edge2%direction = 1.000_wp
        edge2%sy = -6.020_wp
        edge2%ey = 0.040_wp
        edge2%next => null()
        
        ! Test 1: Original y coordinates
        write(*,*) 'TEST 1: Original y coordinates (-2, -1)'
        y_top = -2.0_wp
        y_bottom = -1.0_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'y_top=', y_top, ', y_bottom=', y_bottom
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        ! Test 2: Row 5 scanline coordinates (5, 6)
        write(*,*) 'TEST 2: Row 5 scanline coordinates (5, 6)'
        y_top = 5.0_wp
        y_bottom = 6.0_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'y_top=', y_top, ', y_bottom=', y_bottom
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        ! Test 3: Offset scanline coordinates (-2+7=5, -1+7=6) since offset is -7
        write(*,*) 'TEST 3: With y-offset applied (scanline_y + 7) -> (5, 6)'
        y_top = 5.0_wp - 7.0_wp  ! -2
        y_bottom = 6.0_wp - 7.0_wp  ! -1
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'y_top=', y_top, ', y_bottom=', y_bottom
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        ! Test 4: Exact scanline boundaries from debug output
        write(*,*) 'TEST 4: Exact STB scanline boundaries from debug (-2, -1)'
        y_top = -2.0_wp
        y_bottom = -1.0_wp
        
        ! But modify edge parameters to match STB processing exactly
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'y_top=', y_top, ', y_bottom=', y_bottom
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        
        write(*,*)
        write(*,*) 'ANALYSIS:'
        write(*,*) 'The k-value magnitude is consistently ≈1.174, not ≈0.447'
        write(*,*) 'This suggests the fundamental processing is different from STB'
        
        deallocate(scanline, fill)
        
    end subroutine test_y_coordinate_variations

end program test_debug_y_coordinates