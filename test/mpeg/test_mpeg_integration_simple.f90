program test_mpeg_integration_simple
    use fortplot_mpeg_stream
    use fortplot_mpeg_memory
    use iso_c_binding
    implicit none
    
    ! Simple integration test demonstrating core MPEG components working together
    call test_stream_memory_integration()
    call test_multi_component_pipeline()
    
    print *, "PASS: All MPEG integration tests"
    
contains

    subroutine test_stream_memory_integration()
        ! Test integration between memory operations and stream I/O
        character(len=*), parameter :: test_file = "test_stream_mem.dat"
        type(mem_t) :: test_mem
        integer, parameter :: test_size = 16
        integer :: i, read_value, expected_value
        
        print *, "Testing stream-memory integration..."
        
        ! Create memory with test pattern
        test_mem = mem_create(4, 4)  ! 4x4 = 16 elements
        
        ! Fill with test pattern (use only positive values for simplicity)
        do i = 1, test_size
            test_mem%data(i) = int(mod(i * 13, 128), c_int8_t)  ! Range 0-127 to avoid sign issues
        end do
        
        ! Write memory data to stream
        call stream_open_write(test_file)
        do i = 1, test_size
            call stream_put_variable(int(test_mem%data(i)), 8)
        end do
        call stream_close_write()
        
        ! Read back from stream and verify
        call stream_open_read(test_file)
        do i = 1, test_size
            read_value = stream_get_variable(8)
            expected_value = int(test_mem%data(i))
            if (read_value /= expected_value) then
                print *, "Stream-memory integration failed at", i
                print *, "  Expected:", expected_value
                print *, "  Got:", read_value
                error stop "Stream-memory integration failed"
            end if
        end do
        call stream_close_read()
        
        call mem_destroy(test_mem)
        print *, "PASS: Stream-memory integration"
    end subroutine

    subroutine test_multi_component_pipeline()
        ! Test multiple components working together in a realistic pipeline
        character(len=*), parameter :: input_file = "input_data.dat"
        character(len=*), parameter :: compressed_file = "compressed.dat"
        character(len=*), parameter :: output_file = "output_data.dat"
        
        type(mem_t) :: input_mem, output_mem
        integer, parameter :: width = 8, height = 8
        integer :: x, y, pixel_value, i, pixel_curr, pixel_prev
        integer(c_long) :: start_pos, end_pos, compressed_bits
        
        print *, "Testing multi-component pipeline..."
        
        ! Step 1: Create test image data (use only 0-127 range to avoid signed byte issues)
        input_mem = mem_create(width, height)
        do y = 1, height
            do x = 1, width
                pixel_value = mod((x + y) * 17, 128)  ! Keep in 0-127 range
                input_mem%data((y-1) * width + x) = int(pixel_value, c_int8_t)
            end do
        end do
        
        ! Step 2: Save to file using memory operations
        call mem_save(input_mem, input_file)
        
        ! Step 3: Load and compress using stream operations
        output_mem = mem_load(input_file, width, height)
        
        call stream_open_write(compressed_file)
        start_pos = stream_tell_write()
        
        ! Write header
        call stream_put_variable(width, 8)
        call stream_put_variable(height, 8)
        
        ! Simple compression: write differences from previous pixel
        call stream_put_variable(int(output_mem%data(1)), 8)  ! First pixel (already positive)
        do i = 2, width * height
            ! Write difference (simple delta compression)
            pixel_value = int(output_mem%data(i)) - int(output_mem%data(i-1))
            ! Clamp to valid range for demo
            if (pixel_value < -127) pixel_value = -127
            if (pixel_value > 127) pixel_value = 127
            call stream_put_variable(pixel_value + 128, 8)  ! Offset by 128 to make positive
        end do
        
        end_pos = stream_tell_write()
        call stream_close_write()
        
        compressed_bits = end_pos - start_pos
        print *, "  Original size:", width * height * 8, "bits"
        print *, "  Compressed size:", compressed_bits, "bits"
        print *, "  Compression ratio:", real(width * height * 8) / real(compressed_bits)
        
        ! Step 4: Decompress and verify
        call test_decompression(compressed_file, input_mem, width, height)
        
        call mem_destroy(input_mem)
        call mem_destroy(output_mem)
        print *, "PASS: Multi-component pipeline"
    end subroutine

    subroutine test_decompression(compressed_file, original_mem, width, height)
        character(len=*), intent(in) :: compressed_file
        type(mem_t), intent(in) :: original_mem
        integer, intent(in) :: width, height
        
        type(mem_t) :: decompressed_mem
        integer :: read_width, read_height
        integer :: i, pixel_value, delta, pixel_prev_unsigned
        
        ! Read compressed data
        call stream_open_read(compressed_file)
        
        read_width = stream_get_variable(8)
        read_height = stream_get_variable(8)
        
        if (read_width /= width .or. read_height /= height) then
            error stop "Compressed file header mismatch"
        end if
        
        decompressed_mem = mem_create(width, height)
        
        ! Decompress data - simple delta decompression
        decompressed_mem%data(1) = int(stream_get_variable(8), c_int8_t)  ! First pixel
        do i = 2, width * height
            delta = stream_get_variable(8) - 128  ! Remove offset
            pixel_value = int(decompressed_mem%data(i-1)) + delta
            ! Clamp to valid range (0-127 since we limited input range)
            if (pixel_value < 0) pixel_value = 0
            if (pixel_value > 127) pixel_value = 127
            decompressed_mem%data(i) = int(pixel_value, c_int8_t)
        end do
        
        call stream_close_read()
        
        ! Verify decompression matches original
        do i = 1, width * height
            if (decompressed_mem%data(i) /= original_mem%data(i)) then
                print *, "Decompression failed at pixel", i
                print *, "  Original:", int(original_mem%data(i))
                print *, "  Decompressed:", int(decompressed_mem%data(i))
                error stop "Decompression verification failed"
            end if
        end do
        
        call mem_destroy(decompressed_mem)
    end subroutine

end program test_mpeg_integration_simple