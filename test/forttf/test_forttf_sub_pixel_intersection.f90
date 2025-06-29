program test_forttf_sub_pixel_intersection
    !! Sub-pixel intersection precision test
    !! Tests edge intersection at sub-pixel boundaries
    !! Compares floating-point precision with STB float precision
    !! Focus on boundary condition handling and precision differences
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    real(wp), parameter :: PRECISION_THRESHOLD = 1.0e-10_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: precision_issues = 0

    write(*,*) '🧪 Testing sub-pixel intersection precision'
    write(*,*) '========================================'
    write(*,*)

    ! Test 1: Sub-pixel boundary intersections
    call test_sub_pixel_boundaries()

    ! Test 2: Floating-point precision limits
    call test_floating_point_precision()

    ! Test 3: Edge intersection calculations
    call test_edge_intersections()

    ! Test 4: Double vs float precision
    call test_double_vs_float_precision()

    ! Test 5: Accumulation precision
    call test_accumulation_precision()

    ! Test 6: Critical anti-aliasing cases
    call test_critical_anti_aliasing_cases()

    ! Summary
    write(*,*)
    write(*,*) '📊 Test Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Precision issues found: ', precision_issues
    if (pass_count == test_count .and. precision_issues == 0) then
        write(*,*) '✅ All sub-pixel intersection tests PASSED'
    else
        write(*,*) '❌ Sub-pixel intersection tests revealed issues'
        if (precision_issues > 0) then
            write(*,*) '⚠️  Precision differences detected in sub-pixel calculations!'
        end if
        stop 1
    end if

