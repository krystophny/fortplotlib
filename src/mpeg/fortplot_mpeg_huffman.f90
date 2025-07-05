module fortplot_mpeg_huffman
    !! MPEG Huffman encoding implementation
    !! Adapted from PNG zlib implementation with MPEG-specific tables
    use, intrinsic :: iso_fortran_env, only: int8, int32
    use iso_c_binding, only: c_int
    implicit none
    
    private
    public :: huffman_encoder_t, huffman_decoder_t, bit_buffer_t, init_mpeg_huffman_tables
    public :: encode_huffman_value, decode_huffman_value
    
    integer, parameter :: MAX_CODE_LENGTH = 16
    integer, parameter :: MAX_SYMBOLS = 512
    
    type :: huffman_encoder_t
        integer :: codes(0:MAX_SYMBOLS-1)
        integer :: lengths(0:MAX_SYMBOLS-1)
        integer :: num_symbols
    end type huffman_encoder_t
    
    type :: huffman_decoder_t
        integer :: symbols(0:MAX_SYMBOLS-1)
        integer :: codes(0:MAX_SYMBOLS-1)
        integer :: lengths(0:MAX_SYMBOLS-1)
        integer :: num_symbols
    end type huffman_decoder_t
    
    type :: bit_buffer_t
        integer(int8), allocatable :: buffer(:)
        integer :: bit_pos
        integer :: byte_pos
    end type bit_buffer_t
    
