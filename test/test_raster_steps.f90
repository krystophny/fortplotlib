program test_raster_steps
    !! Test each step of the rasterization pipeline against STB
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    use fortplot_truetype_types
    use fortplot_truetype_parser
    use fortplot_truetype_raster
    use fortplot_truetype_native
    implicit none
    
    character(len=*), parameter :: FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"
    integer, parameter :: GLYPH_CHAR = 65  ! 'A'
    real(wp), parameter :: FONT_SIZE = 24.0_wp
    
    type(native_fontinfo_t) :: font_info
    logical :: success
    integer :: glyph_index
    real(wp) :: scale
    
    ! Test data structures
    type(vertex_t), allocatable :: vertices(:)
    type(raster_point_t), allocatable :: points(:)
    integer, allocatable :: contour_lengths(:)
    integer :: num_vertices, num_points, num_contours
    
    print *, "=== RASTERIZATION STEP-BY-STEP TESTS ==="
    print *
    
    ! Initialize font
    success = native_init_font(font_info, FONT_PATH)
    if (.not. success) then
        print *, "ERROR: Failed to initialize font"
        stop 1
    end if
    
    ! Get glyph index and scale
    glyph_index = native_find_glyph_index(font_info, GLYPH_CHAR)
    scale = native_scale_for_pixel_height(font_info, FONT_SIZE)
    
    print *, "Font initialized successfully"
    print *, "Glyph index for 'A':", glyph_index
    print *, "Scale for", FONT_SIZE, "px:", scale
    print *
    
    ! STEP 1: Test glyph shape extraction
    print *, "=== STEP 1: GLYPH SHAPE EXTRACTION ==="
    call test_glyph_shape_extraction(font_info, glyph_index)
    print *
    
    ! STEP 2: Test curve flattening
    print *, "=== STEP 2: CURVE FLATTENING ==="
    call get_glyph_shape(font_info, glyph_index, vertices, num_vertices, success)
    if (success) then
        call test_curve_flattening(vertices, num_vertices)
    end if
    print *
    
    ! STEP 3: Test edge generation
    print *, "=== STEP 3: EDGE GENERATION ==="
    if (allocated(vertices)) then
        call flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, 0.35_wp)
        call test_edge_generation(points, num_points, contour_lengths, num_contours, scale)
    end if
    print *
    
    ! STEP 4: Test scanline filling
    print *, "=== STEP 4: SCANLINE FILLING ==="
    call test_scanline_filling()
    print *
    
    ! Cleanup
    if (allocated(vertices)) deallocate(vertices)
    if (allocated(points)) deallocate(points)
    if (allocated(contour_lengths)) deallocate(contour_lengths)
    
