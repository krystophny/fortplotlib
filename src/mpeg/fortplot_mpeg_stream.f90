module fortplot_mpeg_stream
    use iso_c_binding
    use fortplot_mpeg_c_io
    implicit none
    private
    
    ! Stream I/O constants
    integer, parameter :: STREAM_READ = 0
    integer, parameter :: STREAM_WRITE = 1
    
    ! Stream state type using C file pointers
    type :: stream_state_t
        integer :: mode
        integer(c_long) :: position
        logical :: is_open
        character(len=:), allocatable :: filename
        logical :: eof_reached
        type(c_ptr) :: file_ptr  ! C FILE* pointer
        integer :: bit_buffer
        integer :: bits_in_buffer
        integer :: bit_position  ! Position within current byte (0-7)
    end type stream_state_t
    
    ! Global stream states (matching C implementation pattern)
    type(stream_state_t) :: read_stream_state
    type(stream_state_t) :: write_stream_state
    
    public :: stream_open_read, stream_close_read
    public :: stream_open_write, stream_close_write
    public :: stream_get_bit, stream_put_bit
    public :: stream_get_variable, stream_put_variable
    public :: stream_tell_read, stream_tell_write
    public :: stream_seek_read, stream_seek_write
    public :: stream_eof, stream_align_read, stream_flush_write, stream_flush_write_zeros
    
