program debug_seek_buffer
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! This will test the seek behavior step by step
    
    print *, "=== Testing Seek Buffer Behavior ==="
    
    ! First understand what should happen:
    ! 1. Write 101 at positions 0,1,2
    ! 2. Buffer should have 10100000, bit_position = 4
    ! 3. Seek to position 1 should:
    !    - Flush buffer (writing 10111111 due to flush with 1s)
    !    - Read back the byte (10111111)
    !    - Mask to preserve bit 0 only (10000000)
    !    - Set bit_position = 6 (for writing at bit position 1)
    
    print *, ""
    print *, "Expected behavior:"
    print *, "1. After writing 101: buffer = 10100000"
    print *, "2. After seek to 1: buffer = 10000000 (bit 0 preserved)"
    print *, "3. Writing 1 at position 1 should give: 11000000"
    
    ! Let's trace through the C behavior
    ! In C, bit positions are: 7,6,5,4,3,2,1,0
    ! Writing at position 0 sets bit 7 (MSB)
    ! Writing at position 1 sets bit 6
    ! etc.
    
    print *, ""
    print *, "Understanding bit positions:"
    print *, "Position 0 -> bit 7 (value 128)"
    print *, "Position 1 -> bit 6 (value 64)"
    print *, "Position 2 -> bit 5 (value 32)"
    print *, "Position 3 -> bit 4 (value 16)"
    print *, "Position 4 -> bit 3 (value 8)"
    print *, "Position 5 -> bit 2 (value 4)"
    print *, "Position 6 -> bit 1 (value 2)"
    print *, "Position 7 -> bit 0 (value 1)"
    
    ! Now let's check our bit_set_mask array
    print *, ""
    print *, "Checking bit_set_mask values:"
    print *, "bit_set_mask(7) =", bit_set_mask(7), " (should be 128)"
    print *, "bit_set_mask(6) =", bit_set_mask(6), " (should be 64)"
    print *, "bit_set_mask(5) =", bit_set_mask(5), " (should be 32)"
    
contains
    function bit_set_mask(pos) result(mask)
        integer, intent(in) :: pos
        integer :: mask
        integer, parameter :: masks(0:7) = [1, 2, 4, 8, 16, 32, 64, 128]
        mask = masks(pos)
    end function bit_set_mask
    
end program debug_seek_buffer