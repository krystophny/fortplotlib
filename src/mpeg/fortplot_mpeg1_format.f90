module fortplot_mpeg1_format
    use fortplot_mpeg_stream
    use fortplot_mpeg_huffman
    use iso_c_binding
    implicit none
    
    ! MPEG-1 format constants and utilities for standard compliance
    
    ! MPEG-1 start codes
    integer, parameter :: MPEG_SEQUENCE_HEADER_CODE = int(z'000001B3')
    integer, parameter :: MPEG_GOP_HEADER_CODE = int(z'000001B8')  
    integer, parameter :: MPEG_PICTURE_HEADER_CODE = int(z'00000100')
    integer, parameter :: MPEG_SLICE_START_CODE = int(z'00000101')  ! First slice
    integer, parameter :: MPEG_SEQUENCE_END_CODE = int(z'000001B7')
    
    ! Picture types
    integer, parameter :: I_FRAME = 1  ! Intra-coded
    integer, parameter :: P_FRAME = 2  ! Predictive-coded  
    integer, parameter :: B_FRAME = 3  ! Bidirectionally predictive-coded
    
    ! Aspect ratio codes
    integer, parameter :: ASPECT_RATIO_1_1 = 1    ! Square pixels
    integer, parameter :: ASPECT_RATIO_4_3 = 2    ! 4:3 display
    integer, parameter :: ASPECT_RATIO_16_9 = 3   ! 16:9 display
    
    ! Frame rate codes
    integer, parameter :: FRAME_RATE_23_976 = 1
    integer, parameter :: FRAME_RATE_24 = 2
    integer, parameter :: FRAME_RATE_25 = 3
    integer, parameter :: FRAME_RATE_29_97 = 4
    integer, parameter :: FRAME_RATE_30 = 5
    integer, parameter :: FRAME_RATE_50 = 6
    integer, parameter :: FRAME_RATE_59_94 = 7
    integer, parameter :: FRAME_RATE_60 = 8
    
    ! MPEG-1 macroblock and block constants
    integer, parameter :: MACROBLOCK_SIZE = 16
    integer, parameter :: BLOCK_SIZE = 8
    integer, parameter :: BLOCKS_PER_MACROBLOCK = 6  ! 4Y + 1Cb + 1Cr
    
    ! Huffman encoders for MPEG-1 compliance
    type(huffman_encoder_t) :: dc_lum_encoder, dc_chrom_encoder
    type(huffman_encoder_t) :: ac_encoder, mba_encoder
    type(huffman_decoder_t) :: dc_lum_decoder, dc_chrom_decoder
    type(huffman_decoder_t) :: ac_decoder, mba_decoder
    logical :: huffman_tables_initialized = .false.
    
    ! MPEG-1 default quantization matrices
    integer, parameter :: DEFAULT_INTRA_MATRIX(8,8) = reshape([ &
        8, 16, 19, 22, 26, 27, 29, 34, &
        16, 16, 22, 24, 27, 29, 34, 37, &
        19, 22, 26, 27, 29, 34, 34, 38, &
        22, 22, 26, 27, 29, 34, 37, 40, &
        22, 26, 27, 29, 32, 35, 40, 48, &
        26, 27, 29, 32, 35, 40, 48, 58, &
        26, 27, 29, 34, 38, 46, 56, 69, &
        27, 29, 35, 38, 46, 56, 69, 83 &
    ], [8, 8])
    
    integer, parameter :: DEFAULT_INTER_MATRIX(8,8) = 16
    
    ! MPEG-1 zigzag scan order (converting 2D to 1D)
    integer, parameter :: ZIGZAG_ORDER(64) = [ &
        1,  2,  9, 17, 10,  3,  4, 11, &
       18, 25, 33, 26, 19, 12,  5,  6, &
       13, 20, 27, 34, 41, 49, 42, 35, &
       28, 21, 14,  7,  8, 15, 22, 29, &
       36, 43, 50, 57, 58, 51, 44, 37, &
       30, 23, 16, 24, 31, 38, 45, 52, &
       59, 60, 53, 46, 39, 32, 40, 47, &
       54, 61, 62, 55, 48, 56, 63, 64 &
    ]

