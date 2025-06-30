program test_forttf_coverage_precision
    !! Test the exact coverage calculation precision for anti-aliasing
    !! Focus on the cases where Pure gives 255 but STB gives lower values
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    implicit none

    call test_edge_coverage_calculations()

contains

    subroutine test_edge_coverage_calculations()
        !! Test specific edge cases that cause coverage calculation differences
        write(*,*) "=== Testing Edge Coverage Calculation Precision ==="

        ! Test the specific conditions that cause extreme differences
        call test_problematic_pixel_case()
        call test_boundary_coverage_cases()
        call test_single_pixel_coverage()

        write(*,*) "✅ Coverage precision tests completed"
    end subroutine test_edge_coverage_calculations

    subroutine test_problematic_pixel_case()
        !! Test the specific case that gives STB=65, Pure=255 difference
        real(wp) :: height, tx0, tx1, bx0, bx1, area
        real(wp) :: k_val, expected_k_val
        integer :: m_val, expected_m_val

        write(*,*) "--- Testing Problematic Pixel Case ---"

        ! Simulate the edge case that produces extreme differences
        ! This would correspond to a case where the coverage is partial
        height = 1.0_wp
        tx0 = 9.2_wp    ! Edge enters pixel 9 at x=9.2
        tx1 = 9.8_wp    ! Edge exits pixel 9 at x=9.8
        bx0 = 9.3_wp    ! Bottom edge at x=9.3
        bx1 = 9.9_wp    ! Bottom edge at x=9.9

        area = stb_position_trapezoid_area(height, tx0, tx1, bx0, bx1)
        k_val = abs(area) * 255.0_wp + 0.5_wp
        m_val = int(k_val)
        if (m_val > 255) m_val = 255
        if (m_val < 0) m_val = 0

        write(*,*) "Area calculation:"
        write(*,*) "  height =", height
        write(*,*) "  tx0, tx1 =", tx0, tx1
        write(*,*) "  bx0, bx1 =", bx0, bx1
        write(*,*) "  area =", area
        write(*,*) "  k_val =", k_val
        write(*,*) "  m_val =", m_val

        ! Test if area > 1.0 (which would cause saturation to 255)
        if (abs(area) > 1.0_wp) then
            write(*,*) "🚨 ISSUE: Area > 1.0 causing saturation to 255"
        end if
    end subroutine test_problematic_pixel_case

    subroutine test_boundary_coverage_cases()
        !! Test edge cases at pixel boundaries that might cause precision issues
        real(wp) :: height, tx0, tx1, bx0, bx1, area
        real(wp) :: k_val
        integer :: m_val, test_case

        write(*,*) "--- Testing Boundary Coverage Cases ---"

        ! Test various boundary conditions
        do test_case = 1, 5
            select case(test_case)
            case(1)
                ! Edge just barely inside pixel
                height = 1.0_wp
                tx0 = 9.001_wp
                tx1 = 9.999_wp
                bx0 = 9.001_wp
                bx1 = 9.999_wp
            case(2)
                ! Edge spanning exactly one pixel
                height = 1.0_wp
                tx0 = 9.0_wp
                tx1 = 10.0_wp
                bx0 = 9.0_wp
                bx1 = 10.0_wp
            case(3)
                ! Very thin coverage
                height = 1.0_wp
                tx0 = 9.9_wp
                tx1 = 9.95_wp
                bx0 = 9.9_wp
                bx1 = 9.95_wp
            case(4)
                ! Negative direction edge
                height = -1.0_wp
                tx0 = 9.2_wp
                tx1 = 9.8_wp
                bx0 = 9.2_wp
                bx1 = 9.8_wp
            case(5)
                ! Slanted edge
                height = 1.0_wp
                tx0 = 9.1_wp
                tx1 = 9.9_wp
                bx0 = 9.3_wp
                bx1 = 10.1_wp
            end select

            area = stb_position_trapezoid_area(height, tx0, tx1, bx0, bx1)
            k_val = abs(area) * 255.0_wp + 0.5_wp
            m_val = int(k_val)
            if (m_val > 255) m_val = 255
            if (m_val < 0) m_val = 0

            write(*,*) "Test case", test_case, ":"
            write(*,*) "  area =", area, "-> pixel =", m_val

            if (abs(area) > 1.01_wp) then
                write(*,*) "  🚨 WARNING: Area exceeds 1.0 by", abs(area) - 1.0_wp
            end if
        end do
    end subroutine test_boundary_coverage_cases

    subroutine test_single_pixel_coverage()
        !! Test the single pixel coverage path that might have issues
        real(wp) :: height, x_top, x_bottom, area
        real(wp) :: k_val
        integer :: m_val, x, test_case

        write(*,*) "--- Testing Single Pixel Coverage ---"

        ! Test various single-pixel scenarios
        do test_case = 1, 3
            select case(test_case)
            case(1)
                ! Standard case
                height = 1.0_wp
                x_top = 9.3_wp
                x_bottom = 9.7_wp
                x = 9
            case(2)
                ! Edge case - very small coverage
                height = 1.0_wp
                x_top = 9.01_wp
                x_bottom = 9.02_wp
                x = 9
            case(3)
                ! Edge case - almost full coverage
                height = 1.0_wp
                x_top = 9.01_wp
                x_bottom = 9.99_wp
                x = 9
            end select

            area = stb_position_trapezoid_area(height, x_top, real(x + 1, wp), x_bottom, real(x + 1, wp))
            k_val = abs(area) * 255.0_wp + 0.5_wp
            m_val = int(k_val)
            if (m_val > 255) m_val = 255
            if (m_val < 0) m_val = 0

            write(*,*) "Single pixel test", test_case, ":"
            write(*,*) "  x_top =", x_top, "x_bottom =", x_bottom
            write(*,*) "  area =", area, "-> pixel =", m_val

            if (abs(area) > 1.01_wp) then
                write(*,*) "  🚨 WARNING: Single pixel area exceeds 1.0"
            end if
        end do

    end subroutine test_single_pixel_coverage

end program test_forttf_coverage_precision
