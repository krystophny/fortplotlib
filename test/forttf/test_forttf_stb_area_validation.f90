program test_forttf_stb_area_validation
    !! Test STB area calculation functions against actual STB C implementation
    use forttf_stb_raster, only: stb_sized_trapezoid_area, stb_position_trapezoid_area, &
                                stb_sized_triangle_area
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! Interface to STB C test functions
    interface
        function stb_test_sized_trapezoid_area(height, top_width, bottom_width) bind(c)
            import :: c_float
            real(c_float), value :: height, top_width, bottom_width
            real(c_float) :: stb_test_sized_trapezoid_area
        end function stb_test_sized_trapezoid_area

        function stb_test_position_trapezoid_area(height, tx0, tx1, bx0, bx1) bind(c)
            import :: c_float
            real(c_float), value :: height, tx0, tx1, bx0, bx1
            real(c_float) :: stb_test_position_trapezoid_area
        end function stb_test_position_trapezoid_area

        function stb_test_sized_triangle_area(height, width) bind(c)
            import :: c_float
            real(c_float), value :: height, width
            real(c_float) :: stb_test_sized_triangle_area
        end function stb_test_sized_triangle_area
    end interface

    logical :: all_passed

    all_passed = .true.
    
    print *, "=== Testing Fortran implementations against STB C reference ==="
    
    ! Test each area calculation function against STB
    call test_sized_trapezoid_area_vs_stb(all_passed)
    call test_position_trapezoid_area_vs_stb(all_passed)
    call test_sized_triangle_area_vs_stb(all_passed)

    if (all_passed) then
        print *, "✅ All STB area calculation validation tests passed!"
        print *, "   Fortran implementations match STB C reference exactly."
    else
        print *, "❌ Some STB area calculation validation tests failed!"
        print *, "   Fortran implementations do NOT match STB C reference."
        error stop 1
    end if

