program test_stb_coordinate_analysis
    !! Analyze STB coordinate system vs ForTTF to find the y-axis orientation issue
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call analyze_stb_coordinate_system()
    
contains

    subroutine analyze_stb_coordinate_system()
        ! Test hypothesis: STB uses different y-axis orientation
        type(stb_active_edge_t) :: edge
        real(wp), allocatable :: scanline(:), fill(:)
        integer, parameter :: width = 20
        real(wp) :: y_top, y_bottom
        real(wp) :: sum_val, k_val
        
        write(*,*) '=== STB COORDINATE SYSTEM ANALYSIS ==='
        write(*,*) 'Testing hypothesis: STB uses different y-axis orientation'
        write(*,*)
        
        ! Original problematic edge
        edge%fx = 8.827_wp
        edge%fdx = -0.003_wp
        edge%fdy = -301.000_wp
        edge%direction = -1.000_wp
        edge%sy = -6.020_wp
        edge%ey = 0.000_wp
        edge%next => null()
        
        allocate(scanline(width), fill(width + 1))
        
        write(*,*) 'HYPOTHESIS 1: STB flips y-axis direction'
        write(*,*) 'Try flipping the edge direction sign'
        
        ! Test with flipped direction
        edge%direction = 1.000_wp  ! Flip from -1 to +1
        y_top = -2.0_wp
        y_bottom = -1.0_wp
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge, y_top, y_bottom)
        
        sum_val = fill(9)  ! Only column 8's fill
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F8.3)') 'Flipped direction = ', edge%direction
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val
        write(*,'(A,I3,A,I3)') 'Final pixel=', int(abs(k_val) * 255.0_wp + 0.5_wp), &
            ', STB expected=', 114
        write(*,*)
        
        write(*,*) 'HYPOTHESIS 2: STB uses different y-coordinate mapping'
        write(*,*) 'Try flipping y coordinates'
        
        ! Restore original direction, flip y coordinates
        edge%direction = -1.000_wp
        edge%sy = 6.020_wp   ! Flip sign
        edge%ey = 0.000_wp   ! Keep same
        y_top = 2.0_wp       ! Flip sign
        y_bottom = 1.0_wp    ! Flip sign (note: y_top > y_bottom now)
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F8.3,A,F8.3)') 'Flipped edge sy=', edge%sy, ', ey=', edge%ey
        write(*,'(A,F8.3,A,F8.3)') 'Flipped y_top=', y_top, ', y_bottom=', y_bottom
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val
        write(*,'(A,I3,A,I3)') 'Final pixel=', int(abs(k_val) * 255.0_wp + 0.5_wp), &
            ', STB expected=', 114
        write(*,*)
        
        write(*,*) 'HYPOTHESIS 3: STB processes differently oriented edge'
        write(*,*) 'Try both flips: direction AND y coordinates'
        
        edge%direction = 1.000_wp  ! Positive direction
        edge%sy = 6.020_wp         ! Positive y
        edge%ey = 0.000_wp         
        y_top = 2.0_wp             
        y_bottom = 1.0_wp          
        
        scanline = 0.0_wp
        fill = 0.0_wp
        call stb_process_non_vertical_edge(scanline, fill, width, edge, y_top, y_bottom)
        
        sum_val = fill(9)
        k_val = scanline(9) + sum_val
        
        write(*,'(A,F8.3)') 'Both flipped direction = ', edge%direction
        write(*,'(A,F8.3,A,F8.3)') 'Both flipped sy=', edge%sy, ', ey=', edge%ey
        write(*,'(A,F12.6,A,F12.6,A,F12.6)') 'Result: scanline[8]=', scanline(9), &
            ' fill[8]=', fill(9), ' k=', k_val
        write(*,'(A,I3,A,I3)') 'Final pixel=', int(abs(k_val) * 255.0_wp + 0.5_wp), &
            ', STB expected=', 114
        write(*,*)
        
        write(*,*) 'ANALYSIS:'
        write(*,*) 'Looking for combination that produces k ≈ 0.447 (target for final=114)'
        
        deallocate(scanline, fill)
        
    end subroutine analyze_stb_coordinate_system

end program test_stb_coordinate_analysis