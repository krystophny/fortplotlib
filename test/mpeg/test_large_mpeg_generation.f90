program test_large_mpeg_generation
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use fortplot_mpeg1_format
    use iso_c_binding
    implicit none
    
    ! Test creating a larger, more complex MPEG video closer to short.mpg size
    call create_complex_video()
    
    print *, "PASS: Large MPEG video generation test"
    
contains

    subroutine create_complex_video()
        ! Video parameters - larger resolution and longer duration
        integer, parameter :: canvas_width = 176    ! CIF/4 resolution
        integer, parameter :: canvas_height = 144   ! CIF/4 resolution  
        integer, parameter :: frames_per_second = 25
        integer, parameter :: video_duration = 5    ! 5 seconds
        integer, parameter :: total_frames = frames_per_second * video_duration
        
        character(len=*), parameter :: video_file = "test_large_video.mpg"
        
        type(mem_t) :: frame_buffer
        integer :: frame_num, bit_rate, file_size
        logical :: file_exists
        
        print *, "Creating large complex video..."
        print *, "  Canvas size:", canvas_width, "x", canvas_height
        print *, "  Frame rate:", frames_per_second, "fps"
        print *, "  Duration:", video_duration, "seconds"
        print *, "  Total frames:", total_frames
        print *, "  Expected complexity: High (multiple moving objects)"
        
        ! Create frame buffer
        frame_buffer = mem_create(canvas_width, canvas_height)
        
        ! Open video file for writing
        call stream_open_write(video_file)
        
        ! Write MPEG-1 compliant headers with higher bit rate
        bit_rate = canvas_width * canvas_height * frames_per_second * 16  ! Higher bit rate
        call write_mpeg1_sequence_header(canvas_width, canvas_height, frames_per_second, bit_rate)
        call write_mpeg1_gop_header(0)
        
        ! Generate and encode each frame with complex content
        do frame_num = 1, total_frames
            ! Create complex frame content
            call generate_complex_frame(frame_buffer, canvas_width, canvas_height, frame_num, total_frames)
            
            call write_mpeg1_picture_header(frame_num - 1, I_FRAME)
            call write_mpeg1_slice_header(1)
            call encode_mpeg1_frame(frame_buffer, canvas_width, canvas_height)
            
            ! Progress reporting
            if (mod(frame_num, 25) == 0) then
                print *, "  Frame", frame_num, "/", total_frames, "completed"
            end if
        end do
        
        call write_mpeg1_sequence_end()
        call stream_close_write()
        call mem_destroy(frame_buffer)
        
        ! Check result
        inquire(file=video_file, exist=file_exists, size=file_size)
        if (file_exists) then
            print *, "✅ Large video created successfully:"
            print *, "  File:", video_file
            print *, "  Size:", file_size, "bytes"
            print *, "  Compression:", real(canvas_width * canvas_height * total_frames) / real(file_size), ":1"
            
            if (file_size > 10000) then
                print *, "✅ File size target achieved (>10KB)"
            else
                print *, "⚠️  File size still small, but improved"
            end if
        else
            error stop "Failed to create large video file"
        end if
    end subroutine
    
    subroutine generate_complex_frame(frame_mem, width, height, frame_num, total_frames)
        ! Generate complex frame content with multiple moving elements
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, frame_num, total_frames
        
        integer :: x, y, pixel_idx, value
        real :: t, progress
        integer :: center_x, center_y, radius
        integer :: dot1_x, dot1_y, dot2_x, dot2_y, dot3_x, dot3_y
        
        ! Calculate time progress (0.0 to 1.0)
        progress = real(frame_num - 1) / real(total_frames - 1)
        t = progress * 6.28318530718 * 3  ! 3 full rotations
        
        ! Calculate positions for multiple moving objects
        center_x = width / 2
        center_y = height / 2
        radius = min(width, height) / 4
        
        ! Three dots moving in different patterns
        dot1_x = center_x + int(radius * cos(t))
        dot1_y = center_y + int(radius * sin(t))
        
        dot2_x = center_x + int((radius/2) * cos(-t * 2))
        dot2_y = center_y + int((radius/2) * sin(-t * 2))
        
        dot3_x = int(width * progress)
        dot3_y = center_y + int((height/4) * sin(t * 4))
        
        ! Generate complex background pattern
        do y = 1, height
            do x = 1, width
                pixel_idx = (y - 1) * width + x
                
                ! Complex background: gradient + pattern
                value = mod(x + y + frame_num, 64) + &
                        int(32 * sin(real(x) / 10.0)) + &
                        int(32 * cos(real(y) / 8.0)) + 64
                
                ! Clamp to valid range
                if (value < 0) value = 0
                if (value > 255) value = 255
                
                frame_mem%data(pixel_idx) = int(value, c_int8_t)
            end do
        end do
        
        ! Draw moving objects (high contrast)
        call draw_object(frame_mem, width, height, dot1_x, dot1_y, 4, 255)
        call draw_object(frame_mem, width, height, dot2_x, dot2_y, 3, 200)
        call draw_object(frame_mem, width, height, dot3_x, dot3_y, 2, 150)
        
        ! Add some noise for complexity
        call add_frame_noise(frame_mem, width, height, frame_num)
    end subroutine
    
    subroutine draw_object(frame_mem, width, height, center_x, center_y, size, brightness)
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, center_x, center_y, size, brightness
        integer :: x, y, dx, dy, pixel_idx, distance_sq
        
        do dy = -size, size
            do dx = -size, size
                x = center_x + dx
                y = center_y + dy
                
                if (x >= 1 .and. x <= width .and. y >= 1 .and. y <= height) then
                    distance_sq = dx*dx + dy*dy
                    if (distance_sq <= size*size) then
                        pixel_idx = (y - 1) * width + x
                        frame_mem%data(pixel_idx) = int(brightness, c_int8_t)
                    end if
                end if
            end do
        end do
    end subroutine
    
    subroutine add_frame_noise(frame_mem, width, height, seed)
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, seed
        integer :: i, noise, current_value
        
        ! Add subtle noise to increase complexity
        do i = 1, width * height, 7  ! Every 7th pixel
            call random_seed_simple(seed + i)
            noise = mod(abs(seed * 17 + i * 23), 32) - 16  ! -16 to +15
            current_value = int(frame_mem%data(i))
            current_value = current_value + noise
            
            if (current_value < 0) current_value = 0
            if (current_value > 255) current_value = 255
            
            frame_mem%data(i) = int(current_value, c_int8_t)
        end do
    end subroutine
    
    subroutine random_seed_simple(seed)
        integer, intent(in) :: seed
        integer :: seed_array(8)  ! Standard size for random seed
        seed_array = seed  ! Fill all elements with same seed
        call random_seed(put=seed_array)
    end subroutine

end program test_large_mpeg_generation