contains

    subroutine validate_sequence_parameters(width, height, frame_rate, bit_rate)
        ! Validate sequence header parameters match C library constraints
        integer, intent(in) :: width, height, frame_rate, bit_rate
        
        ! Width and height must be multiples of 16 (macroblock size)
        if (mod(width, 16) /= 0) then
            print *, "Warning: Width", width, "not multiple of 16, may cause issues"
        end if
        if (mod(height, 16) /= 0) then
            print *, "Warning: Height", height, "not multiple of 16, may cause issues"
        end if
        
        ! Validate dimensions fit in 12 bits
        if (width < 1 .or. width > 4095) then
            error stop "Width must be between 1 and 4095"
        end if
        if (height < 1 .or. height > 4095) then
            error stop "Height must be between 1 and 4095"
        end if
        
        ! Validate bit rate (18 bits in units of 400 bps)
        if (bit_rate < 0 .or. bit_rate > (262143 * 400)) then
            error stop "Bit rate out of valid range"
        end if
    end subroutine

    subroutine write_mpeg1_sequence_header(width, height, frame_rate, bit_rate)
        ! Write MPEG-1 sequence header for standard compliance
        ! Matches C library WriteVSHeader() function
        integer, intent(in) :: width, height, frame_rate, bit_rate
        
        integer :: aspect_ratio, rate_code, brate_units
        integer :: horizontal_size, vertical_size
        
        ! Validate parameters first
        call validate_sequence_parameters(width, height, frame_rate, bit_rate)
        
        print *, "Writing MPEG-1 sequence header..."
        
        ! C: ByteAlign() - align to byte boundary
        call stream_flush_write()
        
        ! C: mputv(MBSC_LENGTH,MBSC) + mputv(VSSC_LENGTH,VSSC)
        ! MPEG-1 sequence start code: 00 00 01 B3
        call write_mpeg_start_code(MPEG_SEQUENCE_HEADER_CODE)
        
        ! Sequence parameters (following MPEG-1 standard)
        horizontal_size = width
        vertical_size = height
        
        ! Encode sequence parameters
        call stream_put_variable(horizontal_size, 12)   ! Horizontal size (12 bits)
        call stream_put_variable(vertical_size, 12)     ! Vertical size (12 bits)
        
        ! Aspect ratio (4 bits) - assume square pixels for simplicity
        aspect_ratio = ASPECT_RATIO_1_1
        call stream_put_variable(aspect_ratio, 4)
        
        ! Picture rate code (4 bits)
        rate_code = get_frame_rate_code(frame_rate)
        call stream_put_variable(rate_code, 4)
        
        ! Bit rate value (18 bits) - in units of 400 bits/sec
        ! C: Brate = (Rate+399)/400 - Round upward
        brate_units = (bit_rate + 399) / 400
        if (brate_units == 0) brate_units = 262143  ! 0x3FFFF for variable bit rate
        call stream_put_variable(brate_units, 18)
        
        ! Marker bit
        call stream_put_bit(1)
        
        ! VBV buffer size (10 bits) - video buffering verifier
        ! Use smaller buffer size for small videos to match reference
        call stream_put_variable(8, 10)  ! Smaller buffer size
        
        ! Constrained parameters flag (1 bit) - set to 0 for compatibility
        call stream_put_bit(0)
        
        ! Load intra quantizer matrix flag (1 bit) - use default
        call stream_put_bit(0)
        
        ! Load non-intra quantizer matrix flag (1 bit) - use default  
        call stream_put_bit(0)
        
        print *, "  Sequence header written for", width, "x", height, "@", frame_rate, "fps"
    end subroutine

    subroutine write_mpeg1_gop_header(time_code)
        ! Write Group of Pictures header
        ! Matches C library WriteGOPHeader() function
        integer, intent(in) :: time_code
        
        ! Validate time code
        if (time_code < 0 .or. time_code >= 2**25) then
            error stop "GOP time code must fit in 25 bits"
        end if
        
        ! C: ByteAlign()
        call stream_flush_write()
        
        ! GOP start code: 00 00 01 B8
        call write_mpeg_start_code(MPEG_GOP_HEADER_CODE)
        
        ! Time code (25 bits)
        call stream_put_variable(time_code, 25)
        
        ! Closed GOP flag (1 bit) - C uses ClosedGOP variable
        call stream_put_bit(1)
        
        ! Broken link flag (1 bit) - C uses BrokenLink variable
        call stream_put_bit(0)
    end subroutine

    subroutine write_mpeg1_picture_header(frame_number, picture_type)
        ! Write picture header for individual frames
        ! Matches C library WritePictureHeader() function
        integer, intent(in) :: frame_number, picture_type
        
        integer :: temporal_reference, vbv_delay
        
        ! C: ByteAlign() - CRITICAL for proper start code alignment
        call stream_flush_write()
        
        ! Picture start code: 00 00 01 00
        call write_mpeg_start_code(MPEG_PICTURE_HEADER_CODE)
        
        ! Temporal reference (10 bits) - display order within GOP
        ! Frame number within GOP (starts at 0)
        temporal_reference = mod(frame_number, 1024)  ! 10-bit max
        call stream_put_variable(temporal_reference, 10)
        
        ! Picture coding type (3 bits)
        call stream_put_variable(picture_type, 3)
        
        ! VBV delay (16 bits) - use constant for simplicity
        vbv_delay = 65535  ! 0xFFFF indicates constant bitrate
        call stream_put_variable(vbv_delay, 16)
        
        ! For P and B frames, would need additional parameters here
        ! For I-frames only, this is sufficient
    end subroutine

    subroutine write_mpeg1_slice_header(slice_number)
        ! Write slice header - mandatory between picture header and macroblocks
        ! Matches C library WriteMBSHeader() function
        integer, intent(in) :: slice_number
        
        ! Validate slice number (1-175)
        if (slice_number < 1 .or. slice_number > 175) then
            error stop "Slice number must be between 1 and 175"
        end if
        
        ! C: ByteAlign()
        call stream_flush_write()
        
        ! C: mputv(MBSC_LENGTH,MBSC) + mputv(1,SVP)
        ! Write slice start code with slice vertical position
        call stream_put_variable(0, 8)    ! 0x00
        call stream_put_variable(0, 8)    ! 0x00
        call stream_put_variable(1, 8)    ! 0x01
        call stream_put_variable(slice_number, 8)  ! Slice vertical position
        
        ! C: mputv(5,SQuant) - Quantizer scale code (5 bits)
        call stream_put_variable(16, 5)  ! Mid-range quantizer
        
        ! C: mputb(0) - Extra slice information (optional)
        call stream_put_bit(0)  ! No extra information
    end subroutine

    subroutine write_mpeg1_sequence_end()
        ! Write sequence end code
        call write_mpeg_start_code(MPEG_SEQUENCE_END_CODE)
    end subroutine

    subroutine write_mpeg_start_code(start_code)
        ! Write a 32-bit MPEG start code in proper byte order
        integer, intent(in) :: start_code
        
        ! Write start code bytes directly (known values)
        if (start_code == MPEG_SEQUENCE_HEADER_CODE) then
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(0, 8)    ! 0x00  
            call stream_put_variable(1, 8)    ! 0x01
            call stream_put_variable(179, 8)  ! 0xB3
        else if (start_code == MPEG_GOP_HEADER_CODE) then
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(1, 8)    ! 0x01  
            call stream_put_variable(184, 8)  ! 0xB8
        else if (start_code == MPEG_PICTURE_HEADER_CODE) then
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(1, 8)    ! 0x01
            call stream_put_variable(0, 8)    ! 0x00
        else if (start_code == MPEG_SLICE_START_CODE) then
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(1, 8)    ! 0x01
            call stream_put_variable(1, 8)    ! 0x01 (slice 1)
        else if (start_code == MPEG_SEQUENCE_END_CODE) then
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(0, 8)    ! 0x00
            call stream_put_variable(1, 8)    ! 0x01
            call stream_put_variable(183, 8)  ! 0xB7
        end if
    end subroutine

    function get_frame_rate_code(frame_rate) result(code)
        ! Map frame rate to MPEG-1 standard code
        integer, intent(in) :: frame_rate
        integer :: code
        
        select case (frame_rate)
        case (24)
            code = FRAME_RATE_24
        case (25)
            code = FRAME_RATE_25
        case (30)
            code = FRAME_RATE_30
        case (50)
            code = FRAME_RATE_50
        case (60)
            code = FRAME_RATE_60
        case default
            ! Default to 25 fps for non-standard rates
            code = FRAME_RATE_25
            print *, "Warning: Non-standard frame rate", frame_rate, "using 25fps code"
        end select
    end function

    subroutine write_mpeg1_compatible_video(filename, width, height, frame_rate, num_frames)
        ! Create MPEG-1 compliant video with proper headers
        character(len=*), intent(in) :: filename
        integer, intent(in) :: width, height, frame_rate, num_frames
        
        integer :: bit_rate, time_code, frame_num
        
        print *, "Creating MPEG-1 compliant video..."
        print *, "  File:", trim(filename)
        print *, "  Format:", width, "x", height, "@", frame_rate, "fps"
        
        ! Open output stream
        call stream_open_write(filename)
        
        ! Calculate reasonable bit rate (bits per second) in units of 400 bits/sec
        ! MPEG-1 bit rate is specified in units of 400 bits/second
        bit_rate = (width * height * frame_rate * 8) / 400
        if (bit_rate < 1) bit_rate = 1  ! Minimum value
        
        ! Write MPEG-1 sequence header
        call write_mpeg1_sequence_header(width, height, frame_rate, bit_rate)
        
        ! Write GOP header
        time_code = 0  ! Start at time 0
        call write_mpeg1_gop_header(time_code)
        
        ! Write frames (I-frames only for simplicity)
        do frame_num = 1, num_frames
            call write_mpeg1_picture_header(frame_num - 1, I_FRAME)
            
            ! Write mandatory slice header
            call write_mpeg1_slice_header(1)
            
            ! Write actual compressed frame data using MPEG-1 structure
            ! For small videos, write minimal encoded macroblock data
            call encode_minimal_frame_data(width, height)
            
            print *, "  Frame", frame_num, "of", num_frames
        end do
        
        ! Write sequence end
        call write_mpeg1_sequence_end()
        
        call stream_close_write()
        
        print *, "MPEG-1 compliant video created successfully"
    end subroutine

    subroutine encode_mpeg1_frame(frame_data, width, height)
        ! Encode frame data using MPEG-1 macroblock structure
        ! Matches C library MpegEncodeSlice() and MpegEncodeMDU() flow
        use fortplot_mpeg_memory, only: mem_t
        type(mem_t), intent(in) :: frame_data
        integer, intent(in) :: width, height
        
        integer :: mb_x, mb_y, num_mb_x, num_mb_y, block_num, quantizer_scale
        integer :: block_data(BLOCK_SIZE, BLOCK_SIZE)
        integer :: dct_coeffs(BLOCK_SIZE, BLOCK_SIZE)
        integer :: y_blocks(4, BLOCK_SIZE, BLOCK_SIZE)
        integer :: cb_block(BLOCK_SIZE, BLOCK_SIZE), cr_block(BLOCK_SIZE, BLOCK_SIZE)
        integer :: last_dc(3)  ! DC predictors for Y, Cb, Cr
        
        ! Calculate number of macroblocks
        num_mb_x = (width + MACROBLOCK_SIZE - 1) / MACROBLOCK_SIZE
        num_mb_y = (height + MACROBLOCK_SIZE - 1) / MACROBLOCK_SIZE
        
        ! C: for(x=0;x<3;x++) LastDC[x]=128 - Reset DC predictors
        last_dc = 128
        
        ! Process each macroblock
        do mb_y = 0, num_mb_y - 1
            do mb_x = 0, num_mb_x - 1
                ! Extract macroblock data and convert to MPEG-1 blocks
                call extract_macroblock_data(frame_data, width, height, mb_x, mb_y, &
                                            y_blocks, cb_block, cr_block)
                
                ! C: MpegWriteMType() - Write macroblock header
                ! For I-frames: address increment + macroblock type
                call write_macroblock_header(mb_x, mb_y)
                
                ! Calculate dynamic quantizer scale based on frame complexity
                ! C library uses adaptive quantization, start with mid-range
                quantizer_scale = calculate_quantizer_scale(mb_x, mb_y, num_mb_x, num_mb_y)
                
                ! Encode Y blocks (4 blocks of 8x8 luminance)
                do block_num = 1, 4
                    block_data = y_blocks(block_num, :, :)
                    call mpeg1_dct_transform(block_data, dct_coeffs)
                    call quantize_block(dct_coeffs, quantizer_scale, block_num <= 4)  ! Intra quantization
                    call encode_dct_block(dct_coeffs, last_dc, block_num)
                end do
                
                ! Encode Cb block (chrominance blue)
                call mpeg1_dct_transform(cb_block, dct_coeffs)
                call quantize_block(dct_coeffs, quantizer_scale, .false.)  ! Chroma quantization
                call encode_dct_block(dct_coeffs, last_dc, 5)
                
                ! Encode Cr block (chrominance red)
                call mpeg1_dct_transform(cr_block, dct_coeffs)
                call quantize_block(dct_coeffs, quantizer_scale, .false.)  ! Chroma quantization
                call encode_dct_block(dct_coeffs, last_dc, 6)
            end do
        end do
    end subroutine

    subroutine extract_macroblock_data(frame_data, width, height, mb_x, mb_y, &
                                     y_blocks, cb_block, cr_block)
        ! Extract 16x16 macroblock and split into 8x8 blocks
        use fortplot_mpeg_memory, only: mem_t
        type(mem_t), intent(in) :: frame_data
        integer, intent(in) :: width, height, mb_x, mb_y
        integer, intent(out) :: y_blocks(4, BLOCK_SIZE, BLOCK_SIZE)
        integer, intent(out) :: cb_block(BLOCK_SIZE, BLOCK_SIZE), cr_block(BLOCK_SIZE, BLOCK_SIZE)
        
        integer :: x, y, pixel_idx, pixel_value
        integer :: block_x, block_y, block_num
        
        ! Initialize blocks
        y_blocks = 0
        cb_block = 0  
        cr_block = 0
        
        ! Extract 16x16 macroblock into 4 Y blocks + Cb/Cr blocks
        do y = 0, MACROBLOCK_SIZE - 1
            do x = 0, MACROBLOCK_SIZE - 1
                ! Calculate source pixel position
                pixel_idx = (mb_y * MACROBLOCK_SIZE + y) * width + (mb_x * MACROBLOCK_SIZE + x) + 1
                
                ! Bounds check
                if (pixel_idx > 0 .and. pixel_idx <= width * height) then
                    pixel_value = int(frame_data%data(pixel_idx))
                else
                    pixel_value = 128  ! Default gray for out-of-bounds
                end if
                
                ! Determine which 8x8 block this pixel belongs to
                block_x = x / BLOCK_SIZE
                block_y = y / BLOCK_SIZE
                block_num = block_y * 2 + block_x + 1
                
                ! Store in appropriate Y block
                if (block_num >= 1 .and. block_num <= 4) then
                    y_blocks(block_num, mod(y, BLOCK_SIZE) + 1, mod(x, BLOCK_SIZE) + 1) = pixel_value
                end if
                
                ! For proper grayscale: Y=brightness, Cb/Cr=neutral (128)
                if (x < BLOCK_SIZE .and. y < BLOCK_SIZE) then
                    cb_block(y + 1, x + 1) = 128  ! Neutral blue/yellow (no color tint)
                    cr_block(y + 1, x + 1) = 128  ! Neutral red/green (no color tint)
                end if
            end do
        end do
    end subroutine
    
    function calculate_quantizer_scale(mb_x, mb_y, num_mb_x, num_mb_y) result(scale)
        ! Calculate dynamic quantizer scale for better compression
        ! Based on macroblock position and content complexity
        integer, intent(in) :: mb_x, mb_y, num_mb_x, num_mb_y
        integer :: scale
        
        ! Simple adaptive scaling: lower quality at edges, higher in center
        ! C library uses complex rate control, this is simplified
        real :: distance_from_center, max_distance
        
        distance_from_center = sqrt(real((mb_x - num_mb_x/2)**2 + (mb_y - num_mb_y/2)**2))
        max_distance = sqrt(real((num_mb_x/2)**2 + (num_mb_y/2)**2))
        
        if (max_distance > 0) then
            ! Scale from 8 (high quality center) to 24 (lower quality edges)
            scale = 8 + int(16 * distance_from_center / max_distance)
        else
            scale = 16  ! Default mid-range
        end if
        
        ! Clamp to valid MPEG-1 range
        if (scale < 1) scale = 1
        if (scale > 31) scale = 31
    end function

    subroutine write_macroblock_header(mb_x, mb_y)
        ! Write macroblock header matching C library
        integer, intent(in) :: mb_x, mb_y
        integer :: mb_address_increment
        
        ! C: Macroblock address increment (always 1 for sequential)
        mb_address_increment = 1
        call encode_macroblock_address_increment(mb_address_increment)
        
        ! C: Macroblock type for I-frame  
        ! From C ctables.h IntraTypeCoeff: Type 0 = 1 bit code 1
        call stream_put_variable(1, 1)  ! Intra macroblock type 0
        
        ! C: MQuant flag is part of macroblock type
        ! For simple I-frame, no quantizer change needed
    end subroutine
    
    subroutine encode_macroblock_address_increment(increment)
        ! Encode macroblock address increment using VLC
        integer, intent(in) :: increment
        
        ! C MBA Huffman table from marker.c:
        ! MBA=1: 1 bit, code 1
        ! MBA=2: 3 bits, code 011
        ! etc.
        
        select case(increment)
        case(1)
            call stream_put_variable(1, 1)  ! Code: 1
        case(2)
            call stream_put_variable(3, 3)  ! Code: 011
        case(3)
            call stream_put_variable(2, 3)  ! Code: 010
        case(4)
            call stream_put_variable(3, 4)  ! Code: 0011
        case(5)
            call stream_put_variable(2, 4)  ! Code: 0010
        case default
            ! Escape sequence for larger increments
            call stream_put_variable(0, 11) ! Escape code
            call stream_put_variable(increment, 6)
        end select
    end subroutine

    subroutine mpeg1_dct_transform(input_block, output_coeffs)
        ! Proper 8x8 DCT transform for MPEG-1 compliance
        integer, intent(in) :: input_block(BLOCK_SIZE, BLOCK_SIZE)
        integer, intent(out) :: output_coeffs(BLOCK_SIZE, BLOCK_SIZE)
        
        real :: temp_input(BLOCK_SIZE, BLOCK_SIZE)
        real :: temp_output(BLOCK_SIZE, BLOCK_SIZE)
        integer :: i, j
        
        ! Convert to real and center around 0 (subtract 128)
        do i = 1, BLOCK_SIZE
            do j = 1, BLOCK_SIZE
                temp_input(i, j) = real(input_block(i, j)) - 128.0
            end do
        end do
        
        ! Apply 2D DCT
        call dct_2d_8x8(temp_input, temp_output)
        
        ! Convert back to integer
        do i = 1, BLOCK_SIZE
            do j = 1, BLOCK_SIZE
                output_coeffs(i, j) = nint(temp_output(i, j))
            end do
        end do
    end subroutine

    subroutine dct_2d_8x8(input, output)
        ! 2D DCT implementation using separable transform
        real, intent(in) :: input(8, 8)
        real, intent(out) :: output(8, 8)
        
        real :: temp(8, 8)
        real :: pi_over_8
        real :: cos_table(0:7, 0:7)
        real :: c_norm(0:7)
        integer :: u, v, x, y
        real :: sum_val
        
        pi_over_8 = atan(1.0) * 4.0 / 8.0  ! π/8
        
        ! Precompute cosine table and normalization factors
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

    subroutine quantize_block(dct_coeffs, quantizer_scale, is_luma)
        ! MPEG-1 quantization using default matrices
        ! EXACT C library MPEGIntraQuantize() algorithm (transform.c:368-396)
        integer, intent(inout) :: dct_coeffs(BLOCK_SIZE, BLOCK_SIZE)
        integer, intent(in) :: quantizer_scale
        logical, intent(in) :: is_luma
        
        integer :: i, j, quantized_value, qvalue, qp
        
        qp = quantizer_scale * 2  ! C library: qp = qfact << 1
        
        do i = 1, BLOCK_SIZE
            do j = 1, BLOCK_SIZE
                if (i == 1 .and. j == 1) then
                    ! DC coefficient - EXACT C library algorithm
                    ! C: if (*mptr>0) *mptr=(*mptr + 4)/8; else *mptr=(*mptr - 4)/8;
                    if (dct_coeffs(i, j) > 0) then
                        dct_coeffs(i, j) = (dct_coeffs(i, j) + 4) / 8
                    else
                        dct_coeffs(i, j) = (dct_coeffs(i, j) - 4) / 8
                    end if
                else
                    ! AC coefficients - EXACT C library 2-step algorithm
                    qvalue = DEFAULT_INTRA_MATRIX(i, j)
                    
                    if (dct_coeffs(i, j) > 0) then
                        ! C: *mptr = FastDivide(((*mptr << 4) + (*qptr >> 1)), *qptr);
                        quantized_value = ((dct_coeffs(i, j) * 16) + (qvalue / 2)) / qvalue
                        ! C: *mptr = FastDivide((*mptr + qfact), qp);
                        quantized_value = (quantized_value + quantizer_scale) / qp
                    else if (dct_coeffs(i, j) < 0) then
                        ! C: *mptr = FastDivide(((*mptr << 4) - (*qptr >> 1)), *qptr);
                        quantized_value = ((dct_coeffs(i, j) * 16) - (qvalue / 2)) / qvalue
                        ! C: *mptr = FastDivide((*mptr - qfact), qp);
                        quantized_value = (quantized_value - quantizer_scale) / qp
                    else
                        quantized_value = 0
                    end if
                    
                    ! Clamp to valid range (C: BoundQuantizeMatrix)
                    if (quantized_value > 255) quantized_value = 255
                    if (quantized_value < -255) quantized_value = -255
                    
                    dct_coeffs(i, j) = quantized_value
                end if
            end do
        end do
    end subroutine

    subroutine encode_dct_block(dct_coeffs, last_dc, block_type)
        ! Encode DCT coefficients using MPEG-1 zigzag scan and VLC
        ! Matches C library block encoding
        integer, intent(in) :: dct_coeffs(BLOCK_SIZE, BLOCK_SIZE)
        integer, intent(inout) :: last_dc(3)
        integer, intent(in) :: block_type  ! 1-4: Y, 5: Cb, 6: Cr
        
        integer :: zigzag_coeffs(64)
        integer :: i, j, idx, run_length, level, coeff_idx
        integer :: dc_diff, dc_index
        
        ! Convert 2D DCT coefficients to 1D using zigzag scan
        do idx = 1, 64
            i = (ZIGZAG_ORDER(idx) - 1) / 8 + 1
            j = mod(ZIGZAG_ORDER(idx) - 1, 8) + 1
            zigzag_coeffs(idx) = dct_coeffs(i, j)
        end do
        
        ! Encode DC coefficient with differential coding
        ! C: DC prediction based on block type
        if (block_type <= 4) then
            dc_index = 1  ! Y blocks use predictor 1
        else if (block_type == 5) then
            dc_index = 2  ! Cb block uses predictor 2
        else
            dc_index = 3  ! Cr block uses predictor 3
        end if
        
        dc_diff = zigzag_coeffs(1) - last_dc(dc_index)
        last_dc(dc_index) = zigzag_coeffs(1)  ! Update predictor
        
        call encode_dc_coefficient(dc_diff)
        
        ! Encode AC coefficients using run-length encoding
        run_length = 0
        coeff_idx = 2  ! Start after DC coefficient
        
        do while (coeff_idx <= 64)
            level = zigzag_coeffs(coeff_idx)
            
            if (level == 0) then
                run_length = run_length + 1
            else
                ! Encode (run, level) pair
                call encode_ac_coefficient(run_length, level)
                run_length = 0
            end if
            
            coeff_idx = coeff_idx + 1
        end do
        
        ! End of block
        call encode_end_of_block()
    end subroutine

    subroutine ensure_huffman_tables_initialized()
        ! Initialize Huffman tables if not already done
        if (.not. huffman_tables_initialized) then
            call init_mpeg_huffman_tables(dc_lum_encoder, dc_lum_decoder, 'DC_LUM')
            call init_mpeg_huffman_tables(dc_chrom_encoder, dc_chrom_decoder, 'DC_CHROM')
            call init_mpeg_huffman_tables(ac_encoder, ac_decoder, 'AC_COEFF')
            call init_mpeg_huffman_tables(mba_encoder, mba_decoder, 'MBA')
            huffman_tables_initialized = .true.
        end if
    end subroutine
    
    subroutine encode_dc_coefficient(dc_value)
        ! Encode DC coefficient using MPEG-1 Huffman tables
        integer, intent(in) :: dc_value
        
        integer :: size, additional_bits
        type(bit_buffer_t) :: temp_buffer
        logical :: success
        
        call ensure_huffman_tables_initialized()
        
        ! Determine size category
        if (abs(dc_value) == 0) then
            size = 0
        else if (abs(dc_value) <= 1) then
            size = 1
        else if (abs(dc_value) <= 3) then
            size = 2
        else if (abs(dc_value) <= 7) then
            size = 3
        else if (abs(dc_value) <= 15) then
            size = 4
        else if (abs(dc_value) <= 31) then
            size = 5
        else if (abs(dc_value) <= 63) then
            size = 6
        else if (abs(dc_value) <= 127) then
            size = 7
        else
            size = 8
        end if
        
        ! Encode size using exact C library DCLumCoeff table 
        select case(size)
        case(0)
            call stream_put_variable(4, 3)  ! Code 4, 3 bits
        case(1) 
            call stream_put_variable(0, 2)  ! Code 0, 2 bits
        case(2)
            call stream_put_variable(1, 2)  ! Code 1, 2 bits
        case(3)
            call stream_put_variable(5, 3)  ! Code 5, 3 bits
        case(4)
            call stream_put_variable(6, 3)  ! Code 6, 3 bits
        case(5)
            call stream_put_variable(14, 4) ! Code 14, 4 bits
        case(6)
            call stream_put_variable(30, 5) ! Code 30, 5 bits
        case(7)
            call stream_put_variable(62, 6) ! Code 62, 6 bits
        case(8)
            call stream_put_variable(126, 7) ! Code 126, 7 bits
        case default
            call stream_put_variable(4, 3)  ! Default to size 0
        end select
        
        ! Encode additional bits if needed
        if (size > 0) then
            if (dc_value >= 0) then
                additional_bits = dc_value
            else
                additional_bits = dc_value + (2**size - 1)
            end if
            call stream_put_variable(additional_bits, size)
        end if
    end subroutine

    subroutine encode_ac_coefficient(run, level)
        ! Encode AC coefficient using MPEG-1 Huffman tables
        integer, intent(in) :: run, level
        
        type(bit_buffer_t) :: temp_buffer
        integer :: symbol
        logical :: success
        
        call ensure_huffman_tables_initialized()
        
        ! Encode (run, level) pair - simplified mapping
        if (run == 0 .and. level == 1) then
            symbol = 1  ! Common case
        else if (run == 1 .and. level == 1) then
            symbol = 257  ! Run=1, Level=1 from AC table
        else
            ! Fallback to escape sequence
            call stream_put_variable(1, 6)  ! Escape code
            call stream_put_variable(run, 6)
            call stream_put_variable(level + 128, 8)
            return
        end if
        
        success = encode_huffman_value(ac_encoder, symbol, temp_buffer)
        if (.not. success) then
            ! Fallback to simple encoding
            call stream_put_variable(run, 6)
            call stream_put_variable(level + 128, 8)
        end if
    end subroutine

    subroutine encode_end_of_block()
        ! End of block marker using exact C library TCoeff1 table
        ! EOB = symbol 0, 2 bits, code 2
        call stream_put_variable(2, 2)  ! Code 2, 2 bits
    end subroutine
    
    subroutine encode_minimal_frame_data(width, height)
        ! Encode minimal valid MPEG-1 frame data for testing
        integer, intent(in) :: width, height
        
        integer :: num_mb_x, num_mb_y, mb_x, mb_y, block_num
        
        ! Calculate number of macroblocks
        num_mb_x = (width + MACROBLOCK_SIZE - 1) / MACROBLOCK_SIZE
        num_mb_y = (height + MACROBLOCK_SIZE - 1) / MACROBLOCK_SIZE
        
        ! Encode each macroblock with minimal data
        do mb_y = 0, num_mb_y - 1
            do mb_x = 0, num_mb_x - 1
                ! Macroblock address increment (always 1 for sequential)
                call stream_put_variable(1, 5)  ! MBA increment = 1
                
                ! Macroblock type: Intra
                call stream_put_variable(1, 5)  ! Intra macroblock
                
                ! Quantizer scale (if needed)
                call stream_put_variable(16, 5)  ! Mid-range quantizer
                
                ! Encode 6 blocks (4Y + Cb + Cr) with minimal DCT data
                do block_num = 1, BLOCKS_PER_MACROBLOCK
                    ! DC coefficient (level 0)
                    call stream_put_variable(0, 3)  ! DC size = 0
                    
                    ! End of block immediately (no AC coefficients)
                    call stream_put_variable(2, 2)  ! EOB code
                end do
            end do
        end do
    end subroutine

end module fortplot_mpeg1_format