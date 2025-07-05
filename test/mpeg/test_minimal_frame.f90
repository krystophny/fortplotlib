program test_minimal_frame
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use fortplot_mpeg1_format
    use iso_c_binding
    implicit none
    
    ! Create the SIMPLEST possible MPEG: single static frame, no movement
    call create_single_static_frame()
    
    print *, "PASS: Minimal static frame created"
    
contains

    subroutine create_single_static_frame()
        ! Create a single 16x16 static frame - no animation, no complexity
        integer, parameter :: width = 16, height = 16  ! Single macroblock
        character(len=*), parameter :: video_file = "minimal_static.mpg"
        
        type(mem_t) :: frame_buffer
        integer :: bit_rate, pixel_idx
        
        print *, "Creating MINIMAL static frame test:"
        print *, "  Size: 16x16 (single macroblock)"
        print *, "  Content: Half black (128), half white (255)"
        print *, "  Goal: Stable colors, no flickering"
        
        frame_buffer = mem_create(width, height)
        
        ! Create simple test pattern: left half black, right half white
        do pixel_idx = 1, width * height
            if (mod((pixel_idx - 1), width) < width/2) then
                ! Left half: black (YUV neutral)
                frame_buffer%data(pixel_idx) = int(-128, c_int8_t)  ! 128 as signed byte
            else
                ! Right half: white  
                frame_buffer%data(pixel_idx) = int(-1, c_int8_t)    ! 255 as signed byte
            end if
        end do
        
        ! Display the pattern we created
        print *, "Created test pattern:"
        call display_frame_pattern(frame_buffer, width, height)
        
        ! Open file and write minimal MPEG
        call stream_open_write(video_file)
        
        bit_rate = width * height * 25 * 8  ! 25 fps
        call write_mpeg1_sequence_header(width, height, 25, bit_rate)
        call write_mpeg1_gop_header(0)
        
        ! Write SINGLE frame
        call write_mpeg1_picture_header(0, I_FRAME)
        call write_mpeg1_slice_header(1)
        call encode_mpeg1_frame(frame_buffer, width, height)
        
        call write_mpeg1_sequence_end()
        call stream_close_write()
        call mem_destroy(frame_buffer)
        
        print *, "✅ Minimal static frame written to:", video_file
        print *, "Expected result: Left half BLACK, right half WHITE"
        print *, "Should be stable with NO flickering"
    end subroutine
    
    subroutine display_frame_pattern(frame_mem, width, height)
        type(mem_t), intent(in) :: frame_mem
        integer, intent(in) :: width, height
        integer :: y, x, pixel_idx, value
        
        print *, "Frame data (showing first 8 rows):"
        do y = 1, min(8, height)
            write(*, '(A)', advance='no') "  "
            do x = 1, width
                pixel_idx = (y - 1) * width + x
                value = int(frame_mem%data(pixel_idx))
                if (value < 0) value = value + 256  ! Convert to unsigned for display
                write(*, '(I4)', advance='no') value
            end do
            print *
        end do
        print *, "Expected: Left=128 (black), Right=255 (white)"
    end subroutine

end program test_minimal_frame