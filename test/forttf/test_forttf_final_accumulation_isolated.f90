program test_forttf_final_accumulation_isolated
    !! Test the final pixel accumulation formula in isolation against STB C implementation
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! Test the exact accumulation scenarios that are failing
    call test_specific_failing_pixels()

contains

    subroutine test_specific_failing_pixels()
        !! Test specific pixel accumulation scenarios that differ from STB
        real(wp) :: scanline_buffer(20), scanline_fill_buffer(20)
        real(wp) :: sum_val, k_val
        integer :: m_val, i
        integer(c_int8_t) :: result_signed
        integer :: result_unsigned

        write(*,*) "=== Testing Final Accumulation for Specific Failing Pixels ==="
        write(*,*) ""

        ! Test case based on pixel 108 (row 5, col 8): STB=114, Pure=221
        write(*,*) "Test case 1: Simulating pixel 108 scenario"
        scanline_buffer = 0.0_wp
        scanline_fill_buffer = 0.0_wp
        
        ! Set up values that might produce STB=114 vs Pure=221 difference
        scanline_buffer(9) = 0.4471_wp  ! Approximate value that should give 114
        scanline_fill_buffer(9) = 0.0_wp
        
        call test_accumulation_step(scanline_buffer, scanline_fill_buffer, 9)
        write(*,*) ""

        ! Test case based on pixel 125 (row 6, col 5): STB=199, Pure=255  
        write(*,*) "Test case 2: Simulating pixel 125 scenario"
        scanline_buffer = 0.0_wp
        scanline_fill_buffer = 0.0_wp
        
        ! Set up values that might produce STB=199 vs Pure=255 difference
        scanline_buffer(6) = 0.7804_wp  ! Approximate value that should give 199
        scanline_fill_buffer(6) = 0.0_wp
        
        call test_accumulation_step(scanline_buffer, scanline_fill_buffer, 6)
        write(*,*) ""

        ! Test case with scanline_fill contribution
        write(*,*) "Test case 3: With scanline_fill contribution"
        scanline_buffer = 0.0_wp
        scanline_fill_buffer = 0.0_wp
        
        scanline_buffer(10) = 0.2_wp
        scanline_fill_buffer(9) = 0.3_wp  ! Previous pixel contributes to sum
        scanline_fill_buffer(10) = 0.1_wp
        
        ! Process pixels 9 and 10 to see accumulation effect
        call test_accumulation_step(scanline_buffer, scanline_fill_buffer, 9)
        call test_accumulation_step(scanline_buffer, scanline_fill_buffer, 10)
        write(*,*) ""

        ! Test edge cases with very small values
        write(*,*) "Test case 4: Edge cases with small values"
        scanline_buffer = 0.0_wp
        scanline_fill_buffer = 0.0_wp
        
        scanline_buffer(5) = 0.001_wp
        scanline_fill_buffer(5) = 0.0001_wp
        
        call test_accumulation_step(scanline_buffer, scanline_fill_buffer, 5)
        write(*,*) ""

        write(*,*) "✅ Final accumulation isolated testing complete"

    end subroutine test_specific_failing_pixels

    subroutine test_accumulation_step(scanline_buffer, scanline_fill_buffer, pixel_idx)
        !! Test accumulation for a specific pixel index
        real(wp), intent(in) :: scanline_buffer(:), scanline_fill_buffer(:)
        integer, intent(in) :: pixel_idx
        
        real(wp) :: sum_val, k_val
        integer :: m_val, i
        integer(c_int8_t) :: result_signed
        integer :: result_unsigned

        ! Simulate the exact STB accumulation formula
        sum_val = 0.0_wp
        do i = 1, pixel_idx
            sum_val = sum_val + scanline_fill_buffer(i)
        end do
        
        k_val = scanline_buffer(pixel_idx) + sum_val
        
        write(*,*) "  Pixel", pixel_idx, ":"
        write(*,*) "    scanline_buffer =", scanline_buffer(pixel_idx)
        write(*,*) "    sum_val         =", sum_val
        write(*,*) "    k_val           =", k_val
        
        ! Apply STB formula: k = (float) STBTT_fabs(k)*255 + 0.5f;
        k_val = abs(k_val) * 255.0_wp + 0.5_wp
        m_val = int(k_val)
        if (m_val > 255) m_val = 255
        if (m_val < 0) m_val = 0
        
        result_signed = int(m_val, c_int8_t)
        result_unsigned = m_val
        
        write(*,*) "    k_val * 255 + 0.5 =", k_val
        write(*,*) "    m_val             =", m_val
        write(*,*) "    result_unsigned   =", result_unsigned
        write(*,*) "    result_signed     =", result_signed

    end subroutine test_accumulation_step

end program test_forttf_final_accumulation_isolated