program test_forttf_stb_algorithm_exact
    !! Test exact STB algorithm step by step to identify divergence
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call test_stb_algorithm_step_by_step()
    
contains

    subroutine test_stb_algorithm_step_by_step()
        type(stb_active_edge_t) :: test_edge
        real(wp), allocatable :: scanline_buffer(:), scanline_fill_buffer(:)
        integer, parameter :: width = 20
        real(wp), parameter :: y_top = 5.0_wp, y_bottom = 6.0_wp
        integer :: i
        
        write(*,*) '=== STB ALGORITHM EXACT STEP-BY-STEP TEST ==='
        write(*,*) 'Testing problematic edge configuration for Row 5'
        write(*,*)
        
        ! Allocate buffers
        allocate(scanline_buffer(width))
        allocate(scanline_fill_buffer(width + 1))
        
        ! Initialize buffers to zero
        scanline_buffer = 0.0_wp
        scanline_fill_buffer = 0.0_wp
        
        ! Create test edge that approximates the problematic case
        ! Based on debug output showing k=-1.175017 for Row 5 Col 8
        test_edge%fx = 8.3_wp      ! x position  
        test_edge%fdx = 0.4_wp     ! x derivative
        test_edge%fdy = 0.8_wp     ! y derivative
        test_edge%direction = 1.0_wp  ! winding direction
        test_edge%sy = 4.5_wp      ! start y
        test_edge%ey = 6.5_wp      ! end y
        test_edge%next => null()
        
        write(*,*) 'Test edge configuration:'
        write(*,'(A,F8.3)') '  fx (x position)     = ', test_edge%fx
        write(*,'(A,F8.3)') '  fdx (x derivative)  = ', test_edge%fdx  
        write(*,'(A,F8.3)') '  fdy (y derivative)  = ', test_edge%fdy
        write(*,'(A,F8.3)') '  direction          = ', test_edge%direction
        write(*,'(A,F8.3)') '  sy (start y)       = ', test_edge%sy
        write(*,'(A,F8.3)') '  ey (end y)         = ', test_edge%ey
        write(*,'(A,F8.3)') '  y_top              = ', y_top
        write(*,'(A,F8.3)') '  y_bottom           = ', y_bottom
        write(*,*)
        
        ! Process the edge using ForTTF's algorithm
        call stb_process_non_vertical_edge(scanline_buffer, scanline_fill_buffer, width, &
                                         test_edge, y_top, y_bottom)
        
        write(*,*) 'Results after processing:'
        do i = 1, width
            if (abs(scanline_buffer(i)) > 1e-10_wp .or. abs(scanline_fill_buffer(i)) > 1e-10_wp) then
                write(*,'(A,I2,A,F12.6,A,F12.6)') &
                    'Col ', i-1, ': scanline=', scanline_buffer(i), ' fill=', scanline_fill_buffer(i)
            end if
        end do
        write(*,*)
        
        ! Now simulate the final accumulation for Col 8
        block
            real(wp) :: sum_val, k_val
            integer :: final_val
            
            sum_val = 0.0_wp
            do i = 1, 9  ! Up to and including column 8 (0-indexed)
                sum_val = sum_val + scanline_fill_buffer(i)
                if (i == 9) then  ! Column 8
                    k_val = scanline_buffer(i) + sum_val
                    final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
                    if (final_val > 255) final_val = 255
                    
                    write(*,'(A,I2,A,F12.6,A,F12.6,A,F12.6,A,I3)') &
                        'CRITICAL Col ', i-1, ': scanline=', scanline_buffer(i), &
                        ' sum_fill=', sum_val, ' k=', k_val, ' final=', final_val
                    write(*,'(A,I3)') 'STB expected final=', 114
                    write(*,'(A,F12.6)') 'Target k value for STB=', 114.0_wp / 255.0_wp
                end if
            end do
        end block
        
        deallocate(scanline_buffer, scanline_fill_buffer)
        
    end subroutine test_stb_algorithm_step_by_step

end program test_forttf_stb_algorithm_exact