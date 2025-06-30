program test_stb_direct_comparison
    !! Direct comparison with actual STB C functions
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
    implicit none

    interface
        subroutine stb_edge_debug_c(fx, fdx, fdy, direction, sy, ey, y_top, y_bottom) bind(c)
            import :: c_float
            real(c_float), intent(in) :: fx, fdx, fdy, direction, sy, ey, y_top, y_bottom
        end subroutine stb_edge_debug_c
    end interface

    call test_actual_stb_functions()
    
contains

    subroutine test_actual_stb_functions()
        ! Call actual STB C functions with exact problematic edge parameters
        real(c_float) :: fx, fdx, fdy, direction, sy, ey, y_top, y_bottom
        
        write(*,*) '=== CALLING ACTUAL STB C FUNCTIONS ==='
        write(*,*) 'Testing exact problematic edge with real STB implementation'
        write(*,*)
        
        ! Exact parameters from debug output (converted to C float)
        fx = real(8.827_wp, c_float)
        fdx = real(-0.003_wp, c_float)
        fdy = real(-301.000_wp, c_float)
        direction = real(-1.000_wp, c_float)
        sy = real(-6.020_wp, c_float)
        ey = real(0.000_wp, c_float)
        y_top = real(-2.0_wp, c_float)
        y_bottom = real(-1.0_wp, c_float)
        
        write(*,*) 'Calling STB C wrapper...'
        call stb_edge_debug_c(fx, fdx, fdy, direction, sy, ey, y_top, y_bottom)
        
        write(*,*)
        write(*,*) 'This will show us exactly what STB produces for the same edge'
        write(*,*) 'and help identify where ForTTF differs from STB.'
        
    end subroutine test_actual_stb_functions

end program test_stb_direct_comparison