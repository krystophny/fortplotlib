program debug_c_algorithm
    use fortplot_mpeg_c_io
    use iso_c_binding
    implicit none
    
    type(c_ptr) :: file_ptr
    integer(c_int) :: status, byte_code
    integer(c_long) :: file_length, target_byte_pos, position
    integer :: current_write_byte, write_position
    character(len=20) :: filename = "debug_c_alg.dat" // c_null_char
    character(len=3) :: mode = "w+" // c_null_char
    
    print *, "=== Debugging C Algorithm ==="
    
    ! Simulate exactly what C mwseek does
    file_ptr = c_fopen(filename, mode)
    if (.not. c_associated(file_ptr)) then
        print *, "Failed to open file"
        stop
    end if
    
    ! Initial state (matching C mwopen)
    current_write_byte = 0
    write_position = 7
    
    print *, "Initial: write_position =", write_position, "current_write_byte =", current_write_byte
    
    ! Write 3 bits: 1, 0, 1 (matching our test)
    ! Bit 1: current_write_byte |= bit_set_mask[7] = 128
    current_write_byte = ior(current_write_byte, 128)  ! bit 7
    write_position = write_position - 1  ! write_position = 6
    
    ! Bit 0: write_position-- (no set)
    write_position = write_position - 1  ! write_position = 5
    
    ! Bit 1: current_write_byte |= bit_set_mask[5] = 32
    current_write_byte = ior(current_write_byte, 32)   ! bit 5
    write_position = write_position - 1  ! write_position = 4
    
    print *, "After 3 bits: write_position =", write_position, "current_write_byte =", current_write_byte
    print *, "Buffer bits:", to_binary(current_write_byte)
    
    ! Now simulate mwseek(1)
    position = 1
    print *, ""
    print *, "Starting mwseek(", position, ")..."
    
    ! Step 1: if (write_position != 7) {putc(current_write_byte,swout);}
    if (write_position /= 7) then
        print *, "Step 1: Flushing current byte", to_binary(current_write_byte)
        status = c_fputc(current_write_byte, file_ptr)
        print *, "  putc returned:", status
    end if
    
    ! Step 2: fseek(swout,0,2L);
    status = c_fseek(file_ptr, 0_c_long, SEEK_END)
    print *, "Step 2: Sought to end, status =", status
    
    ! Step 3: Length = ftell(swout);
    file_length = c_ftell(file_ptr)
    print *, "Step 3: File length =", file_length, "bytes"
    
    ! Step 4: fseek(swout,(distance+7)>>3,0L);
    target_byte_pos = ishft(position + 7, -3)
    print *, "Step 4: Target byte pos = (", position, " + 7) >> 3 =", target_byte_pos
    status = c_fseek(file_ptr, target_byte_pos, SEEK_SET)
    print *, "  Sought to byte", target_byte_pos, "status =", status
    
    ! Step 5: if ((Length << 3) <= distance)
    print *, "Step 5: Check (", file_length, " << 3) <= ", position
    print *, "        ", ishft(file_length, 3), " <= ", position, " =", ishft(file_length, 3) <= position
    
    if (ishft(file_length, 3) <= position) then
        print *, "  Beyond file end: current_write_byte = 0"
        current_write_byte = 0
        write_position = 7 - int(iand(position, 7_c_long))
    else
        print *, "  Within file: reading existing byte"
        byte_code = c_fgetc(file_ptr)
        print *, "    getc returned:", byte_code, "=", to_binary(byte_code)
        current_write_byte = byte_code
        write_position = 7 - int(iand(position, 7_c_long))
        
        ! Step 6: fseek(swout,(distance+7)>>3,0L);
        status = c_fseek(file_ptr, target_byte_pos, SEEK_SET)
        print *, "    Sought back to byte", target_byte_pos, "status =", status
    end if
    
    print *, "Final: write_position =", write_position, "current_write_byte =", current_write_byte
    print *, "Final buffer:", to_binary(current_write_byte)
    
    status = c_fclose(file_ptr)
    
contains
    function to_binary(byte) result(binary_str)
        integer, intent(in) :: byte
        character(len=8) :: binary_str
        integer :: i, bit_val
        
        do i = 1, 8
            bit_val = iand(ishft(byte, -(8-i)), 1)
            if (bit_val == 1) then
                binary_str(i:i) = '1'
            else
                binary_str(i:i) = '0'
            end if
        end do
    end function to_binary
    
end program debug_c_algorithm