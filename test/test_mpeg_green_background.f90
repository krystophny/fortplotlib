program test_mpeg_green_background
    use fortplot_mpeg1_format
    use fortplot_mpeg_stream
    use fortplot_rgb_to_mpeg
    use fortplot_mpeg_memory, only: mem_t, mem_create, mem_destroy
    implicit none
    
    integer :: width, height
    type(yuv420_frame_t) :: yuv_frame
    type(mem_t) :: test_frame
    integer :: x, y, idx
    integer(1) :: test_bitmap(3*160*120 + 120)  ! RGB bitmap
    
    width = 160
    height = 120
    
    print *, "Testing MPEG encoding with solid color frames..."
    
    ! Test 1: Create white frame
    print *, "Test 1: White frame"
    do y = 0, height-1
        do x = 0, width-1
            idx = y * width * 3 + x * 3 + 1
            test_bitmap(idx) = -1     ! R = 255
            test_bitmap(idx+1) = -1   ! G = 255  
            test_bitmap(idx+2) = -1   ! B = 255
        end do
    end do
    
    call create_test_mpeg("test_white.mpg", test_bitmap, width, height)
    
    ! Test 2: Create black frame
    print *, "Test 2: Black frame"
    do y = 0, height-1
        do x = 0, width-1
            idx = y * width * 3 + x * 3 + 1
            test_bitmap(idx) = 0      ! R = 0
            test_bitmap(idx+1) = 0    ! G = 0
            test_bitmap(idx+2) = 0    ! B = 0
        end do
    end do
    
    call create_test_mpeg("test_black.mpg", test_bitmap, width, height)
    
    ! Test 3: Create red frame
    print *, "Test 3: Red frame"
    do y = 0, height-1
        do x = 0, width-1
            idx = y * width * 3 + x * 3 + 1
            test_bitmap(idx) = -1     ! R = 255
            test_bitmap(idx+1) = 0    ! G = 0
            test_bitmap(idx+2) = 0    ! B = 0
        end do
    end do
    
    call create_test_mpeg("test_red.mpg", test_bitmap, width, height)
    
    ! Test 4: Create pattern with square
    print *, "Test 4: Pattern with square"
    do y = 0, height-1
        do x = 0, width-1
            idx = y * width * 3 + x * 3 + 1
            ! White background
            test_bitmap(idx) = -1     ! R = 255
            test_bitmap(idx+1) = -1   ! G = 255
            test_bitmap(idx+2) = -1   ! B = 255
            
            ! Black square in center
            if (x >= 60 .and. x < 100 .and. y >= 40 .and. y < 80) then
                test_bitmap(idx) = 0      ! R = 0
                test_bitmap(idx+1) = 0    ! G = 0
                test_bitmap(idx+2) = 0    ! B = 0
            end if
        end do
    end do
    
    call create_test_mpeg("test_pattern.mpg", test_bitmap, width, height)
    
    print *, "Test files created. Check for green background issue."
    
contains

    subroutine create_test_mpeg(filename, bitmap, w, h)
        character(len=*), intent(in) :: filename
        integer(1), intent(in) :: bitmap(:)
        integer, intent(in) :: w, h
        
        type(yuv420_frame_t) :: yuv
        type(mem_t) :: frame_data
        integer :: i
        
        ! Open stream
        call stream_open_write(filename)
        
        ! Write headers
        call write_mpeg1_sequence_header(w, h, 25, 1150000)
        call write_mpeg1_gop_header(0)
        
        ! Create YUV frame
        yuv = create_yuv420_frame(w, h)
        
        ! Convert bitmap to YUV
        call bitmap_to_yuv420(bitmap, w, h, yuv)
        
        ! Debug: Print some YUV values
        print *, "  First Y values:", yuv%y_plane%data(1:5)
        print *, "  First U values:", yuv%u_plane%data(1:5)  
        print *, "  First V values:", yuv%v_plane%data(1:5)
        
        ! Write 10 identical frames
        do i = 1, 10
            ! Picture header
            call write_mpeg1_picture_header(i-1, 1)  ! I-frame
            
            ! Slice header
            call write_mpeg1_slice_header(1)
            
            ! Convert YUV to frame data for encoder
            frame_data = mem_create(w, h)
            frame_data%data(1:w*h) = yuv%y_plane%data(1:w*h)
            
            ! Encode frame
            call encode_mpeg1_frame(frame_data, w, h)
            
            call mem_destroy(frame_data)
        end do
        
        ! End sequence
        call write_mpeg1_sequence_end()
        
        ! Cleanup
        call destroy_yuv420_frame(yuv)
        call stream_close_write()
        
        print *, "  Created:", trim(filename)
    end subroutine create_test_mpeg

end program test_mpeg_green_background