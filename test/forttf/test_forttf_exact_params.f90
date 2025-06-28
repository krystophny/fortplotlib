program test_exact_params
    !! Test with EXACT same parameters as bitmap content test
    use forttf_types
    use forttf_stb_raster
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    type(stb_fontinfo_pure_t) :: font_info
    type(ttf_vertex_t), allocatable, target :: vertices(:)
    type(stb_bitmap_t) :: bitmap
    integer(c_int8_t), allocatable, target :: pixels(:)
    integer :: num_vertices, pixel_count, i
    
    ! EXACT parameters from bitmap content test
    integer, parameter :: glyph_index = 36  ! Letter 'A'
    real(wp), parameter :: scale = 0.5_wp
    integer, parameter :: width = 684, height = 747
    integer, parameter :: xoff = 8, yoff = -747  ! From bitmap test output
    
    write(*,*) "=== Testing with EXACT bitmap test parameters ==="
    
    if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/TTF/DejaVuSans.ttf")) then
        write(*,*) "❌ Failed to initialize font"
        stop 1
    end if
    
    num_vertices = stb_get_glyph_shape_pure(font_info, glyph_index, vertices)
    write(*,*) "Vertices:", num_vertices
    
    allocate(pixels(width * height))
    pixels = 0
    
    bitmap%w = width
    bitmap%h = height  
    bitmap%stride = width
    bitmap%pixels => pixels
    
    ! Use EXACT same parameters as bitmap content test would use internally
    call stbtt_rasterize(bitmap, 0.35_wp, vertices, num_vertices, &
                        scale, scale, 0.0_wp, 0.0_wp, xoff, yoff, .true., c_null_ptr)
    
    ! Count pixels
    pixel_count = 0
    do i = 1, width * height
        if (pixels(i) /= 0) pixel_count = pixel_count + 1
    end do
    
    write(*,*) "Pixel count with bitmap test params:", pixel_count
    write(*,*) "Expected STB pixel count: 1817"
    write(*,*) "Previous debug test result: 170,632"
    
    if (pixel_count == 1817) then
        write(*,*) "✅ EXACT MATCH!"
    else
        write(*,*) "❌ Still mismatch. Difference:", abs(pixel_count - 1817)
    end if
    
    call stb_free_shape_pure(vertices)
    call stb_cleanup_font_pure(font_info)
    deallocate(pixels)

end program test_exact_params