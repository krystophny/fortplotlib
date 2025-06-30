program test_forttf_precision_comparison
    !! Compare STB C float precision vs Fortran real64 precision
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
    implicit none

    call test_float_precision_differences()
    
contains

    subroutine test_float_precision_differences()
        real(real32) :: c_float_x0, c_float_dx, c_float_result
        real(wp) :: fortran_x0, fortran_dx, fortran_result
        real(wp) :: y_top, y_bottom
        
        write(*,*) '=== FLOATING-POINT PRECISION COMPARISON ==='
        write(*,*) 'Testing exact calculations from problematic pixels'
        write(*,*)
        
        ! Use values from the debug output that showed divergence
        ! These are approximate values from the edge that caused Row 5 Col 8 issue
        fortran_x0 = 8.5_wp
        fortran_dx = 0.15_wp
        y_top = 5.0_wp
        y_bottom = 6.0_wp
        
        ! Convert to C float precision
        c_float_x0 = real(fortran_x0, real32)
        c_float_dx = real(fortran_dx, real32)
        
        ! Test key calculation from STB: x_top = x0 + dx * (y - y_top)
        fortran_result = fortran_x0 + fortran_dx * (5.2_wp - y_top)
        c_float_result = c_float_x0 + c_float_dx * (real(5.2_wp, real32) - real(y_top, real32))
        
        write(*,'(A,F20.12)') 'Fortran real64 calculation: ', fortran_result
        write(*,'(A,F20.12)') 'C float precision:         ', real(c_float_result, wp)
        write(*,'(A,E15.6)') 'Difference:                ', abs(fortran_result - real(c_float_result, wp))
        write(*,*)
        
        ! Test area calculation that diverges
        fortran_result = (8.8_wp - 8.5_wp) * 0.3_wp / 2.0_wp  ! Triangle area
        c_float_result = (real(8.8_wp, real32) - real(8.5_wp, real32)) * real(0.3_wp, real32) / 2.0_real32
        
        write(*,'(A,F20.12)') 'Fortran triangle area:     ', fortran_result
        write(*,'(A,F20.12)') 'C float triangle area:     ', real(c_float_result, wp)
        write(*,'(A,E15.6)') 'Difference:                ', abs(fortran_result - real(c_float_result, wp))
        write(*,*)
        
        ! Test the problematic scanline buffer value from debug output
        write(*,*) 'CRITICAL TEST: Row 5 Col 8 problematic calculation'
        write(*,'(A,F12.6)') 'ForTTF produced k=', -1.175017_wp
        write(*,'(A,I3)') 'ForTTF final pixel=', int(abs(-1.175017_wp) * 255.0_wp + 0.5_wp)
        write(*,'(A,I3)') 'STB expected final=', 114
        write(*,*)
        
        ! Reverse engineer what STB k value would produce 114
        write(*,'(A,F12.6)') 'STB k to produce 114:', 114.0_wp / 255.0_wp
        write(*,'(A,F12.6)') 'Difference in k values:', abs(-1.175017_wp) - (114.0_wp / 255.0_wp)
        
    end subroutine test_float_precision_differences

end program test_forttf_precision_comparison