contains

    subroutine test_glyph_shape_extraction(font_info, glyph_index)
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        
        type(glyph_point_t), allocatable :: pts(:)
        integer, allocatable :: endpoints(:)
        type(vertex_t), allocatable :: vertices(:)
        integer :: npts, ncont, num_vertices, i
        integer :: dummy_xmin, dummy_ymin, dummy_xmax, dummy_ymax
        logical :: parse_ok, success
        
        ! Parse raw glyph data
        call parse_glyph_header(font_info, glyph_index, ncont, dummy_xmin, dummy_ymin, dummy_xmax, dummy_ymax)
        call parse_simple_glyph_points(font_info, glyph_index, pts, npts, parse_ok)
        call parse_simple_glyph_endpoints(font_info, glyph_index, endpoints, parse_ok)
        
        print *, "Raw glyph data:"
        print *, "  Contours:", ncont
        print *, "  Points:", npts
        print *, "  Endpoints:", endpoints
        print *, "  Bounding box: (", dummy_xmin, ",", dummy_ymin, ") to (", dummy_xmax, ",", dummy_ymax, ")"
        print *
        
        ! Show first few points
        print *, "First 10 points (x, y, flags):"
        do i = 1, min(10, npts)
            print *, "  Point", i, ":", pts(i)%x, pts(i)%y, pts(i)%flags, &
                     "(on-curve:", btest(int(pts(i)%flags), 0), ")"
        end do
        print *
        
        ! Test vertex extraction
        call get_glyph_shape(font_info, glyph_index, vertices, num_vertices, success)
        print *, "Vertex extraction:"
        print *, "  Success:", success
        print *, "  Vertices generated:", num_vertices
        print *
        
        ! Show first few vertices
        if (allocated(vertices) .and. num_vertices > 0) then
            print *, "First 10 vertices (x, y, type):"
            do i = 1, min(10, num_vertices)
                print *, "  Vertex", i, ":", vertices(i)%x, vertices(i)%y, vertices(i)%type
            end do
        end if
        
        ! Cleanup
        if (allocated(pts)) deallocate(pts)
        if (allocated(endpoints)) deallocate(endpoints)
        if (allocated(vertices)) deallocate(vertices)
        
    end subroutine test_glyph_shape_extraction

    subroutine test_curve_flattening(vertices, num_vertices)
        type(vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_vertices
        
        type(raster_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_points, num_contours, i
        integer :: line_count, quad_count
        
        print *, "Input vertices:", num_vertices
        
        ! Count different vertex types
        line_count = 0
        quad_count = 0
        do i = 1, num_vertices
            if (vertices(i)%type == CURVE_LINE) line_count = line_count + 1
            if (vertices(i)%type == CURVE_QUAD) quad_count = quad_count + 1
        end do
        print *, "  LINE vertices:", line_count
        print *, "  QUAD vertices:", quad_count
        print *
        
        ! Test flattening
        call flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, 0.35_wp)
        
        print *, "Flattening results:"
        print *, "  Points generated:", num_points
        print *, "  Contours:", num_contours
        if (allocated(contour_lengths)) then
            print *, "  Contour lengths:", contour_lengths
        end if
        print *
        
        ! Show first few points
        if (allocated(points) .and. num_points > 0) then
            print *, "First 10 flattened points (x, y):"
            do i = 1, min(10, num_points)
                print *, "  Point", i, ":", points(i)%x, points(i)%y
            end do
        end if
        
        ! Cleanup
        if (allocated(points)) deallocate(points)
        if (allocated(contour_lengths)) deallocate(contour_lengths)
        
    end subroutine test_curve_flattening

    subroutine test_edge_generation(points, num_points, contour_lengths, num_contours, scale)
        type(raster_point_t), intent(in) :: points(:)
        integer, intent(in) :: num_points, num_contours
        integer, intent(in) :: contour_lengths(:)
        real(wp), intent(in) :: scale
        
        type(raster_edge_t), allocatable :: edges(:)
        integer :: num_edges, i, j, k, a, b, point_idx
        real(wp) :: real_x1, real_y1, real_x2, real_y2
        
        print *, "Edge generation from", num_points, "points in", num_contours, "contours"
        print *, "Scale factor:", scale
        print *
        
        ! Calculate expected number of edges
        num_edges = 0
        do i = 1, num_contours
            num_edges = num_edges + contour_lengths(i)
        end do
        print *, "Expected edges:", num_edges
        
        allocate(edges(num_edges))
        
        ! Generate edges (same logic as in rasterize_points)
        num_edges = 0
        point_idx = 1
        
        do i = 1, num_contours
            print *, "Contour", i, "length:", contour_lengths(i)
            
            do j = 1, contour_lengths(i)
                k = point_idx + j - 1
                if (j == contour_lengths(i)) then
                    a = k
                    b = point_idx
                else
                    a = k
                    b = k + 1
                end if
                
                ! Transform to screen coordinates (simplified)
                real_x1 = points(a)%x * scale
                real_y1 = points(a)%y * (-scale)  ! Invert Y
                real_x2 = points(b)%x * scale
                real_y2 = points(b)%y * (-scale)
                
                ! Skip horizontal edges
                if (abs(real_y1 - real_y2) < 1.0e-6_wp) cycle
                
                num_edges = num_edges + 1
                
                if (real_y1 <= real_y2) then
                    edges(num_edges)%x0 = real_x1
                    edges(num_edges)%y0 = real_y1
                    edges(num_edges)%x1 = real_x2
                    edges(num_edges)%y1 = real_y2
                    edges(num_edges)%invert = .false.
                else
                    edges(num_edges)%x0 = real_x2
                    edges(num_edges)%y0 = real_y2
                    edges(num_edges)%x1 = real_x1
                    edges(num_edges)%y1 = real_y1
                    edges(num_edges)%invert = .true.
                end if
                
                ! Show first few edges
                if (num_edges <= 10) then
                    print *, "  Edge", num_edges, ":", &
                             "(", edges(num_edges)%x0, ",", edges(num_edges)%y0, ") to", &
                             "(", edges(num_edges)%x1, ",", edges(num_edges)%y1, ")", &
                             "invert=", edges(num_edges)%invert
                end if
            end do
            
            point_idx = point_idx + contour_lengths(i)
        end do
        
        print *, "Generated", num_edges, "actual edges"
        
        deallocate(edges)
        
    end subroutine test_edge_generation

    subroutine test_scanline_filling()
        ! Create a simple test case with known edges
        type(active_edge_t), pointer :: active => null()
        type(raster_edge_t) :: test_edge
        real(wp), allocatable :: scanline(:), scanline_fill(:)
        integer, parameter :: width = 16
        integer :: x
        real(wp) :: y_top, sum, k
        integer :: m
        
        print *, "Testing scanline filling with simple vertical edge"
        
        allocate(scanline(0:width-1))
        allocate(scanline_fill(0:width-1))
        
        ! Create a simple vertical edge at x=5, from y=0 to y=1
        test_edge%x0 = 5.0_wp
        test_edge%y0 = 0.0_wp
        test_edge%x1 = 5.0_wp
        test_edge%y1 = 1.0_wp
        test_edge%invert = .false.
        
        y_top = 0.0_wp
        
        ! Clear scanlines
        scanline = 0.0_wp
        scanline_fill = 0.0_wp
        
        ! Add edge to active list
        call add_active_edge(active, test_edge, 0, y_top)
        
        ! Fill scanline
        call fill_active_edges_stb_exact(scanline, scanline_fill, width, active, y_top)
        
        ! Show results
        print *, "Scanline results:"
        do x = 0, width - 1
            if (scanline(x) /= 0.0_wp .or. scanline_fill(x) /= 0.0_wp) then
                print *, "  x=", x, "scanline=", scanline(x), "fill=", scanline_fill(x)
            end if
        end do
        
        ! Convert to final pixel values
        sum = 0.0_wp
        print *, "Final pixel values:"
        do x = 0, width - 1
            sum = sum + scanline_fill(x)
            k = scanline(x) + sum
            
            ! STB conversion: scale and round
            k = abs(k) * 255.0_wp + 0.5_wp
            
            m = int(k)
            ! Clamp to 0-255 range
            if (m > 255) m = 255
            if (m < 0) m = 0
            
            ! Store as signed int8 (0-255 becomes signed representation)
            if (m /= 0) then
                print *, "  x=", x, "pixel=", m
            end if
        end do
        
        ! Cleanup
        call cleanup_active_edges(active)
        deallocate(scanline, scanline_fill)
        
    end subroutine test_scanline_filling

end program test_raster_steps
