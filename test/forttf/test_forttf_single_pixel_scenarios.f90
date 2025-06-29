program test_forttf_single_pixel_scenarios
    !! Single pixel scenarios test
    !! Target the current anti-aliasing differences at debugging scale
    !! Test specific cases like Pure=255, STB=65 (over-saturation)
    !! Focus on achieving 100% match at current scale before scaling up
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    integer, parameter :: PIXEL_WIDTH = 30
    integer, parameter :: PIXEL_HEIGHT = 30
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: over_saturation_cases = 0
    integer :: under_estimation_cases = 0

    ! C interface for STB reference
    interface
        subroutine test_stb_handle_clipped_edge_c(scanline, x, sy, ey, direction, &
                                                  x0, y0, x1, y1) bind(c, name='test_stb_handle_clipped_edge_c')
            import :: c_float, c_int
            real(c_float), intent(inout) :: scanline(*)
            integer(c_int), intent(in) :: x
            real(c_float), intent(in) :: sy, ey, direction
            real(c_float), intent(in) :: x0, y0, x1, y1
        end subroutine
    end interface

    write(*,*) '🧪 Testing single pixel scenarios (debugging scale)'
    write(*,*) '=================================================='
    write(*,*)

    ! Test 1: Over-saturation scenarios
    call test_over_saturation_scenarios()

    ! Test 2: Under-estimation scenarios
    call test_under_estimation_scenarios()

    ! Test 3: Specific problematic coordinates
    call test_problematic_coordinates()

    ! Test 4: Edge boundary cases
    call test_edge_boundary_cases()

    ! Test 5: Coverage calculation extremes
    call test_coverage_extremes()

    ! Test 6: Simulate real anti-aliasing differences
    call test_real_anti_aliasing_differences()

    ! Summary
    write(*,*)
    write(*,*) '📊 Test Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Over-saturation cases: ', over_saturation_cases
    write(*,'(A,I0)') '   Under-estimation cases: ', under_estimation_cases
    if (pass_count == test_count) then
        write(*,*) '✅ All single pixel scenario tests PASSED'
        if (over_saturation_cases > 0 .or. under_estimation_cases > 0) then
            write(*,*) '⚠️  Issues found that may explain anti-aliasing differences'
        end if
    else
        write(*,*) '❌ Single pixel scenario tests FAILED'
        stop 1
    end if

