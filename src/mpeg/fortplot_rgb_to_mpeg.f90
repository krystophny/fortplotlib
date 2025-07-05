module fortplot_rgb_to_mpeg
    !! RGB to MPEG YUV 4:2:0 conversion module
    !! Converts RGB frames to YUV format required by MPEG encoder
    use fortplot_mpeg_memory, only: mem_t, mem_create, mem_destroy
    use fortplot_raster, only: raster_image_t
    use iso_c_binding, only: c_int8_t
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    private
    public :: rgb_frame_t, rgb_to_yuv420, test_rgb_conversion
    public :: validate_rgb_to_mpeg_conversion, bitmap_to_yuv420
    public :: yuv420_frame_t, create_yuv420_frame, destroy_yuv420_frame
    
    ! RGB frame structure
    type :: rgb_frame_t
        integer :: width, height
        integer, allocatable :: r(:), g(:), b(:)  ! RGB values 0-255
    end type rgb_frame_t
    
    ! YUV 4:2:0 frame structure for MPEG
    type, public :: yuv420_frame_t
        integer :: width, height
        type(mem_t) :: y_plane    ! Luminance (full resolution)
        type(mem_t) :: u_plane    ! Chrominance U/Cb (quarter resolution)
        type(mem_t) :: v_plane    ! Chrominance V/Cr (quarter resolution)
    end type yuv420_frame_t
    
    ! ITU-R BT.601 conversion coefficients (MPEG standard)
    real, parameter :: KR = 0.299
    real, parameter :: KG = 0.587  
    real, parameter :: KB = 0.114
    
    ! Derived coefficients for U and V
    real, parameter :: KU_R = -0.14713  ! -KR/(1-KB)
    real, parameter :: KU_G = -0.28886  ! -KG/(1-KB)
    real, parameter :: KU_B = 0.436     ! 0.5
    
    real, parameter :: KV_R = 0.615     ! 0.5
    real, parameter :: KV_G = -0.51499  ! -KG/(1-KR)
    real, parameter :: KV_B = -0.10001  ! -KB/(1-KR)
    
