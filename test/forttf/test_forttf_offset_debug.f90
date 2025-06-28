program test_forttf_offset_debug
    !! Debug the offset issue causing 0 pixels
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
    type(stb_point_t), allocatable :: points(:)
    type(stb_edge_t), allocatable :: edges(:)
    integer, allocatable :: contour_lengths(:)
    integer(c_int8_t), allocatable, target :: pixels(:)
    integer :: num_vertices, pixel_count, i, num_contours, num_edges
    
    integer, parameter :: glyph_index = 36  ! Letter 'A'
    real(wp), parameter :: scale = 0.5_wp
    real(wp), parameter :: flatness = 0.35_wp
    integer, parameter :: width = 684, height = 747
    
    write(*,*) "=== Testing offset impact on pixel count ==="
    
    if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/TTF/DejaVuSans.ttf")) then
        write(*,*) "❌ Failed to initialize font"
        stop 1
    end if
    
    num_vertices = stb_get_glyph_shape_pure(font_info, glyph_index, vertices)
    write(*,*) "Vertices:", num_vertices
    
    ! Step 2: Flatten curves to points
    points = stb_flatten_curves(vertices, num_vertices, flatness, contour_lengths, num_contours)
    write(*,*) "Flattened to", size(points), "points in", num_contours, "contours"
    
    allocate(pixels(width * height))
    
    bitmap%w = width
    bitmap%h = height  
    bitmap%stride = width
    bitmap%pixels => pixels
    
    ! Test 1: Original problematic parameters
    write(*,*) "--- Test 1: Original params (xoff=8, yoff=-747) ---"
    pixels = 0
    
    ! Step 3: Build edges with scale
    edges = stb_build_edges(points, contour_lengths, num_contours, &
                           scale, scale, 0.0_wp, 0.0_wp, .false.)
    num_edges = size(edges)
    write(*,*) "  Built", num_edges, "edges"
    
    ! Step 4: Sort edges  
    call stb_sort_edges(edges, num_edges)
    
    ! Step 5: Rasterize with offsets
    call stb_rasterize_sorted_edges(bitmap, edges, num_edges, 1, 8, -747, c_null_ptr)
    
    pixel_count = 0
    do i = 1, width * height
        if (pixels(i) /= 0) pixel_count = pixel_count + 1
    end do
    write(*,*) "  Pixel count:", pixel_count
    
    ! Test 2: Zero offsets
    write(*,*) "--- Test 2: Zero offsets (xoff=0, yoff=0) ---"
    pixels = 0
    call stb_rasterize_sorted_edges(bitmap, edges, num_edges, 1, 0, 0, c_null_ptr)
    
    pixel_count = 0
    do i = 1, width * height
        if (pixels(i) /= 0) pixel_count = pixel_count + 1
    end do
    write(*,*) "  Pixel count:", pixel_count
    
    ! Test 3: Positive yoff
    write(*,*) "--- Test 3: Positive yoff (xoff=8, yoff=100) ---"
    pixels = 0
    call stb_rasterize_sorted_edges(bitmap, edges, num_edges, 1, 8, 100, c_null_ptr)
    
    pixel_count = 0
    do i = 1, width * height
        if (pixels(i) /= 0) pixel_count = pixel_count + 1
    end do
    write(*,*) "  Pixel count:", pixel_count
    
    ! Test 4: Different canvas size
    write(*,*) "--- Test 4: Larger canvas (1000x1000) with original offsets ---"
    deallocate(pixels)
    allocate(pixels(1000 * 1000))
    pixels = 0
    
    bitmap%w = 1000
    bitmap%h = 1000
    bitmap%stride = 1000
    bitmap%pixels => pixels
    
    call stb_rasterize_sorted_edges(bitmap, edges, num_edges, 1, 8, -747, c_null_ptr)
    
    pixel_count = 0
    do i = 1, 1000 * 1000
        if (pixels(i) /= 0) pixel_count = pixel_count + 1
    end do
    write(*,*) "  Pixel count on large canvas:", pixel_count
    
    call stb_free_shape_pure(vertices)
    call stb_cleanup_font_pure(font_info)
    deallocate(pixels)

end program test_forttf_offset_debug
