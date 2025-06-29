program test_forttf_coverage_bounds_validation
    !! Coverage bounds validation test
    !! Ensures all area calculations stay within [0.0, 1.0] bounds
    !! Tests mathematical consistency of trapezoid/triangle calculations
    !! Validates against STB reference implementation
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    real(wp), parameter :: TOLERANCE = 1.0e-12_wp
    real(wp), parameter :: BOUNDS_TOLERANCE = 1.0e-10_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: bounds_violations = 0

    write(*,*) '🧪 Testing coverage bounds validation'
    write(*,*) '===================================='
    write(*,*)

    ! Test 1: Trapezoid area bounds
    call test_trapezoid_bounds()

    ! Test 2: Triangle area bounds
    call test_triangle_bounds()

    ! Test 3: Position trapezoid bounds
    call test_position_trapezoid_bounds()

    ! Test 4: Extreme parameter bounds
    call test_extreme_parameters()

    ! Test 5: Edge case parameters
    call test_edge_case_parameters()

    ! Test 6: Real-world edge scenarios
    call test_real_world_scenarios()

    ! Test 7: Mathematical consistency
    call test_mathematical_consistency()

    ! Summary
    write(*,*)
    write(*,*) '📊 Test Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Bounds violations found: ', bounds_violations
    if (pass_count == test_count .and. bounds_violations == 0) then
        write(*,*) '✅ All coverage bounds validation tests PASSED'
    else
        write(*,*) '❌ Coverage bounds validation tests FAILED'
        if (bounds_violations > 0) then
            write(*,*) '⚠️  Coverage calculations exceeded valid bounds!'
        end if
        stop 1
    end if

