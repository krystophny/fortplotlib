program debug_byte_calc
    implicit none
    integer :: position, current_byte_pos, target_byte_pos, bit_position
    
    print *, "=== Debug Byte Calculations ==="
    
    ! Simulate the failing case:
    ! After writing 3 bits (101), position = 3, bit_position = 4
    ! Seeking to position 1
    
    print *, "After writing 3 bits:"
    position = 3
    bit_position = 4  ! 7, 6, 5, next would be 4
    current_byte_pos = ishft(position - (7 - bit_position), -3)
    print *, "  position =", position
    print *, "  bit_position =", bit_position
    print *, "  current_byte_pos = (", position, "- (7 -", bit_position, ")) >> 3 =", current_byte_pos
    
    print *, ""
    print *, "Seeking to position 1:"
    position = 1
    target_byte_pos = ishft(position + 7, -3)
    print *, "  target position =", position
    print *, "  target_byte_pos = (", position, "+ 7) >> 3 =", target_byte_pos
    
    print *, ""
    print *, "Comparison:"
    print *, "  current_byte_pos =", current_byte_pos
    print *, "  target_byte_pos =", target_byte_pos
    if (current_byte_pos == target_byte_pos) then
        print *, "  SAME BYTE - should not flush during seek"
    else
        print *, "  DIFFERENT BYTE - should flush during seek"
    end if
    
end program debug_byte_calc