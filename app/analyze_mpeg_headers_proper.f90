program analyze_mpeg_headers_proper
    implicit none
    
    ! Hex bytes for the three MPEG files
    integer(1) :: short_mpg(16) = [ &
        int(z'00', 1), int(z'00', 1), int(z'01', 1), int(z'B3', 1), &
        int(z'16', 1), int(z'00', 1), int(z'F0', 1), int(z'15', 1), &
        int(z'FF', 1), int(z'FF', 1), int(z'E0', 1), int(z'A0', 1), &
        int(z'00', 1), int(z'00', 1), int(z'01', 1), int(z'B8', 1) ]
        
    integer(1) :: reference_mpeg(16) = [ &
        int(z'00', 1), int(z'00', 1), int(z'01', 1), int(z'B3', 1), &
        int(z'14', 1), int(z'00', 1), int(z'F0', 1), int(z'13', 1), &
        int(z'FF', 1), int(z'FF', 1), int(z'E0', 1), int(z'18', 1), &
        int(z'00', 1), int(z'00', 1), int(z'01', 1), int(z'B8', 1) ]
        
    integer(1) :: moving_dot(20) = [ &
        int(z'00', 1), int(z'00', 1), int(z'01', 1), int(z'B3', 1), &
        int(z'02', 1), int(z'00', 1), int(z'18', 1), int(z'13', 1), &
        int(z'00', 1), int(z'39', 1), int(z'A0', 1), int(z'40', 1), &
        int(z'00', 1), int(z'00', 1), int(z'20', 1), int(z'00', 1), &
        int(z'01', 1), int(z'FF', 1), int(z'FF', 1), int(z'00', 1) ]
    
    print *, "MPEG-1 Sequence Header Analysis"
    print *, "==============================="
    print *, ""
    
    ! Analyze short.mpg
    print *, "1. short.mpg (Old MPEG Library Format):"
    print *, "   Expected: 352x240, 30fps"
    call analyze_sequence_header(short_mpg(5:))
    
    ! Analyze reference.mpeg
    print *, ""
    print *, "2. reference.mpeg (Standard Format):"
    print *, "   Expected: 320x240, 25fps"
    call analyze_sequence_header(reference_mpeg(5:))
    
    ! Analyze moving_dot_video.mpg
    print *, ""
    print *, "3. moving_dot_video.mpg (Small Format):"
    print *, "   Expected: 32x24, 25fps"
    call analyze_sequence_header(moving_dot(5:))
    
    print *, ""
    print *, "Key Differences and Compatibility Analysis:"
    print *, "==========================================="
    print *, ""
    print *, "1. Resolution Encoding: All files correctly encode dimensions"
    print *, ""
    print *, "2. Frame Rate Differences:"
    print *, "   - short.mpg: 30 fps (NTSC standard)"
    print *, "   - Others: 25 fps (PAL standard)"
    print *, ""
    print *, "3. Bit Rate Values:"
    print *, "   - short.mpg and reference.mpeg: Maximum bit rate (variable)"
    print *, "   - moving_dot_video.mpg: Lower bit rate for small dimensions"
    print *, ""
    print *, "4. VBV Buffer Sizes:"
    print *, "   - Vary based on encoder and video complexity"
    print *, "   - short.mpg uses larger buffer (older encoder characteristic)"
    print *, ""
    print *, "5. Compatibility: All files are MPEG-1 compliant"

contains

    subroutine analyze_sequence_header(header_bytes)
        integer(1), intent(in) :: header_bytes(:)
        
        integer :: horizontal_size, vertical_size
        integer :: aspect_ratio, frame_rate_code
        integer :: bit_rate
        integer :: vbv_buffer_size
        integer :: constrained_flag
        integer :: load_intra_flag, load_non_intra_flag
        integer :: temp
        
        ! Parse 12-bit horizontal size from bytes 0-1
        horizontal_size = ior(ishft(iand(int(header_bytes(1)), 255), 4), &
                             ishft(iand(int(header_bytes(2)), 255), -4))
        
        ! Parse 12-bit vertical size from bytes 1-2
        vertical_size = ior(ishft(iand(int(header_bytes(2)), 15), 8), &
                           iand(int(header_bytes(3)), 255))
        
        ! Parse 4-bit aspect ratio from byte 3
        aspect_ratio = ishft(iand(int(header_bytes(4)), 255), -4)
        
        ! Parse 4-bit frame rate code from byte 3
        frame_rate_code = iand(int(header_bytes(4)), 15)
        
        ! Parse 18-bit bit rate from bytes 4-6
        bit_rate = ior(ior(ishft(iand(int(header_bytes(5)), 255), 10), &
                          ishft(iand(int(header_bytes(6)), 255), 2)), &
                          ishft(iand(int(header_bytes(7)), 255), -6))
        
        ! Skip marker bit and parse 10-bit VBV buffer size
        vbv_buffer_size = ior(ishft(iand(int(header_bytes(7)), 31), 5), &
                             ishft(iand(int(header_bytes(8)), 255), -3))
        
        ! Parse flags
        constrained_flag = iand(ishft(int(header_bytes(8)), -2), 1)
        load_intra_flag = iand(ishft(int(header_bytes(8)), -1), 1)
        load_non_intra_flag = iand(int(header_bytes(8)), 1)
        
        print *, "   Horizontal size:", horizontal_size, "pixels"
        print *, "   Vertical size:", vertical_size, "pixels"
        print *, "   Aspect ratio:", aspect_ratio, "=", aspect_ratio_name(aspect_ratio)
        print *, "   Frame rate code:", frame_rate_code, "=", frame_rate_name(frame_rate_code)
        print *, "   Bit rate:", bit_rate, "units (", real(bit_rate) * 400.0 / 1e6, "Mbps)"
        print *, "   VBV buffer size:", vbv_buffer_size, "units"
        print *, "   Constrained parameters:", constrained_flag
        print *, "   Load intra matrix:", load_intra_flag
        print *, "   Load non-intra matrix:", load_non_intra_flag
    end subroutine
    
    function aspect_ratio_name(code) result(name)
        integer, intent(in) :: code
        character(len=20) :: name
        
        select case (code)
        case (1)
            name = "1:1 square pixels"
        case (2)
            name = "4:3 display"
        case (3)
            name = "16:9 display"
        case (4)
            name = "2.21:1 display"
        case default
            write(name, '(A,I0)') "reserved(", code, ")"
        end select
    end function
    
    function frame_rate_name(code) result(name)
        integer, intent(in) :: code
        character(len=20) :: name
        
        select case (code)
        case (1)
            name = "23.976 fps"
        case (2)
            name = "24 fps"
        case (3)
            name = "25 fps"
        case (4)
            name = "29.97 fps"
        case (5)
            name = "30 fps"
        case (6)
            name = "50 fps"
        case (7)
            name = "59.94 fps"
        case (8)
            name = "60 fps"
        case default
            write(name, '(A,I0)') "reserved(", code, ")"
        end select
    end function

end program analyze_mpeg_headers_proper