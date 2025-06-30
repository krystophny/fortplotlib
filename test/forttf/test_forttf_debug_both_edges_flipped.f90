program test_forttf_debug_both_edges_flipped
    !! Test both edges with various direction combinations
    use forttf_stb_raster
    use forttf_types
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_direction_combinations()

contains

    subroutine test_direction_combinations()
        type(stb_active_edge_t), target :: edge1, edge2
        real(wp), allocatable :: scanline(:), fill(:)
        integer, parameter :: width = 20
        real(wp), parameter :: y_top = -2.0_wp, y_bottom = -1.0_wp
        real(wp) :: sum_val, k_val
        integer :: final_val
        
        write(*,*) '=== TESTING BOTH EDGES WITH DIRECTION COMBINATIONS ==='
        write(*,*) 'Target: STB k ≈ +0.447, final = 114'
        write(*,*)
        
        allocate(scanline(width), fill(width + 1))
        
        ! Set up base edge parameters
        edge1%fx = 8.827_wp
        edge1%fdx = -0.003_wp
        edge1%fdy = -301.000_wp
        edge1%sy = -6.020_wp
        edge1%ey = 0.000_wp
        edge1%next => edge2
        
        edge2%fx = 10.840_wp
        edge2%fdx = 0.000_wp
        edge2%fdy = 1.0e30_wp
        edge2%sy = -6.020_wp
        edge2%ey = 0.040_wp
        edge2%next => null()
        
        ! Test 1: Original directions (-1, +1)
        write(*,*) 'TEST 1: Original directions (-1, +1)'
        edge1%direction = -1.000_wp
        edge2%direction = 1.000_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'Directions: ', edge1%direction, ', ', edge2%direction
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        ! Test 2: Both positive (+1, +1)
        write(*,*) 'TEST 2: Both positive (+1, +1)'
        edge1%direction = 1.000_wp
        edge2%direction = 1.000_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'Directions: ', edge1%direction, ', ', edge2%direction
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        ! Test 3: Both negative (-1, -1)
        write(*,*) 'TEST 3: Both negative (-1, -1)'
        edge1%direction = -1.000_wp
        edge2%direction = -1.000_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'Directions: ', edge1%direction, ', ', edge2%direction
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        ! Test 4: Flipped directions (+1, -1)
        write(*,*) 'TEST 4: Flipped directions (+1, -1)'
        edge1%direction = 1.000_wp
        edge2%direction = -1.000_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3,A,F8.3)') 'Directions: ', edge1%direction, ', ', edge2%direction
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        write(*,*) 'ANALYSIS:'
        write(*,*) 'Looking for combination that produces k ≈ +0.447 (final ≈ 114)'
        
        deallocate(scanline, fill)
        
    end subroutine test_direction_combinations

end program test_forttf_debug_both_edges_flipped