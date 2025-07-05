program debug_seek_positions
    use fortplot_mpeg_stream
    use iso_c_binding
    implicit none
    
    ! Test the exact sequence that's failing
    
    print *, "=== Debug Seek Positions ==="
    
    ! Manually simulate what should happen:
    print *, ""
    print *, "Manual simulation:"
    print *, "1. Write 1 at pos 0 (bit 7): 10000000"
    print *, "2. Write 0 at pos 1 (bit 6): 10000000" 
    print *, "3. Write 1 at pos 2 (bit 5): 10100000"
    print *, "4. Flush with 1s: 10111111"
    print *, "5. Seek to pos 1:"
    print *, "   - Read 10111111"
    print *, "   - Mask to keep bit 7: 10000000"
    print *, "6. Write 1 at pos 1 (bit 6): 11000000"
    print *, "7. Write 1 at pos 2 (bit 5): 11100000"
    print *, "8. Continue to fill: 11100111"
    
    ! Test what position calculation gives us
    print *, ""
    print *, "Testing position calculations:"
    print *, "After 8 bits written (position = 8):"
    print *, "  target_byte_pos = (8 - 7) >> 3 + 1 =", ishft(8 - 7, -3) + 1
    print *, "After 7 bits written (position = 7):"
    print *, "  target_byte_pos = (7 - 7) >> 3 + 1 =", ishft(7 - 7, -3) + 1
    
    ! Check if the issue is in stream_put_bit when position != bit count
    print *, ""
    print *, "After seek to 1, when we write 7 more bits:"
    print *, "  Starting position = 1"
    print *, "  After 7 bits, position = 8"
    print *, "  Byte position = (8 - 7) >> 3 + 1 =", ishft(8 - 7, -3) + 1
    
    ! Ah! I think I see it. When we seek to position 1, we set:
    ! - write_stream_state%position = 1
    ! - write_stream_state%bit_position = 6
    ! But when we've written 7 more bits, position is 8, but we've only 
    ! written 7 bits total in this byte!
    
    print *, ""
    print *, "POTENTIAL BUG:"
    print *, "The position counter tracks absolute bit position"
    print *, "But bit_position tracks position within current byte"
    print *, "After seek, these can be out of sync!"
    
end program debug_seek_positions