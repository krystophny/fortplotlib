program test_trace_encoding
    use fortplot_mpeg1_format
    use fortplot_mpeg_memory
    use iso_c_binding
    implicit none
    
    ! Trace through the EXACT encoding process step by step
    call trace_single_macroblock()
    
    print *, "PASS: Encoding trace complete"
    
contains

    subroutine trace_single_macroblock()
        ! Trace a single macroblock encoding to find where colors go wrong
        integer, parameter :: BLOCK_SIZE = 8, MACROBLOCK_SIZE = 16
        type(mem_t) :: frame_buffer
        integer :: y_blocks(4, BLOCK_SIZE, BLOCK_SIZE)
        integer :: cb_block(BLOCK_SIZE, BLOCK_SIZE), cr_block(BLOCK_SIZE, BLOCK_SIZE)
        integer :: dct_coeffs(BLOCK_SIZE, BLOCK_SIZE)
        integer :: last_dc(3) = [0, 0, 0]
        integer :: width = 16, height = 16
        integer :: i, j, pixel_idx
        
        print *, "=== TRACING SINGLE MACROBLOCK ENCODING ==="
        
        ! Create simple pattern: all black (128)
        frame_buffer = mem_create(width, height)
        do pixel_idx = 1, width * height
            frame_buffer%data(pixel_idx) = int(-128, c_int8_t)  ! All black (128)
        end do
        
        print *, "Step 1: Frame data created (all black = 128)"
        print *, "  First few pixels:", (int(frame_buffer%data(i)) + 256, i=1, min(8, width*height))
        
        ! Extract macroblock
        call extract_macroblock_data(frame_buffer, width, height, 0, 0, &
                                   y_blocks, cb_block, cr_block)
        
        print *, ""
        print *, "Step 2: Macroblock extracted"
        print *, "  Y block 1 (top-left 8x8):"
        do i = 1, 3
            write(*, '(A,8I4)') "    ", (y_blocks(1, i, j), j=1, 8)
        end do
        print *, "    ..."
        
        print *, "  Cb block (should be all 128):"
        do i = 1, 3
            write(*, '(A,8I4)') "    ", (cb_block(i, j), j=1, 8)
        end do
        print *, "    ..."
        
        print *, "  Cr block (should be all 128):"
        do i = 1, 3
            write(*, '(A,8I4)') "    ", (cr_block(i, j), j=1, 8)
        end do
        print *, "    ..."
        
        ! Test DCT transform on Y block
        call mpeg1_dct_transform(y_blocks(1,:,:), dct_coeffs)
        
        print *, ""
        print *, "Step 3: DCT transform of Y block 1"
        print *, "  DC coefficient (1,1):", dct_coeffs(1,1), "(should be ~0 for 128 input)"
        print *, "  AC coefficient (1,2):", dct_coeffs(1,2), "(should be 0 for uniform block)"
        print *, "  AC coefficient (2,1):", dct_coeffs(2,1), "(should be 0 for uniform block)"
        
        ! Test quantization
        call quantize_block(dct_coeffs, 16, .true.)
        
        print *, ""
        print *, "Step 4: Quantization (scale=16)"
        print *, "  Quantized DC (1,1):", dct_coeffs(1,1), "(should be 0)"
        print *, "  Quantized AC (1,2):", dct_coeffs(1,2), "(should be 0)"
        print *, "  Quantized AC (2,1):", dct_coeffs(2,1), "(should be 0)"
        
        ! Check if all coefficients are zero
        call check_all_coefficients_zero(dct_coeffs)
        
        ! Test Cb block encoding
        print *, ""
        print *, "Step 5: Cb block DCT and quantization"
        call mpeg1_dct_transform(cb_block, dct_coeffs)
        print *, "  Cb DCT DC:", dct_coeffs(1,1), "(should be ~0 for 128)"
        call quantize_block(dct_coeffs, 16, .false.)
        print *, "  Cb quantized DC:", dct_coeffs(1,1), "(should be 0)"
        
        ! Test Cr block encoding
        print *, ""
        print *, "Step 6: Cr block DCT and quantization"
        call mpeg1_dct_transform(cr_block, dct_coeffs)
        print *, "  Cr DCT DC:", dct_coeffs(1,1), "(should be ~0 for 128)"
        call quantize_block(dct_coeffs, 16, .false.)
        print *, "  Cr quantized DC:", dct_coeffs(1,1), "(should be 0)"
        
        call mem_destroy(frame_buffer)
        
        print *, ""
        print *, "=== ANALYSIS ==="
        print *, "If all DC coefficients are 0, the block should decode to neutral gray."
        print *, "If any DC coefficient is non-zero, it will cause color shift."
    end subroutine
    
    subroutine check_all_coefficients_zero(coeffs)
        integer, intent(in) :: coeffs(8, 8)
        integer :: i, j, non_zero_count
        
        non_zero_count = 0
        do i = 1, 8
            do j = 1, 8
                if (coeffs(i, j) /= 0) then
                    non_zero_count = non_zero_count + 1
                    if (non_zero_count <= 5) then  ! Show first few
                        print *, "    Non-zero coeff at (", i, ",", j, ") =", coeffs(i, j)
                    end if
                end if
            end do
        end do
        
        if (non_zero_count == 0) then
            print *, "  ✅ ALL coefficients are zero (will decode to uniform color)"
        else
            print *, "  ❌", non_zero_count, "non-zero coefficients (may cause artifacts)"
        end if
    end subroutine

end program test_trace_encoding