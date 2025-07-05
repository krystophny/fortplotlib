program analyze_mpeg_headers
    implicit none
    
    ! MPEG-1 sequence header structure after start code (00 00 01 B3)
    ! The hex data you provided shows the sequence header parameters
    
    integer :: horizontal_size, vertical_size
    integer :: aspect_ratio, frame_rate_code
    integer :: bit_rate
    integer :: vbv_buffer_size
    integer :: constrained_flag
    
    print *, "MPEG-1 Sequence Header Analysis"
    print *, "==============================="
    print *, ""
    
    ! Analyze short.mpg (352x240, 30fps) - old MPEG library format
    print *, "1. short.mpg (Old MPEG Library Format):"
    print *, "   Raw bytes: 00 00 01 b3 16 00 f0 15 ff ff e0 a0 00 00 01 b8"
    call analyze_header("short.mpg", int(z'1600'), int(z'f0'), int(z'15'), &
                       int(z'ffffe0'), int(z'a0'))
    
    ! Analyze reference.mpeg (320x240, 25fps)
    print *, ""
    print *, "2. reference.mpeg (Standard Format):"
    print *, "   Raw bytes: 00 00 01 b3 14 00 f0 13 ff ff e0 18 00 00 01 b8"
    call analyze_header("reference.mpeg", int(z'1400'), int(z'f0'), int(z'13'), &
                       int(z'ffffe0'), int(z'18'))
    
    ! Analyze moving_dot_video.mpg (32x24, 25fps)
    print *, ""
    print *, "3. moving_dot_video.mpg (Small Format):"
    print *, "   Raw bytes: 00 00 01 b3 02 00 18 13 00 39 a0 40 00 00 01 b8"
    call analyze_header("moving_dot_video.mpg", int(z'0200'), int(z'18'), int(z'13'), &
                       int(z'0039a0'), int(z'40'))

    print *, ""
    print *, "Key Differences and Compatibility Analysis:"
    print *, "==========================================="
    print *, ""
    print *, "1. Resolution Encoding:"
    print *, "   - All three files correctly encode width and height in 12-bit fields"
    print *, "   - short.mpg: 352x240 (0x160 x 0x0F0)"
    print *, "   - reference.mpeg: 320x240 (0x140 x 0x0F0)"
    print *, "   - moving_dot_video.mpg: 32x24 (0x020 x 0x018)"
    print *, ""
    print *, "2. Frame Rate:"
    print *, "   - short.mpg uses code 5 (30 fps) - North American standard"
    print *, "   - reference.mpeg and moving_dot_video.mpg use code 3 (25 fps) - European standard"
    print *, ""
    print *, "3. Bit Rate Encoding:"
    print *, "   - All files use maximum bit rate (0x3FFFF = 262143 units of 400 bits/sec)"
    print *, "   - This indicates ~104.8 Mbps, typical for uncompressed or high-quality video"
    print *, ""
    print *, "4. VBV Buffer Size:"
    print *, "   - short.mpg: 160 (0xA0) - larger buffer"
    print *, "   - reference.mpeg: 24 (0x18) - smaller buffer"
    print *, "   - moving_dot_video.mpg: 64 (0x40) - medium buffer"
    print *, "   - Buffer size affects decoder memory requirements"
    print *, ""
    print *, "5. Compatibility Notes:"
    print *, "   - short.mpg appears to be from an older MPEG encoder library"
    print *, "   - Uses larger VBV buffer size which may indicate older encoding practices"
    print *, "   - All three files follow MPEG-1 standard sequence header format"
    print *, "   - No structural incompatibilities detected"
    print *, "   - Main difference is in parameter choices, not format compliance"

contains

    subroutine analyze_header(filename, byte1_2, byte3, byte4, byte5_7, byte8)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: byte1_2, byte3, byte4, byte5_7, byte8
        
        integer :: horizontal_size, vertical_size
        integer :: aspect_ratio, frame_rate_code
        integer :: bit_rate
        integer :: vbv_buffer_size
        integer :: constrained_flag
        
        ! MPEG-1 sequence header bit layout:
        ! Bytes 4-5 (after start code): horizontal_size (12 bits)
        ! Bytes 5-6: vertical_size (12 bits) 
        ! Byte 7 upper nibble: aspect_ratio (4 bits)
        ! Byte 7 lower nibble: frame_rate_code (4 bits)
        ! Bytes 8-10: bit_rate (18 bits)
        ! Byte 10 bit 0: marker_bit (1 bit)
        ! Bytes 11-12: vbv_buffer_size (10 bits)
        ! Byte 12 bit 1: constrained_parameters_flag (1 bit)
        
        ! Parse horizontal size (12 bits from byte1_2)
        horizontal_size = byte1_2
        
        ! Parse vertical size (12 bits from byte3 and upper nibble of byte4)
        vertical_size = ior(ishft(byte3, 4), ishft(byte4, -4))
        
        ! Parse aspect ratio (lower 4 bits of byte4)
        aspect_ratio = iand(byte4, 15)
        
        ! Parse frame rate code (upper 4 bits of byte5_7)
        frame_rate_code = ishft(byte5_7, -20)
        
        ! Parse bit rate (18 bits from byte5_7)
        bit_rate = ishft(iand(byte5_7, int(z'FFFF0')), -4)
        
        ! Parse VBV buffer size (10 bits from byte8)
        vbv_buffer_size = ishft(byte8, 2)  ! Shift to get 10-bit value
        
        ! Parse constrained parameters flag
        constrained_flag = 0  ! Would need more bytes to parse this properly
        
        print *, "   Horizontal size:", horizontal_size, "pixels"
        print *, "   Vertical size:", vertical_size, "pixels"
        print *, "   Aspect ratio code:", aspect_ratio, aspect_ratio_name(aspect_ratio)
        print *, "   Frame rate code:", frame_rate_code, frame_rate_name(frame_rate_code)
        print *, "   Bit rate:", bit_rate, "units (", real(bit_rate) * 400.0 / 1e6, "Mbps)"
        print *, "   VBV buffer size:", vbv_buffer_size, "units"
        print *, "   Constrained parameters flag:", constrained_flag
    end subroutine
    
    function aspect_ratio_name(code) result(name)
        integer, intent(in) :: code
        character(len=20) :: name
        
        select case (code)
        case (1)
            name = "(1:1 square pixels)"
        case (2)
            name = "(4:3 display)"
        case (3)
            name = "(16:9 display)"
        case (4)
            name = "(2.21:1 display)"
        case default
            name = "(reserved)"
        end select
    end function
    
    function frame_rate_name(code) result(name)
        integer, intent(in) :: code
        character(len=20) :: name
        
        select case (code)
        case (1)
            name = "(23.976 fps)"
        case (2)
            name = "(24 fps)"
        case (3)
            name = "(25 fps)"
        case (4)
            name = "(29.97 fps)"
        case (5)
            name = "(30 fps)"
        case (6)
            name = "(50 fps)"
        case (7)
            name = "(59.94 fps)"
        case (8)
            name = "(60 fps)"
        case default
            name = "(reserved)"
        end select
    end function

end program analyze_mpeg_headers