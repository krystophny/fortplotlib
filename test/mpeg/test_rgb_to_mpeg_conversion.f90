program test_rgb_to_mpeg_conversion
    use fortplot_rgb_to_mpeg
    use fortplot_raster, only: create_raster_image, destroy_raster_image, raster_image_t
    use fortplot_mpeg_memory, only: mem_t
    use iso_c_binding, only: c_int8_t
    implicit none
    
    ! Test comprehensive RGB to MPEG conversion pipeline
    call test_basic_rgb_conversion()
    call test_bitmap_to_yuv_conversion()
    call test_mpeg_legal_range_validation()
    call test_color_accuracy()
    call test_subsampling_quality()
    
    print *, "PASS: All RGB to MPEG conversion tests passed"
    
contains

    subroutine test_basic_rgb_conversion()
        ! Test basic RGB to YUV conversion functionality
        print *, "Testing basic RGB to YUV conversion..."
        
        call validate_rgb_to_mpeg_conversion()
        
        print *, "  ✅ Basic RGB conversion validated"
    end subroutine

    subroutine test_bitmap_to_yuv_conversion()
        ! Test bitmap format to YUV conversion
        type(raster_image_t) :: raster
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 32, height = 32
        integer :: x, y, idx, r, g, b
        
        print *, "Testing bitmap to YUV conversion..."
        
        ! Create test bitmap
        raster = create_raster_image(width, height)
        
        ! Create test pattern - gradient
        do y = 0, height - 1
            do x = 0, width - 1
                ! Calculate bitmap index accounting for filter bytes
                idx = y * (1 + width * 3) + 1 + 1 + x * 3
                
                ! Create gradient pattern
                r = (x * 255) / (width - 1)
                g = (y * 255) / (height - 1)
                b = ((x + y) * 255) / (width + height - 2)
                
                ! Store as signed bytes (PNG format)
                if (r > 127) then
                    raster%image_data(idx) = int(r - 256, c_int8_t)
                else
                    raster%image_data(idx) = int(r, c_int8_t)
                end if
                
                if (g > 127) then
                    raster%image_data(idx + 1) = int(g - 256, c_int8_t)
                else
                    raster%image_data(idx + 1) = int(g, c_int8_t)
                end if
                
                if (b > 127) then
                    raster%image_data(idx + 2) = int(b - 256, c_int8_t)
                else
                    raster%image_data(idx + 2) = int(b, c_int8_t)
                end if
            end do
        end do
        
        ! Create YUV frame
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Convert bitmap to YUV
        call bitmap_to_yuv420(raster%image_data, width, height, yuv_frame)
        
        ! Validate conversion
        call validate_yuv_frame(yuv_frame)
        
        ! Cleanup
        call destroy_raster_image(raster)
        call destroy_yuv420_frame(yuv_frame)
        
        print *, "  ✅ Bitmap to YUV conversion validated"
    end subroutine

    subroutine test_mpeg_legal_range_validation()
        ! Test that all YUV values are in MPEG legal ranges
        type(raster_image_t) :: raster
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 16, height = 16
        integer :: i, y_val, u_val, v_val
        
        print *, "Testing MPEG legal range validation..."
        
        ! Create test bitmap with extreme values
        raster = create_raster_image(width, height)
        
        ! Fill with white (maximum values)
        raster%image_data = -1_c_int8_t  ! 255 as signed byte
        
        yuv_frame = create_yuv420_frame(width, height)
        call bitmap_to_yuv420(raster%image_data, width, height, yuv_frame)
        
        ! Check Y values (16-235)
        do i = 1, width * height
            y_val = int(yuv_frame%y_plane%data(i))
            if (y_val < 0) y_val = y_val + 256
            if (y_val < 16 .or. y_val > 235) then
                print *, "Y value out of range:", y_val
                error stop "Y value outside MPEG legal range"
            end if
        end do
        
        ! Check UV values (16-240)
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
        
        call destroy_raster_image(raster)
        call destroy_yuv420_frame(yuv_frame)
        
        print *, "  ✅ MPEG legal ranges validated"
    end subroutine

    subroutine test_color_accuracy()
        ! Test color conversion accuracy with known RGB values
        type(raster_image_t) :: raster
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 8, height = 8
        integer :: idx, y_val
        
        print *, "Testing color conversion accuracy..."
        
        raster = create_raster_image(width, height)
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Test pure red (255, 0, 0)
        call set_bitmap_color(raster, width, height, 255, 0, 0)
        call bitmap_to_yuv420(raster%image_data, width, height, yuv_frame)
        
        idx = 1
        y_val = int(yuv_frame%y_plane%data(idx))
        if (y_val < 0) y_val = y_val + 256
        
        ! Red should give Y ≈ 76 (MPEG range: ~70-85)
        if (y_val < 60 .or. y_val > 90) then
            print *, "Red Y value unexpected:", y_val
            error stop "Red conversion accuracy failed"
        end if
        
        ! Test pure green (0, 255, 0)
        call set_bitmap_color(raster, width, height, 0, 255, 0)
        call bitmap_to_yuv420(raster%image_data, width, height, yuv_frame)
        
        y_val = int(yuv_frame%y_plane%data(idx))
        if (y_val < 0) y_val = y_val + 256
        
        ! Green should give Y ≈ 145 (MPEG range: ~140-150)
        if (y_val < 140 .or. y_val > 150) then
            print *, "Green Y value unexpected:", y_val
            error stop "Green conversion accuracy failed"
        end if
        
        call destroy_raster_image(raster)
        call destroy_yuv420_frame(yuv_frame)
        
        print *, "  ✅ Color conversion accuracy validated"
    end subroutine

    subroutine test_subsampling_quality()
        ! Test 4:2:0 subsampling quality
        type(raster_image_t) :: raster
        type(yuv420_frame_t) :: yuv_frame
        integer, parameter :: width = 16, height = 16
        
        print *, "Testing 4:2:0 subsampling quality..."
        
        raster = create_raster_image(width, height)
        yuv_frame = create_yuv420_frame(width, height)
        
        ! Create checkerboard pattern to test subsampling
        call create_checkerboard_bitmap(raster, width, height)
        call bitmap_to_yuv420(raster%image_data, width, height, yuv_frame)
        
        ! Verify UV planes are quarter resolution
        if (size(yuv_frame%u_plane%data) /= (width/2) * (height/2)) then
            error stop "UV plane size incorrect"
        end if
        
        if (size(yuv_frame%v_plane%data) /= (width/2) * (height/2)) then
            error stop "UV plane size incorrect"
        end if
        
        call destroy_raster_image(raster)
        call destroy_yuv420_frame(yuv_frame)
        
        print *, "  ✅ Subsampling quality validated"
    end subroutine

    ! Helper subroutines

    subroutine validate_yuv_frame(yuv_frame)
        type(yuv420_frame_t), intent(in) :: yuv_frame
        integer :: i, val
        
        ! Check Y plane values
        do i = 1, size(yuv_frame%y_plane%data)
            val = int(yuv_frame%y_plane%data(i))
            if (val < 0) val = val + 256
            if (val < 16 .or. val > 235) then
                error stop "Y plane validation failed"
            end if
        end do
        
        ! Check U plane values
        do i = 1, size(yuv_frame%u_plane%data)
            val = int(yuv_frame%u_plane%data(i))
            if (val < 0) val = val + 256
            if (val < 16 .or. val > 240) then
                error stop "U plane validation failed"
            end if
        end do
        
        ! Check V plane values
        do i = 1, size(yuv_frame%v_plane%data)
            val = int(yuv_frame%v_plane%data(i))
            if (val < 0) val = val + 256
            if (val < 16 .or. val > 240) then
                error stop "V plane validation failed"
            end if
        end do
    end subroutine validate_yuv_frame

    subroutine set_bitmap_color(raster, width, height, r, g, b)
        type(raster_image_t), intent(inout) :: raster
        integer, intent(in) :: width, height, r, g, b
        integer :: x, y, idx
        
        do y = 0, height - 1
            do x = 0, width - 1
                idx = y * (1 + width * 3) + 1 + 1 + x * 3
                
                ! Convert to signed bytes
                if (r > 127) then
                    raster%image_data(idx) = int(r - 256, c_int8_t)
                else
                    raster%image_data(idx) = int(r, c_int8_t)
                end if
                
                if (g > 127) then
                    raster%image_data(idx + 1) = int(g - 256, c_int8_t)
                else
                    raster%image_data(idx + 1) = int(g, c_int8_t)
                end if
                
                if (b > 127) then
                    raster%image_data(idx + 2) = int(b - 256, c_int8_t)
                else
                    raster%image_data(idx + 2) = int(b, c_int8_t)
                end if
            end do
        end do
    end subroutine set_bitmap_color

    subroutine create_checkerboard_bitmap(raster, width, height)
        type(raster_image_t), intent(inout) :: raster
        integer, intent(in) :: width, height
        integer :: x, y, r, g, b
        
        do y = 0, height - 1
            do x = 0, width - 1
                if (mod(x/2 + y/2, 2) == 0) then
                    r = 255; g = 255; b = 255  ! White
                else
                    r = 0; g = 0; b = 0        ! Black
                end if
                
                call set_bitmap_pixel(raster, width, x, y, r, g, b)
            end do
        end do
    end subroutine create_checkerboard_bitmap

    subroutine set_bitmap_pixel(raster, width, x, y, r, g, b)
        type(raster_image_t), intent(inout) :: raster
        integer, intent(in) :: width, x, y, r, g, b
        integer :: idx
        
        idx = y * (1 + width * 3) + 1 + 1 + x * 3
        
        if (r > 127) then
            raster%image_data(idx) = int(r - 256, c_int8_t)
        else
            raster%image_data(idx) = int(r, c_int8_t)
        end if
        
        if (g > 127) then
            raster%image_data(idx + 1) = int(g - 256, c_int8_t)
        else
            raster%image_data(idx + 1) = int(g, c_int8_t)
        end if
        
        if (b > 127) then
            raster%image_data(idx + 2) = int(b - 256, c_int8_t)
        else
            raster%image_data(idx + 2) = int(b, c_int8_t)
        end if
    end subroutine set_bitmap_pixel

end program test_rgb_to_mpeg_conversion