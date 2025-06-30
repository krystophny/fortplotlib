program test_multiple_edges_interaction
    !! Test how multiple edges with opposite directions interact
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call test_two_edge_interaction()
    
contains

    subroutine test_two_edge_interaction()
        ! Test both edges from Row 5 debug output together
        type(stb_active_edge_t), target :: edge1, edge2
        real(wp), allocatable :: scanline(:), fill(:)
        integer, parameter :: width = 20
        real(wp), parameter :: y_top = -2.0_wp, y_bottom = -1.0_wp
        real(wp) :: sum_val, k_val
        
        write(*,*) '=== MULTIPLE EDGES INTERACTION TEST ==='
        write(*,*) 'Testing both edges from Row 5 debug output'
        write(*,*)
        
        ! Edge 1: The problematic negative direction edge
        edge1%fx = 8.827_wp
        edge1%fdx = -0.003_wp
        edge1%fdy = -301.000_wp
        edge1%direction = -1.000_wp
        edge1%sy = -6.020_wp
        edge1%ey = 0.000_wp
        edge1%next => edge2
        
        ! Edge 2: The positive direction edge  
        edge2%fx = 10.840_wp
        edge2%fdx = 0.000_wp
        edge2%fdy = 1.0e30_wp  ! Infinity approximation
        edge2%direction = 1.000_wp
        edge2%sy = -6.020_wp
        edge2%ey = 0.040_wp
        edge2%next => null()
        
        allocate(scanline(width), fill(width + 1))
        scanline = 0.0_wp
        fill = 0.0_wp
        
        write(*,*) 'Edge 1 (negative direction):'
        write(*,'(A,F8.3,A,F8.3,A,F8.3,A,F8.3)') '  fx=', edge1%fx, ' fdx=', edge1%fdx, &
            ' dir=', edge1%direction, ' sy=', edge1%sy
        
        write(*,*) 'Edge 2 (positive direction):'
        write(*,'(A,F8.3,A,F8.3,A,F8.3,A,F8.3)') '  fx=', edge2%fx, ' fdx=', edge2%fdx, &
            ' dir=', edge2%direction, ' sy=', edge2%sy
        write(*,*)
        
        write(*,*) 'Processing Edge 1 only:'
        call stb_process_non_vertical_edge(scanline, fill, width, edge1, y_top, y_bottom)
        
        sum_val = 0.0_wp
        sum_val = sum_val + fill(9)  ! Column 8 fill
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Edge1 only: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val
        
        write(*,*) 'Processing Edge 2 additionally:'
        call stb_process_non_vertical_edge(scanline, fill, width, edge2, y_top, y_bottom)
        
        sum_val = 0.0_wp  
        sum_val = sum_val + fill(9)  ! Column 8 fill after both edges
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Both edges: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val
        write(*,'(A,I3,A,I3)') 'Final pixel=', int(abs(k_val) * 255.0_wp + 0.5_wp), &
            ', STB expected=', 114
        write(*,*)
        
        write(*,*) 'CRITICAL ANALYSIS:'
        write(*,*) 'STB processes edges with opposite directions (+1 and -1)'
        write(*,*) 'This creates a winding pattern that should cancel out interior regions'
        write(*,*) 'The issue might be in how ForTTF accumulates opposite-direction edges'
        write(*,*)
        
        write(*,*) 'TARGET: Need to produce k ≈ 0.447 for final=114'
        write(*,'(A,F8.3)') 'Current k = ', k_val
        write(*,'(A,F8.3)') 'Target k  = ', 114.0_wp / 255.0_wp
        write(*,'(A,F8.3)') 'Difference = ', abs(k_val - 114.0_wp / 255.0_wp)
        
        deallocate(scanline, fill)
        
    end subroutine test_two_edge_interaction

end program test_multiple_edges_interaction