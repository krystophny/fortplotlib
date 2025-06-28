program test_forttf_pixel_analysis
    !! Detailed analysis of the 270-pixel difference between Fortran and STB
    use forttf_types
    use forttf_stb_raster
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    type(stb_fontinfo_pure_t) :: font_info
    type(ttf_vertex_t), allocatable, target :: vertices(:)
    type(stb_bitmap_t) :: fortran_bitmap
    integer(c_int8_t), allocatable, target :: fortran_pixels(:)
    integer :: num_vertices, i, j, fortran_count, stb_count
    
    ! Test parameters - exact same as working exact params test
    integer, parameter :: glyph_index = 36
    real(wp), parameter :: scale = 0.5_wp
    integer, parameter :: width = 684, height = 747
    integer, parameter :: xoff = 8, yoff = -747
    real(wp), parameter :: flatness = 0.35_wp
    
    ! STB C results
    type(c_ptr) :: stb_bitmap_ptr
    integer(c_int8_t), pointer :: stb_pixels_array(:)
    
    ! C interface for exact STB comparison  
    interface
        subroutine stb_test_complete_rasterize_exact(vertices, num_verts, &
                    scale_x, scale_y, shift_x, shift_y, &
                    width, height, x_off, y_off, invert, &
                    bitmap_out, pixel_count_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: vertices
            integer(c_int), value :: num_verts, width, height, x_off, y_off, invert
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            type(c_ptr), intent(out) :: bitmap_out
            integer(c_int), intent(out) :: pixel_count_out
        end subroutine

        subroutine stb_free_bitmap(bitmap) bind(c)
            import :: c_ptr
            type(c_ptr), value :: bitmap
        end subroutine
    end interface
    
    write(*,*) "=== DETAILED PIXEL ANALYSIS ==="
    write(*,*) "Analyzing the 270-pixel difference between Fortran and STB..."
    
    if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/TTF/DejaVuSans.ttf")) then
        write(*,*) "❌ Failed to initialize font"
        stop 1
    end if
    
    num_vertices = stb_get_glyph_shape_pure(font_info, glyph_index, vertices)
    
    ! === FORTRAN RASTERIZATION ===
    allocate(fortran_pixels(width * height))
    fortran_pixels = 0
    
    fortran_bitmap%w = width
    fortran_bitmap%h = height
    fortran_bitmap%stride = width
    fortran_bitmap%pixels => fortran_pixels
    
    call stbtt_rasterize(fortran_bitmap, flatness, vertices, num_vertices, &
                        scale, scale, 0.0_wp, 0.0_wp, xoff, yoff, .false., c_null_ptr)
    
    ! === STB C RASTERIZATION ===
    call stb_test_complete_rasterize_exact(c_loc(vertices(1)), num_vertices, &
                                         real(scale, c_float), real(scale, c_float), &
                                         0.0_c_float, 0.0_c_float, &
                                         width, height, xoff, yoff, 0, &
                                         stb_bitmap_ptr, stb_count)
    
    call c_f_pointer(stb_bitmap_ptr, stb_pixels_array, [width * height])
    
    ! === DETAILED COMPARISON ===
    fortran_count = 0
    do i = 1, width * height
        if (fortran_pixels(i) /= 0) fortran_count = fortran_count + 1
    end do
    
    write(*,*) "Pixel counts:"
    write(*,*) "  Fortran:", fortran_count
    write(*,*) "  STB C:  ", stb_count
    write(*,*) "  Difference:", abs(fortran_count - stb_count)
    write(*,*)
    
    ! Find first differences
    write(*,*) "First 10 pixel differences:"
    j = 0
    do i = 1, width * height
        if (fortran_pixels(i) /= stb_pixels_array(i)) then
            j = j + 1
            write(*,'("  Position", I6, ": Fortran=", I4, " STB=", I4, " Diff=", I4)') &
                i, int(fortran_pixels(i)), int(stb_pixels_array(i)), &
                int(fortran_pixels(i)) - int(stb_pixels_array(i))
            if (j >= 10) exit
        end if
    end do
    
    ! Find positions where one has pixels and other doesn't
    write(*,*)
    write(*,*) "Positions where only one implementation has pixels:"
    j = 0
    do i = 1, width * height
        if ((fortran_pixels(i) /= 0 .and. stb_pixels_array(i) == 0) .or. &
            (fortran_pixels(i) == 0 .and. stb_pixels_array(i) /= 0)) then
            j = j + 1
            write(*,'("  Position", I6, ": Fortran=", I4, " STB=", I4)') &
                i, int(fortran_pixels(i)), int(stb_pixels_array(i))
            if (j >= 10) exit
        end if
    end do
    
    ! Cleanup
    call stb_free_bitmap(stb_bitmap_ptr)
    call stb_free_shape_pure(vertices)
    call stb_cleanup_font_pure(font_info)
    deallocate(fortran_pixels)
    
end program test_forttf_pixel_analysis
