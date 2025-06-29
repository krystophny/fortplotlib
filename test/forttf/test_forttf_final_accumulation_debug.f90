program test_forttf_final_accumulation_debug
    !! Test the final pixel accumulation formula to match STB exactly
    !! This is the critical step where pixel values are computed from scanline buffers
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    implicit none

    ! Test the exact accumulation formula used in stb_rasterize_sorted_edges
    call test_accumulation_formula()

contains

    subroutine test_accumulation_formula()
        !! Test specific accumulation cases that cause over/under-saturation
        real(wp) :: scanline_buffer(5), scanline_fill_buffer(5)
        real(wp) :: sum_val, k_val
        integer :: m_val, i
        integer(c_int8_t) :: result_signed
        integer :: result_unsigned

        write(*,*) "=== Testing Final Pixel Accumulation Formula ==="
        write(*,*) ""

        ! Test case 1: Over-saturation case (Pure=255, STB=low)
        write(*,*) "Test 1: Over-saturation case analysis"
        scanline_buffer = [0.0_wp, 0.0_wp, 1.0_wp, 0.0_wp, 0.0_wp]
        scanline_fill_buffer = [0.0_wp, 0.0_wp, 255.0_wp, 0.0_wp, 0.0_wp]
        
        sum_val = 0.0_wp
        do i = 1, 5
            sum_val = sum_val + scanline_fill_buffer(i)
            k_val = scanline_buffer(i) + sum_val
            write(*,*) "  Pixel", i, ": scanline=", scanline_buffer(i), " fill=", scanline_fill_buffer(i)
            write(*,*) "         sum=", sum_val, " k_val=", k_val
            k_val = abs(k_val) * 255.0_wp + 0.5_wp
            m_val = int(k_val)
            if (m_val > 255) m_val = 255
            if (m_val < 0) m_val = 0
            result_signed = int(m_val, c_int8_t)
            result_unsigned = m_val
            write(*,*) "         final: unsigned=", result_unsigned, " signed=", result_signed
        end do
        write(*,*) ""

        ! Test case 2: Under-estimation case (Pure=low, STB=high)
        write(*,*) "Test 2: Under-estimation case analysis"
        scanline_buffer = [0.0_wp, 0.3_wp, 0.7_wp, 0.2_wp, 0.0_wp]
        scanline_fill_buffer = [0.0_wp, 0.1_wp, 0.2_wp, 0.1_wp, 0.0_wp]
        
        sum_val = 0.0_wp
        do i = 1, 5
            sum_val = sum_val + scanline_fill_buffer(i)
            k_val = scanline_buffer(i) + sum_val
            write(*,*) "  Pixel", i, ": scanline=", scanline_buffer(i), " fill=", scanline_fill_buffer(i)
            write(*,*) "         sum=", sum_val, " k_val=", k_val
            k_val = abs(k_val) * 255.0_wp + 0.5_wp
            m_val = int(k_val)
            if (m_val > 255) m_val = 255
            if (m_val < 0) m_val = 0
            result_signed = int(m_val, c_int8_t)
            result_unsigned = m_val
            write(*,*) "         final: unsigned=", result_unsigned, " signed=", result_signed
        end do
        write(*,*) ""

        ! Test case 3: Negative values (winding)
        write(*,*) "Test 3: Negative winding case"
        scanline_buffer = [0.0_wp, -0.5_wp, 0.8_wp, -0.3_wp, 0.0_wp]
        scanline_fill_buffer = [0.0_wp, -0.2_wp, 0.4_wp, -0.1_wp, 0.0_wp]
        
        sum_val = 0.0_wp
        do i = 1, 5
            sum_val = sum_val + scanline_fill_buffer(i)
            k_val = scanline_buffer(i) + sum_val
            write(*,*) "  Pixel", i, ": scanline=", scanline_buffer(i), " fill=", scanline_fill_buffer(i)
            write(*,*) "         sum=", sum_val, " k_val=", k_val
            k_val = abs(k_val) * 255.0_wp + 0.5_wp
            m_val = int(k_val)
            if (m_val > 255) m_val = 255
            if (m_val < 0) m_val = 0
            result_signed = int(m_val, c_int8_t)
            result_unsigned = m_val
            write(*,*) "         final: unsigned=", result_unsigned, " signed=", result_signed
        end do
        
        write(*,*) "✅ Final accumulation formula analysis complete"

    end subroutine test_accumulation_formula

end program test_forttf_final_accumulation_debug