contains

    subroutine test_sized_trapezoid_area_vs_stb(passed)
        logical, intent(inout) :: passed
        real(wp) :: fortran_result
        real(c_float) :: stb_result
        real(wp), parameter :: tolerance = 1.0e-6_wp
        integer :: test_case
        
        real(wp), parameter :: test_heights(5) = [0.0_wp, 1.0_wp, 2.0_wp, 0.5_wp, 10.0_wp]
        real(wp), parameter :: test_top_widths(5) = [1.0_wp, 3.0_wp, 1.0_wp, 0.0_wp, 5.0_wp]
        real(wp), parameter :: test_bottom_widths(5) = [1.0_wp, 3.0_wp, 3.0_wp, 4.0_wp, 5.0_wp]
        
        print *, "Testing stb_sized_trapezoid_area vs STB C reference..."
        
        do test_case = 1, 5
            ! Call Fortran implementation
            fortran_result = stb_sized_trapezoid_area(test_heights(test_case), &
                                                     test_top_widths(test_case), &
                                                     test_bottom_widths(test_case))
            
            ! Call STB C reference
            stb_result = stb_test_sized_trapezoid_area(real(test_heights(test_case), c_float), &
                                                      real(test_top_widths(test_case), c_float), &
                                                      real(test_bottom_widths(test_case), c_float))
            
            if (abs(fortran_result - real(stb_result, wp)) > tolerance) then
                print '(A,I0,A,F0.6,A,F0.6)', "❌ Test case ", test_case, " failed: Fortran=", &
                      fortran_result, ", STB=", real(stb_result, wp)
                print '(A,3F0.3)', "   Inputs: height=", test_heights(test_case), &
                      " top_width=", test_top_widths(test_case), &
                      " bottom_width=", test_bottom_widths(test_case)
                passed = .false.
            else
                print '(A,I0,A)', "✅ Test case ", test_case, " passed"
            end if
        end do
        
    end subroutine test_sized_trapezoid_area_vs_stb

    subroutine test_position_trapezoid_area_vs_stb(passed)
        logical, intent(inout) :: passed
        real(wp) :: fortran_result
        real(c_float) :: stb_result
        real(wp), parameter :: tolerance = 1.0e-6_wp
        integer :: test_case
        
        real(wp), parameter :: test_heights(4) = [1.0_wp, 2.0_wp, 0.5_wp, 3.0_wp]
        real(wp), parameter :: test_tx0(4) = [1.0_wp, 0.0_wp, 2.0_wp, -1.0_wp]
        real(wp), parameter :: test_tx1(4) = [4.0_wp, 2.0_wp, 2.0_wp, 2.0_wp]
        real(wp), parameter :: test_bx0(4) = [0.0_wp, -1.0_wp, 0.0_wp, -2.0_wp]
        real(wp), parameter :: test_bx1(4) = [5.0_wp, 4.0_wp, 4.0_wp, 3.0_wp]
        
        print *, "Testing stb_position_trapezoid_area vs STB C reference..."
        
        do test_case = 1, 4
            ! Call Fortran implementation
            fortran_result = stb_position_trapezoid_area(test_heights(test_case), &
                                                        test_tx0(test_case), test_tx1(test_case), &
                                                        test_bx0(test_case), test_bx1(test_case))
            
            ! Call STB C reference
            stb_result = stb_test_position_trapezoid_area(real(test_heights(test_case), c_float), &
                                                         real(test_tx0(test_case), c_float), &
                                                         real(test_tx1(test_case), c_float), &
                                                         real(test_bx0(test_case), c_float), &
                                                         real(test_bx1(test_case), c_float))
            
            if (abs(fortran_result - real(stb_result, wp)) > tolerance) then
                print '(A,I0,A,F0.6,A,F0.6)', "❌ Test case ", test_case, " failed: Fortran=", &
                      fortran_result, ", STB=", real(stb_result, wp)
                print '(A,5F0.3)', "   Inputs: height=", test_heights(test_case), &
                      " tx0=", test_tx0(test_case), " tx1=", test_tx1(test_case), &
                      " bx0=", test_bx0(test_case), " bx1=", test_bx1(test_case)
                passed = .false.
            else
                print '(A,I0,A)', "✅ Test case ", test_case, " passed"
            end if
        end do
        
    end subroutine test_position_trapezoid_area_vs_stb

    subroutine test_sized_triangle_area_vs_stb(passed)
        logical, intent(inout) :: passed
        real(wp) :: fortran_result
        real(c_float) :: stb_result
        real(wp), parameter :: tolerance = 1.0e-6_wp
        integer :: test_case
        
        real(wp), parameter :: test_heights(4) = [0.0_wp, 1.0_wp, 4.0_wp, 2.5_wp]
        real(wp), parameter :: test_widths(4) = [5.0_wp, 2.0_wp, 6.0_wp, 1.0_wp]
        
        print *, "Testing stb_sized_triangle_area vs STB C reference..."
        
        do test_case = 1, 4
            ! Call Fortran implementation
            fortran_result = stb_sized_triangle_area(test_heights(test_case), test_widths(test_case))
            
            ! Call STB C reference
            stb_result = stb_test_sized_triangle_area(real(test_heights(test_case), c_float), &
                                                     real(test_widths(test_case), c_float))
            
            if (abs(fortran_result - real(stb_result, wp)) > tolerance) then
                print '(A,I0,A,F0.6,A,F0.6)', "❌ Test case ", test_case, " failed: Fortran=", &
                      fortran_result, ", STB=", real(stb_result, wp)
                print '(A,2F0.3)', "   Inputs: height=", test_heights(test_case), &
                      " width=", test_widths(test_case)
                passed = .false.
            else
                print '(A,I0,A)', "✅ Test case ", test_case, " passed"
            end if
        end do
        
    end subroutine test_sized_triangle_area_vs_stb

end program test_forttf_stb_area_validation