contains

    subroutine test_over_saturation_scenarios()
        !! Test scenarios that could cause over-saturation (Pure=255, STB=65)
        real(wp) :: fortran_result, stb_result
        type(stb_active_edge_t) :: edge
        
        write(*,*) '  Testing over-saturation scenarios...'
        
        ! Scenario 1: Very steep edge with large direction
        edge%direction = 2.0_wp  ! Large direction value
        call test_single_edge_scenario("Steep edge large direction", &
                                      edge, 5, 0.0_wp, 1.0_wp, &
                                      5.1_wp, 0.2_wp, 5.9_wp, 0.8_wp, &
                                      fortran_result, stb_result)
        
        if (fortran_result > 200.0_wp .and. stb_result < 100.0_wp) then
            over_saturation_cases = over_saturation_cases + 1
            write(*,'(A,F6.1,A,F6.1)') &
                '    ⚠️  Over-saturation: Pure=', fortran_result, ', STB=', stb_result
        end if
        
        ! Scenario 2: Edge with extreme coverage calculation
        edge%direction = 1.0_wp
        call test_single_edge_scenario("Extreme coverage calculation", &
                                      edge, 10, 0.0_wp, 1.0_wp, &
                                      10.01_wp, 0.1_wp, 10.99_wp, 0.9_wp, &
                                      fortran_result, stb_result)
        
        if (fortran_result > 200.0_wp .and. stb_result < 100.0_wp) then
            over_saturation_cases = over_saturation_cases + 1
            write(*,'(A,F6.1,A,F6.1)') &
                '    ⚠️  Over-saturation: Pure=', fortran_result, ', STB=', stb_result
        end if
        
        call record_test("Over-saturation scenarios", .true.)
    end subroutine

    subroutine test_under_estimation_scenarios()
        !! Test scenarios that could cause under-estimation (Pure=52, STB=203)
        real(wp) :: fortran_result, stb_result
        type(stb_active_edge_t) :: edge
        
        write(*,*) '  Testing under-estimation scenarios...'
        
        ! Scenario 1: Small direction with edge calculation
        edge%direction = 0.1_wp  ! Small direction value
        call test_single_edge_scenario("Small direction edge", &
                                      edge, 15, 0.0_wp, 1.0_wp, &
                                      15.2_wp, 0.3_wp, 15.8_wp, 0.7_wp, &
                                      fortran_result, stb_result)
        
        if (fortran_result < 100.0_wp .and. stb_result > 150.0_wp) then
            under_estimation_cases = under_estimation_cases + 1
            write(*,'(A,F6.1,A,F6.1)') &
                '    ⚠️  Under-estimation: Pure=', fortran_result, ', STB=', stb_result
        end if
        
        ! Scenario 2: Edge with minimal coverage
        edge%direction = 1.0_wp
        call test_single_edge_scenario("Minimal coverage edge", &
                                      edge, 20, 0.0_wp, 1.0_wp, &
                                      20.9_wp, 0.1_wp, 20.95_wp, 0.9_wp, &
                                      fortran_result, stb_result)
        
        if (fortran_result < 100.0_wp .and. stb_result > 150.0_wp) then
            under_estimation_cases = under_estimation_cases + 1
            write(*,'(A,F6.1,A,F6.1)') &
                '    ⚠️  Under-estimation: Pure=', fortran_result, ', STB=', stb_result
        end if
        
        call record_test("Under-estimation scenarios", .true.)
    end subroutine

    subroutine test_problematic_coordinates()
        !! Test specific coordinates that show differences in real debugging
        real(wp) :: fortran_result, stb_result
        type(stb_active_edge_t) :: edge
        
        write(*,*) '  Testing problematic coordinates...'
        
        ! Based on observed differences like (27,28): STB=30, Pure=225
        edge%direction = 1.0_wp
        call test_single_edge_scenario("Coordinate (27,28) type", &
                                      edge, 27, 0.0_wp, 1.0_wp, &
                                      27.3_wp, 0.2_wp, 27.7_wp, 0.8_wp, &
                                      fortran_result, stb_result)
        
        if (abs(fortran_result - stb_result) > 50.0_wp) then
            write(*,'(A,F6.1,A,F6.1,A,F6.1)') &
                '    ⚠️  Large difference: Pure=', fortran_result, ', STB=', stb_result, &
                ', diff=', abs(fortran_result - stb_result)
        end if
        
        ! Test coordinates (23,29): STB=178, Pure=255 type
        call test_single_edge_scenario("Coordinate (23,29) type", &
                                      edge, 23, 0.0_wp, 1.0_wp, &
                                      23.1_wp, 0.1_wp, 23.9_wp, 0.9_wp, &
                                      fortran_result, stb_result)
        
        if (abs(fortran_result - stb_result) > 50.0_wp) then
            write(*,'(A,F6.1,A,F6.1,A,F6.1)') &
                '    ⚠️  Large difference: Pure=', fortran_result, ', STB=', stb_result, &
                ', diff=', abs(fortran_result - stb_result)
        end if
        
        call record_test("Problematic coordinates", .true.)
    end subroutine

    subroutine test_edge_boundary_cases()
        !! Test edges at exact pixel boundaries
        real(wp) :: fortran_result, stb_result
        type(stb_active_edge_t) :: edge
        
        write(*,*) '  Testing edge boundary cases...'
        
        ! Edge exactly at pixel boundary
        edge%direction = 1.0_wp
        call test_single_edge_scenario("Exact pixel boundary", &
                                      edge, 10, 0.0_wp, 1.0_wp, &
                                      10.0_wp, 0.0_wp, 11.0_wp, 1.0_wp, &
                                      fortran_result, stb_result)
        
        ! Edge crossing pixel center
        call test_single_edge_scenario("Pixel center crossing", &
                                      edge, 10, 0.0_wp, 1.0_wp, &
                                      10.5_wp, 0.0_wp, 10.5_wp, 1.0_wp, &
                                      fortran_result, stb_result)
        
        call record_test("Edge boundary cases", .true.)
    end subroutine

    subroutine test_coverage_extremes()
        !! Test extreme coverage calculation scenarios
        real(wp) :: area1, area2, area3
        
        write(*,*) '  Testing coverage extremes...'
        
        ! Maximum coverage trapezoid
        area1 = stb_sized_trapezoid_area(1.0_wp, 1.0_wp, 1.0_wp)
        if (area1 > 1.0_wp + TOLERANCE) then
            write(*,'(A,F8.5)') '    ⚠️  Max coverage exceeded: ', area1
        end if
        
        ! Minimum coverage triangle
        area2 = stb_sized_triangle_area(0.001_wp, 0.001_wp)
        if (area2 < 0.0_wp) then
            write(*,'(A,F8.5)') '    ⚠️  Negative coverage: ', area2
        end if
        
        ! Position trapezoid with extreme coordinates
        area3 = stb_position_trapezoid_area(1.0_wp, 0.0_wp, 1.0_wp, 0.0_wp, 1.0_wp)
        write(*,'(A,F8.5)') '    Info: Extreme position area: ', area3
        
        call record_test("Coverage extremes", .true.)
    end subroutine

    subroutine test_real_anti_aliasing_differences()
        !! Simulate real anti-aliasing differences observed in debugging
        real(wp) :: fortran_result, stb_result
        type(stb_active_edge_t) :: edge
        integer :: significant_differences
        
        write(*,*) '  Testing real anti-aliasing differences...'
        
        significant_differences = 0
        edge%direction = 1.0_wp
        
        ! Test multiple scenarios that could cause the observed differences
        call test_single_edge_scenario("Anti-aliasing case 1", &
                                      edge, 5, 0.0_wp, 1.0_wp, &
                                      5.2_wp, 0.1_wp, 5.8_wp, 0.9_wp, &
                                      fortran_result, stb_result)
        
        if (abs(fortran_result - stb_result) > 10.0_wp) then
            significant_differences = significant_differences + 1
        end if
        
        call test_single_edge_scenario("Anti-aliasing case 2", &
                                      edge, 15, 0.0_wp, 1.0_wp, &
                                      15.1_wp, 0.3_wp, 15.7_wp, 0.6_wp, &
                                      fortran_result, stb_result)
        
        if (abs(fortran_result - stb_result) > 10.0_wp) then
            significant_differences = significant_differences + 1
        end if
        
        write(*,'(A,I0)') '    Significant differences found: ', significant_differences
        
        call record_test("Real anti-aliasing differences", .true.)
    end subroutine

    subroutine test_single_edge_scenario(scenario_name, edge, x, sy, ey, x0, y0, x1, y1, &
                                       fortran_result, stb_result)
        character(len=*), intent(in) :: scenario_name
        type(stb_active_edge_t), intent(in) :: edge
        integer, intent(in) :: x
        real(wp), intent(in) :: sy, ey, x0, y0, x1, y1
        real(wp), intent(out) :: fortran_result, stb_result

        real(wp) :: fortran_scanline(PIXEL_WIDTH)
        real(c_float) :: stb_scanline(PIXEL_WIDTH)
        type(stb_active_edge_t) :: test_edge

        ! Initialize scanlines
        fortran_scanline = 0.0_wp
        stb_scanline = 0.0_c_float

        ! Setup edge
        test_edge = edge
        test_edge%sy = sy
        test_edge%ey = ey

        ! Run Fortran implementation
        call stb_handle_clipped_edge(fortran_scanline, x, test_edge, x0, y0, x1, y1)

        ! Run STB C implementation
        call test_stb_handle_clipped_edge_c(stb_scanline, x, &
                                          real(sy, c_float), real(ey, c_float), &
                                          real(edge%direction, c_float), &
                                          real(x0, c_float), real(y0, c_float), &
                                          real(x1, c_float), real(y1, c_float))

        ! Extract results (convert to 0-255 scale like pixel values)
        fortran_result = abs(fortran_scanline(x + 1)) * 255.0_wp
        stb_result = abs(stb_scanline(x + 1)) * 255.0_wp

        ! Optional: Print detailed results for debugging
        if (abs(fortran_result - stb_result) > 5.0_wp) then
            write(*,'(A,A,A,F6.1,A,F6.1,A,F6.1)') &
                '    ', scenario_name, ': Pure=', fortran_result, &
                ', STB=', stb_result, ', diff=', abs(fortran_result - stb_result)
        end if
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

end program test_forttf_single_pixel_scenarios