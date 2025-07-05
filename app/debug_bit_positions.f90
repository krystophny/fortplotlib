program debug_bit_positions
    use iso_c_binding
    implicit none
    
    integer :: buffer, result
    integer, parameter :: bit_set_mask(0:7) = [1, 2, 4, 8, 16, 32, 64, 128]
    
    print *, "=== Debug Bit Positions ==="
    print *, ""
    print *, "Bit positions (MSB to LSB):"
    print *, "Position 0 -> bit 7 (mask=128)"
    print *, "Position 1 -> bit 6 (mask=64)"
    print *, "Position 2 -> bit 5 (mask=32)"
    print *, "..."
    print *, "Position 7 -> bit 0 (mask=1)"
    
    print *, ""
    print *, "Test: Start with 10000000, set bit at position 1 (bit 6)"
    buffer = int(b'10000000')  ! 128
    print *, "Initial buffer:", to_binary(buffer)
    
    ! Set bit at position 1 (bit 6)
    buffer = ior(buffer, bit_set_mask(6))  ! Position 1 corresponds to bit 6
    print *, "After setting bit 6:", to_binary(buffer)
    print *, "Expected: 11000000"
    
    print *, ""
    print *, "Wait! In stream_put_bit, we use bit_set_mask(bit_position)"
    print *, "If bit_position = 6, we'd use bit_set_mask(6) = 64"
    print *, "That's correct!"
    
    print *, ""
    print *, "So why are we getting 0 as the first bit?"
    print *, "Let's check the masking:"
    
    buffer = int(b'10111111')  ! What we read from file
    print *, ""
    print *, "File contains:", to_binary(buffer)
    
    ! Mask for position 1 (preserve bit 0 only)
    buffer = iand(buffer, int(b'10000000'))
    print *, "After masking for position 1:", to_binary(buffer)
    
    ! Now if bit_position is set to 6, and we write a 1:
    buffer = ior(buffer, bit_set_mask(6))
    print *, "After writing 1 at bit_position 6:", to_binary(buffer)
    print *, "This should be 11000000"
    
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
    
end program debug_bit_positions