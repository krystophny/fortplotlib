program debug_mpeg_mask
    use iso_c_binding
    implicit none
    
    integer :: buffer
    integer :: bit_position
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
    
    ! Test masking at position 1
    buffer = int(b'10111111')  ! What we read from file
    print *, "Original buffer: ", to_binary(buffer)
    
    bit_position = 1
    buffer = iand(buffer, preserve_masks(bit_position))
    print *, "After masking at position 1:", to_binary(buffer)
    print *, "Expected: 10000000"
    
    ! Now simulate writing bit 1 at position 1 (bit position 6)
    ! bit positions go 7,6,5,4,3,2,1,0 from left to right
    buffer = ior(buffer, ishft(1, 6))  ! Set bit at position 6
    print *, "After writing 1 at bit pos 6:", to_binary(buffer)
    print *, "Expected: 11000000"
    
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
    
end program debug_mpeg_mask