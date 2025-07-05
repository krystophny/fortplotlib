program test_mpeg_huffman
    !! Test MPEG Huffman encoding and decoding implementation
    use fortplot_mpeg_huffman
    implicit none
    
    logical :: all_tests_passed
    
    all_tests_passed = .true.
    
    call test_dc_lum_huffman_encoding(all_tests_passed)
    call test_dc_chrom_huffman_encoding(all_tests_passed)
    call test_ac_coeff_huffman_encoding(all_tests_passed)
    call test_huffman_roundtrip(all_tests_passed)
    call test_bit_buffer_operations(all_tests_passed)
    
    if (all_tests_passed) then
        print *, "All MPEG Huffman tests passed!"
    else
        print *, "Some MPEG Huffman tests failed!"
        stop 1
    end if
    
contains

    subroutine test_dc_lum_huffman_encoding(all_passed)
        logical, intent(inout) :: all_passed
        type(huffman_encoder_t) :: encoder
        type(huffman_decoder_t) :: decoder
        type(bit_buffer_t) :: buffer
        logical :: success
        
        print *, "Testing DC luminance Huffman encoding..."
        
        call init_mpeg_huffman_tables(encoder, decoder, 'DC_LUM')
        
        if (encoder%num_symbols /= 9) then
            print *, "FAILED: DC_LUM table should have 9 symbols, got", encoder%num_symbols
            all_passed = .false.
            return
        end if
        
        if (encoder%lengths(0) /= 3 .or. encoder%codes(0) /= 4) then
            print *, "FAILED: DC_LUM symbol 0 should be length 3, code 4"
            print *, "Got length", encoder%lengths(0), "code", encoder%codes(0)
            all_passed = .false.
            return
        end if
        
        if (encoder%lengths(1) /= 2 .or. encoder%codes(1) /= 0) then
            print *, "FAILED: DC_LUM symbol 1 should be length 2, code 0"
            print *, "Got length", encoder%lengths(1), "code", encoder%codes(1)
            all_passed = .false.
            return
        end if
        
        success = encode_huffman_value(encoder, 1, buffer)
        if (.not. success) then
            print *, "FAILED: Could not encode DC_LUM symbol 1"
            all_passed = .false.
            return
        end if
        
        print *, "DC luminance Huffman encoding test passed"
    end subroutine test_dc_lum_huffman_encoding
    
    subroutine test_dc_chrom_huffman_encoding(all_passed)
        logical, intent(inout) :: all_passed
        type(huffman_encoder_t) :: encoder
        type(huffman_decoder_t) :: decoder
        type(bit_buffer_t) :: buffer
        logical :: success
        
        print *, "Testing DC chrominance Huffman encoding..."
        
        call init_mpeg_huffman_tables(encoder, decoder, 'DC_CHROM')
        
        if (encoder%num_symbols /= 9) then
            print *, "FAILED: DC_CHROM table should have 9 symbols, got", encoder%num_symbols
            all_passed = .false.
            return
        end if
        
        if (encoder%lengths(0) /= 2 .or. encoder%codes(0) /= 0) then
            print *, "FAILED: DC_CHROM symbol 0 should be length 2, code 0"
            print *, "Got length", encoder%lengths(0), "code", encoder%codes(0)
            all_passed = .false.
            return
        end if
        
        if (encoder%lengths(8) /= 8 .or. encoder%codes(8) /= 254) then
            print *, "FAILED: DC_CHROM symbol 8 should be length 8, code 254"
            print *, "Got length", encoder%lengths(8), "code", encoder%codes(8)
            all_passed = .false.
            return
        end if
        
        success = encode_huffman_value(encoder, 0, buffer)
        if (.not. success) then
            print *, "FAILED: Could not encode DC_CHROM symbol 0"
            all_passed = .false.
            return
        end if
        
        print *, "DC chrominance Huffman encoding test passed"
    end subroutine test_dc_chrom_huffman_encoding
    
    subroutine test_ac_coeff_huffman_encoding(all_passed)
        logical, intent(inout) :: all_passed
        type(huffman_encoder_t) :: encoder
        type(huffman_decoder_t) :: decoder
        type(bit_buffer_t) :: buffer
        logical :: success
        
        print *, "Testing AC coefficient Huffman encoding..."
        
        call init_mpeg_huffman_tables(encoder, decoder, 'AC_COEFF')
        
        if (encoder%num_symbols /= 12) then
            print *, "FAILED: AC_COEFF table should have 12 symbols, got", encoder%num_symbols
            all_passed = .false.
            return
        end if
        
        if (encoder%lengths(0) /= 2 .or. encoder%codes(0) /= 2) then
            print *, "FAILED: AC_COEFF EOF should be length 2, code 2"
            print *, "Got length", encoder%lengths(0), "code", encoder%codes(0)
            all_passed = .false.
            return
        end if
        
        if (encoder%lengths(257) /= 3 .or. encoder%codes(257) /= 3) then
            print *, "FAILED: AC_COEFF run=1,level=1 should be length 3, code 3"
            print *, "Got length", encoder%lengths(257), "code", encoder%codes(257)
            all_passed = .false.
            return
        end if
        
        success = encode_huffman_value(encoder, 0, buffer)
        if (.not. success) then
            print *, "FAILED: Could not encode AC_COEFF EOF"
            all_passed = .false.
            return
        end if
        
        print *, "AC coefficient Huffman encoding test passed"
    end subroutine test_ac_coeff_huffman_encoding
    
    subroutine test_huffman_roundtrip(all_passed)
        logical, intent(inout) :: all_passed
        type(huffman_encoder_t) :: encoder
        type(huffman_decoder_t) :: decoder
        type(bit_buffer_t) :: buffer
        logical :: encode_success, decode_success
        integer :: original_symbol, decoded_symbol, bit_pos
        
        print *, "Testing Huffman roundtrip (encode then decode)..."
        
        call init_mpeg_huffman_tables(encoder, decoder, 'DC_LUM')
        
        original_symbol = 1
        
        encode_success = encode_huffman_value(encoder, original_symbol, buffer)
        if (.not. encode_success) then
            print *, "FAILED: Could not encode symbol", original_symbol
            all_passed = .false.
            return
        end if
        
        bit_pos = 1
        decode_success = decode_huffman_value(decoder, buffer%buffer, bit_pos, decoded_symbol)
        if (.not. decode_success) then
            print *, "FAILED: Could not decode symbol"
            all_passed = .false.
            return
        end if
        
        if (decoded_symbol /= original_symbol) then
            print *, "FAILED: Roundtrip failed - encoded", original_symbol, "but decoded", decoded_symbol
            all_passed = .false.
            return
        end if
        
        print *, "Huffman roundtrip test passed"
    end subroutine test_huffman_roundtrip
    
    subroutine test_bit_buffer_operations(all_passed)
        logical, intent(inout) :: all_passed
        type(huffman_encoder_t) :: encoder
        type(huffman_decoder_t) :: decoder
        type(bit_buffer_t) :: buffer
        logical :: success
        integer :: i
        
        print *, "Testing bit buffer operations..."
        
        call init_mpeg_huffman_tables(encoder, decoder, 'DC_LUM')
        
        do i = 0, 5
            success = encode_huffman_value(encoder, mod(i, encoder%num_symbols), buffer)
            if (.not. success) then
                print *, "FAILED: Could not encode symbol", mod(i, encoder%num_symbols)
                all_passed = .false.
                return
            end if
        end do
        
        if (buffer%byte_pos < 2) then
            print *, "FAILED: Buffer should have at least 2 bytes after encoding 6 symbols"
            all_passed = .false.
            return
        end if
        
        print *, "Bit buffer operations test passed"
    end subroutine test_bit_buffer_operations
    
end program test_mpeg_huffman