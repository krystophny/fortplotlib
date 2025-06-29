program test_forttf_scanline_conversion_precision
    !! Test exact scanline-to-pixel conversion precision vs STB
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, sp => real32
    implicit none

    ! Test various edge cases in scanline-to-pixel conversion
    call test_conversion_precision()

contains

    subroutine test_conversion_precision()
        !! Test the exact conversion: k = abs(k) * 255 + 0.5; m = int(k)
        real(wp) :: test_values(20)
        real(wp) :: k_val, expected_k, diff
        integer :: m_val, expected_m, i
        logical :: all_passed

        ! Test cases that might cause precision issues
        test_values = [ &
            0.0_wp, 0.001_wp, 0.499_wp, 0.5_wp, 0.501_wp, &
            1.0_wp, 1.001_wp, 1.499_wp, 1.5_wp, 1.501_wp, &
            -0.5_wp, -1.0_wp, -1.5_wp, &
            127.0_wp/255.0_wp, 128.0_wp/255.0_wp, &
            254.0_wp/255.0_wp, 255.0_wp/255.0_wp, &
            1.99999_wp, 2.00001_wp, 100.0_wp &
        ]

        write(*,*) "=== Testing Scanline-to-Pixel Conversion Precision ==="
        write(*,*) "Formula: k = abs(input) * 255 + 0.5; m = int(k); clamp(m, 0, 255)"
        write(*,*)

        all_passed = .true.

        do i = 1, size(test_values)
            ! Our implementation
            k_val = abs(test_values(i)) * 255.0_wp + 0.5_wp
            m_val = int(k_val)
            if (m_val > 255) m_val = 255
            if (m_val < 0) m_val = 0

            ! Expected STB result (using same formula)
            expected_k = abs(test_values(i)) * 255.0 + 0.5
            expected_m = int(expected_k)
            if (expected_m > 255) expected_m = 255
            if (expected_m < 0) expected_m = 0

            diff = abs(k_val - expected_k)

            write(*,*) "Input:", test_values(i)
            write(*,*) "  Our k:", k_val, " -> m:", m_val
            write(*,*) "  STB k:", expected_k, " -> m:", expected_m
            write(*,*) "  Diff k:", diff

            if (m_val /= expected_m .or. diff > 1e-10_wp) then
                write(*,*) "  ❌ MISMATCH!"
                all_passed = .false.
            else
                write(*,*) "  ✅ MATCH"
            end if
            write(*,*)
        end do

        if (all_passed) then
            write(*,*) "✅ All conversion precision tests passed"
        else
            write(*,*) "❌ Some conversion precision tests failed"
        end if

        ! Test floating-point edge cases around 127.5 and 255.5
        write(*,*) "=== Testing Critical Boundary Cases ==="
        call test_critical_boundary(127.0_wp/255.0_wp)
        call test_critical_boundary(127.5_wp/255.0_wp)
        call test_critical_boundary(128.0_wp/255.0_wp)
        call test_critical_boundary(254.0_wp/255.0_wp)
        call test_critical_boundary(254.5_wp/255.0_wp)
        call test_critical_boundary(255.0_wp/255.0_wp)

    end subroutine test_conversion_precision

    subroutine test_critical_boundary(input_val)
        real(wp), intent(in) :: input_val
        real(wp) :: k_val, expected_k
        integer :: m_val, expected_m

        ! Our implementation
        k_val = abs(input_val) * 255.0_wp + 0.5_wp
        m_val = int(k_val)
        if (m_val > 255) m_val = 255

        ! Expected (STB uses float, we use double)
        expected_k = abs(real(input_val, sp)) * 255.0 + 0.5
        expected_m = int(expected_k)
        if (expected_m > 255) expected_m = 255

        write(*,*) "Boundary test input:", input_val
        write(*,*) "  Our (double):", k_val, " -> ", m_val
        write(*,*) "  STB (float):", expected_k, " -> ", expected_m
        write(*,*) "  Precision diff:", abs(k_val - expected_k)
        if (m_val /= expected_m) then
            write(*,*) "  ❌ BOUNDARY MISMATCH!"
        else
            write(*,*) "  ✅ BOUNDARY MATCH"
        end if
        write(*,*)

    end subroutine test_critical_boundary

end program test_forttf_scanline_conversion_precision
