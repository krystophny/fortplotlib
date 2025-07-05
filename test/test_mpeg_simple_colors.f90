program test_mpeg_simple_colors
    use fortplot_rgb_to_mpeg
    use fortplot_mpeg1_format
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory, only: mem_t, mem_create, mem_destroy
    implicit none
    
    call test_rgb_to_yuv_direct()
    call test_minimal_mpeg_encoding()
    
contains

    subroutine test_rgb_to_yuv_direct()
        print *, "Testing RGB to YUV conversion:"
        
        ! Test known color values
        call test_color("White", 255, 255, 255)
        call test_color("Black", 0, 0, 0)
        call test_color("Red", 255, 0, 0)
        call test_color("Green", 0, 255, 0)
        call test_color("Blue", 0, 0, 255)
        call test_color("Gray", 128, 128, 128)
    end subroutine test_rgb_to_yuv_direct
    
    subroutine test_color(name, r, g, b)
        character(len=*), intent(in) :: name
        integer, intent(in) :: r, g, b
        integer :: y, u, v
        
        ! Convert using the same formula as in the module
        y = int(0.299 * r + 0.587 * g + 0.114 * b)
        u = int(-0.14713 * r - 0.28886 * g + 0.436 * b) + 128
        v = int(0.615 * r - 0.51499 * g - 0.10001 * b) + 128
        
        ! Clamp to MPEG legal range
        y = max(16, min(235, y))
        u = max(16, min(240, u))
        v = max(16, min(240, v))
        
        print '(A10, ": RGB(", I3, ",", I3, ",", I3, ") -> YUV(", I3, ",", I3, ",", I3, ")")', &
            name, r, g, b, y, u, v
    end subroutine test_color
    
    subroutine test_minimal_mpeg_encoding()
        integer :: width, height
        integer(1), allocatable :: bitmap(:)
        integer :: x, y, idx
        
        print *, ""
        print *, "Creating minimal MPEG with known pattern..."
        
        width = 160
        height = 120
        allocate(bitmap(width * height * 3))
        
        ! Create a gradient pattern
        do y = 0, height-1
            do x = 0, width-1
                idx = y * width * 3 + x * 3 + 1
                ! Horizontal gradient from black to white
                bitmap(idx) = int(x * 255 / width, 1)     ! R
                bitmap(idx+1) = int(x * 255 / width, 1)   ! G
                bitmap(idx+2) = int(x * 255 / width, 1)   ! B
            end do
        end do
        
        call create_minimal_mpeg("test_gradient.mpg", bitmap, width, height)
        
        ! Create checkerboard pattern
        do y = 0, height-1
            do x = 0, width-1
                idx = y * width * 3 + x * 3 + 1
                if (mod(x/20 + y/20, 2) == 0) then
                    bitmap(idx) = -1      ! R = 255
                    bitmap(idx+1) = -1    ! G = 255
                    bitmap(idx+2) = -1    ! B = 255
                else
                    bitmap(idx) = 0       ! R = 0
                    bitmap(idx+1) = 0     ! G = 0
                    bitmap(idx+2) = 0     ! B = 0
                end if
            end do
        end do
        
        call create_minimal_mpeg("test_checkerboard.mpg", bitmap, width, height)
        
        deallocate(bitmap)
        print *, "Test files created."
    end subroutine test_minimal_mpeg_encoding
    
    subroutine create_minimal_mpeg(filename, bitmap, width, height)
        character(len=*), intent(in) :: filename
        integer(1), intent(in) :: bitmap(:)
        integer, intent(in) :: width, height
        
        type(yuv420_frame_t) :: yuv_frame
        type(mem_t) :: frame_data
        integer :: i, y_idx, u_idx, v_idx
        integer :: x, y, rgb_idx
        integer :: r, g, b, y_val, u_val, v_val
        
        ! Open output
        call stream_open_write(filename)
        
        ! Write headers
        call write_mpeg1_sequence_header(width, height, 25, 1150000)
        call write_mpeg1_gop_header(0)
        
        ! Create YUV frame
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Manual RGB to YUV conversion for debugging
        do y = 0, height-1
            do x = 0, width-1
                rgb_idx = y * width * 3 + x * 3 + 1
                r = iand(int(bitmap(rgb_idx)), 255)
                g = iand(int(bitmap(rgb_idx+1)), 255)
                b = iand(int(bitmap(rgb_idx+2)), 255)
                
                ! YUV conversion
                y_val = int(0.299 * r + 0.587 * g + 0.114 * b)
                
                ! Store Y value (full resolution)
                y_idx = y * width + x + 1
                yuv_frame%y_plane%data(y_idx) = int(max(16, min(235, y_val)), 1)
                
                ! Store U/V values (4:2:0 subsampling - every 2x2 block)
                if (mod(x, 2) == 0 .and. mod(y, 2) == 0) then
                    u_val = int(-0.14713 * r - 0.28886 * g + 0.436 * b) + 128
                    v_val = int(0.615 * r - 0.51499 * g - 0.10001 * b) + 128
                    
                    u_idx = (y/2) * (width/2) + (x/2) + 1
                    v_idx = u_idx
                    
                    yuv_frame%u_plane%data(u_idx) = int(max(16, min(240, u_val)), 1)
                    yuv_frame%v_plane%data(v_idx) = int(max(16, min(240, v_val)), 1)
                end if
            end do
        end do
        
        ! Write a single frame
        call write_mpeg1_picture_header(0, 1)  ! I-frame
        call write_mpeg1_slice_header(1)
        
        ! Use minimal encoding
        call encode_minimal_frame_data(width, height)
        
        ! End sequence
        call write_mpeg1_sequence_end()
        
        ! Cleanup
        call destroy_yuv420_frame(yuv_frame)
        call stream_close_write()
        
        print *, "Created:", trim(filename)
    end subroutine create_minimal_mpeg

end program test_mpeg_simple_colors