contains

    subroutine init_mpeg_huffman_tables(encoder, decoder, table_type)
        !! Initialize MPEG Huffman tables based on C reference implementation
        type(huffman_encoder_t), intent(out) :: encoder
        type(huffman_decoder_t), intent(out) :: decoder
        character(len=*), intent(in) :: table_type
        
        select case (trim(table_type))
        case ('DC_LUM')
            call init_dc_lum_table(encoder, decoder)
        case ('DC_CHROM')
            call init_dc_chrom_table(encoder, decoder)
        case ('AC_COEFF')
            call init_ac_coeff_table(encoder, decoder)
        case ('MBA')
            call init_mba_table(encoder, decoder)
        case ('MVD')
            call init_mvd_table(encoder, decoder)
        case default
            call init_dc_lum_table(encoder, decoder)
        end select
    end subroutine init_mpeg_huffman_tables
    
    subroutine init_dc_lum_table(encoder, decoder)
        !! Initialize DC luminance Huffman table from MPEG ctables.h
        type(huffman_encoder_t), intent(out) :: encoder
        type(huffman_decoder_t), intent(out) :: decoder
        
        integer, parameter :: DC_LUM_TABLE(0:26) = [ &
            0, 3, 4, &    ! Symbol 0, length 3, code 4
            1, 2, 0, &    ! Symbol 1, length 2, code 0  
            2, 2, 1, &    ! Symbol 2, length 2, code 1
            3, 3, 5, &    ! Symbol 3, length 3, code 5
            4, 3, 6, &    ! Symbol 4, length 3, code 6
            5, 4, 14, &   ! Symbol 5, length 4, code 14
            6, 5, 30, &   ! Symbol 6, length 5, code 30
            7, 6, 62, &   ! Symbol 7, length 6, code 62
            8, 7, 126 &   ! Symbol 8, length 7, code 126
        ]
        
        call build_huffman_tables(DC_LUM_TABLE, size(DC_LUM_TABLE)/3, encoder, decoder)
    end subroutine init_dc_lum_table
    
    subroutine init_dc_chrom_table(encoder, decoder)
        !! Initialize DC chrominance Huffman table from MPEG ctables.h
        type(huffman_encoder_t), intent(out) :: encoder
        type(huffman_decoder_t), intent(out) :: decoder
        
        integer, parameter :: DC_CHROM_TABLE(0:26) = [ &
            0, 2, 0, &    ! Symbol 0, length 2, code 0
            1, 2, 1, &    ! Symbol 1, length 2, code 1
            2, 2, 2, &    ! Symbol 2, length 2, code 2
            3, 3, 6, &    ! Symbol 3, length 3, code 6
            4, 4, 14, &   ! Symbol 4, length 4, code 14
            5, 5, 30, &   ! Symbol 5, length 5, code 30
            6, 6, 62, &   ! Symbol 6, length 6, code 62
            7, 7, 126, &  ! Symbol 7, length 7, code 126
            8, 8, 254 &   ! Symbol 8, length 8, code 254
        ]
        
        call build_huffman_tables(DC_CHROM_TABLE, size(DC_CHROM_TABLE)/3, encoder, decoder)
    end subroutine init_dc_chrom_table
    
    subroutine init_ac_coeff_table(encoder, decoder)
        !! Initialize AC coefficient Huffman table (simplified version of TCoeff1 from ctables.h)
        type(huffman_encoder_t), intent(out) :: encoder
        type(huffman_decoder_t), intent(out) :: decoder
        
        integer, parameter :: AC_COEFF_TABLE(0:35) = [ &
            0, 2, 2, &     ! EOF
            1, 2, 3, &     ! Not First Coef
            257, 3, 3, &   ! Run=1, Level=1
            2, 4, 4, &     ! Run=0, Level=2
            513, 4, 5, &   ! Run=2, Level=1
            3, 5, 5, &     ! Run=0, Level=3
            769, 5, 7, &   ! Run=3, Level=1
            1025, 5, 6, &  ! Run=4, Level=1
            258, 6, 6, &   ! Run=1, Level=2
            1281, 6, 7, &  ! Run=5, Level=1
            1537, 6, 5, &  ! Run=6, Level=1
            1793, 6, 4 &   ! Run=7, Level=1
        ]
        
        call build_huffman_tables(AC_COEFF_TABLE, size(AC_COEFF_TABLE)/3, encoder, decoder)
    end subroutine init_ac_coeff_table
    
    subroutine init_mba_table(encoder, decoder)
        !! Initialize Macroblock Address Huffman table from MPEG ctables.h
        type(huffman_encoder_t), intent(out) :: encoder
        type(huffman_decoder_t), intent(out) :: decoder
        
        ! Complete MBA table from C reference ctables.h MBACoeff[]
        ! 35 entries × 3 values each = 105 total elements
        integer, parameter :: MBA_TABLE(0:104) = [ &
            1, 1, 1, &     ! MBA increment 1
            2, 3, 3, &     ! MBA increment 2
            3, 3, 2, &     ! MBA increment 3
            4, 4, 3, &     ! MBA increment 4
            5, 4, 2, &     ! MBA increment 5
            6, 5, 3, &     ! MBA increment 6
            7, 5, 2, &     ! MBA increment 7
            8, 7, 7, &     ! MBA increment 8
            9, 7, 6, &     ! MBA increment 9
            10, 8, 11, &   ! MBA increment 10
            11, 8, 10, &   ! MBA increment 11
            12, 8, 9, &    ! MBA increment 12
            13, 8, 8, &    ! MBA increment 13
            14, 8, 7, &    ! MBA increment 14
            15, 8, 6, &    ! MBA increment 15
            16, 10, 23, &  ! MBA increment 16
            17, 10, 22, &  ! MBA increment 17
            18, 10, 21, &  ! MBA increment 18
            19, 10, 20, &  ! MBA increment 19
            20, 10, 19, &  ! MBA increment 20
            21, 10, 18, &  ! MBA increment 21
            22, 11, 35, &  ! MBA increment 22
            23, 11, 34, &  ! MBA increment 23
            24, 11, 33, &  ! MBA increment 24
            25, 11, 32, &  ! MBA increment 25
            26, 11, 31, &  ! MBA increment 26
            27, 11, 30, &  ! MBA increment 27
            28, 11, 29, &  ! MBA increment 28
            29, 11, 28, &  ! MBA increment 29
            30, 11, 27, &  ! MBA increment 30
            31, 11, 26, &  ! MBA increment 31
            32, 11, 25, &  ! MBA increment 32
            33, 11, 24, &  ! MBA increment 33
            34, 11, 15, &  ! Stuffing
            35, 11, 8 &    ! Escape
        ]
        
        call build_huffman_tables(MBA_TABLE, size(MBA_TABLE)/3, encoder, decoder)
    end subroutine init_mba_table
    
    subroutine init_mvd_table(encoder, decoder)
        !! Initialize Motion Vector Difference Huffman table from MPEG ctables.h
        type(huffman_encoder_t), intent(out) :: encoder
        type(huffman_decoder_t), intent(out) :: decoder
        
        integer, parameter :: MVD_TABLE(0:35) = [ &
            0, 1, 1, &     ! MVD = 0
            1, 3, 2, &     ! MVD = +1
            2, 4, 2, &     ! MVD = +2
            3, 5, 2, &     ! MVD = +3
            4, 7, 6, &     ! MVD = +4
            5, 8, 10, &    ! MVD = +5
            6, 8, 8, &     ! MVD = +6
            7, 8, 6, &     ! MVD = +7
            8, 10, 22, &   ! MVD = +8
            9, 10, 20, &   ! MVD = +9
            10, 10, 18, &  ! MVD = +10
            11, 11, 34 &   ! MVD = +11
        ]
        
        call build_huffman_tables(MVD_TABLE, size(MVD_TABLE)/3, encoder, decoder)
    end subroutine init_mvd_table
    
    subroutine build_huffman_tables(table_data, num_entries, encoder, decoder)
        !! Build encoder and decoder tables from raw table data
        integer, intent(in) :: table_data(0:)
        integer, intent(in) :: num_entries
        type(huffman_encoder_t), intent(out) :: encoder
        type(huffman_decoder_t), intent(out) :: decoder
        
        integer :: i, symbol, length, code
        
        encoder%num_symbols = num_entries
        decoder%num_symbols = num_entries
        
        encoder%codes = 0
        encoder%lengths = 0
        decoder%symbols = 0
        decoder%codes = 0
        decoder%lengths = 0
        
        do i = 0, num_entries - 1
            symbol = table_data(i * 3)
            length = table_data(i * 3 + 1)
            code = table_data(i * 3 + 2)
            
            if (symbol < MAX_SYMBOLS) then
                encoder%codes(symbol) = code
                encoder%lengths(symbol) = length
                
                decoder%symbols(i) = symbol
                decoder%codes(i) = code
                decoder%lengths(i) = length
            end if
        end do
    end subroutine build_huffman_tables
    
    
    subroutine write_bits_to_buffer(buffer, value, num_bits)
        !! Write bits to output buffer (MSB first for MPEG)
        type(bit_buffer_t), intent(inout) :: buffer
        integer, intent(in) :: value, num_bits
        
        integer :: i, bit
        
        if (.not. allocated(buffer%buffer)) then
            allocate(buffer%buffer(1000))
            buffer%bit_pos = 0
            buffer%byte_pos = 1
        end if
        
        do i = num_bits - 1, 0, -1
            bit = iand(ishft(value, -i), 1)
            
            if (buffer%bit_pos == 0) then
                buffer%buffer(buffer%byte_pos) = 0
            end if
            
            buffer%buffer(buffer%byte_pos) = ior(buffer%buffer(buffer%byte_pos), &
                                               int(ishft(bit, 7 - buffer%bit_pos), int8))
            buffer%bit_pos = buffer%bit_pos + 1
            
            if (buffer%bit_pos == 8) then
                buffer%bit_pos = 0
                buffer%byte_pos = buffer%byte_pos + 1
                
                if (buffer%byte_pos > size(buffer%buffer)) then
                    call resize_buffer(buffer)
                end if
            end if
        end do
    end subroutine write_bits_to_buffer
    
    subroutine resize_buffer(buffer)
        !! Resize buffer when it runs out of space
        type(bit_buffer_t), intent(inout) :: buffer
        
        integer(int8), allocatable :: temp(:)
        integer :: old_size, new_size
        
        old_size = size(buffer%buffer)
        new_size = old_size * 2
        
        allocate(temp(new_size))
        temp(1:old_size) = buffer%buffer(1:old_size)
        temp(old_size+1:new_size) = 0
        
        deallocate(buffer%buffer)
        allocate(buffer%buffer(new_size))
        buffer%buffer = temp
        deallocate(temp)
    end subroutine resize_buffer
    
    function encode_huffman_value(encoder, symbol, buffer) result(success)
        !! Encode a symbol using Huffman table
        type(huffman_encoder_t), intent(in) :: encoder
        integer, intent(in) :: symbol
        type(bit_buffer_t), intent(inout) :: buffer
        logical :: success
        
        if (symbol < 0 .or. symbol >= encoder%num_symbols) then
            success = .false.
            return
        end if
        
        if (encoder%lengths(symbol) == 0) then
            success = .false.
            return
        end if
        
        call write_bits_to_buffer(buffer, encoder%codes(symbol), encoder%lengths(symbol))
        success = .true.
    end function encode_huffman_value
    
    function decode_huffman_value(decoder, bit_stream, bit_pos, symbol) result(success)
        !! Decode a symbol from bit stream using direct lookup
        type(huffman_decoder_t), intent(in) :: decoder
        integer(int8), intent(in) :: bit_stream(:)
        integer, intent(inout) :: bit_pos
        integer, intent(out) :: symbol
        logical :: success
        
        integer :: code, length, i, start_bit_pos
        
        success = .false.
        
        ! Try all possible code lengths starting from shortest
        do length = 1, MAX_CODE_LENGTH
            start_bit_pos = bit_pos
            code = 0
            
            ! Extract 'length' bits
            do i = 1, length
                if (start_bit_pos > size(bit_stream) * 8) exit
                code = ishft(code, 1)
                code = ior(code, extract_bit(bit_stream, start_bit_pos))
                start_bit_pos = start_bit_pos + 1
            end do
            
            ! Search decoder table for exact match of code and length
            do i = 0, decoder%num_symbols - 1
                if (decoder%codes(i) == code .and. decoder%lengths(i) == length) then
                    symbol = decoder%symbols(i)
                    bit_pos = bit_pos + length
                    success = .true.
                    return
                end if
            end do
        end do
    end function decode_huffman_value
    
    function extract_bit(bit_stream, bit_pos) result(bit_value)
        !! Extract a single bit from bit stream
        integer(int8), intent(in) :: bit_stream(:)
        integer, intent(in) :: bit_pos
        integer :: bit_value
        
        integer :: byte_index, bit_index
        
        byte_index = (bit_pos - 1) / 8 + 1
        bit_index = mod(bit_pos - 1, 8)
        
        if (byte_index <= size(bit_stream)) then
            bit_value = iand(ishft(int(bit_stream(byte_index)), -(7 - bit_index)), 1)
        else
            bit_value = 0
        end if
    end function extract_bit
    
end module fortplot_mpeg_huffman