contains

    subroutine test_sub_pixel_boundaries()
        !! Test intersections at exact sub-pixel boundaries
        real(wp) :: x_intersection, y_intersection
        real(wp) :: x0, y0, x1, y1, target_y, target_x
        integer :: i

        write(*,*) '  Testing sub-pixel boundary intersections...'
        
        ! Test edge crossing at various sub-pixel positions
        do i = 1, 100
            ! Create edge from (0.1, 0.0) to (0.9, 1.0)
            x0 = 0.1_wp
            y0 = 0.0_wp
            x1 = 0.9_wp
            y1 = 1.0_wp
            
            ! Test intersection at sub-pixel Y positions
            target_y = real(i, wp) * 0.01_wp  ! 0.01 to 1.0
            
            ! Calculate X intersection at target Y
            x_intersection = x0 + (x1 - x0) * (target_y - y0) / (y1 - y0)
            
            ! Check precision
            if (x_intersection < 0.0_wp .or. x_intersection > 1.0_wp) then
                precision_issues = precision_issues + 1
                write(*,'(A,F8.5,A,F8.5)') &
                    '    ⚠️  X intersection out of bounds: ', x_intersection, ' at Y=', target_y
            end if
            
            ! Test intersection at sub-pixel X positions
            target_x = real(i, wp) * 0.01_wp  ! 0.01 to 1.0
            
            ! Calculate Y intersection at target X (only if X is within edge range)
            if (abs(x1 - x0) > PRECISION_THRESHOLD .and. &
                target_x >= min(x0, x1) .and. target_x <= max(x0, x1)) then
                y_intersection = y0 + (y1 - y0) * (target_x - x0) / (x1 - x0)
                
                if (y_intersection < -TOLERANCE .or. y_intersection > 1.0_wp + TOLERANCE) then
                    precision_issues = precision_issues + 1
                    write(*,'(A,F8.5,A,F8.5)') &
                        '    ⚠️  Y intersection out of bounds: ', y_intersection, ' at X=', target_x
                end if
            end if
        end do
        
        call record_test("Sub-pixel boundaries", .true.)
    end subroutine

    subroutine test_floating_point_precision()
        !! Test floating-point precision limits
        real(wp) :: diff, expected, calculated
        real(wp) :: height, width
        integer :: i

        write(*,*) '  Testing floating-point precision limits...'
        
        ! Test area calculations with very small values
        do i = 1, 50
            height = 10.0_wp ** (-real(i, wp) / 5.0_wp)  ! 10^-0.2 to 10^-10
            width = 10.0_wp ** (-real(i, wp) / 5.0_wp)
            
            calculated = stb_sized_triangle_area(height, width)
            expected = 0.5_wp * height * width  ! Analytical triangle area
            
            if (abs(height * width) > PRECISION_THRESHOLD) then
                diff = abs(calculated - expected)
                if (diff > TOLERANCE * abs(expected)) then
                    precision_issues = precision_issues + 1
                    write(*,'(A,ES10.3,A,ES10.3,A,ES10.3)') &
                        '    ⚠️  Precision loss: diff=', diff, ' h=', height, ' w=', width
                end if
            end if
        end do
        
        call record_test("Floating-point precision", .true.)
    end subroutine

    subroutine test_edge_intersections()
        !! Test edge intersection calculations similar to anti-aliasing
        real(wp) :: x_start, x_end, y_start, y_end
        real(wp) :: pixel_y, intersection_x
        real(wp) :: coverage
        integer :: i

        write(*,*) '  Testing edge intersection calculations...'
        
        ! Test scenarios similar to those causing over/under-estimation
        do i = 1, 20
            ! Various edge slopes
            x_start = real(i, wp) * 0.05_wp  ! 0.05 to 1.0
            y_start = 0.0_wp
            x_end = x_start + 0.5_wp
            y_end = 1.0_wp
            
            ! Test intersection at pixel boundary
            pixel_y = 0.5_wp
            
            if (abs(y_end - y_start) > PRECISION_THRESHOLD) then
                intersection_x = x_start + (x_end - x_start) * (pixel_y - y_start) / (y_end - y_start)
                
                ! Calculate simple coverage (this is not exact STB algorithm)
                if (intersection_x >= real(int(intersection_x), wp) .and. &
                    intersection_x <= real(int(intersection_x) + 1, wp)) then
                    coverage = 1.0_wp - (intersection_x - real(int(intersection_x), wp))
                    
                    ! Check coverage bounds
                    if (coverage < -TOLERANCE .or. coverage > 1.0_wp + TOLERANCE) then
                        precision_issues = precision_issues + 1
                        write(*,'(A,F8.5,A,F8.5)') &
                            '    ⚠️  Coverage out of bounds: ', coverage, ' at X=', intersection_x
                    end if
                end if
            end if
        end do
        
        call record_test("Edge intersections", .true.)
    end subroutine

    subroutine test_double_vs_float_precision()
        !! Test differences between double and float precision
        real(wp) :: double_result
        real(c_float) :: float_input, float_result
        real(wp) :: precision_diff
        integer :: i

        write(*,*) '  Testing double vs float precision differences...'
        
        ! Test area calculations with float vs double precision
        do i = 1, 50
            ! Use values that might cause precision differences
            float_input = real(i, c_float) * 0.02_c_float  ! 0.02 to 1.0
            
            ! Calculate using our double precision
            double_result = stb_sized_triangle_area(real(float_input, wp), real(float_input, wp))
            
            ! Calculate using float precision (simulate STB)
            float_result = 0.5_c_float * float_input * float_input
            
            precision_diff = abs(double_result - real(float_result, wp))
            
            ! Check if precision difference is significant
            if (precision_diff > TOLERANCE .and. abs(double_result) > PRECISION_THRESHOLD) then
                precision_issues = precision_issues + 1
                write(*,'(A,ES10.3,A,F8.5,A,F8.5)') &
                    '    ⚠️  Double/float diff: ', precision_diff, &
                    ' double=', double_result, ' float=', float_result
            end if
        end do
        
        call record_test("Double vs float precision", .true.)
    end subroutine

    subroutine test_accumulation_precision()
        !! Test precision in accumulation operations
        real(wp) :: accumulator, increment
        real(wp) :: expected, actual
        integer :: i

        write(*,*) '  Testing accumulation precision...'
        
        ! Test accumulation similar to scanline filling
        accumulator = 0.0_wp
        do i = 1, 1000
            increment = 0.001_wp  ! Small increment
            accumulator = accumulator + increment
        end do
        
        expected = 1.0_wp
        actual = accumulator
        
        if (abs(actual - expected) > TOLERANCE) then
            precision_issues = precision_issues + 1
            write(*,'(A,ES10.3,A,F10.7,A,F10.7)') &
                '    ⚠️  Accumulation error: ', abs(actual - expected), &
                ' expected=', expected, ' actual=', actual
        end if
        
        call record_test("Accumulation precision", .true.)
    end subroutine

    subroutine test_critical_anti_aliasing_cases()
        !! Test cases that might cause the anti-aliasing differences we observe
        real(wp) :: area1, area2, area3
        
        write(*,*) '  Testing critical anti-aliasing cases...'
        
        ! Case 1: Over-saturation scenario (Pure=255, STB=65)
        area1 = stb_sized_trapezoid_area(0.9_wp, 0.8_wp, 0.2_wp)
        if (area1 > 1.0_wp) then
            precision_issues = precision_issues + 1
            write(*,'(A,F8.5)') '    ⚠️  Over-saturation case: area=', area1
        end if
        
        ! Case 2: Under-estimation scenario (Pure=52, STB=203)
        area2 = stb_sized_triangle_area(0.3_wp, 0.1_wp)
        if (area2 < 0.01_wp .and. area2 > 0.0_wp) then
            write(*,'(A,F8.5)') '    Info: Small area calculated: ', area2
        end if
        
        ! Case 3: Edge boundary precision
        area3 = stb_position_trapezoid_area(1.0_wp, 0.999_wp, 1.001_wp, 0.999_wp, 1.001_wp)
        write(*,'(A,F8.5)') '    Info: Boundary area: ', area3
        
        call record_test("Critical anti-aliasing cases", .true.)
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

end program test_forttf_sub_pixel_intersection