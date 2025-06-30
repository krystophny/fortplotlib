program test_forttf_buffer_filling_comparison
    !! Direct comparison of STB vs ForTTF buffer filling for exact same edge
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call test_exact_edge_comparison()
    
contains

    subroutine test_exact_edge_comparison()
        ! Use the exact edge parameters from problematic Row 5 Col 8
        ! Based on the debug output from actual bitmap test
        type(stb_active_edge_t) :: test_edge
        real(wp), allocatable :: forttf_scanline(:), forttf_fill(:)
        integer, parameter :: width = 20
        real(wp), parameter :: y_top = 5.0_wp, y_bottom = 6.0_wp
        integer :: i
        
        write(*,*) '=== BUFFER FILLING DIRECT COMPARISON ==='
        write(*,*) 'Using exact edge parameters from actual failing case'
        write(*,*)
        
        ! Allocate ForTTF buffers
        allocate(forttf_scanline(width))
        allocate(forttf_fill(width + 1))
        forttf_scanline = 0.0_wp
        forttf_fill = 0.0_wp
        
        ! Create edge that matches the problematic case from bitmap export
        ! These values are estimated from the actual edge causing the Row 5 Col 8 issue
        test_edge%fx = 8.15_wp     ! Edge x position
        test_edge%fdx = 0.25_wp    ! Edge x slope  
        test_edge%fdy = 1.0_wp     ! Edge y slope
        test_edge%direction = 1.0_wp ! Positive direction
        test_edge%sy = 4.8_wp      ! Edge start y
        test_edge%ey = 6.2_wp      ! Edge end y
        test_edge%next => null()
        
        write(*,*) 'Edge configuration:'
        write(*,'(A,F10.6)') '  fx  = ', test_edge%fx
        write(*,'(A,F10.6)') '  fdx = ', test_edge%fdx
        write(*,'(A,F10.6)') '  fdy = ', test_edge%fdy
        write(*,'(A,F10.6)') '  dir = ', test_edge%direction
        write(*,'(A,F10.6)') '  sy  = ', test_edge%sy
        write(*,'(A,F10.6)') '  ey  = ', test_edge%ey
        write(*,'(A,F10.6)') '  y_top = ', y_top
        write(*,'(A,F10.6)') '  y_bot = ', y_bottom
        write(*,*)
        
        ! Test ForTTF buffer filling
        write(*,*) 'Testing ForTTF buffer filling...'
        call stb_process_non_vertical_edge(forttf_scanline, forttf_fill, width, &
                                         test_edge, y_top, y_bottom)
        
        write(*,*) 'ForTTF Results:'
        do i = 1, width
            if (abs(forttf_scanline(i)) > 1e-10_wp .or. abs(forttf_fill(i)) > 1e-10_wp) then
                write(*,'(A,I2,A,F12.6,A,F12.6)') &
                    'Col ', i-1, ': scanline=', forttf_scanline(i), ' fill=', forttf_fill(i)
            end if
        end do
        write(*,*)
        
        ! Focus on Col 8 specifically
        if (width >= 9) then
            write(*,*) 'FOCUS: Column 8 analysis'
            write(*,'(A,F12.6)') 'ForTTF scanline[8] = ', forttf_scanline(9)
            write(*,'(A,F12.6)') 'ForTTF fill[8]     = ', forttf_fill(9)
            write(*,*)
            
            ! Simulate the final accumulation for this column
            block
                real(wp) :: sum_val, k_val
                integer :: final_val
                
                sum_val = 0.0_wp
                do i = 1, 9  ! Accumulate up to column 8
                    sum_val = sum_val + forttf_fill(i)
                end do
                
                k_val = forttf_scanline(9) + sum_val
                final_val = int(abs(k_val) * 255.0_wp + 0.5_wp)
                if (final_val > 255) final_val = 255
                
                write(*,'(A,F12.6)') 'Accumulated fill sum = ', sum_val
                write(*,'(A,F12.6)') 'Final k value       = ', k_val
                write(*,'(A,I3)') 'Final pixel value   = ', final_val
                write(*,'(A,I3)') 'STB expected        = ', 114
                write(*,'(A,F12.6)') 'STB expected k      = ', 114.0_wp / 255.0_wp
                write(*,*)
            end block
        end if
        
        deallocate(forttf_scanline, forttf_fill)
        
        write(*,*) 'CRITICAL QUESTION: Why does ForTTF produce different buffer values than STB?'
        write(*,*) 'HYPOTHESIS: Edge processing algorithm difference in non-vertical edge handling'
        
    end subroutine test_exact_edge_comparison

end program test_forttf_buffer_filling_comparison