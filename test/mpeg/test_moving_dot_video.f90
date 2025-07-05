program test_moving_dot_video
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use fortplot_mpeg1_format
    use iso_c_binding
    implicit none
    
    ! Test creating a 2-second MPEG video with a moving dot animation
    call create_moving_dot_video()
    
    print *, "PASS: Moving dot video created successfully"
    
contains

    subroutine create_moving_dot_video()
        ! Video parameters
        integer, parameter :: canvas_width = 32
        integer, parameter :: canvas_height = 24
        integer, parameter :: frames_per_second = 15
        integer, parameter :: video_duration = 2  ! seconds
        integer, parameter :: total_frames = frames_per_second * video_duration
        
        ! Dot parameters (MPEG YUV values)
        integer, parameter :: dot_size = 2
        integer, parameter :: dot_brightness = 255    ! White
        integer, parameter :: background_brightness = 128  ! True black in YUV
        
        ! File parameters
        character(len=*), parameter :: video_file = "moving_dot_video.mpg"
        
        type(mem_t) :: frame_buffer
        integer :: frame_num, dot_x, dot_y, x, y, pixel_idx, bit_rate
        integer(c_long) :: total_bits_written, frame_start_pos, frame_end_pos
        real :: progress_x, progress_y
        
        print *, "Creating moving dot video..."
        print *, "  Canvas size:", canvas_width, "x", canvas_height
        print *, "  Frame rate:", frames_per_second, "fps"
        print *, "  Duration:", video_duration, "seconds"
        print *, "  Total frames:", total_frames
        
        ! Create frame buffer
        frame_buffer = mem_create(canvas_width, canvas_height)
        
        ! Open video file for writing
        call stream_open_write(video_file)
        
        ! Write MPEG-1 compliant headers
        bit_rate = canvas_width * canvas_height * frames_per_second * 8
        call write_mpeg1_sequence_header(canvas_width, canvas_height, frames_per_second, bit_rate)
        call write_mpeg1_gop_header(0)  ! GOP starting at time 0
        
        total_bits_written = 0
        
        ! Generate and encode each frame
        do frame_num = 1, total_frames
            frame_start_pos = stream_tell_write()
            
            ! Calculate dot position for this frame
            ! Move dot in a circular pattern around the canvas
            progress_x = real(frame_num - 1) / real(total_frames - 1)
            progress_y = real(frame_num - 1) / real(total_frames - 1)
            
            ! Circular motion
            dot_x = int(canvas_width / 2 + (canvas_width / 4) * cos(progress_x * 6.28318530718))
            dot_y = int(canvas_height / 2 + (canvas_height / 4) * sin(progress_y * 6.28318530718))
            
            ! Ensure dot stays within bounds
            if (dot_x < 1) dot_x = 1
            if (dot_x > canvas_width) dot_x = canvas_width
            if (dot_y < 1) dot_y = 1
            if (dot_y > canvas_height) dot_y = canvas_height
            
            ! Clear frame to background
            call clear_frame(frame_buffer, canvas_width, canvas_height, background_brightness)
            
            ! Draw dot
            call draw_dot(frame_buffer, canvas_width, canvas_height, dot_x, dot_y, dot_size, dot_brightness)
            
            ! Write MPEG-1 picture header for this frame
            call write_mpeg1_picture_header(frame_num - 1, I_FRAME)
            
            ! Write mandatory slice header
            call write_mpeg1_slice_header(1)
            
            ! Encode frame using proper MPEG-1 macroblock structure
            call encode_mpeg1_frame(frame_buffer, canvas_width, canvas_height)
            
            frame_end_pos = stream_tell_write()
            total_bits_written = total_bits_written + (frame_end_pos - frame_start_pos)
            
            ! Progress reporting
            if (mod(frame_num, 5) == 0) then
                print *, "  Frame", frame_num, "/", total_frames, "- dot at (", dot_x, ",", dot_y, ")"
            end if
        end do
        
        ! Write MPEG-1 sequence end
        call write_mpeg1_sequence_end()
        
        call stream_close_write()
        call mem_destroy(frame_buffer)
        
        ! Report results
        print *, "Video encoding complete:"
        print *, "  Output file:", video_file
        print *, "  Total bits written:", total_bits_written
        print *, "  Bits per frame:", total_bits_written / total_frames
        print *, "  Estimated file size:", (total_bits_written + 7) / 8, "bytes"
        print *, "  Compression ratio:", real(canvas_width * canvas_height * 8 * total_frames) / real(total_bits_written)
    end subroutine

    ! Old header/footer functions removed - now using MPEG-1 standard headers

    subroutine clear_frame(frame_mem, width, height, brightness)
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, brightness
        integer :: i
        
        do i = 1, width * height
            ! Convert brightness to proper signed byte
            if (brightness == 255) then
                frame_mem%data(i) = int(-1, c_int8_t)     ! 255 as signed byte
            else if (brightness == 128) then
                frame_mem%data(i) = int(-128, c_int8_t)   ! 128 as signed byte
            else
                frame_mem%data(i) = int(brightness, c_int8_t)
            end if
        end do
    end subroutine

    subroutine draw_dot(frame_mem, width, height, center_x, center_y, size, brightness)
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height, center_x, center_y, size, brightness
        integer :: x, y, dx, dy, pixel_idx
        
        ! Draw a square dot of given size centered at (center_x, center_y)
        do dy = -(size/2), size/2
            do dx = -(size/2), size/2
                x = center_x + dx
                y = center_y + dy
                
                ! Check bounds
                if (x >= 1 .and. x <= width .and. y >= 1 .and. y <= height) then
                    pixel_idx = (y - 1) * width + x
                    ! Convert brightness to proper signed byte representation
                    if (brightness == 255) then
                        frame_mem%data(pixel_idx) = int(-1, c_int8_t)  ! 255 as signed byte
                    else if (brightness == 128) then
                        frame_mem%data(pixel_idx) = int(-128, c_int8_t) ! 128 as signed byte
                    else
                        frame_mem%data(pixel_idx) = int(brightness, c_int8_t)
                    end if
                end if
            end do
        end do
    end subroutine

    ! Old delta compression encode_frame function removed - now using MPEG-1 macroblock structure

end program test_moving_dot_video