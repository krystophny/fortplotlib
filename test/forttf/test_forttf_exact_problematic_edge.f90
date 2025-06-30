program test_forttf_exact_problematic_edge
    !! Test the exact edge parameters from Row 5 Col 8 that causes the sign issue
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call test_exact_edge_from_debug()
    
contains

    subroutine test_exact_edge_from_debug()
        ! Use EXACT edge parameters from the debug output
        type(stb_active_edge_t) :: problem_edge
        real(wp), allocatable :: scanline_buffer(:), fill_buffer(:)
        integer, parameter :: width = 20
        real(wp), parameter :: y_top = -2.0_wp, y_bottom = -1.0_wp  ! Row 5 corresponds to this range
        integer :: i
        real(wp) :: sum_val, k_val
        
        write(*,*) '=== EXACT PROBLEMATIC EDGE TEST ==='
        write(*,*) 'Testing the exact edge that produces k=-1.175017'
        write(*,*)
        
        ! Exact parameters from debug output for Row 5
        problem_edge%fx = 8.827_wp
        problem_edge%fdx = -0.003_wp
        problem_edge%fdy = -301.000_wp
        problem_edge%direction = -1.000_wp
        problem_edge%sy = -6.020_wp
        problem_edge%ey = 0.000_wp
        problem_edge%next => null()
        
        write(*,*) 'Edge parameters (from actual debug output):'
        write(*,'(A,F10.6)') '  fx  = ', problem_edge%fx
        write(*,'(A,F10.6)') '  fdx = ', problem_edge%fdx
        write(*,'(A,F10.6)') '  fdy = ', problem_edge%fdy
        write(*,'(A,F10.6)') '  dir = ', problem_edge%direction
        write(*,'(A,F10.6)') '  sy  = ', problem_edge%sy
        write(*,'(A,F10.6)') '  ey  = ', problem_edge%ey
        write(*,*)
        
        ! Allocate buffers
        allocate(scanline_buffer(width))
        allocate(fill_buffer(width + 1))
        scanline_buffer = 0.0_wp
        fill_buffer = 0.0_wp
        
        write(*,*) 'Processing edge for Row 5 (y_top=-2, y_bottom=-1)...'
        
        ! Process using ForTTF algorithm
        call stb_process_non_vertical_edge(scanline_buffer, fill_buffer, width, &
                                         problem_edge, y_top, y_bottom)
        
        write(*,*) 'ForTTF Results:'
        do i = 1, width
            if (abs(scanline_buffer(i)) > 1e-10_wp .or. abs(fill_buffer(i)) > 1e-10_wp) then
                write(*,'(A,I2,A,F12.6,A,F12.6)') &
                    'Col ', i-1, ': scanline=', scanline_buffer(i), ' fill=', fill_buffer(i)
            end if
        end do
        write(*,*)
        
        ! Focus on Column 8 specifically and simulate final accumulation
        write(*,*) 'CRITICAL ANALYSIS: Column 8'
        sum_val = 0.0_wp
        do i = 1, 9  ! Accumulate up to column 8
            sum_val = sum_val + fill_buffer(i)
        end do
        k_val = scanline_buffer(9) + sum_val
        
        write(*,'(A,F12.6)') 'ForTTF scanline[8] = ', scanline_buffer(9)
        write(*,'(A,F12.6)') 'ForTTF fill_sum    = ', sum_val
        write(*,'(A,F12.6)') 'ForTTF k_val       = ', k_val
        write(*,'(A,I3)') 'ForTTF final       = ', int(abs(k_val) * 255.0_wp + 0.5_wp)
        write(*,'(A,I3)') 'STB expected       = ', 114
        write(*,*)
        
        write(*,*) 'SIGN ANALYSIS:'
        write(*,'(A,F8.3)') 'Edge direction = ', problem_edge%direction
        write(*,*) 'Direction = -1.0 means counter-clockwise winding'
        write(*,*) 'This should contribute NEGATIVE area to scanline buffer'
        write(*,*) 'But STB apparently produces POSITIVE k value'
        write(*,*)
        
        write(*,*) 'HYPOTHESIS: STB handles negative direction differently'
        write(*,*) 'Maybe STB flips the sign somewhere in the processing?'
        
        deallocate(scanline_buffer, fill_buffer)
        
    end subroutine test_exact_edge_from_debug

end program test_forttf_exact_problematic_edge