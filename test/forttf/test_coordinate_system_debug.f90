program test_coordinate_system_debug
    !! Debug the coordinate system transformation that might be causing sign differences
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call test_coordinate_transformation()
    
contains

    subroutine test_coordinate_transformation()
        ! From debug output: Row 5 corresponds to scan_y_top = -2.0
        ! But the actual problematic case shows y=5 in the loop
        type(stb_active_edge_t) :: edge
        real(wp), allocatable :: scanline(:), fill(:)
        integer, parameter :: width = 20
        real(wp) :: y_top, y_bottom
        integer :: i
        real(wp) :: sum_val, k_val
        
        write(*,*) '=== COORDINATE SYSTEM DEBUG ==='
        write(*,*) 'Understanding the y-coordinate transformation'
        write(*,*)
        
        ! Exact edge from debug output
        edge%fx = 8.827_wp
        edge%fdx = -0.003_wp
        edge%fdy = -301.000_wp
        edge%direction = -1.000_wp
        edge%sy = -6.020_wp
        edge%ey = 0.000_wp
        edge%next => null()
        
        ! The debug output showed Row 5, which maps to:
        ! scan_y_top = real(y + off_y, wp) + 0.0_wp = real(5 + (-7), wp) = -2.0
        ! scan_y_bottom = -1.0
        y_top = -2.0_wp
        y_bottom = -1.0_wp
        
        write(*,*) 'TEST 1: Using Row 5 coordinates (y_top=-2, y_bottom=-1)'
        write(*,'(A,F8.3,A,F8.3)') 'y_top = ', y_top, ', y_bottom = ', y_bottom
        
        allocate(scanline(width), fill(width + 1))
        scanline = 0.0_wp
        fill = 0.0_wp
        
        call stb_process_non_vertical_edge(scanline, fill, width, edge, y_top, y_bottom)
        
        sum_val = 0.0_wp
        do i = 1, 9
            sum_val = sum_val + fill(i)
        end do
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Result: scanline[8]=', scanline(9), &
            ' fill_sum=', sum_val, ' k=', k_val
        write(*,*)
        
        ! Now try a different y range that might intersect the edge better
        write(*,*) 'TEST 2: Using edge intersection range (sy=-6.02, ey=0.0)'
        y_top = -1.0_wp
        y_bottom = 0.0_wp
        write(*,'(A,F8.3,A,F8.3)') 'y_top = ', y_top, ', y_bottom = ', y_bottom
        
        scanline = 0.0_wp
        fill = 0.0_wp
        
        call stb_process_non_vertical_edge(scanline, fill, width, edge, y_top, y_bottom)
        
        sum_val = 0.0_wp
        do i = 1, 9
            sum_val = sum_val + fill(i)
        end do
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Result: scanline[8]=', scanline(9), &
            ' fill_sum=', sum_val, ' k=', k_val
        write(*,*)
        
        ! Try positive y range
        write(*,*) 'TEST 3: Using positive y range'
        y_top = 5.0_wp
        y_bottom = 6.0_wp
        write(*,'(A,F8.3,A,F8.3)') 'y_top = ', y_top, ', y_bottom = ', y_bottom
        
        scanline = 0.0_wp
        fill = 0.0_wp
        
        call stb_process_non_vertical_edge(scanline, fill, width, edge, y_top, y_bottom)
        
        sum_val = 0.0_wp
        do i = 1, 9
            sum_val = sum_val + fill(i)
        end do
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Result: scanline[8]=', scanline(9), &
            ' fill_sum=', sum_val, ' k=', k_val
        write(*,*)
        
        write(*,*) 'CRITICAL ANALYSIS:'
        write(*,*) 'The edge spans from sy=-6.02 to ey=0.0'
        write(*,*) 'For Row 5 processing, we should use the scanline that'
        write(*,*) 'intersects this edge in a way that produces the observed result'
        
        deallocate(scanline, fill)
        
    end subroutine test_coordinate_transformation

end program test_coordinate_system_debug