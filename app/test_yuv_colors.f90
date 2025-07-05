program test_yuv_colors
    !! Test what YUV values we get for different RGB colors
    use fortplot_rgb_to_mpeg, only: yuv420_frame_t, create_yuv420_frame, destroy_yuv420_frame, bitmap_to_yuv420
    use fortplot_raster, only: raster_image_t, create_raster_image, destroy_raster_image
    use iso_c_binding
    implicit none
    
    type(raster_image_t) :: raster
    type(yuv420_frame_t) :: yuv_frame
    integer :: idx
    integer(1) :: test_val
    
    print *, "Testing YUV Color Conversion"
    print *, "============================"
    
    ! Create small test image
    raster = create_raster_image(16, 16)
    yuv_frame = create_yuv420_frame(16, 16)
    
    ! Test 1: Fill with green (0, 255, 0)
    print *, ""
    print *, "Test 1: Pure Green (0, 255, 0)"
    call fill_raster_color(raster, 0, 255, 0)
    call bitmap_to_yuv420(raster%image_data, 16, 16, yuv_frame)
    
    idx = 1
    test_val = yuv_frame%y_plane%data(idx)
    print *, "  Y value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    test_val = yuv_frame%u_plane%data(1)
    print *, "  U value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    test_val = yuv_frame%v_plane%data(1)
    print *, "  V value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    
    ! Test 2: Fill with black (0, 0, 0)
    print *, ""
    print *, "Test 2: Black (0, 0, 0)"
    call fill_raster_color(raster, 0, 0, 0)
    call bitmap_to_yuv420(raster%image_data, 16, 16, yuv_frame)
    
    test_val = yuv_frame%y_plane%data(1)
    print *, "  Y value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    test_val = yuv_frame%u_plane%data(1)
    print *, "  U value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    test_val = yuv_frame%v_plane%data(1)
    print *, "  V value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    
    ! Test 3: Fill with white (255, 255, 255)
    print *, ""
    print *, "Test 3: White (255, 255, 255)"
    call fill_raster_color(raster, 255, 255, 255)
    call bitmap_to_yuv420(raster%image_data, 16, 16, yuv_frame)
    
    test_val = yuv_frame%y_plane%data(1)
    print *, "  Y value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    test_val = yuv_frame%u_plane%data(1)
    print *, "  U value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    test_val = yuv_frame%v_plane%data(1)
    print *, "  V value:", test_val, "(signed), or", iand(int(test_val), 255), "(unsigned)"
    
    ! Cleanup
    call destroy_raster_image(raster)
    call destroy_yuv420_frame(yuv_frame)
    
    print *, ""
    print *, "Done!"
    
contains

    subroutine fill_raster_color(raster, r, g, b)
        type(raster_image_t), intent(inout) :: raster
        integer, intent(in) :: r, g, b
        integer :: x, y, idx
        
        do y = 0, raster%height - 1
            do x = 0, raster%width - 1
                idx = y * (1 + raster%width * 3) + 1 + 1 + x * 3
                
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
    end subroutine fill_raster_color

end program test_yuv_colors