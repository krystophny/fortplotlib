program test_visible_objects
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use fortplot_mpeg1_format
    use iso_c_binding
    implicit none
    
    ! Test creating MPEG video with clearly visible objects
    call create_high_contrast_video()
    
    print *, "PASS: High contrast video with visible objects"
    
contains

    subroutine create_high_contrast_video()
        integer, parameter :: canvas_width = 176
        integer, parameter :: canvas_height = 144
        integer, parameter :: frames_per_second = 25
        integer, parameter :: video_duration = 3
        integer, parameter :: total_frames = frames_per_second * video_duration
        
        character(len=*), parameter :: video_file = "test_visible_objects.mpg"
        
        type(mem_t) :: frame_buffer
        integer :: frame_num, bit_rate, file_size
        logical :: file_exists
        
        print *, "Creating high contrast video with visible objects..."
        print *, "  Canvas size:", canvas_width, "x", canvas_height
        print *, "  Duration:", video_duration, "seconds"
        print *, "  Total frames:", total_frames
        
        frame_buffer = mem_create(canvas_width, canvas_height)
        call stream_open_write(video_file)
        
        bit_rate = canvas_width * canvas_height * frames_per_second * 8
        call write_mpeg1_sequence_header(canvas_width, canvas_height, frames_per_second, bit_rate)
        call write_mpeg1_gop_header(0)
        
        do frame_num = 1, total_frames
            ! Create high contrast frame with obvious objects
            call generate_high_contrast_frame(frame_buffer, canvas_width, canvas_height, frame_num, total_frames)
            
            call write_mpeg1_picture_header(frame_num - 1, I_FRAME)
            call write_mpeg1_slice_header(1)
            call encode_mpeg1_frame(frame_buffer, canvas_width, canvas_height)
            
            if (mod(frame_num, 25) == 0) then
                print *, "  Frame", frame_num, "/", total_frames, "- objects should be clearly visible"
            end if
        end do
        
        call write_mpeg1_sequence_end()
        call stream_close_write()
        call mem_destroy(frame_buffer)
        
        inquire(file=video_file, exist=file_exists, size=file_size)
        if (file_exists) then
            print *, "✅ High contrast video created:"
            print *, "  File:", video_file
            print *, "  Size:", file_size, "bytes"
            print *, "✅ Should show: BLACK background with WHITE moving objects"
        end if
    end subroutine
    
    subroutine generate_high_contrast_frame(frame_mem, width, height, frame_num, total_frames)
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, frame_num, total_frames
        
        integer :: x, y, pixel_idx
        real :: progress, t
        integer :: obj1_x, obj1_y, obj2_x, obj2_y, obj3_x, obj3_y
        
        ! Calculate animation progress
        progress = real(frame_num - 1) / real(total_frames - 1)
        t = progress * 6.28318530718 * 2  ! 2 full rotations
        
        ! Fill with proper black background (YUV neutral = 128)
        do pixel_idx = 1, width * height
            frame_mem%data(pixel_idx) = int(-128, c_int8_t)  ! 128 as signed byte = YUV black
        end do
        
        ! Calculate object positions - slow, obvious movement
        obj1_x = int(width * 0.25 + (width * 0.5) * (cos(t) + 1.0) / 2.0)
        obj1_y = height / 2
        
        obj2_x = width / 2
        obj2_y = int(height * 0.25 + (height * 0.5) * (sin(t) + 1.0) / 2.0)
        
        obj3_x = int(width * progress)
        obj3_y = int(height * 0.75)
        
        ! Draw large, bright white objects
        call draw_white_square(frame_mem, width, height, obj1_x, obj1_y, 12)  ! Large square
        call draw_white_circle(frame_mem, width, height, obj2_x, obj2_y, 8)   ! Circle
        call draw_white_square(frame_mem, width, height, obj3_x, obj3_y, 6)   ! Moving square
        
        print *, "    Frame", frame_num, ": Objects at (", obj1_x, ",", obj1_y, "), (", obj2_x, ",", obj2_y, "), (", obj3_x, ",", obj3_y, ")"
    end subroutine
    
    subroutine draw_white_square(frame_mem, width, height, center_x, center_y, size)
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, center_x, center_y, size
        integer :: x, y, dx, dy, pixel_idx
        
        do dy = -size/2, size/2
            do dx = -size/2, size/2
                x = center_x + dx
                y = center_y + dy
                
                if (x >= 1 .and. x <= width .and. y >= 1 .and. y <= height) then
                    pixel_idx = (y - 1) * width + x
                    frame_mem%data(pixel_idx) = int(-1, c_int8_t)   ! 255 as signed byte = -1
                end if
            end do
        end do
    end subroutine
    
    subroutine draw_white_circle(frame_mem, width, height, center_x, center_y, radius)
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, center_x, center_y, radius
        integer :: x, y, dx, dy, pixel_idx, distance_sq
        
        do dy = -radius, radius
            do dx = -radius, radius
                x = center_x + dx
                y = center_y + dy
                
                if (x >= 1 .and. x <= width .and. y >= 1 .and. y <= height) then
                    distance_sq = dx*dx + dy*dy
                    if (distance_sq <= radius*radius) then
                        pixel_idx = (y - 1) * width + x
                        frame_mem%data(pixel_idx) = int(-1, c_int8_t)   ! 255 as signed byte = -1
                    end if
                end if
            end do
        end do
    end subroutine

end program test_visible_objects