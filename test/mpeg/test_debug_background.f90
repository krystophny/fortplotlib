program test_debug_background
    use fortplot_mpeg1_format
    use fortplot_mpeg_memory, only: mem_t, mem_create, mem_destroy
    use iso_c_binding, only: c_int8_t
    implicit none
    
    ! Debug background encoding specifically
    call test_pure_black_encoding()
    call test_black_vs_white_blocks()
    
    print *, "PASS: Background debugging complete"
    
contains

    subroutine test_pure_black_encoding()
        ! Test encoding of pure black pixels
        integer, parameter :: BLOCK_SIZE = 8
        integer :: input_block(BLOCK_SIZE, BLOCK_SIZE)
        integer :: dct_coeffs(BLOCK_SIZE, BLOCK_SIZE)
        integer :: quantized_coeffs(BLOCK_SIZE, BLOCK_SIZE)
        integer :: quantizer_scale = 16
        integer :: i, j
        
        print *, "=== Testing Pure Black Encoding ==="
        
        ! Create pure black block (all zeros)
        input_block = 0
        
        print *, "Input block (all black = 0):"
        do i = 1, 3
            write(*, '(8I4)') (input_block(i, j), j=1, 8)
        end do
        print *, "..."
        
        ! Apply DCT transform  
        call mpeg1_dct_transform_integer(input_block, dct_coeffs)
        
        print *, "DCT coefficients after transform:"
        print *, "  DC(1,1) =", dct_coeffs(1,1), "(should be ~0 for all-black)"
        print *, "  AC(1,2) =", dct_coeffs(1,2), "(should be 0)"
        print *, "  AC(2,1) =", dct_coeffs(2,1), "(should be 0)"
        
        ! Apply quantization
        quantized_coeffs = dct_coeffs
        call quantize_block(quantized_coeffs, quantizer_scale, .true.)
        
        print *, "Quantized coefficients:"
        print *, "  DC(1,1) =", quantized_coeffs(1,1), "(should be 0 after quantization)"
        print *, "  AC(1,2) =", quantized_coeffs(1,2), "(should be 0)"
        print *, "  AC(2,1) =", quantized_coeffs(2,1), "(should be 0)"
        
        ! Check if all coefficients are zero
        do i = 1, BLOCK_SIZE
            do j = 1, BLOCK_SIZE
                if (quantized_coeffs(i,j) /= 0) then
                    print *, "  WARNING: Non-zero coefficient at (", i, ",", j, ") =", quantized_coeffs(i,j)
                end if
            end do
        end do
        
        print *, "Expected: All coefficients should be 0 for pure black block"
    end subroutine
    
    subroutine test_black_vs_white_blocks()
        ! Compare black vs white block encoding
        integer, parameter :: BLOCK_SIZE = 8
        integer :: black_block(BLOCK_SIZE, BLOCK_SIZE)
        integer :: white_block(BLOCK_SIZE, BLOCK_SIZE)
        integer :: black_dct(BLOCK_SIZE, BLOCK_SIZE), white_dct(BLOCK_SIZE, BLOCK_SIZE)
        integer :: quantizer_scale = 16
        
        print *, ""
        print *, "=== Testing Black vs White Encoding ==="
        
        ! Create pure black and white blocks
        black_block = 0
        white_block = 127  ! Use 127 to avoid signed byte overflow
        
        ! Transform both
        call mpeg1_dct_transform_integer(black_block, black_dct)
        call mpeg1_dct_transform_integer(white_block, white_dct)
        
        print *, "Black block DCT DC coefficient:", black_dct(1,1)
        print *, "White block DCT DC coefficient:", white_dct(1,1)
        
        ! Quantize both
        call quantize_block(black_dct, quantizer_scale, .true.)
        call quantize_block(white_dct, quantizer_scale, .true.)
        
        print *, "Black block quantized DC:", black_dct(1,1)
        print *, "White block quantized DC:", white_dct(1,1)
        
        print *, "Expected: Black DC ≈ 0, White DC > 0 for good contrast"
        
        if (black_dct(1,1) == white_dct(1,1)) then
            print *, "WARNING: No contrast between black and white!"
        end if
    end subroutine
    
    subroutine mpeg1_dct_transform_integer(input, output)
        ! Simple integer DCT for testing
        integer, intent(in) :: input(8, 8)
        integer, intent(out) :: output(8, 8)
        real :: temp_input(8, 8), temp_output(8, 8)
        integer :: i, j
        
        ! Convert to real
        do i = 1, 8
            do j = 1, 8
                temp_input(i, j) = real(input(i, j) - 128)  ! Center around 0
            end do
        end do
        
        ! Apply DCT
        call dct_2d_8x8_test(temp_input, temp_output)
        
        ! Convert back to integer
        do i = 1, 8
            do j = 1, 8
                output(i, j) = nint(temp_output(i, j))
            end do
        end do
    end subroutine
    
    subroutine dct_2d_8x8_test(input, output)
        ! Simplified DCT implementation for testing
        real, intent(in) :: input(8, 8)
        real, intent(out) :: output(8, 8)
        
        real :: pi_over_8, cos_table(0:7, 0:7), c_norm(0:7)
        integer :: u, v, x, y
        real :: sum_val
        
        pi_over_8 = atan(1.0) * 4.0 / 8.0
        
        ! Precompute tables
        do u = 0, 7
            c_norm(u) = merge(1.0/sqrt(2.0), 1.0, u == 0)
            do x = 0, 7
                cos_table(u, x) = cos((2*x + 1) * u * pi_over_8)
            end do
        end do
        
        ! 2D DCT
        do u = 0, 7
            do v = 0, 7
                sum_val = 0.0
                do x = 0, 7
                    do y = 0, 7
                        sum_val = sum_val + input(x+1, y+1) * cos_table(u, x) * cos_table(v, y)
                    end do
                end do
                output(u+1, v+1) = 0.25 * c_norm(u) * c_norm(v) * sum_val
            end do
        end do
    end subroutine

end program test_debug_background