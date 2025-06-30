program test_forttf_area_calculation_debug
    !! Step-by-step debugging of area calculations in stb_process_non_vertical_edge
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call test_step_by_step_area_calculation()
    
contains

    subroutine test_step_by_step_area_calculation()
        ! Manually walk through the exact STB algorithm step by step
        type(stb_active_edge_t) :: test_edge
        real(wp) :: x0, dx, xb, x_top, x_bottom, sy0, sy1, dy
        real(wp) :: y_top, y_bottom
        real(wp) :: height, sign, area
        integer :: x1, x2
        
        write(*,*) '=== STEP-BY-STEP AREA CALCULATION DEBUG ==='
        write(*,*) 'Manually walking through STB algorithm for problematic edge'
        write(*,*)
        
        ! Use the exact edge that produces scanline[8]=0.725
        test_edge%fx = 8.15_wp
        test_edge%fdx = 0.25_wp  
        test_edge%fdy = 1.0_wp
        test_edge%direction = 1.0_wp
        test_edge%sy = 4.8_wp
        test_edge%ey = 6.2_wp
        
        y_top = 5.0_wp
        y_bottom = 6.0_wp
        
        write(*,*) 'Input parameters:'
        write(*,'(A,F10.6)') '  edge.fx  = ', test_edge%fx
        write(*,'(A,F10.6)') '  edge.fdx = ', test_edge%fdx
        write(*,'(A,F10.6)') '  edge.fdy = ', test_edge%fdy
        write(*,'(A,F10.6)') '  edge.dir = ', test_edge%direction
        write(*,'(A,F10.6)') '  edge.sy  = ', test_edge%sy
        write(*,'(A,F10.6)') '  edge.ey  = ', test_edge%ey
        write(*,'(A,F10.6)') '  y_top    = ', y_top
        write(*,'(A,F10.6)') '  y_bottom = ', y_bottom
        write(*,*)
        
        ! Step 1: Initial calculations (matching STB exactly)
        x0 = test_edge%fx
        dx = test_edge%fdx
        xb = x0 + dx
        dy = test_edge%fdy
        
        write(*,*) 'Step 1: Initial calculations'
        write(*,'(A,F10.6)') '  x0 = edge.fx = ', x0
        write(*,'(A,F10.6)') '  dx = edge.fdx = ', dx  
        write(*,'(A,F10.6)') '  xb = x0 + dx = ', xb
        write(*,'(A,F10.6)') '  dy = edge.fdy = ', dy
        write(*,*)
        
        ! Step 2: Compute endpoints (STB lines 3114-3127)
        if (test_edge%sy > y_top) then
            x_top = x0 + dx * (test_edge%sy - y_top)
            sy0 = test_edge%sy
        else
            x_top = x0
            sy0 = y_top
        end if
        
        if (test_edge%ey < y_bottom) then
            x_bottom = x0 + dx * (test_edge%ey - y_top)
            sy1 = test_edge%ey
        else
            x_bottom = xb
            sy1 = y_bottom
        end if
        
        write(*,*) 'Step 2: Endpoint calculations'
        write(*,'(A,F10.6)') '  x_top    = ', x_top
        write(*,'(A,F10.6)') '  x_bottom = ', x_bottom
        write(*,'(A,F10.6)') '  sy0      = ', sy0
        write(*,'(A,F10.6)') '  sy1      = ', sy1
        write(*,*)
        
        ! Step 3: Check if single pixel case (STB line 3132)
        if (int(x_top) == int(x_bottom)) then
            write(*,*) 'Step 3: Single pixel case detected'
            write(*,'(A,I3)') '  pixel_x = ', int(x_top)
            
            height = (sy1 - sy0) * test_edge%direction
            write(*,'(A,F10.6)') '  height = (sy1 - sy0) * direction = ', height
            
            ! STB: scanline[x] += stbtt__position_trapezoid_area(height, x_top, x+1.0f, x_bottom, x+1.0f);
            area = stb_position_trapezoid_area(height, x_top, real(int(x_top) + 1, wp), x_bottom, real(int(x_top) + 1, wp))
            write(*,'(A,F10.6)') '  area = position_trapezoid_area(...) = ', area
            write(*,*)
            
            write(*,*) 'CRITICAL: This should be scanline[8] contribution'
            write(*,'(A,F10.6)') '  Expected ForTTF result: ', area
            write(*,'(A,F10.6)') '  Actual ForTTF result:   ', 0.725000_wp
            write(*,'(A,F10.6)') '  Difference:             ', abs(area - 0.725000_wp)
            
        else
            write(*,*) 'Step 3: Multi-pixel case'
            x1 = int(x_top)
            x2 = int(x_bottom)
            write(*,'(A,I3,A,I3)') '  x1 = ', x1, ', x2 = ', x2
            write(*,*) '  (This case not expected for current test edge)'
        end if
        
    end subroutine test_step_by_step_area_calculation

end program test_forttf_area_calculation_debug