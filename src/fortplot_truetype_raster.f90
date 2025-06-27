module fortplot_truetype_raster
    !! Glyph rasterization using scanline algorithm for TrueType outlines
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    use fortplot_truetype_types, only: native_fontinfo_t, vertex_t, glyph_point_t, CURVE_LINE, CURVE_QUAD
    use fortplot_truetype_parser, only: parse_glyph_header, parse_simple_glyph_points, parse_simple_glyph_endpoints
    implicit none

    private
    public :: rasterize_glyph_outline_to_buffer, rasterize_glyph_outline, rasterize_glyph_outline_with_offset, rasterize_glyph_outline_to_buffer_with_offset

    type :: raster_edge_t
        real(wp) :: x0, y0, x1, y1
        logical :: invert
    end type raster_edge_t

    type :: active_edge_t
        real(wp) :: fx, fdx, fdy
        real(wp) :: direction
        real(wp) :: sy, ey
        type(active_edge_t), pointer :: next => null()
    end type active_edge_t

    type :: raster_point_t
        real(wp) :: x, y
    end type raster_point_t

    type :: bitmap_t
        integer(int8), pointer :: pixels(:) => null()
        integer :: w, h, stride
    end type bitmap_t

contains

    subroutine rasterize_glyph_outline(font_info, bitmap, width, height, glyph_index, scale_x, scale_y)
        !! Rasterize a glyph outline to a bitmap
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height, glyph_index
        real(wp), intent(in) :: scale_x, scale_y

        call rasterize_glyph_outline_to_buffer(font_info, bitmap, width, height, width, glyph_index, scale_x, scale_y)
    end subroutine rasterize_glyph_outline

    subroutine rasterize_glyph_outline_with_offset(font_info, bitmap, width, height, glyph_index, scale_x, scale_y, x_off, y_off)
        !! Rasterize a glyph outline to a bitmap with STB-matching offsets
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout) :: bitmap(:)
        integer, intent(in) :: width, height, glyph_index, x_off, y_off
        real(wp), intent(in) :: scale_x, scale_y

        call rasterize_glyph_outline_to_buffer_with_offset(font_info, bitmap, width, height, width, glyph_index, scale_x, scale_y, x_off, y_off)
    end subroutine rasterize_glyph_outline_with_offset

    subroutine rasterize_glyph_outline_to_buffer(font_info, buffer, width, height, stride, glyph_index, scale_x, scale_y)
        !! Rasterize a glyph outline to a strided buffer
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout), target :: buffer(*)
        integer, intent(in) :: width, height, stride, glyph_index
        real(wp), intent(in) :: scale_x, scale_y

        type(vertex_t), allocatable :: vertices(:)
        type(raster_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_vertices, num_points, num_contours
        type(bitmap_t) :: bmp
        logical :: success

        call clear_buffer(buffer, width, height, stride)

        call get_glyph_shape(font_info, glyph_index, vertices, num_vertices, success)
        if (.not. success .or. num_vertices == 0) then
            print *, "DEBUG: get_glyph_shape failed, success=", success, "num_vertices=", num_vertices
            return
        end if

        print *, "DEBUG: Got", num_vertices, "vertices from glyph shape"

        call flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, 0.35_wp)
        if (num_points == 0) then
            print *, "DEBUG: flatten_curves produced 0 points"
            if (allocated(vertices)) deallocate(vertices)
            return
        end if

        print *, "DEBUG: Flattened to", num_points, "points,", num_contours, "contours"

        bmp%w = width
        bmp%h = height
        bmp%stride = stride
        bmp%pixels => buffer(1:stride*height)

        call rasterize_points(bmp, points, num_points, contour_lengths, num_contours, &
                              scale_x, scale_y, 0.0_wp, 0.0_wp, 0, 0, .false.)

        if (allocated(vertices)) deallocate(vertices)
        if (allocated(points)) deallocate(points)
        if (allocated(contour_lengths)) deallocate(contour_lengths)

    end subroutine rasterize_glyph_outline_to_buffer

    subroutine rasterize_glyph_outline_to_buffer_with_offset(font_info, buffer, width, height, stride, glyph_index, scale_x, scale_y, x_off, y_off)
        !! Rasterize a glyph outline to a strided buffer with STB-matching offsets
        type(native_fontinfo_t), intent(in) :: font_info
        integer(int8), intent(inout), target :: buffer(*)
        integer, intent(in) :: width, height, stride, glyph_index, x_off, y_off
        real(wp), intent(in) :: scale_x, scale_y

        type(vertex_t), allocatable :: vertices(:)
        type(raster_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_vertices, num_points, num_contours
        type(bitmap_t) :: bmp
        logical :: success

        call clear_buffer(buffer, width, height, stride)

        call get_glyph_shape(font_info, glyph_index, vertices, num_vertices, success)
        if (.not. success .or. num_vertices == 0) then
            print *, "DEBUG: get_glyph_shape(offset) failed, success=", success, "num_vertices=", num_vertices
            return
        end if

        print *, "DEBUG: Got", num_vertices, "vertices from glyph shape (offset)"

        call flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, 0.35_wp)
        if (num_points == 0) then
            print *, "DEBUG: flatten_curves(offset) produced 0 points"
            if (allocated(vertices)) deallocate(vertices)
            return
        end if

        print *, "DEBUG: Flattened to", num_points, "points,", num_contours, "contours (offset)"

        bmp%w = width
        bmp%h = height
        bmp%stride = stride
        bmp%pixels => buffer(1:stride*height)

        ! Pass offsets to rasterize_points - this is the key STB matching change
        call rasterize_points(bmp, points, num_points, contour_lengths, num_contours, &
                              scale_x, scale_y, 0.0_wp, 0.0_wp, x_off, y_off, .true.)

        print *, "DEBUG: Rasterization complete (offset)"

        if (allocated(vertices)) deallocate(vertices)
        if (allocated(points)) deallocate(points)
        if (allocated(contour_lengths)) deallocate(contour_lengths)

    end subroutine rasterize_glyph_outline_to_buffer_with_offset

    subroutine clear_buffer(buffer, width, height, stride)
        !! Clear the raster buffer
        integer(int8), intent(inout) :: buffer(*)
        integer, intent(in) :: width, height, stride
        integer :: y, idx

        do y = 0, height - 1
            do idx = y * stride + 1, y * stride + width
                buffer(idx) = 0_int8
            end do
        end do
    end subroutine clear_buffer

    subroutine get_glyph_shape(font_info, glyph_index, vertices, num_vertices, success)
        !! Extract glyph shape as vertex array (STB-style on/off-curve logic)
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        type(vertex_t), allocatable, intent(out) :: vertices(:)
        integer, intent(out) :: num_vertices
        logical, intent(out) :: success

        type(glyph_point_t), allocatable :: pts(:)
        integer, allocatable :: endpoints(:)
        integer :: npts, ncont, start, endp, i, j, maxv
        integer :: prev_i, next_i, do_i
        integer :: dummy_xmin, dummy_ymin, dummy_xmax, dummy_ymax
        type(vertex_t), allocatable :: tmp(:)
        logical :: parse_ok
        real(wp) :: midx, midy

        success = .false.
        num_vertices = 0

        ! Load raw points and contour endpoints
        call parse_glyph_header(font_info, glyph_index, ncont, dummy_xmin, dummy_ymin, dummy_xmax, dummy_ymax)
        if (ncont < 0) return
        call parse_simple_glyph_points(font_info, glyph_index, pts, npts, parse_ok)
        if (.not. parse_ok .or. npts == 0) return
        call parse_simple_glyph_endpoints(font_info, glyph_index, endpoints, parse_ok)
        if (.not. parse_ok) then; deallocate(pts); return; end if

        ! Rough max vertices: 3*npts
        maxv = npts * 3
        allocate(vertices(maxv))
        j = 1

        ! Walk each contour
        start = 1
        do i = 1, size(endpoints)
            endp = endpoints(i) + 1
            ! Remove placeholder loop
            ! Determine prev_i and next_i per point
            do do_i = start, endp
                if (do_i == start) then
                    prev_i = endp
                else
                    prev_i = do_i - 1
                end if
                if (do_i == endp) then
                    next_i = start
                else
                    next_i = do_i + 1
                end if
                ! On-curve
                if (btest(int(pts(do_i)%flags), 0)) then
                    vertices(j)%x = real(pts(do_i)%x, wp)
                    vertices(j)%y = real(pts(do_i)%y, wp)
                    vertices(j)%type = CURVE_LINE
                    j = j + 1
                else
                    ! off-curve quad, expect on-curve prev and next
                    if (btest(int(pts(prev_i)%flags),0) .and. btest(int(pts(next_i)%flags),0)) then
                        ! implicit quad prev->off->next
                        vertices(j)%x = real(pts(prev_i)%x, wp)
                        vertices(j)%y = real(pts(prev_i)%y, wp)
                        vertices(j)%type = CURVE_LINE; j = j+1
                        vertices(j)%x = real(pts(do_i)%x, wp)
                        vertices(j)%y = real(pts(do_i)%y, wp)
                        vertices(j)%type = CURVE_QUAD; j = j+1
                        vertices(j)%x = real(pts(next_i)%x, wp)
                        vertices(j)%y = real(pts(next_i)%y, wp)
                        vertices(j)%type = CURVE_LINE; j = j+1
                    else
                        ! two off-curves: insert midpoint
                        midx = (pts(do_i)%x + pts(next_i)%x) * 0.5_wp
                        midy = (pts(do_i)%y + pts(next_i)%y) * 0.5_wp
                        vertices(j)%x = real(pts(do_i)%x, wp)
                        vertices(j)%y = real(pts(do_i)%y, wp)
                        vertices(j)%type = CURVE_QUAD; j=j+1
                        vertices(j)%x = midx
                        vertices(j)%y = midy
                        vertices(j)%type = CURVE_LINE; j=j+1
                    end if
                end if
            end do
            start = endp + 1
        end do

        num_vertices = j - 1
        if (num_vertices < maxv) then
            ! shrink vertices to actual size
            allocate(tmp(num_vertices))
            tmp = vertices(1:num_vertices)
            deallocate(vertices)
            allocate(vertices(num_vertices))
            vertices = tmp
            deallocate(tmp)
        end if

        success = .true.
        deallocate(pts, endpoints)
    end subroutine get_glyph_shape

    subroutine flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, flatness)
        !! Flatten curved vertices to line segments with quadratic support
        type(vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_vertices
        type(raster_point_t), allocatable, intent(out) :: points(:)
        integer, intent(out) :: num_points
        integer, allocatable, intent(out) :: contour_lengths(:)
        integer, intent(out) :: num_contours
        real(wp), intent(in) :: flatness

        integer :: i, pcount, max_estimate
        type(raster_point_t), allocatable :: old_points(:)

        if (num_vertices == 0) then
            num_points = 0
            num_contours = 0
            return
        end if

        ! Single contour for now
        num_contours = 1
        allocate(contour_lengths(1))

        ! Rough estimate: each vertex may generate up to flat segments
        max_estimate = num_vertices * 4
        allocate(old_points(max_estimate))

        ! Start collecting points
        pcount = 1
        old_points(pcount)%x = vertices(1)%x
        old_points(pcount)%y = vertices(1)%y

        do i = 2, num_vertices
            if (vertices(i)%type == CURVE_LINE) then
                pcount = pcount + 1
                old_points(pcount)%x = vertices(i)%x
                old_points(pcount)%y = vertices(i)%y
            else if (vertices(i)%type == CURVE_QUAD) then
                call subdivide_quad(vertices(i-1), vertices(i), vertices(i+1), flatness, old_points, pcount)
            end if
        end do

        ! Allocate output and copy
        num_points = pcount
        allocate(points(num_points))
        points = old_points(1:num_points)
        contour_lengths(1) = num_points

        ! Clean up
        deallocate(old_points)

    end subroutine flatten_curves

    recursive subroutine subdivide_quad(p0, p1, p2, flatness, pts, pcount)
        type(vertex_t), intent(in) :: p0, p1, p2
        real(wp), intent(in) :: flatness
        type(raster_point_t), allocatable, intent(inout) :: pts(:)
        integer, intent(inout) :: pcount
        real(wp) :: midx1, midy1, midx2, midy2, midx, midy, dx, dy

        ! Midpoints
        midx1 = (p0%x + p1%x)/2
        midy1 = (p0%y + p1%y)/2
        midx2 = (p1%x + p2%x)/2
        midy2 = (p1%y + p2%y)/2
        midx  = (midx1 + midx2)/2
        midy  = (midy1 + midy2)/2
        ! Flatness test (distance from p1 to midpoint)
        dx = p1%x - midx
        dy = p1%y - midy
        if (dx*dx + dy*dy < flatness*flatness) then
            pcount = pcount + 1
            pts(pcount)%x = p2%x
            pts(pcount)%y = p2%y
        else
            ! Subdivide first half
            call subdivide_quad(p0, vertex_t(midx1,midy1,0.0_wp,0.0_wp,CURVE_QUAD), &
                                vertex_t(midx,midy,0.0_wp,0.0_wp,CURVE_QUAD), flatness, pts, pcount)
            ! Subdivide second half
            call subdivide_quad(vertex_t(midx,midy,0.0_wp,0.0_wp,CURVE_QUAD), &
                                vertex_t(midx2,midy2,0.0_wp,0.0_wp,CURVE_QUAD), p2, flatness, pts, pcount)
        end if
    end subroutine subdivide_quad

    subroutine rasterize_points(bmp, points, num_points, contour_lengths, num_contours, &
                                scale_x, scale_y, shift_x, shift_y, off_x, off_y, invert)
        !! Rasterize flattened points to bitmap
        type(bitmap_t), intent(inout) :: bmp
        type(raster_point_t), intent(in) :: points(:)
        integer, intent(in) :: num_points, num_contours
        integer, intent(in) :: contour_lengths(:)
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: off_x, off_y
        logical, intent(in) :: invert

        type(raster_edge_t), allocatable :: edges(:)
        integer :: num_edges, m, i, j, k, a, b, point_idx
        real(wp) :: y_scale_inv, real_x1, real_y1, real_x2, real_y2

        print *, "DEBUG: rasterize_points called with", num_points, "points,", num_contours, "contours"
        print *, "DEBUG: scale:", scale_x, scale_y, "shift:", shift_x, shift_y, "off:", off_x, off_y

        y_scale_inv = merge(-scale_y, scale_y, invert)

        num_edges = 0
        do i = 1, num_contours
            num_edges = num_edges + contour_lengths(i)
        end do

        if (num_edges == 0) then
            print *, "DEBUG: No edges generated, returning"
            return
        end if

        print *, "DEBUG: Generated", num_edges, "edges"

        allocate(edges(num_edges))

        num_edges = 0
        point_idx = 1
        
        ! Generate edges from each contour
        do i = 1, num_contours
            ! Create edges from consecutive points in this contour
            do j = 1, contour_lengths(i)
                ! Current point and next point (wrapping around)
                k = point_idx + j - 1
                if (j == contour_lengths(i)) then
                    ! Last point connects to first point of contour
                    a = k
                    b = point_idx
                else
                    a = k
                    b = k + 1
                end if

                ! Transform points to screen coordinates
                real_x1 = points(a)%x * scale_x + shift_x
                real_y1 = points(a)%y * y_scale_inv + shift_y
                real_x2 = points(b)%x * scale_x + shift_x  
                real_y2 = points(b)%y * y_scale_inv + shift_y

                ! Skip horizontal edges (degenerate)
                if (abs(real_y1 - real_y2) < 1.0e-6_wp) then
                    cycle
                end if

                num_edges = num_edges + 1
                
                ! Simple STB-style edge creation: store with y0 <= y1
                if (real_y1 <= real_y2) then
                    edges(num_edges)%x0 = real_x1
                    edges(num_edges)%y0 = real_y1  
                    edges(num_edges)%x1 = real_x2
                    edges(num_edges)%y1 = real_y2
                    edges(num_edges)%invert = .false.  ! Normal direction 
                else
                    edges(num_edges)%x0 = real_x2
                    edges(num_edges)%y0 = real_y2
                    edges(num_edges)%x1 = real_x1
                    edges(num_edges)%y1 = real_y1
                    edges(num_edges)%invert = .true.   ! Inverted direction
                end if

                ! Debug first few edges
                if (num_edges <= 5) then
                    print *, "DEBUG: Edge", num_edges, "invert=", edges(num_edges)%invert, &
                             "from (", edges(num_edges)%x0, ",", edges(num_edges)%y0, ") to (", &
                             edges(num_edges)%x1, ",", edges(num_edges)%y1, ")"
                end if
            end do
            
            point_idx = point_idx + contour_lengths(i)
        end do

        call sort_edges(edges, num_edges)

        call rasterize_sorted_edges(bmp, edges, num_edges, off_x, off_y)

        if (allocated(edges)) deallocate(edges)

    end subroutine rasterize_points

    subroutine sort_edges(edges, num_edges)
        !! Simple bubble sort for edges by minimum y coordinate
        type(raster_edge_t), intent(inout) :: edges(:)
        integer, intent(in) :: num_edges
        integer :: i, j
        type(raster_edge_t) :: temp
        real(wp) :: y1, y2

        do i = 1, num_edges - 1
            do j = i + 1, num_edges
                y1 = min(edges(i)%y0, edges(i)%y1)
                y2 = min(edges(j)%y0, edges(j)%y1)
                if (y1 > y2) then
                    temp = edges(i)
                    edges(i) = edges(j)
                    edges(j) = temp
                end if
            end do
        end do
    end subroutine sort_edges

    subroutine rasterize_sorted_edges(bmp, edges, num_edges, off_x, off_y)
        !! Rasterize sorted edges with simple scanline approach
        type(bitmap_t), intent(inout) :: bmp
        type(raster_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: num_edges, off_x, off_y

        integer :: i, j, y, x
        real(wp) :: y_pos, x_pos, coverage
        real(wp), allocatable :: intersections(:)
        integer, allocatable :: directions(:)
        integer :: num_intersections, k, winding_count
        real(wp) :: temp_x
        integer :: temp_dir

        if (num_edges == 0 .or. bmp%h <= 0 .or. bmp%w <= 0) return

        allocate(intersections(num_edges))
        allocate(directions(num_edges))

        ! Simple scanline approach
        do y = 0, bmp%h - 1
            y_pos = real(y + off_y, wp) + 0.5_wp  ! Middle of pixel row
            
            ! Find all edge intersections with this scanline
            num_intersections = 0
            do i = 1, num_edges
                if (edges(i)%y0 <= y_pos .and. edges(i)%y1 > y_pos) then
                    ! Edge intersects this scanline
                    if (abs(edges(i)%y1 - edges(i)%y0) > 1.0e-6_wp) then
                        x_pos = edges(i)%x0 + (edges(i)%x1 - edges(i)%x0) * &
                                (y_pos - edges(i)%y0) / (edges(i)%y1 - edges(i)%y0)
                        
                        num_intersections = num_intersections + 1
                        intersections(num_intersections) = x_pos - real(off_x, wp)
                        directions(num_intersections) = merge(1, -1, edges(i)%invert)
                    end if
                end if
            end do
            
            ! Sort intersections
            do i = 1, num_intersections - 1
                do j = i + 1, num_intersections
                    if (intersections(i) > intersections(j)) then
                        temp_x = intersections(i)
                        intersections(i) = intersections(j)
                        intersections(j) = temp_x
                        temp_dir = directions(i)
                        directions(i) = directions(j)
                        directions(j) = temp_dir
                    end if
                end do
            end do
            
            ! Simple fill using winding rule
            winding_count = 0
            do x = 0, bmp%w - 1
                ! Count intersections to the left of this pixel
                do k = 1, num_intersections
                    if (intersections(k) < real(x, wp) + 0.5_wp) then
                        winding_count = winding_count + directions(k)
                    end if
                end do
                
                ! Fill pixel if winding count is non-zero
                coverage = merge(127.0_wp, 0.0_wp, winding_count /= 0)
                
                i = y * bmp%stride + x + 1
                if (i >= 1 .and. i <= bmp%stride * bmp%h) then
                    bmp%pixels(i) = int(coverage, int8)
                end if
                
                ! Reset for next pixel
                winding_count = 0
            end do
        end do

        if (allocated(intersections)) deallocate(intersections)
        if (allocated(directions)) deallocate(directions)

    end subroutine rasterize_sorted_edges

    subroutine advance_active_edges(active)
        !! Advance all active edges to next scanline
        type(active_edge_t), pointer, intent(in) :: active
        type(active_edge_t), pointer :: edge

        edge => active
        do while (associated(edge))
            edge%fx = edge%fx + edge%fdx
            edge => edge%next
        end do
    end subroutine advance_active_edges

    subroutine add_active_edge(active, edge, off_x, start_point)
        !! Add an edge to the active edge list
        type(active_edge_t), pointer, intent(inout) :: active
        type(raster_edge_t), intent(in) :: edge
        integer, intent(in) :: off_x
        real(wp), intent(in) :: start_point

        type(active_edge_t), pointer :: new_edge
        real(wp) :: dxdy

        allocate(new_edge)

        ! Calculate slope
        if (abs(edge%y1 - edge%y0) > 1.0e-10_wp) then
            dxdy = (edge%x1 - edge%x0) / (edge%y1 - edge%y0)
        else
            dxdy = 0.0_wp
        end if
        
        new_edge%fdx = dxdy
        new_edge%fdy = merge(1.0_wp / dxdy, 0.0_wp, abs(dxdy) > 1.0e-10_wp)
        new_edge%fx = edge%x0 + dxdy * (start_point - edge%y0) - real(off_x, wp)
        
        ! STB direction: invert ? 1.0f : -1.0f 
        ! This means inverted edges contribute +1, normal edges contribute -1
        new_edge%direction = merge(1.0_wp, -1.0_wp, edge%invert)
        
        new_edge%sy = edge%y0
        new_edge%ey = edge%y1
        new_edge%next => active
        active => new_edge

    end subroutine add_active_edge

    subroutine fill_active_edges(scanline, scanline_fill, len, active, y_top)
        !! Fill scanline using simplified approach based on STB
        real(wp), intent(inout) :: scanline(0:), scanline_fill(0:)
        integer, intent(in) :: len
        type(active_edge_t), pointer, intent(in) :: active
        real(wp), intent(in) :: y_top

        type(active_edge_t), pointer :: edge
        real(wp) :: y_bottom, height, x_pos
        integer :: x

        y_bottom = y_top + 1.0_wp
        scanline(0:len-1) = 0.0_wp
        scanline_fill(0:len) = 0.0_wp

        edge => active
        do while (associated(edge))
            ! Skip degenerate edges
            if (abs(edge%ey - edge%sy) < 1.0e-6_wp) then
                edge => edge%next
                cycle
            end if

            ! Get x position for this edge at current scanline
            x_pos = edge%fx
            
            ! Simple approach: just accumulate edge contributions
            if (x_pos >= 0.0_wp .and. x_pos < real(len, wp)) then
                x = int(x_pos)
                if (x >= 0 .and. x < len) then
                    ! Add edge direction to scanline_fill for winding rule
                    scanline_fill(x) = scanline_fill(x) + edge%direction
                    
                    ! Simple coverage calculation
                    height = min(edge%ey, y_bottom) - max(edge%sy, y_top)
                    scanline(x) = scanline(x) + edge%direction * height * (1.0_wp - (x_pos - real(x, wp)))
                    
                    ! Also affect the next pixel if we're not at the boundary
                    if (x + 1 < len) then
                        scanline(x + 1) = scanline(x + 1) + edge%direction * height * (x_pos - real(x, wp))
                    end if
                end if
            end if

            edge => edge%next
        end do

    end subroutine fill_active_edges

    real(wp) function sized_triangle_area(height, width)
        !! Calculate triangle area like STB
        real(wp), intent(in) :: height, width
        sized_triangle_area = height * width * 0.5_wp
    end function sized_triangle_area

    real(wp) function position_trapezoid_area(height, tx0, tx1, bx0, bx1)
        !! Calculate trapezoid area like STB
        real(wp), intent(in) :: height, tx0, tx1, bx0, bx1
        real(wp) :: top_width, bottom_width
        
        top_width = tx1 - tx0
        bottom_width = bx1 - bx0
        position_trapezoid_area = (top_width + bottom_width) * height * 0.5_wp
    end function position_trapezoid_area

    subroutine swap_real(a, b)
        !! Swap two real values
        real(wp), intent(inout) :: a, b
        real(wp) :: temp
        temp = a
        a = b
        b = temp
    end subroutine swap_real

    subroutine remove_finished_edges(active, y_bottom)
        !! Remove edges that have finished
        type(active_edge_t), pointer, intent(inout) :: active
        real(wp), intent(in) :: y_bottom

        type(active_edge_t), pointer :: current, prev, temp

        prev => null()
        current => active

        do while (associated(current))
            if (current%ey <= y_bottom) then
                if (associated(prev)) then
                    prev%next => current%next
                else
                    active => current%next
                end if
                temp => current%next
                deallocate(current)
                current => temp
            else
                current%fx = current%fx + current%fdx
                prev => current
                current => current%next
            end if
        end do

    end subroutine remove_finished_edges

    subroutine cleanup_active_edges(active)
        !! Clean up all active edges
        type(active_edge_t), pointer, intent(inout) :: active
        type(active_edge_t), pointer :: current, temp

        current => active
        do while (associated(current))
            temp => current%next
            deallocate(current)
            current => temp
        end do
        active => null()

    end subroutine cleanup_active_edges

end module fortplot_truetype_raster