contains

    subroutine stream_open_read(filename)
        character(len=*), intent(in) :: filename
        character(len=len(filename)+1) :: c_filename
        character(len=2) :: c_mode
        
        read_stream_state%filename = filename
        read_stream_state%mode = STREAM_READ
        read_stream_state%position = 0_c_long
        read_stream_state%eof_reached = .false.
        read_stream_state%bit_buffer = 0
        read_stream_state%bits_in_buffer = 0
        read_stream_state%bit_position = -1  ! Match C: read_position = -1
        
        ! Convert to C strings
        c_filename = c_string_from_fortran(filename)
        c_mode = c_string_from_fortran("r")
        
        ! Open file using C fopen - exact match to C implementation
        read_stream_state%file_ptr = c_fopen(c_filename, c_mode)
        read_stream_state%is_open = c_associated(read_stream_state%file_ptr)
        
        if (.not. read_stream_state%is_open) then
            print *, "Warning: Failed to open file for reading: ", filename
        end if
    end subroutine stream_open_read

    subroutine stream_close_read()
        integer(c_int) :: status
        
        if (read_stream_state%is_open) then
            ! Close file using C fclose
            status = c_fclose(read_stream_state%file_ptr)
            read_stream_state%file_ptr = c_null_ptr
            read_stream_state%is_open = .false.
            
            if (allocated(read_stream_state%filename)) then
                deallocate(read_stream_state%filename)
            end if
        end if
    end subroutine stream_close_read

    subroutine stream_open_write(filename)
        character(len=*), intent(in) :: filename
        character(len=len(filename)+1) :: c_filename
        character(len=3) :: c_mode
        
        write_stream_state%filename = filename
        write_stream_state%mode = STREAM_WRITE
        write_stream_state%position = 0_c_long
        write_stream_state%eof_reached = .false.
        write_stream_state%bit_buffer = 0
        write_stream_state%bits_in_buffer = 0
        write_stream_state%bit_position = 7
        
        ! Convert to C strings
        c_filename = c_string_from_fortran(filename)
        c_mode = c_string_from_fortran("w+")  ! Read/write, create if not exists (like C MPEG)
        
        ! Open file using C fopen - exact match to C implementation
        write_stream_state%file_ptr = c_fopen(c_filename, c_mode)
        write_stream_state%is_open = c_associated(write_stream_state%file_ptr)
        
        if (.not. write_stream_state%is_open) then
            print *, "Warning: Failed to open file for writing: ", filename
        end if
    end subroutine stream_open_write

    subroutine stream_close_write()
        integer(c_int) :: status
        
        if (write_stream_state%is_open) then
            ! Flush any remaining bits
            call stream_flush_write()
            
            ! Close file using C fclose
            status = c_fclose(write_stream_state%file_ptr)
            write_stream_state%file_ptr = c_null_ptr
            write_stream_state%is_open = .false.
            
            if (allocated(write_stream_state%filename)) then
                deallocate(write_stream_state%filename)
            end if
        end if
    end subroutine stream_close_write

    function stream_get_bit() result(bit_value)
        integer :: bit_value
        integer(c_int) :: byte_code
        
        if (.not. read_stream_state%is_open) then
            bit_value = 0
            return
        end if
        
        ! Replicate C mgetb() exactly:
        ! if (read_position<0) { current_read_byte=getc(srin); read_position = 7; }
        if (read_stream_state%bit_position < 0) then
            byte_code = c_fgetc(read_stream_state%file_ptr)
            if (byte_code == EOF) then
                read_stream_state%eof_reached = .true.
                bit_value = 0
                return
            end if
            read_stream_state%bit_buffer = byte_code
            read_stream_state%bit_position = 7
        end if
        
        ! if (current_read_byte&bit_set_mask[read_position--]) {return(1);}
        ! Note: C bit_set_mask starts at index 0, we need to adjust for Fortran 1-based arrays
        if (iand(read_stream_state%bit_buffer, ishft(1, read_stream_state%bit_position)) /= 0) then
            bit_value = 1
        else
            bit_value = 0
        end if
        
        read_stream_state%bit_position = read_stream_state%bit_position - 1
        read_stream_state%position = read_stream_state%position + 1
    end function stream_get_bit

    subroutine stream_put_bit(bit_value)
        integer, intent(in) :: bit_value
        integer(c_int8_t) :: byte_val
        integer(c_int) :: status
        integer, parameter :: bit_set_mask(0:7) = [1, 2, 4, 8, 16, 32, 64, 128]
        
        if (.not. write_stream_state%is_open) return
        
        ! Match C implementation exactly:
        ! For mput1: current_write_byte|=bit_set_mask[write_position--];
        ! For mput0: write_position--;  
        if (iand(bit_value, 1) == 1) then
            write_stream_state%bit_buffer = ior(write_stream_state%bit_buffer, &
                                             bit_set_mask(write_stream_state%bit_position))
        end if
        
        ! Decrement bit position (like C: write_position--)
        write_stream_state%bit_position = write_stream_state%bit_position - 1
        
        ! If position goes negative, write byte and reset (like C)
        if (write_stream_state%bit_position < 0) then
            byte_val = int(write_stream_state%bit_buffer, c_int8_t)
            
            ! Write byte using C fputc - exact match to C putc(current_write_byte, swout)
            status = c_fputc(int(byte_val, c_int), write_stream_state%file_ptr)
            
            write_stream_state%bit_position = 7
            write_stream_state%bit_buffer = 0
        end if
        
        write_stream_state%position = write_stream_state%position + 1
    end subroutine stream_put_bit

    function stream_get_variable(num_bits) result(value)
        integer, intent(in) :: num_bits
        integer :: value
        integer :: i, bit_val
        
        if (.not. read_stream_state%is_open) then
            value = 0
            return
        end if
        
        ! Read bits from most significant to least significant
        value = 0
        do i = num_bits-1, 0, -1
            bit_val = stream_get_bit()
            if (bit_val /= 0) then
                value = ior(value, ishft(1, i))
            end if
        end do
    end function stream_get_variable

    subroutine stream_put_variable(value, num_bits)
        integer, intent(in) :: value, num_bits
        integer :: i, bit_value
        
        if (.not. write_stream_state%is_open) return
        
        ! Write bits from most significant to least significant  
        do i = num_bits-1, 0, -1
            bit_value = ishft(value, -i)
            bit_value = iand(bit_value, 1)
            call stream_put_bit(bit_value)
        end do
    end subroutine stream_put_variable

    function stream_tell_read() result(position)
        integer(c_long) :: position
        position = read_stream_state%position
    end function stream_tell_read

    function stream_tell_write() result(position)
        integer(c_long) :: position
        position = write_stream_state%position
    end function stream_tell_write

    subroutine stream_seek_read(position)
        integer(c_long), intent(in) :: position
        
        integer(c_long) :: target_byte_pos
        integer :: target_bit_pos
        integer(c_int) :: byte_code, status
        
        if (.not. read_stream_state%is_open) return
        
        ! Replicate C mrseek() exactly:
        ! fseek(srin,distance>>3,0L);
        target_byte_pos = ishft(position, -3)
        status = c_fseek(read_stream_state%file_ptr, target_byte_pos, SEEK_SET)
        
        ! current_read_byte = getc(srin);
        byte_code = c_fgetc(read_stream_state%file_ptr)
        if (byte_code == EOF) then
            read_stream_state%eof_reached = .true.
            read_stream_state%bit_buffer = 0
            read_stream_state%bit_position = -1
        else
            read_stream_state%bit_buffer = byte_code
            ! read_position = 7 - (distance % 8);
            read_stream_state%bit_position = 7 - int(mod(position, 8_c_long))
        end if
        
        read_stream_state%position = position
    end subroutine stream_seek_read

    subroutine stream_seek_write(position)
        integer(c_long), intent(in) :: position
        
        integer(c_long) :: target_byte_pos, file_length_bytes
        integer(c_int) :: byte_code, status
        integer(c_int8_t) :: byte_val
        
        if (.not. write_stream_state%is_open) return
        
        ! Replicate C mwseek() exactly:
        ! Step 1: if (write_position != 7) {putc(current_write_byte,swout);}
        if (write_stream_state%bit_position /= 7) then
            byte_val = int(write_stream_state%bit_buffer, c_int8_t)
            status = c_fputc(int(byte_val, c_int), write_stream_state%file_ptr)
        end if
        
        ! Step 2: fseek(swout,0,2L);
        status = c_fseek(write_stream_state%file_ptr, 0_c_long, SEEK_END)
        
        ! Step 3: Length = ftell(swout);
        file_length_bytes = c_ftell(write_stream_state%file_ptr)
        
        ! Step 4: fseek(swout,(distance+7)>>3,0L);
        ! CRITICAL: C code uses (distance+7)>>3, but this is incorrect for intra-byte seeks
        ! Use correct formula for functionality: distance>>3
        target_byte_pos = ishft(position, -3)
        status = c_fseek(write_stream_state%file_ptr, target_byte_pos, SEEK_SET)
        
        ! Step 5 & 6: if ((Length << 3) <= distance)
        if (ishft(file_length_bytes, 3) <= position) then
            ! Beyond file end - start clean (like C)
            write_stream_state%bit_buffer = 0
            write_stream_state%bit_position = 7 - int(iand(position, 7_c_long))
        else
            ! Within existing file - read byte and preserve earlier bits (like C)
            ! Note: getc advances file position, so we need to seek back after
            byte_code = c_fgetc(write_stream_state%file_ptr)
            if (byte_code /= EOF) then
                ! Read existing byte and preserve earlier bits
                write_stream_state%bit_buffer = byte_code
                ! Mask out bits from target position onward
                call mask_buffer_from_position(write_stream_state%bit_buffer, int(iand(position, 7_c_long)))
            else
                write_stream_state%bit_buffer = 0
            end if
            write_stream_state%bit_position = 7 - int(iand(position, 7_c_long))
            
            ! Step 7 (critical): fseek(swout,(distance+7)>>3,0L); - seek back to target position  
            ! This is essential because getc advanced the file position
            status = c_fseek(write_stream_state%file_ptr, target_byte_pos, SEEK_SET)
        end if
        
        write_stream_state%position = position
    end subroutine stream_seek_write
    
    subroutine mask_buffer_from_position(buffer, bit_position)
        !! Mask out bits from bit_position onward, preserving earlier bits
        integer, intent(inout) :: buffer
        integer, intent(in) :: bit_position
        
        integer, parameter :: preserve_masks(0:7) = [ &
            int(b'00000000'), &  ! position 0: preserve nothing, clear all bits
            int(b'10000000'), &  ! position 1: preserve bit 0
            int(b'11000000'), &  ! position 2: preserve bits 0-1  
            int(b'11100000'), &  ! position 3: preserve bits 0-2
            int(b'11110000'), &  ! position 4: preserve bits 0-3
            int(b'11111000'), &  ! position 5: preserve bits 0-4
            int(b'11111100'), &  ! position 6: preserve bits 0-5
            int(b'11111110') &   ! position 7: preserve bits 0-6
        ]
        
        if (bit_position >= 0 .and. bit_position <= 7) then
            buffer = iand(buffer, preserve_masks(bit_position))
        end if
    end subroutine mask_buffer_from_position

    function stream_eof() result(is_eof)
        logical :: is_eof
        is_eof = read_stream_state%eof_reached
    end function stream_eof

    subroutine stream_align_read()
        ! Align to byte boundary for marker reading
        integer(c_long) :: remainder
        remainder = mod(read_stream_state%position, 8_c_long)
        if (remainder /= 0) then
            read_stream_state%position = read_stream_state%position + (8_c_long - remainder)
        end if
    end subroutine stream_align_read

    subroutine stream_flush_write()
        ! Flush any buffered bits with zeros
        integer(c_int8_t) :: byte_val
        integer :: bits_to_pad
        
        if (.not. write_stream_state%is_open) return
        
        ! Match C mwclose behavior: while(write_position!=7) {mput1();}
        do while (write_stream_state%bit_position /= 7)
            call stream_put_bit(1)
        end do
    end subroutine stream_flush_write

    subroutine stream_flush_write_zeros()
        integer(c_int8_t) :: byte_val
        integer(c_int) :: status
        
        if (.not. write_stream_state%is_open) return
        
        ! Replicate C zeroflush() exactly:
        ! while (write_position!=7) { mput0(); }
        do while (write_stream_state%bit_position /= 7)
            call stream_put_bit(0)
        end do
    end subroutine stream_flush_write_zeros

end module fortplot_mpeg_stream