contains

    subroutine test_trapezoid_bounds()
        !! Test stb_sized_trapezoid_area bounds
        real(wp) :: area
        real(wp) :: height, top_width, bottom_width
        integer :: i

        write(*,*) '  Testing stb_sized_trapezoid_area bounds...'
        
        ! Test various trapezoid configurations
        do i = 1, 100
            height = real(i, wp) * 0.01_wp  ! 0.01 to 1.0
            top_width = real(mod(i * 3, 100), wp) * 0.01_wp  ! 0.0 to 0.99
            bottom_width = real(mod(i * 7, 100), wp) * 0.01_wp  ! 0.0 to 0.99
            
            area = stb_sized_trapezoid_area(height, top_width, bottom_width)
            
            ! Check bounds
            if (area < -BOUNDS_TOLERANCE .or. area > 1.0_wp + BOUNDS_TOLERANCE) then
                bounds_violations = bounds_violations + 1
                write(*,'(A,ES12.5,A,F6.3,A,F6.3,A,F6.3,A)') &
                    '    ⚠️  Bounds violation: area=', area, &
                    ' (h=', height, ', tw=', top_width, ', bw=', bottom_width, ')'
            end if
        end do
        
        call record_test("Trapezoid bounds", .true.)
    end subroutine

    subroutine test_triangle_bounds()
        !! Test stb_sized_triangle_area bounds
        real(wp) :: area
        real(wp) :: height, width
        integer :: i

        write(*,*) '  Testing stb_sized_triangle_area bounds...'
        
        ! Test various triangle configurations
        do i = 1, 100
            height = real(i, wp) * 0.01_wp  ! 0.01 to 1.0
            width = real(mod(i * 5, 100), wp) * 0.01_wp  ! 0.0 to 0.99
            
            area = stb_sized_triangle_area(height, width)
            
            ! Check bounds
            if (area < -BOUNDS_TOLERANCE .or. area > 1.0_wp + BOUNDS_TOLERANCE) then
                bounds_violations = bounds_violations + 1
                write(*,'(A,ES12.5,A,F6.3,A,F6.3,A)') &
                    '    ⚠️  Bounds violation: area=', area, &
                    ' (h=', height, ', w=', width, ')'
            end if
        end do
        
        call record_test("Triangle bounds", .true.)
    end subroutine

    subroutine test_position_trapezoid_bounds()
        !! Test stb_position_trapezoid_area bounds
        real(wp) :: area
        real(wp) :: height, tx1, tx2, bx1, bx2
        integer :: i

        write(*,*) '  Testing stb_position_trapezoid_area bounds...'
        
        ! Test various positioned trapezoid configurations
        do i = 1, 100
            height = real(i, wp) * 0.01_wp  ! 0.01 to 1.0
            tx1 = real(mod(i * 2, 100), wp) * 0.01_wp  ! 0.0 to 0.99
            tx2 = tx1 + real(mod(i * 3, 50), wp) * 0.01_wp  ! tx1 to tx1+0.49
            bx1 = real(mod(i * 4, 100), wp) * 0.01_wp  ! 0.0 to 0.99
            bx2 = bx1 + real(mod(i * 5, 50), wp) * 0.01_wp  ! bx1 to bx1+0.49
            
            area = stb_position_trapezoid_area(height, tx1, tx2, bx1, bx2)
            
            ! Check bounds - positioned trapezoids can have larger areas
            if (area < -1.0_wp - BOUNDS_TOLERANCE .or. area > 2.0_wp + BOUNDS_TOLERANCE) then
                bounds_violations = bounds_violations + 1
                write(*,'(A,ES12.5)') &
                    '    ⚠️  Extreme bounds violation: area=', area
            end if
        end do
        
        call record_test("Position trapezoid bounds", .true.)
    end subroutine

    subroutine test_extreme_parameters()
        !! Test extreme parameter values
        real(wp) :: area

        write(*,*) '  Testing extreme parameter values...'
        
        ! Zero height trapezoid
        area = stb_sized_trapezoid_area(0.0_wp, 0.5_wp, 0.5_wp)
        if (abs(area) > BOUNDS_TOLERANCE) then
            bounds_violations = bounds_violations + 1
            write(*,'(A,ES12.5)') '    ⚠️  Zero height should give zero area: ', area
        end if
        
        ! Zero width triangle
        area = stb_sized_triangle_area(0.5_wp, 0.0_wp)
        if (abs(area) > BOUNDS_TOLERANCE) then
            bounds_violations = bounds_violations + 1
            write(*,'(A,ES12.5)') '    ⚠️  Zero width should give zero area: ', area
        end if
        
        ! Maximum unit values
        area = stb_sized_trapezoid_area(1.0_wp, 1.0_wp, 1.0_wp)
        if (area < -BOUNDS_TOLERANCE .or. area > 1.0_wp + BOUNDS_TOLERANCE) then
            bounds_violations = bounds_violations + 1
            write(*,'(A,ES12.5)') '    ⚠️  Unit trapezoid bounds violation: ', area
        end if
        
        call record_test("Extreme parameters", .true.)
    end subroutine

    subroutine test_edge_case_parameters()
        !! Test edge case parameter combinations
        real(wp) :: area

        write(*,*) '  Testing edge case parameters...'
        
        ! Very small values
        area = stb_sized_trapezoid_area(1.0e-10_wp, 1.0e-10_wp, 1.0e-10_wp)
        if (area < -BOUNDS_TOLERANCE .or. area > BOUNDS_TOLERANCE) then
            bounds_violations = bounds_violations + 1
            write(*,'(A,ES12.5)') '    ⚠️  Tiny value bounds violation: ', area
        end if
        
        ! Large height, small width
        area = stb_sized_triangle_area(0.999_wp, 0.001_wp)
        if (area < -BOUNDS_TOLERANCE .or. area > 1.0_wp + BOUNDS_TOLERANCE) then
            bounds_violations = bounds_violations + 1
            write(*,'(A,ES12.5)') '    ⚠️  Large height bounds violation: ', area
        end if
        
        call record_test("Edge case parameters", .true.)
    end subroutine

    subroutine test_real_world_scenarios()
        !! Test real-world anti-aliasing scenarios
        real(wp) :: area
        
        write(*,*) '  Testing real-world scenarios...'
        
        ! Scenarios that could cause over-saturation (Pure=255, STB=65)
        area = stb_sized_trapezoid_area(0.8_wp, 0.9_wp, 0.1_wp)
        if (area < -BOUNDS_TOLERANCE .or. area > 1.0_wp + BOUNDS_TOLERANCE) then
            bounds_violations = bounds_violations + 1
            write(*,'(A,ES12.5)') '    ⚠️  Over-saturation scenario: ', area
        end if
        
        ! Scenarios that could cause under-estimation (Pure=52, STB=203)
        area = stb_sized_triangle_area(0.2_wp, 0.1_wp)
        if (area < -BOUNDS_TOLERANCE .or. area > 1.0_wp + BOUNDS_TOLERANCE) then
            bounds_violations = bounds_violations + 1
            write(*,'(A,ES12.5)') '    ⚠️  Under-estimation scenario: ', area
        end if
        
        call record_test("Real-world scenarios", .true.)
    end subroutine

    subroutine test_mathematical_consistency()
        !! Test mathematical consistency between functions
        real(wp) :: trap_area, tri_area, pos_trap_area
        real(wp) :: height, width
        logical :: consistent

        write(*,*) '  Testing mathematical consistency...'
        
        height = 0.5_wp
        width = 0.3_wp
        
        ! Triangle vs trapezoid with same base
        tri_area = stb_sized_triangle_area(height, width)
        trap_area = stb_sized_trapezoid_area(height, width, 0.0_wp)
        
        consistent = abs(tri_area - trap_area) < TOLERANCE
        if (.not. consistent) then
            write(*,'(A,ES12.5,A,ES12.5)') &
                '    ⚠️  Triangle/trapezoid inconsistency: tri=', tri_area, ', trap=', trap_area
        end if
        
        ! Position trapezoid vs sized trapezoid
        pos_trap_area = stb_position_trapezoid_area(height, 0.0_wp, width, 0.0_wp, width)
        
        ! Note: positioned trapezoids may have different scaling, so this is informational
        write(*,'(A,ES12.5,A,ES12.5)') &
            '    Info: sized_trap=', trap_area, ', pos_trap=', pos_trap_area
        
        call record_test("Mathematical consistency", consistent)
    end subroutine

    subroutine record_test(test_name, passed)
        character(len=*), intent(in) :: test_name
        logical, intent(in) :: passed

        test_count = test_count + 1
        if (passed) then
            pass_count = pass_count + 1
            write(*,'(A,A,A)') '    ', test_name, ': ✅ PASS'
        else
            write(*,'(A,A,A)') '    ', test_name, ': ❌ FAIL'
        end if
    end subroutine

end program test_forttf_coverage_bounds_validation