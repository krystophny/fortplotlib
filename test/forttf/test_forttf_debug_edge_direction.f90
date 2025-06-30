program test_forttf_debug_edge_direction
    !! Test hypothesis: Edge direction interpretation differs between ForTTF and STB
    use forttf_stb_raster
    use forttf_types
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_edge_direction_hypothesis()

contains

    subroutine test_edge_direction_hypothesis()
        type(stb_active_edge_t) :: edge1
        real(wp), allocatable :: scanline(:), fill(:)
        integer, parameter :: width = 20
        real(wp), parameter :: y_top = -2.0_wp, y_bottom = -1.0_wp
        real(wp) :: sum_val, k_val
        integer :: final_val
        
        write(*,*) '=== TESTING EDGE DIRECTION HYPOTHESIS ==='
        write(*,*) 'Hypothesis: ForTTF and STB interpret edge direction differently'
        write(*,*)
        
        allocate(scanline(width), fill(width + 1))
        
        ! Original problematic edge
        edge1%fx = 8.827_wp
        edge1%fdx = -0.003_wp
        edge1%fdy = -301.000_wp
        edge1%sy = -6.020_wp
        edge1%ey = 0.000_wp
        edge1%next => null()
        
        write(*,*) 'TEST 1: Original edge (direction = -1)'
        edge1%direction = -1.000_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3)') 'Direction = ', edge1%direction
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        write(*,*) 'TEST 2: Flipped edge (direction = +1)'
        edge1%direction = 1.000_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
        if (final_val > 255) final_val = 255
        
        write(*,'(A,F8.3)') 'Direction = ', edge1%direction
        write(*,'(A,F12.6,A,F12.6,A,F12.6,A,I3)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val, ' final=', final_val
        write(*,*)
        
        write(*,*) 'ANALYSIS:'
        write(*,*) 'STB target: k ≈ +0.447, final = 114'
        write(*,*) 'Looking for which direction produces positive k-value'
        
        deallocate(scanline, fill)
        
    end subroutine test_edge_direction_hypothesis

end program test_forttf_debug_edge_direction