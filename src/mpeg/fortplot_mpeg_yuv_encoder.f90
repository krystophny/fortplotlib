module fortplot_mpeg_yuv_encoder
    use fortplot_mpeg_stream
    use fortplot_mpeg1_format
    use fortplot_rgb_to_mpeg, only: yuv420_frame_t
    implicit none
    private
    
    public :: encode_yuv420_frame_simple
    
contains

    subroutine encode_yuv420_frame_simple(yuv_frame)
        !! Simple MPEG-1 frame encoding using actual YUV data
        type(yuv420_frame_t), intent(in) :: yuv_frame
        
        integer :: mb_x, mb_y, num_mb_x, num_mb_y
        integer :: block_num, x, y, idx
        integer :: dc_value
        
        ! Calculate number of macroblocks
        num_mb_x = (yuv_frame%width + 15) / 16
        num_mb_y = (yuv_frame%height + 15) / 16
        
        ! Process each macroblock
        do mb_y = 0, num_mb_y - 1
            do mb_x = 0, num_mb_x - 1
                ! Macroblock address increment
                call stream_put_variable(1, 1)  ! MBA = 1 (1 bit)
                
                ! Macroblock type for I-frame (intra)
                call stream_put_variable(1, 2)  ! Type = 01 (2 bits)
                
                ! Encode Y blocks (4 blocks of 8x8)
                do block_num = 0, 3
                    call encode_simple_y_block(yuv_frame, mb_x, mb_y, block_num)
                end do
                
                ! Encode Cb block
                call encode_simple_chroma_block(yuv_frame%u_plane%data, &
                    yuv_frame%width/2, yuv_frame%height/2, mb_x, mb_y)
                
                ! Encode Cr block  
                call encode_simple_chroma_block(yuv_frame%v_plane%data, &
                    yuv_frame%width/2, yuv_frame%height/2, mb_x, mb_y)
            end do
        end do
    end subroutine encode_yuv420_frame_simple
    
    subroutine encode_simple_y_block(yuv_frame, mb_x, mb_y, block_num)
        !! Encode a single Y block from the macroblock
        type(yuv420_frame_t), intent(in) :: yuv_frame
        integer, intent(in) :: mb_x, mb_y, block_num
        
        integer :: block_x, block_y, x, y, idx
        integer :: dc_value, avg_value
        integer :: sum
        
        ! Determine which 8x8 block within the macroblock
        block_x = mod(block_num, 2) * 8
        block_y = (block_num / 2) * 8
        
        ! Calculate average value for this block (simple DC approximation)
        sum = 0
        do y = 0, 7
            do x = 0, 7
                idx = (mb_y * 16 + block_y + y) * yuv_frame%width + &
                      (mb_x * 16 + block_x + x) + 1
                if (idx > 0 .and. idx <= size(yuv_frame%y_plane%data)) then
                    sum = sum + iand(int(yuv_frame%y_plane%data(idx)), 255)
                else
                    sum = sum + 128  ! Default gray for out of bounds
                end if
            end do
        end do
        
        avg_value = sum / 64
        dc_value = (avg_value - 128) / 8  ! Simple DC coefficient
        
        ! Encode DC coefficient
        call encode_simple_dc(dc_value)
        
        ! End of block (no AC coefficients for simplicity)
        call stream_put_variable(2, 2)  ! EOB = 10 (2 bits)
    end subroutine encode_simple_y_block
    
    subroutine encode_simple_chroma_block(chroma_data, width, height, mb_x, mb_y)
        !! Encode a chroma (Cb or Cr) block
        integer(1), intent(in) :: chroma_data(:)
        integer, intent(in) :: width, height, mb_x, mb_y
        
        integer :: x, y, idx, sum, avg_value, dc_value
        
        ! Calculate average for 8x8 chroma block
        sum = 0
        do y = 0, 7
            do x = 0, 7
                idx = (mb_y * 8 + y) * width + (mb_x * 8 + x) + 1
                if (idx > 0 .and. idx <= size(chroma_data)) then
                    sum = sum + iand(int(chroma_data(idx)), 255)
                else
                    sum = sum + 128
                end if
            end do
        end do
        
        avg_value = sum / 64
        dc_value = (avg_value - 128) / 8
        
        ! Encode DC coefficient
        call encode_simple_dc(dc_value)
        
        ! End of block
        call stream_put_variable(2, 2)  ! EOB
    end subroutine encode_simple_chroma_block
    
    subroutine encode_simple_dc(dc_value)
        !! Encode a DC coefficient using simple VLC
        integer, intent(in) :: dc_value
        
        integer :: size, value
        
        ! Determine size category
        if (dc_value == 0) then
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
        
        ! Encode size using simple VLC (not full Huffman for now)
        if (size == 0) then
            call stream_put_variable(0, 2)  ! 00
        else if (size == 1) then
            call stream_put_variable(1, 2)  ! 01
        else if (size == 2) then
            call stream_put_variable(2, 2)  ! 10
        else
            call stream_put_variable(3, 2)  ! 11
            call stream_put_variable(size - 3, 3)  ! Additional bits
        end if
        
        ! Encode value bits
        if (size > 0) then
            if (dc_value >= 0) then
                value = dc_value
            else
                value = dc_value + (2**size - 1)
            end if
            call stream_put_variable(value, size)
        end if
    end subroutine encode_simple_dc

end module fortplot_mpeg_yuv_encoder