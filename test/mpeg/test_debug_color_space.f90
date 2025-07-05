program test_debug_color_space
    use fortplot_rgb_to_mpeg
    use fortplot_mpeg_memory, only: mem_t, mem_create, mem_destroy
    use iso_c_binding, only: c_int8_t
    implicit none
    
    ! Debug the color space conversion to understand the green video issue
    call test_simple_black_white_conversion()
    call test_actual_animation_data()
    
    print *, "PASS: Color space debugging complete"
    
contains

    subroutine test_simple_black_white_conversion()
        ! Test basic black and white conversion
        type(yuv420_frame_t) :: yuv_frame
        integer(1), allocatable :: bitmap_data(:)
        integer, parameter :: width = 16, height = 16
        integer :: total_size, i, y, x, idx
        
        print *, "=== Testing Simple Black/White Conversion ==="
        
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Create bitmap data: PNG-style with filter bytes
        ! Each row: 1 filter byte + width*3 RGB bytes
        total_size = height * (1 + width * 3)
        allocate(bitmap_data(total_size))
        
        ! Fill with black background, white center square
        do y = 0, height - 1
            ! Filter byte (0 = no filter)
            bitmap_data(y * (1 + width * 3) + 1) = 0
            
            do x = 0, width - 1
                idx = y * (1 + width * 3) + 1 + 1 + x * 3  ! +1 for filter, +1 for 1-based
                
                ! Create white square in center
                if (x >= 6 .and. x <= 9 .and. y >= 6 .and. y <= 9) then
                    bitmap_data(idx) = int(127, c_int8_t)     ! R = white (use 127 to avoid overflow)
                    bitmap_data(idx + 1) = int(127, c_int8_t) ! G = white  
                    bitmap_data(idx + 2) = int(127, c_int8_t) ! B = white
                else
                    bitmap_data(idx) = int(0, c_int8_t)       ! R = black
                    bitmap_data(idx + 1) = int(0, c_int8_t)   ! G = black
                    bitmap_data(idx + 2) = int(0, c_int8_t)   ! B = black
                end if
            end do
        end do
        
        print *, "Input bitmap created: BLACK background with WHITE center square"
        
        ! Convert to YUV
        call bitmap_to_yuv420(bitmap_data, width, height, yuv_frame)
        
        ! Analyze Y plane values
        print *, "Y plane analysis:"
        print *, "  Black pixels (should be ~16 in MPEG legal range):"
        print *, "    Y(1,1) =", int(yuv_frame%y_plane%data(1))
        print *, "  White pixels (should be ~235 in MPEG legal range):"
        idx = 6 * width + 6 + 1  ! Center of white square
        print *, "    Y(7,7) =", int(yuv_frame%y_plane%data(idx))
        
        ! Analyze UV planes (should be ~128 for grayscale)
        print *, "UV plane analysis (should be ~128 for grayscale):"
        print *, "  U(1,1) =", int(yuv_frame%u_plane%data(1))
        print *, "  V(1,1) =", int(yuv_frame%v_plane%data(1))
        
        call destroy_yuv420_frame(yuv_frame)
        deallocate(bitmap_data)
    end subroutine
    
    subroutine test_actual_animation_data()
        ! Test with data that might come from actual animation
        type(yuv420_frame_t) :: yuv_frame
        integer(1), allocatable :: bitmap_data(:)
        integer, parameter :: width = 32, height = 24
        integer :: total_size, y, x, idx
        
        print *, ""
        print *, "=== Testing Actual Animation-style Data ==="
        
        yuv_frame = create_yuv420_frame(width, height)
        
        total_size = height * (1 + width * 3)
        allocate(bitmap_data(total_size))
        
        ! Simulate animation frame: gray background with white moving dot
        do y = 0, height - 1
            bitmap_data(y * (1 + width * 3) + 1) = 0  ! Filter byte
            
            do x = 0, width - 1
                idx = y * (1 + width * 3) + 1 + 1 + x * 3
                
                ! Create moving dot at specific position
                if (x == 16 .and. y == 12) then  ! Center dot
                    bitmap_data(idx) = int(127, c_int8_t)     ! White dot
                    bitmap_data(idx + 1) = int(127, c_int8_t)
                    bitmap_data(idx + 2) = int(127, c_int8_t)
                else
                    bitmap_data(idx) = int(32, c_int8_t)      ! Dark gray background
                    bitmap_data(idx + 1) = int(32, c_int8_t)
                    bitmap_data(idx + 2) = int(32, c_int8_t)
                end if
            end do
        end do
        
        print *, "Animation data created: DARK GRAY background with WHITE dot at (16,12)"
        
        call bitmap_to_yuv420(bitmap_data, width, height, yuv_frame)
        
        ! Check background
        print *, "Background Y value (dark gray 64,64,64):", int(yuv_frame%y_plane%data(1))
        
        ! Check dot
        idx = 12 * width + 16 + 1  ! Dot position
        print *, "Dot Y value (white 255,255,255):", int(yuv_frame%y_plane%data(idx))
        
        ! Check if this creates the contrast we expect
        print *, "Expected: Background <50, Dot >200 for good contrast"
        
        call destroy_yuv420_frame(yuv_frame)
        deallocate(bitmap_data)
    end subroutine

end program test_debug_color_space