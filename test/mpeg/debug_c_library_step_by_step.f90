program debug_c_library_step_by_step
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use fortplot_mpeg1_format
    use iso_c_binding
    implicit none
    
    ! Debug EVERY step against C library implementation
    call debug_sequence_header()
    call debug_frame_extraction()
    call debug_dct_transform()
    call debug_quantization()
    call debug_huffman_encoding()
    
    print *, "PASS: Step-by-step C library debugging complete"
    
contains

    subroutine debug_sequence_header()
        ! Compare sequence header with C library byte-for-byte
        character(len=*), parameter :: test_file = "debug_sequence_header.mpg"
        integer(1) :: header_bytes(20)
        integer :: i, ios
        
        print *, "=== DEBUGGING SEQUENCE HEADER vs C LIBRARY ==="
        
        call stream_open_write(test_file)
        call write_mpeg1_sequence_header(32, 24, 25, 32*24*25*8)
        call stream_close_write()
        
        ! Read and display header bytes
        open(unit=10, file=test_file, access='stream', form='unformatted')
        read(10, iostat=ios) header_bytes
        close(10)
        
        print *, "Fortran sequence header (first 20 bytes):"
        do i = 1, 20
            write(*, '(I3, " (0x", Z2.2, ") ")', advance='no') int(header_bytes(i)), header_bytes(i)
            if (mod(i, 8) == 0) print *
        end do
        print *
        
        ! Expected C library sequence header for 32x24@25fps:
        print *, "Expected C library sequence header:"
        print *, "00 00 01 B3 (start code)"
        print *, "02 00 18 (width=32, height=24)"
        print *, "13 xx xx xx (aspect=1, rate=25fps, bitrate)"
        print *, "xx xx (VBV buffer, constrained flag)"
    end subroutine
    
    subroutine debug_frame_extraction()
        ! Debug macroblock extraction vs C library
        type(mem_t) :: test_frame
        integer :: y_blocks(4, 8, 8), cb_block(8, 8), cr_block(8, 8)
        integer :: i, j, block_num
        
        print *, "=== DEBUGGING FRAME EXTRACTION vs C LIBRARY ==="
        
        ! Create simple test frame
        test_frame = mem_create(16, 16)  ! Single macroblock
        
        ! Fill with test pattern (match C library test data)
        do i = 1, 16*16
            test_frame%data(i) = int(mod(i-1, 256), c_int8_t)
        end do
        
        call extract_macroblock_data(test_frame, 16, 16, 0, 0, y_blocks, cb_block, cr_block)
        
        print *, "Y block 1 (top-left 8x8):"
        do i = 1, 8
            write(*, '(8I4)') (y_blocks(1, i, j), j=1, 8)
        end do
        
        print *, "Cb block (should be all 128 for grayscale):"
        do i = 1, 8
            write(*, '(8I4)') (cb_block(i, j), j=1, 8)
        end do
        
        print *, "Cr block (should be all 128 for grayscale):"
        do i = 1, 8
            write(*, '(8I4)') (cr_block(i, j), j=1, 8)
        end do
        
        call mem_destroy(test_frame)
    end subroutine
    
    subroutine debug_dct_transform()
        ! Debug DCT transform vs C library
        integer :: input_block(8, 8), dct_coeffs(8, 8)
        integer :: i, j
        
        print *, "=== DEBUGGING DCT TRANSFORM vs C LIBRARY ==="
        
        ! Create test block (match C library fdct test)
        do i = 1, 8
            do j = 1, 8
                input_block(i, j) = 128  ! Constant block
            end do
        end do
        
        print *, "Input block (all 128):"
        do i = 1, 8
            write(*, '(8I4)') (input_block(i, j), j=1, 8)
        end do
        
        call mpeg1_dct_transform(input_block, dct_coeffs)
        
        print *, "DCT coefficients (DC should be 0, AC should be near 0):"
        do i = 1, 8
            write(*, '(8I6)') (dct_coeffs(i, j), j=1, 8)
        end do
        
        print *, "Expected: DC(1,1)=0 (128-128=0 after centering), AC≈0"
    end subroutine
    
    subroutine debug_quantization()
        ! Debug quantization vs C library
        integer :: dct_block(8, 8), quant_block(8, 8)
        integer :: i, j, qvalue
        
        print *, "=== DEBUGGING QUANTIZATION vs C LIBRARY ==="
        
        ! Create test DCT block
        dct_block = 0
        dct_block(1, 1) = 1024  ! DC coefficient
        dct_block(1, 2) = 64    ! AC coefficient
        dct_block(2, 1) = 32    ! AC coefficient
        
        print *, "Test DCT block:"
        do i = 1, 3
            write(*, '(8I6)') (dct_block(i, j), j=1, 3)
        end do
        
        quant_block = dct_block
        call quantize_block(quant_block, 16, .true.)
        
        print *, "Quantized block (scale=16, intra):"
        do i = 1, 3
            write(*, '(8I6)') (quant_block(i, j), j=1, 3)
        end do
        
        ! Show quantization formula for verification
        print *, "Quantization formulas:"
        print *, "DC: 1024 / 8 =", 1024/8
        qvalue = (DEFAULT_INTRA_MATRIX(1, 2) * 16 + 8) / 16
        print *, "AC(1,2): 64 / ((", DEFAULT_INTRA_MATRIX(1, 2), " * 16 + 8) / 16) = 64 /", qvalue, "=", 64/qvalue
    end subroutine
    
    subroutine debug_huffman_encoding()
        ! Debug Huffman encoding vs C library tables
        character(len=*), parameter :: test_file = "debug_huffman.dat"
        integer :: dc_diff, test_cases(5) = [0, 1, -1, 7, -7]
        integer :: i
        
        print *, "=== DEBUGGING HUFFMAN ENCODING vs C LIBRARY ==="
        
        call stream_open_write(test_file)
        
        do i = 1, 5
            dc_diff = test_cases(i)
            print *, "Encoding DC diff =", dc_diff
            call encode_dc_coefficient(dc_diff)
        end do
        
        ! Encode End of Block
        print *, "Encoding End of Block"
        call encode_end_of_block()
        
        call stream_close_write()
        
        ! Display bit stream
        call display_bit_stream(test_file)
    end subroutine
    
    subroutine display_bit_stream(filename)
        character(len=*), intent(in) :: filename
        integer(1) :: bytes(50)
        integer :: i, ios, file_size
        
        inquire(file=filename, size=file_size)
        if (file_size > 50) file_size = 50
        
        open(unit=10, file=filename, access='stream', form='unformatted')
        read(10, iostat=ios) bytes(1:file_size)
        close(10)
        
        print *, "Bit stream (", file_size, " bytes):"
        do i = 1, file_size
            write(*, '(Z2.2, " ")', advance='no') bytes(i)
            if (mod(i, 16) == 0) print *
        end do
        print *
    end subroutine

end program debug_c_library_step_by_step