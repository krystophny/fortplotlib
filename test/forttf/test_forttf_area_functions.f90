program test_forttf_area_functions
    !! Test individual STB area calculation functions against C reference
    use forttf_stb_raster, only: stb_sized_trapezoid_area, stb_position_trapezoid_area, &
                                stb_sized_triangle_area
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    interface
        ! C wrapper functions for STB reference
        function stb_test_sized_trapezoid_area(height, top_width, bottom_width) bind(C, name="stb_test_sized_trapezoid_area")
            import :: c_float
            real(c_float), value :: height, top_width, bottom_width
            real(c_float) :: stb_test_sized_trapezoid_area
        end function
        
        function stb_test_position_trapezoid_area(height, tx0, tx1, bx0, bx1) bind(C, name="stb_test_position_trapezoid_area")
            import :: c_float
            real(c_float), value :: height, tx0, tx1, bx0, bx1
            real(c_float) :: stb_test_position_trapezoid_area
        end function
        
        function stb_test_sized_triangle_area(height, width) bind(C, name="stb_test_sized_triangle_area")
            import :: c_float
            real(c_float), value :: height, width
            real(c_float) :: stb_test_sized_triangle_area
        end function
    end interface

    logical :: all_passed

    all_passed = .true.
    
    ! Test each area calculation function against STB C reference
    call test_sized_trapezoid_area_vs_stb(all_passed)
    call test_position_trapezoid_area_vs_stb(all_passed)
    call test_sized_triangle_area_vs_stb(all_passed)

    if (all_passed) then
        print *, "✅ All STB area calculation tests passed!"
    else
        print *, "❌ Some STB area calculation tests failed!"
        error stop 1
    end if

contains

    subroutine test_sized_trapezoid_area_vs_stb(passed)
        logical, intent(inout) :: passed
        real(wp) :: fortran_result, stb_result
        real(wp), parameter :: tolerance = 1.0e-6_wp
        
        print *, "Testing stb_sized_trapezoid_area vs STB C reference..."
        
        ! Test case 1: Rectangle (top_width = bottom_width)
        fortran_result = stb_sized_trapezoid_area(2.0_wp, 3.0_wp, 3.0_wp)
        stb_result = real(stb_test_sized_trapezoid_area(2.0, 3.0, 3.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Rectangle test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Rectangle test passed (", fortran_result, ")"
        end if
        
        ! Test case 2: True trapezoid
        fortran_result = stb_sized_trapezoid_area(2.0_wp, 1.0_wp, 3.0_wp)
        stb_result = real(stb_test_sized_trapezoid_area(2.0, 1.0, 3.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Trapezoid test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Trapezoid test passed (", fortran_result, ")"
        end if
        
        ! Test case 3: Zero height
        fortran_result = stb_sized_trapezoid_area(0.0_wp, 5.0_wp, 10.0_wp)
        stb_result = real(stb_test_sized_trapezoid_area(0.0, 5.0, 10.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Zero height test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Zero height test passed (", fortran_result, ")"
        end if
        
    end subroutine test_sized_trapezoid_area_vs_stb

    subroutine test_position_trapezoid_area_vs_stb(passed)
        logical, intent(inout) :: passed
        real(wp) :: fortran_result, stb_result
        real(wp), parameter :: tolerance = 1.0e-6_wp
        
        print *, "Testing stb_position_trapezoid_area vs STB C reference..."
        
        ! Test case 1: Simple positioned trapezoid
        fortran_result = stb_position_trapezoid_area(2.0_wp, 1.0_wp, 4.0_wp, 0.0_wp, 5.0_wp)
        stb_result = real(stb_test_position_trapezoid_area(2.0, 1.0, 4.0, 0.0, 5.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Positioned trapezoid test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Positioned trapezoid test passed (", fortran_result, ")"
        end if
        
        ! Test case 2: Zero width at top
        fortran_result = stb_position_trapezoid_area(1.0_wp, 2.0_wp, 2.0_wp, 0.0_wp, 4.0_wp)
        stb_result = real(stb_test_position_trapezoid_area(1.0, 2.0, 2.0, 0.0, 4.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Zero top width test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Zero top width test passed (", fortran_result, ")"
        end if
        
    end subroutine test_position_trapezoid_area_vs_stb

    subroutine test_sized_triangle_area_vs_stb(passed)
        logical, intent(inout) :: passed
        real(wp) :: fortran_result, stb_result
        real(wp), parameter :: tolerance = 1.0e-6_wp
        
        print *, "Testing stb_sized_triangle_area vs STB C reference..."
        
        ! Test case 1: Standard triangle
        fortran_result = stb_sized_triangle_area(4.0_wp, 6.0_wp)
        stb_result = real(stb_test_sized_triangle_area(4.0, 6.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Standard triangle test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Standard triangle test passed (", fortran_result, ")"
        end if
        
        ! Test case 2: Unit triangle
        fortran_result = stb_sized_triangle_area(1.0_wp, 2.0_wp)
        stb_result = real(stb_test_sized_triangle_area(1.0, 2.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Unit triangle test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Unit triangle test passed (", fortran_result, ")"
        end if
        
        ! Test case 3: Zero dimensions
        fortran_result = stb_sized_triangle_area(0.0_wp, 5.0_wp)
        stb_result = real(stb_test_sized_triangle_area(0.0, 5.0), wp)
        if (abs(fortran_result - stb_result) > tolerance) then
            print *, "❌ Zero height triangle test failed: Fortran=", fortran_result, "STB=", stb_result
            passed = .false.
        else
            print *, "✅ Zero height triangle test passed (", fortran_result, ")"
        end if
        
    end subroutine test_sized_triangle_area_vs_stb

end program test_forttf_area_functions
