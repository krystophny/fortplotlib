program test_mpeg_to_avi
    use fortplot_mpeg_avi
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use iso_c_binding
    implicit none
    
    ! Test converting MPEG stream to AVI container format
    call test_create_simple_mpeg_for_avi()
    call test_mpeg_to_avi_conversion()
    call test_avi_file_structure()
    
    print *, "PASS: All MPEG to AVI conversion tests"
    
contains

    subroutine test_create_simple_mpeg_for_avi()
        ! Create a simple MPEG test file for AVI conversion
        character(len=*), parameter :: test_mpeg = "test_for_avi.mpg"
        type(mem_t) :: frame_buffer
        integer, parameter :: width = 16, height = 12, num_frames = 10
        integer :: frame_num, x, y, pixel_idx, brightness
        
        print *, "Creating test MPEG file for AVI conversion..."
        
        ! Create frame buffer
        frame_buffer = mem_create(width, height)
        
        ! Open MPEG file for writing
        call stream_open_write(test_mpeg)
        
        ! Write simple header
        call stream_put_variable(width, 16)
        call stream_put_variable(height, 16)
        call stream_put_variable(num_frames, 16)
        call stream_put_variable(15, 8)  ! Frame rate
        
        ! Generate frames with simple pattern
        do frame_num = 1, num_frames
            ! Clear frame
            do pixel_idx = 1, width * height
                frame_buffer%data(pixel_idx) = 0
            end do
            
            ! Draw a simple pattern that changes each frame
            do y = 1, height
                do x = 1, width
                    brightness = mod((x + y + frame_num * 2), 256)
                    if (brightness > 128) then
                        pixel_idx = (y - 1) * width + x
                        frame_buffer%data(pixel_idx) = int(brightness, c_int8_t)
                    end if
                end do
            end do
            
            ! Write frame header
            call stream_put_variable(frame_num, 16)
            
            ! Write frame data
            do pixel_idx = 1, width * height
                call stream_put_variable(int(frame_buffer%data(pixel_idx)), 8)
            end do
        end do
        
        call stream_close_write()
        call mem_destroy(frame_buffer)
        
        print *, "  Created test MPEG file:", test_mpeg
        print *, "  Dimensions:", width, "x", height
        print *, "  Frames:", num_frames
    end subroutine

    subroutine test_mpeg_to_avi_conversion()
        ! Test the main conversion function
        character(len=*), parameter :: test_mpeg = "test_for_avi.mpg"
        character(len=*), parameter :: test_avi = "test_output.avi"
        integer, parameter :: width = 16, height = 12, frame_rate = 15, num_frames = 10
        
        print *, "Testing MPEG to AVI conversion..."
        
        ! Perform conversion
        call mpeg_to_avi(test_mpeg, test_avi, width, height, frame_rate, num_frames)
        
        ! Verify AVI file was created
        call verify_avi_file_exists(test_avi)
        
        print *, "  Conversion completed successfully"
        print *, "  Output file:", test_avi
    end subroutine

    subroutine test_avi_file_structure()
        ! Test AVI file structure validation
        character(len=*), parameter :: test_avi = "test_output.avi"
        
        print *, "Validating AVI file structure..."
        
        ! Basic file structure checks
        call validate_avi_header(test_avi)
        call validate_avi_size(test_avi)
        
        print *, "  AVI file structure validation completed"
    end subroutine

    subroutine verify_avi_file_exists(filename)
        character(len=*), intent(in) :: filename
        type(c_ptr) :: file_ptr
        integer(c_int) :: status
        
        file_ptr = c_fopen(trim(filename)//c_null_char, "rb"//c_null_char)
        if (.not. c_associated(file_ptr)) then
            error stop "AVI file was not created"
        end if
        status = c_fclose(file_ptr)
        
        print *, "    ✅ AVI file exists:", filename
    end subroutine

    subroutine validate_avi_header(filename)
        character(len=*), intent(in) :: filename
        type(c_ptr) :: file_ptr
        integer(c_int32_t), target :: fourcc, file_size
        integer(c_size_t) :: read_count
        integer(c_int) :: status
        
        file_ptr = c_fopen(trim(filename)//c_null_char, "rb"//c_null_char)
        if (.not. c_associated(file_ptr)) then
            error stop "Cannot open AVI file for validation"
        end if
        
        ! Read and verify RIFF header
        read_count = c_fread(c_loc(fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        if (fourcc /= int(z'46464952', c_int32_t)) then  ! 'RIFF'
            status = c_fclose(file_ptr)
            error stop "Invalid RIFF signature in AVI file"
        end if
        
        ! Read file size
        read_count = c_fread(c_loc(file_size), 4_c_size_t, 1_c_size_t, file_ptr)
        if (file_size <= 0) then
            status = c_fclose(file_ptr)
            error stop "Invalid file size in AVI header"
        end if
        
        ! Read and verify AVI signature
        read_count = c_fread(c_loc(fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        if (fourcc /= int(z'20495641', c_int32_t)) then  ! 'AVI '
            status = c_fclose(file_ptr)
            error stop "Invalid AVI signature"
        end if
        
        status = c_fclose(file_ptr)
        
        print *, "    ✅ Valid RIFF/AVI header structure"
        print *, "    ✅ File size:", file_size, "bytes"
    end subroutine

    subroutine validate_avi_size(filename)
        character(len=*), intent(in) :: filename
        type(c_ptr) :: file_ptr
        integer(c_long) :: file_size
        integer(c_int) :: status
        
        file_ptr = c_fopen(trim(filename)//c_null_char, "rb"//c_null_char)
        if (.not. c_associated(file_ptr)) then
            error stop "Cannot open AVI file for size validation"
        end if
        
        ! Get file size
        status = c_fseek(file_ptr, 0_c_long, SEEK_END)
        file_size = c_ftell(file_ptr)
        status = c_fclose(file_ptr)
        
        if (file_size <= 0) then
            error stop "AVI file has invalid size"
        end if
        
        ! Reasonable size check (should be larger than headers alone)
        if (file_size < 200) then
            error stop "AVI file too small - missing data"
        end if
        
        print *, "    ✅ AVI file size validation passed:", file_size, "bytes"
        
        ! Estimate compression ratio
        if (file_size > 1000) then
            print *, "    ✅ File size indicates successful data inclusion"
        end if
    end subroutine

end program test_mpeg_to_avi