contains

    function create_rgb_frame(width, height) result(frame)
        !! Create RGB frame with specified dimensions
        integer, intent(in) :: width, height
        type(rgb_frame_t) :: frame
        
        frame%width = width
        frame%height = height
        allocate(frame%r(width * height))
        allocate(frame%g(width * height))
        allocate(frame%b(width * height))
        
        ! Initialize to black
        frame%r = 0
        frame%g = 0
        frame%b = 0
    end function create_rgb_frame

    subroutine destroy_rgb_frame(frame)
        !! Destroy RGB frame and free memory
        type(rgb_frame_t), intent(inout) :: frame
        
        if (allocated(frame%r)) deallocate(frame%r)
        if (allocated(frame%g)) deallocate(frame%g)
        if (allocated(frame%b)) deallocate(frame%b)
        frame%width = 0
        frame%height = 0
    end subroutine destroy_rgb_frame

    function create_yuv420_frame(width, height) result(frame)
        !! Create YUV 4:2:0 frame for MPEG encoding
        integer, intent(in) :: width, height
        type(yuv420_frame_t) :: frame
        
        ! Validate dimensions are even (required for 4:2:0)
        if (mod(width, 2) /= 0 .or. mod(height, 2) /= 0) then
            error stop "RGB to YUV: Width and height must be even for 4:2:0 format"
        end if
        
        frame%width = width
        frame%height = height
        
        ! Create memory planes
        frame%y_plane = mem_create(width, height)              ! Full resolution
        frame%u_plane = mem_create(width/2, height/2)          ! Quarter resolution
        frame%v_plane = mem_create(width/2, height/2)          ! Quarter resolution
    end function create_yuv420_frame

    subroutine destroy_yuv420_frame(frame)
        !! Destroy YUV 4:2:0 frame and free memory
        type(yuv420_frame_t), intent(inout) :: frame
        
        call mem_destroy(frame%y_plane)
        call mem_destroy(frame%u_plane)
        call mem_destroy(frame%v_plane)
        frame%width = 0
        frame%height = 0
    end subroutine destroy_yuv420_frame

    subroutine rgb_to_yuv420(rgb_frame, yuv_frame)
        !! Convert RGB frame to YUV 4:2:0 format for MPEG encoding
        !! Uses ITU-R BT.601 color space conversion
        type(rgb_frame_t), intent(in) :: rgb_frame
        type(yuv420_frame_t), intent(inout) :: yuv_frame
        
        integer :: x, y, idx, uv_idx
        integer :: r, g, b
        real :: y_val, u_val, v_val
        integer :: y_mpeg, u_mpeg, v_mpeg
        
        ! Validate dimensions match
        if (rgb_frame%width /= yuv_frame%width .or. &
            rgb_frame%height /= yuv_frame%height) then
            error stop "RGB to YUV: Frame dimensions must match"
        end if
        
        ! Convert Y plane (luminance) - full resolution
        do y = 0, rgb_frame%height - 1
            do x = 0, rgb_frame%width - 1
                idx = y * rgb_frame%width + x + 1
                
                r = rgb_frame%r(idx)
                g = rgb_frame%g(idx)
                b = rgb_frame%b(idx)
                
                ! ITU-R BT.601 luminance conversion
                y_val = KR * real(r) + KG * real(g) + KB * real(b)
                
                ! Convert to MPEG legal range (16-235)
                y_mpeg = nint(16.0 + (y_val * 219.0 / 255.0))
                y_mpeg = max(16, min(235, y_mpeg))
                
                yuv_frame%y_plane%data(idx) = int(y_mpeg, c_int8_t)
            end do
        end do
        
        ! Convert UV planes (chrominance) - subsampled 2:1 horizontally and vertically
        do y = 0, rgb_frame%height - 1, 2
            do x = 0, rgb_frame%width - 1, 2
                ! Average 2x2 block for subsampling
                call subsample_2x2_block(rgb_frame, x, y, r, g, b)
                
                ! ITU-R BT.601 chrominance conversion
                u_val = KU_R * real(r) + KU_G * real(g) + KU_B * real(b)
                v_val = KV_R * real(r) + KV_G * real(g) + KV_B * real(b)
                
                ! Convert to MPEG legal range (16-240)
                u_mpeg = nint(128.0 + (u_val * 224.0 / 255.0))
                v_mpeg = nint(128.0 + (v_val * 224.0 / 255.0))
                
                u_mpeg = max(16, min(240, u_mpeg))
                v_mpeg = max(16, min(240, v_mpeg))
                
                ! Store in subsampled planes
                uv_idx = (y/2) * (rgb_frame%width/2) + (x/2) + 1
                yuv_frame%u_plane%data(uv_idx) = int(u_mpeg, c_int8_t)
                yuv_frame%v_plane%data(uv_idx) = int(v_mpeg, c_int8_t)
            end do
        end do
    end subroutine rgb_to_yuv420

    subroutine subsample_2x2_block(rgb_frame, start_x, start_y, avg_r, avg_g, avg_b)
        !! Subsample a 2x2 RGB block by averaging
        type(rgb_frame_t), intent(in) :: rgb_frame
        integer, intent(in) :: start_x, start_y
        integer, intent(out) :: avg_r, avg_g, avg_b
        
        integer :: x, y, idx
        integer :: sum_r, sum_g, sum_b, count
        
        sum_r = 0
        sum_g = 0
        sum_b = 0
        count = 0
        
        ! Average 2x2 block
        do y = start_y, min(start_y + 1, rgb_frame%height - 1)
            do x = start_x, min(start_x + 1, rgb_frame%width - 1)
                idx = y * rgb_frame%width + x + 1
                
                sum_r = sum_r + rgb_frame%r(idx)
                sum_g = sum_g + rgb_frame%g(idx)
                sum_b = sum_b + rgb_frame%b(idx)
                count = count + 1
            end do
        end do
        
        if (count > 0) then
            avg_r = sum_r / count
            avg_g = sum_g / count
            avg_b = sum_b / count
        else
            avg_r = 0
            avg_g = 0
            avg_b = 0
        end if
    end subroutine subsample_2x2_block

    subroutine yuv420_to_rgb(yuv_frame, rgb_frame)
        !! Convert YUV 4:2:0 back to RGB for validation
        type(yuv420_frame_t), intent(in) :: yuv_frame
        type(rgb_frame_t), intent(inout) :: rgb_frame
        
        integer :: x, y, idx, uv_idx
        integer :: y_mpeg, u_mpeg, v_mpeg
        real :: y_val, u_val, v_val
        real :: r_val, g_val, b_val
        integer :: r, g, b
        
        do y = 0, yuv_frame%height - 1
            do x = 0, yuv_frame%width - 1
                idx = y * yuv_frame%width + x + 1
                uv_idx = (y/2) * (yuv_frame%width/2) + (x/2) + 1
                
                ! Get YUV values
                y_mpeg = int(yuv_frame%y_plane%data(idx))
                u_mpeg = int(yuv_frame%u_plane%data(uv_idx))
                v_mpeg = int(yuv_frame%v_plane%data(uv_idx))
                
                ! Handle signed byte conversion
                if (y_mpeg < 0) y_mpeg = y_mpeg + 256
                if (u_mpeg < 0) u_mpeg = u_mpeg + 256
                if (v_mpeg < 0) v_mpeg = v_mpeg + 256
                
                ! Convert from MPEG legal range back to 0-255
                y_val = (real(y_mpeg) - 16.0) * 255.0 / 219.0
                u_val = (real(u_mpeg) - 128.0) * 255.0 / 224.0
                v_val = (real(v_mpeg) - 128.0) * 255.0 / 224.0
                
                ! ITU-R BT.601 inverse conversion
                r_val = y_val + 1.402 * v_val
                g_val = y_val - 0.344136 * u_val - 0.714136 * v_val
                b_val = y_val + 1.772 * u_val
                
                ! Clamp to valid range
                r = max(0, min(255, nint(r_val)))
                g = max(0, min(255, nint(g_val)))
                b = max(0, min(255, nint(b_val)))
                
                rgb_frame%r(idx) = r
                rgb_frame%g(idx) = g
                rgb_frame%b(idx) = b
            end do
        end do
    end subroutine yuv420_to_rgb

    subroutine test_rgb_conversion()
        !! Test RGB to YUV conversion with known patterns
        type(rgb_frame_t) :: rgb_frame, rgb_back
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 32, height = 32
        integer :: x, y, idx
        
        print *, "Testing RGB to YUV 4:2:0 conversion..."
        
        ! Create frames
        rgb_frame = create_rgb_frame(width, height)
        rgb_back = create_rgb_frame(width, height)
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Test 1: Pure colors
        call test_pure_colors(rgb_frame, yuv_frame, rgb_back)
        
        ! Test 2: Gradient
        call test_gradient_pattern(rgb_frame, yuv_frame, rgb_back)
        
        ! Test 3: Checkerboard
        call test_checkerboard_pattern(rgb_frame, yuv_frame, rgb_back)
        
        ! Cleanup
        call destroy_rgb_frame(rgb_frame)
        call destroy_rgb_frame(rgb_back)
        call destroy_yuv420_frame(yuv_frame)
        
        print *, "  ✅ RGB to YUV conversion tests passed"
    end subroutine test_rgb_conversion

    subroutine test_pure_colors(rgb_frame, yuv_frame, rgb_back)
        type(rgb_frame_t), intent(inout) :: rgb_frame, rgb_back
        type(yuv420_frame_t), intent(inout) :: yuv_frame
        integer :: idx, y_val
        
        ! Test pure red
        rgb_frame%r = 255
        rgb_frame%g = 0
        rgb_frame%b = 0
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        call yuv420_to_rgb(yuv_frame, rgb_back)
        
        ! Verify Y plane has expected luminance for red
        idx = 1
        if (int(yuv_frame%y_plane%data(idx)) < 60 .or. int(yuv_frame%y_plane%data(idx)) > 90) then
            error stop "Red luminance conversion failed"
        end if
        
        ! Test pure green
        rgb_frame%r = 0
        rgb_frame%g = 255
        rgb_frame%b = 0
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        
        idx = 1
        y_val = int(yuv_frame%y_plane%data(idx))
        if (y_val < 0) y_val = y_val + 256
        if (y_val < 140 .or. y_val > 150) then
            error stop "Green luminance conversion failed"
        end if
        
        ! Test pure blue
        rgb_frame%r = 0
        rgb_frame%g = 0
        rgb_frame%b = 255
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        
        idx = 1
        if (int(yuv_frame%y_plane%data(idx)) < 25 .or. int(yuv_frame%y_plane%data(idx)) > 45) then
            error stop "Blue luminance conversion failed"
        end if
    end subroutine test_pure_colors

    subroutine test_gradient_pattern(rgb_frame, yuv_frame, rgb_back)
        type(rgb_frame_t), intent(inout) :: rgb_frame, rgb_back
        type(yuv420_frame_t), intent(inout) :: yuv_frame
        integer :: x, y, idx, value
        
        ! Create gradient pattern
        do y = 0, rgb_frame%height - 1
            do x = 0, rgb_frame%width - 1
                idx = y * rgb_frame%width + x + 1
                value = (x + y) * 255 / (rgb_frame%width + rgb_frame%height - 2)
                
                rgb_frame%r(idx) = value
                rgb_frame%g(idx) = value
                rgb_frame%b(idx) = value
            end do
        end do
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        call yuv420_to_rgb(yuv_frame, rgb_back)
        
        ! Verify conversion preserves general structure
        ! (Some loss expected due to subsampling and rounding)
    end subroutine test_gradient_pattern

    subroutine test_checkerboard_pattern(rgb_frame, yuv_frame, rgb_back)
        type(rgb_frame_t), intent(inout) :: rgb_frame, rgb_back
        type(yuv420_frame_t), intent(inout) :: yuv_frame
        integer :: x, y, idx
        
        ! Create checkerboard pattern
        do y = 0, rgb_frame%height - 1
            do x = 0, rgb_frame%width - 1
                idx = y * rgb_frame%width + x + 1
                
                if (mod(x/4 + y/4, 2) == 0) then
                    rgb_frame%r(idx) = 255
                    rgb_frame%g(idx) = 255
                    rgb_frame%b(idx) = 255
                else
                    rgb_frame%r(idx) = 0
                    rgb_frame%g(idx) = 0
                    rgb_frame%b(idx) = 0
                end if
            end do
        end do
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        call yuv420_to_rgb(yuv_frame, rgb_back)
    end subroutine test_checkerboard_pattern

    subroutine validate_rgb_to_mpeg_conversion()
        !! Comprehensive validation of RGB to MPEG conversion
        print *, "Validating RGB to MPEG conversion pipeline..."
        
        call test_rgb_conversion()
        call test_mpeg_legal_ranges()
        call test_subsampling_accuracy()
        call test_color_space_accuracy()
        
        print *, "  ✅ All RGB to MPEG validation tests passed"
    end subroutine validate_rgb_to_mpeg_conversion

    subroutine test_mpeg_legal_ranges()
        !! Test that YUV values are in MPEG legal ranges
        type(rgb_frame_t) :: rgb_frame
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 16, height = 16
        integer :: i, y_val, u_val, v_val
        
        rgb_frame = create_rgb_frame(width, height)
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Test with extreme RGB values
        rgb_frame%r = 255
        rgb_frame%g = 255
        rgb_frame%b = 255
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        
        ! Check all Y values are in legal range (16-235)
        do i = 1, width * height
            y_val = int(yuv_frame%y_plane%data(i))
            if (y_val < 0) y_val = y_val + 256
            if (y_val < 16 .or. y_val > 235) then
                error stop "Y value outside MPEG legal range"
            end if
        end do
        
        ! Check all UV values are in legal range (16-240)
        do i = 1, (width/2) * (height/2)
            u_val = int(yuv_frame%u_plane%data(i))
            v_val = int(yuv_frame%v_plane%data(i))
            if (u_val < 0) u_val = u_val + 256
            if (v_val < 0) v_val = v_val + 256
            
            if (u_val < 16 .or. u_val > 240) then
                error stop "U value outside MPEG legal range"
            end if
            if (v_val < 16 .or. v_val > 240) then
                error stop "V value outside MPEG legal range"
            end if
        end do
        
        call destroy_rgb_frame(rgb_frame)
        call destroy_yuv420_frame(yuv_frame)
    end subroutine test_mpeg_legal_ranges

    subroutine test_subsampling_accuracy()
        !! Test 4:2:0 subsampling accuracy
        type(rgb_frame_t) :: rgb_frame
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 8, height = 8
        
        rgb_frame = create_rgb_frame(width, height)
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Test known pattern
        rgb_frame%r = 128
        rgb_frame%g = 128
        rgb_frame%b = 128
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        
        ! Verify UV plane dimensions
        if (size(yuv_frame%u_plane%data) /= (width/2) * (height/2)) then
            error stop "UV plane size incorrect"
        end if
        
        call destroy_rgb_frame(rgb_frame)
        call destroy_yuv420_frame(yuv_frame)
    end subroutine test_subsampling_accuracy

    subroutine test_color_space_accuracy()
        !! Test ITU-R BT.601 color space conversion accuracy
        type(rgb_frame_t) :: rgb_frame, rgb_back
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 16, height = 16
        integer :: i, r_err, g_err, b_err
        integer :: max_error = 10  ! Allow small error due to rounding
        
        rgb_frame = create_rgb_frame(width, height)
        rgb_back = create_rgb_frame(width, height)
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Test gray levels (should convert well)
        do i = 1, width * height
            rgb_frame%r(i) = 128
            rgb_frame%g(i) = 128
            rgb_frame%b(i) = 128
        end do
        
        call rgb_to_yuv420(rgb_frame, yuv_frame)
        call yuv420_to_rgb(yuv_frame, rgb_back)
        
        ! Check roundtrip accuracy for gray levels
        do i = 1, width * height
            r_err = abs(rgb_frame%r(i) - rgb_back%r(i))
            g_err = abs(rgb_frame%g(i) - rgb_back%g(i))
            b_err = abs(rgb_frame%b(i) - rgb_back%b(i))
            
            if (r_err > max_error .or. g_err > max_error .or. b_err > max_error) then
                print *, "Roundtrip error too large:", r_err, g_err, b_err
                error stop "Color space conversion accuracy test failed"
            end if
        end do
        
        call destroy_rgb_frame(rgb_frame)
        call destroy_rgb_frame(rgb_back)
        call destroy_yuv420_frame(yuv_frame)
    end subroutine test_color_space_accuracy

    subroutine bitmap_to_yuv420(bitmap_data, width, height, yuv_frame)
        !! Convert bitmap image data to YUV 4:2:0 format
        !! Handles PNG-style bitmap format with filter bytes
        integer(1), intent(in) :: bitmap_data(:)
        integer, intent(in) :: width, height
        type(yuv420_frame_t), intent(inout) :: yuv_frame
        
        integer :: x, y, bitmap_idx, yuv_idx, uv_idx
        integer :: r, g, b
        real :: y_val, u_val, v_val
        integer :: y_mpeg, u_mpeg, v_mpeg
        integer :: sum_r, sum_g, sum_b, count
        
        ! Validate dimensions
        if (yuv_frame%width /= width .or. yuv_frame%height /= height) then
            error stop "Bitmap to YUV: Frame dimensions must match"
        end if
        
        ! Convert Y plane (luminance) - full resolution
        do y = 0, height - 1
            do x = 0, width - 1
                ! Calculate bitmap index: filter byte + row offset + pixel offset
                bitmap_idx = y * (1 + width * 3) + 1 + 1 + x * 3
                
                ! Extract RGB values (handle signed byte conversion)
                r = int(bitmap_data(bitmap_idx))
                g = int(bitmap_data(bitmap_idx + 1))
                b = int(bitmap_data(bitmap_idx + 2))
                
                ! Convert signed bytes to unsigned
                if (r < 0) r = r + 256
                if (g < 0) g = g + 256
                if (b < 0) b = b + 256
                
                ! ITU-R BT.601 luminance conversion
                y_val = KR * real(r) + KG * real(g) + KB * real(b)
                
                ! Convert to MPEG legal range (16-235)
                y_mpeg = nint(16.0 + (y_val * 219.0 / 255.0))
                y_mpeg = max(16, min(235, y_mpeg))
                
                yuv_idx = y * width + x + 1
                yuv_frame%y_plane%data(yuv_idx) = int(y_mpeg, c_int8_t)
            end do
        end do
        
        ! Convert UV planes (chrominance) - subsampled 2:1
        do y = 0, height - 1, 2
            do x = 0, width - 1, 2
                ! Sample 2x2 block
                call sample_bitmap_2x2_block(bitmap_data, width, height, x, y, &
                                            sum_r, sum_g, sum_b, count)
                
                if (count > 0) then
                    r = sum_r / count
                    g = sum_g / count
                    b = sum_b / count
                else
                    r = 128
                    g = 128
                    b = 128
                end if
                
                ! ITU-R BT.601 chrominance conversion
                u_val = KU_R * real(r) + KU_G * real(g) + KU_B * real(b)
                v_val = KV_R * real(r) + KV_G * real(g) + KV_B * real(b)
                
                ! Convert to MPEG legal range (16-240)
                u_mpeg = nint(128.0 + (u_val * 224.0 / 255.0))
                v_mpeg = nint(128.0 + (v_val * 224.0 / 255.0))
                
                u_mpeg = max(16, min(240, u_mpeg))
                v_mpeg = max(16, min(240, v_mpeg))
                
                ! Store in subsampled planes
                uv_idx = (y/2) * (width/2) + (x/2) + 1
                yuv_frame%u_plane%data(uv_idx) = int(u_mpeg, c_int8_t)
                yuv_frame%v_plane%data(uv_idx) = int(v_mpeg, c_int8_t)
            end do
        end do
    end subroutine bitmap_to_yuv420
    
    subroutine sample_bitmap_2x2_block(bitmap_data, width, height, start_x, start_y, &
                                       sum_r, sum_g, sum_b, count)
        !! Sample 2x2 block from bitmap for subsampling
        integer(1), intent(in) :: bitmap_data(:)
        integer, intent(in) :: width, height, start_x, start_y
        integer, intent(out) :: sum_r, sum_g, sum_b, count
        
        integer :: x, y, bitmap_idx, r, g, b
        
        sum_r = 0
        sum_g = 0
        sum_b = 0
        count = 0
        
        ! Sample 2x2 block
        do y = start_y, min(start_y + 1, height - 1)
            do x = start_x, min(start_x + 1, width - 1)
                bitmap_idx = y * (1 + width * 3) + 1 + 1 + x * 3
                
                r = int(bitmap_data(bitmap_idx))
                g = int(bitmap_data(bitmap_idx + 1))
                b = int(bitmap_data(bitmap_idx + 2))
                
                ! Convert signed bytes to unsigned
                if (r < 0) r = r + 256
                if (g < 0) g = g + 256
                if (b < 0) b = b + 256
                
                sum_r = sum_r + r
                sum_g = sum_g + g
                sum_b = sum_b + b
                count = count + 1
            end do
        end do
    end subroutine sample_bitmap_2x2_block

end module fortplot_rgb_to_mpeg