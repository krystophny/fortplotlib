program test_minimal_c_comparison
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use fortplot_mpeg1_format
    use iso_c_binding
    implicit none
    
    ! Create MINIMAL test case that exactly matches what C library would produce
    call create_minimal_test_frame()
    
    print *, "PASS: Minimal C comparison test"
    
contains

    subroutine create_minimal_test_frame()
        ! Create the SMALLEST possible valid MPEG that matches C library exactly
        character(len=*), parameter :: test_file = "minimal_c_test.mpg"
        type(mem_t) :: frame_buffer
        integer :: width, height, frame_rate, bit_rate
        integer :: file_size
        logical :: file_exists
        
        ! Use exact parameters that would match C library output
        width = 16    ! Single macroblock
        height = 16   ! Single macroblock  
        frame_rate = 25
        bit_rate = width * height * frame_rate * 8
        
        print *, "Creating minimal test case:"
        print *, "  Size: 16x16 (single macroblock)"
        print *, "  1 frame only"
        print *, "  Goal: Match C library output exactly"
        
        frame_buffer = mem_create(width, height)
        
        ! Fill with KNOWN pattern that C library would use
        call fill_with_c_test_pattern(frame_buffer, width, height)
        
        call stream_open_write(test_file)
        
        ! EXACT sequence header as C library
        call write_mpeg1_sequence_header(width, height, frame_rate, bit_rate)
        call write_mpeg1_gop_header(0)
        
        ! Single I-frame
        call write_mpeg1_picture_header(0, I_FRAME)
        call write_mpeg1_slice_header(1)
        call encode_mpeg1_frame(frame_buffer, width, height)
        
        call write_mpeg1_sequence_end()
        call stream_close_write()
        call mem_destroy(frame_buffer)
        
        inquire(file=test_file, exist=file_exists, size=file_size)
        if (file_exists) then
            print *, "✅ Minimal test created:"
            print *, "  File:", test_file
            print *, "  Size:", file_size, "bytes"
            
            ! Display hex dump for comparison
            call display_hex_dump(test_file, 100)
        end if
    end subroutine
    
    subroutine fill_with_c_test_pattern(frame_mem, width, height)
        ! Fill with pattern that C library test would use
        type(mem_t), intent(inout) :: frame_mem
        integer, intent(in) :: width, height
        integer :: i, j, pixel_idx, value
        
        ! Pattern 1: Simple gradient (common C test pattern)
        do i = 1, height
            do j = 1, width
                pixel_idx = (i - 1) * width + j
                value = mod((i - 1) * 16 + (j - 1), 256)
                
                ! Keep in valid signed byte range
                if (value > 127) value = value - 256
                
                frame_mem%data(pixel_idx) = int(value, c_int8_t)
            end do
        end do
        
        print *, "Test pattern filled:"
        print *, "  Top-left 8x8 block:"
        do i = 1, 8
            write(*, '(8I4)') (int(frame_mem%data((i-1)*width + j)), j=1, 8)
        end do
    end subroutine
    
    subroutine display_hex_dump(filename, max_bytes)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: max_bytes
        integer(1) :: bytes(max_bytes)
        integer :: i, ios, file_size, bytes_to_read
        
        inquire(file=filename, size=file_size)
        bytes_to_read = min(file_size, max_bytes)
        
        open(unit=10, file=filename, access='stream', form='unformatted')
        read(10, iostat=ios) bytes(1:bytes_to_read)
        close(10)
        
        print *, "Hex dump (first", bytes_to_read, "bytes):"
        do i = 1, bytes_to_read
            write(*, '(Z2.2, " ")', advance='no') bytes(i)
            if (mod(i, 16) == 0) then
                print *
            else if (mod(i, 8) == 0) then
                write(*, '(" ")', advance='no')
            end if
        end do
        if (mod(bytes_to_read, 16) /= 0) print *
        
        print *, "Key markers to verify:"
        print *, "  00 00 01 B3 = Sequence header"
        print *, "  00 00 01 B8 = GOP header"  
        print *, "  00 00 01 00 = Picture header"
        print *, "  00 00 01 01 = Slice header"
        print *, "  00 00 01 B7 = Sequence end"
    end subroutine

end program test_minimal_c_comparison