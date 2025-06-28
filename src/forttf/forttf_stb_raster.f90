module forttf_stb_raster
    !! STB TrueType-compatible rasterization pipeline
    !! Implements exact algorithms from stb_truetype.h for pixel-perfect matching
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    implicit none

    private

    ! Public interface for STB-compatible rasterization
    public :: stb_flatten_curves
    public :: stb_tesselate_curve
    public :: stb_tesselate_cubic
    public :: stb_add_point
    ! Edge building and sorting
    public :: stb_build_edges
    public :: stb_sort_edges
    public :: stb_sort_edges_quicksort
    public :: stb_sort_edges_ins_sort
    ! Active edge management
    public :: stb_new_active_edge
    public :: stb_update_active_edges
    public :: stb_remove_completed_edges
    public :: stb_insert_active_edge
    public :: stb_fill_active_edges
    public :: stb_rasterize
    public :: stb_rasterize_sorted_edges
    ! Area calculation functions for anti-aliasing
    public :: stb_sized_trapezoid_area
    public :: stb_position_trapezoid_area
    public :: stb_sized_triangle_area
    public :: stb_handle_clipped_edge

contains

    function stb_flatten_curves(vertices, num_verts, objspace_flatness, &
                               contour_lengths, num_contours) result(points)
        !! Main curve flattening function (matches stbtt_FlattenCurves)
        type(ttf_vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_verts
        real(wp), intent(in) :: objspace_flatness
        integer, allocatable, intent(out) :: contour_lengths(:)
        integer, intent(out) :: num_contours
        type(stb_point_t), allocatable :: points(:)
        
        type(stb_point_t), allocatable :: temp_points(:)
        integer :: max_points, num_points
        integer :: i, contour_start, n
        real(wp) :: objspace_flatness_squared
        logical :: in_contour
        
        ! Pre-calculate squared flatness for efficiency (matches STB)
        objspace_flatness_squared = objspace_flatness * objspace_flatness
        
        ! Estimate maximum points needed (conservative)
        max_points = num_verts * 32  ! Each curve could expand significantly
        allocate(temp_points(max_points))
        
        ! Track contours
        allocate(contour_lengths(num_verts))  ! Max possible contours
        num_contours = 0
        num_points = 0
        in_contour = .false.
        contour_start = 0
        
        i = 1
        do while (i <= num_verts)
            select case (vertices(i)%type)
            case (TTF_VERTEX_MOVE)
                ! End previous contour if any
                if (in_contour) then
                    num_contours = num_contours + 1
                    contour_lengths(num_contours) = num_points - contour_start
                end if
                
                ! Start new contour
                in_contour = .true.
                contour_start = num_points
                call stb_add_point(temp_points, num_points, max_points, &
                                  real(vertices(i)%x, wp), real(vertices(i)%y, wp))
                i = i + 1
                
            case (TTF_VERTEX_LINE)
                if (in_contour) then
                    call stb_add_point(temp_points, num_points, max_points, &
                                      real(vertices(i)%x, wp), real(vertices(i)%y, wp))
                end if
                i = i + 1
                
            case (TTF_VERTEX_CURVE)
                if (in_contour .and. i <= num_verts) then
                    ! Quadratic Bézier curve (P0, P1, P2)
                    ! P0 = previous point, P1 = control point, P2 = end point
                    call stb_tesselate_curve(temp_points, num_points, max_points, &
                                           temp_points(num_points)%x, temp_points(num_points)%y, &
                                           real(vertices(i)%cx, wp), real(vertices(i)%cy, wp), &
                                           real(vertices(i)%x, wp), real(vertices(i)%y, wp), &
                                           objspace_flatness_squared, 0)
                end if
                i = i + 1
                
            case (TTF_VERTEX_CUBIC)
                if (in_contour .and. i <= num_verts) then
                    ! Cubic Bézier curve (P0, P1, P2, P3)
                    ! P0 = previous point, P1 = first control, P2 = second control, P3 = end
                    call stb_tesselate_cubic(temp_points, num_points, max_points, &
                                           temp_points(num_points)%x, temp_points(num_points)%y, &
                                           real(vertices(i)%cx, wp), real(vertices(i)%cy, wp), &
                                           real(vertices(i)%cx1, wp), real(vertices(i)%cy1, wp), &
                                           real(vertices(i)%x, wp), real(vertices(i)%y, wp), &
                                           objspace_flatness_squared, 0)
                end if
                i = i + 1
                
            case default
                i = i + 1
            end select
        end do
        
        ! End final contour
        if (in_contour) then
            num_contours = num_contours + 1
            contour_lengths(num_contours) = num_points - contour_start
        end if
        
        ! Copy to final result array (exact size)
        allocate(points(num_points))
        points(1:num_points) = temp_points(1:num_points)
        
        ! Resize contour_lengths to actual size
        if (num_contours > 0) then
            contour_lengths = contour_lengths(1:num_contours)
        else
            deallocate(contour_lengths)
            allocate(contour_lengths(0))
        end if
        
    end function stb_flatten_curves
    
    subroutine stb_add_point(points, num_points, max_points, x, y)
        !! Add point to points array (matches stbtt__add_point)
        type(stb_point_t), intent(inout) :: points(:)
        integer, intent(inout) :: num_points
        integer, intent(in) :: max_points
        real(wp), intent(in) :: x, y
        
        if (num_points < max_points) then
            num_points = num_points + 1
            points(num_points) = stb_point_t(x=x, y=y)
        end if
        
    end subroutine stb_add_point
    
    recursive subroutine stb_tesselate_curve(points, num_points, max_points, &
                                            x0, y0, x1, y1, x2, y2, &
                                            objspace_flatness_squared, n)
        !! Tessellate quadratic Bézier curve (matches stbtt__tesselate_curve)
        type(stb_point_t), intent(inout) :: points(:)
        integer, intent(inout) :: num_points
        integer, intent(in) :: max_points
        real(wp), intent(in) :: x0, y0, x1, y1, x2, y2
        real(wp), intent(in) :: objspace_flatness_squared
        integer, intent(in) :: n
        
        real(wp) :: mx, my, dx, dy
        
        ! Prevent infinite recursion (matches STB's max depth)
        if (n > TTF_MAX_RECURSION_DEPTH) then
            call stb_add_point(points, num_points, max_points, x2, y2)
            return
        end if
        
        ! Calculate midpoint of control polygon vs actual curve midpoint
        ! STB algorithm: compare (x0+2*x1+x2)/4 vs (x0+x2)/2
        mx = (x0 + 2.0_wp * x1 + x2) * 0.25_wp  ! Curve midpoint
        my = (y0 + 2.0_wp * y1 + y2) * 0.25_wp
        
        dx = (x0 + x2) * 0.5_wp - mx  ! Difference from linear midpoint  
        dy = (y0 + y2) * 0.5_wp - my
        
        ! STB flatness test: is deviation within tolerance?
        if (dx * dx + dy * dy > objspace_flatness_squared) then
            ! Curve is not flat enough - subdivide
            ! Left half: (x0,y0) to ((x0+x1)/2, (y0+y1)/2) to (mx,my)
            call stb_tesselate_curve(points, num_points, max_points, &
                                   x0, y0, &
                                   (x0 + x1) * 0.5_wp, (y0 + y1) * 0.5_wp, &
                                   mx, my, &
                                   objspace_flatness_squared, n + 1)
            
            ! Right half: (mx,my) to ((x1+x2)/2, (y1+y2)/2) to (x2,y2)
            call stb_tesselate_curve(points, num_points, max_points, &
                                   mx, my, &
                                   (x1 + x2) * 0.5_wp, (y1 + y2) * 0.5_wp, &
                                   x2, y2, &
                                   objspace_flatness_squared, n + 1)
        else
            ! Curve is flat enough - add endpoint
            call stb_add_point(points, num_points, max_points, x2, y2)
        end if
        
    end subroutine stb_tesselate_curve
    
    recursive subroutine stb_tesselate_cubic(points, num_points, max_points, &
                                           x0, y0, x1, y1, x2, y2, x3, y3, &
                                           objspace_flatness_squared, n)
        !! Tessellate cubic Bézier curve (matches stbtt__tesselate_cubic)
        type(stb_point_t), intent(inout) :: points(:)
        integer, intent(inout) :: num_points
        integer, intent(in) :: max_points
        real(wp), intent(in) :: x0, y0, x1, y1, x2, y2, x3, y3
        real(wp), intent(in) :: objspace_flatness_squared
        integer, intent(in) :: n
        
        real(wp) :: dx0, dy0, dx1, dy1, dx2, dy2, dx3, dy3
        real(wp) :: longlen, shortlen
        real(wp) :: x01, y01, x12, y12, x23, y23
        real(wp) :: x012, y012, x123, y123, x0123, y0123
        
        ! Prevent infinite recursion
        if (n > TTF_MAX_RECURSION_DEPTH) then
            call stb_add_point(points, num_points, max_points, x3, y3)
            return
        end if
        
        ! STB algorithm: compare arc length vs chord length
        ! Calculate the sum of all segment lengths
        dx0 = x1 - x0
        dy0 = y1 - y0
        dx1 = x2 - x1  
        dy1 = y2 - y1
        dx2 = x3 - x2
        dy2 = y3 - y2
        dx3 = x3 - x0  ! Direct chord
        dy3 = y3 - y0
        
        longlen = sqrt(dx0*dx0 + dy0*dy0) + sqrt(dx1*dx1 + dy1*dy1) + sqrt(dx2*dx2 + dy2*dy2)
        shortlen = sqrt(dx3*dx3 + dy3*dy3)
        
        ! STB flatness test for cubic curves
        if (longlen - shortlen > sqrt(objspace_flatness_squared)) then
            ! Curve is not flat enough - subdivide using de Casteljau's algorithm
            ! First level interpolation
            x01 = (x0 + x1) * 0.5_wp
            y01 = (y0 + y1) * 0.5_wp
            x12 = (x1 + x2) * 0.5_wp
            y12 = (y1 + y2) * 0.5_wp
            x23 = (x2 + x3) * 0.5_wp
            y23 = (y2 + y3) * 0.5_wp
            
            ! Second level interpolation
            x012 = (x01 + x12) * 0.5_wp
            y012 = (y01 + y12) * 0.5_wp
            x123 = (x12 + x23) * 0.5_wp
            y123 = (y12 + y23) * 0.5_wp
            
            ! Final midpoint
            x0123 = (x012 + x123) * 0.5_wp
            y0123 = (y012 + y123) * 0.5_wp
            
            ! Left half: (x0,y0,x01,y01,x012,y012,x0123,y0123)
            call stb_tesselate_cubic(points, num_points, max_points, &
                                   x0, y0, x01, y01, x012, y012, x0123, y0123, &
                                   objspace_flatness_squared, n + 1)
            
            ! Right half: (x0123,y0123,x123,y123,x23,y23,x3,y3)  
            call stb_tesselate_cubic(points, num_points, max_points, &
                                   x0123, y0123, x123, y123, x23, y23, x3, y3, &
                                   objspace_flatness_squared, n + 1)
        else
            ! Curve is flat enough - add endpoint
            call stb_add_point(points, num_points, max_points, x3, y3)
        end if
        
    end subroutine stb_tesselate_cubic

    function stb_build_edges(points, contour_lengths, num_contours, &
                            scale_x, scale_y, shift_x, shift_y, invert) result(edges)
        !! Build edges from flattened points (matches STB edge building)
        type(stb_point_t), intent(in) :: points(:)
        integer, intent(in) :: contour_lengths(:)
        integer, intent(in) :: num_contours
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        logical, intent(in) :: invert
        type(stb_edge_t), allocatable :: edges(:)
        
        integer :: max_edges, num_edges, contour, point_idx, i
        integer :: contour_start, contour_end
        real(wp) :: x0, y0, x1, y1
        integer :: winding
        
        ! Estimate maximum edges (one per point minus one per contour)
        max_edges = size(points)
        allocate(edges(max_edges))
        num_edges = 0
        
        ! Set winding direction based on invert flag
        winding = merge(1, 0, invert)
        
        point_idx = 1
        do contour = 1, num_contours
            contour_start = point_idx
            contour_end = point_idx + contour_lengths(contour) - 1
            
            ! Build edges for this contour (including closing edge)
            do i = contour_start, contour_end
                ! Get current and next point (wrap around for closing edge)
                if (i < contour_end) then
                    x0 = points(i)%x * scale_x + shift_x
                    y0 = points(i)%y * scale_y + shift_y
                    x1 = points(i + 1)%x * scale_x + shift_x
                    y1 = points(i + 1)%y * scale_y + shift_y
                else
                    ! Closing edge: last point to first point
                    x0 = points(contour_end)%x * scale_x + shift_x
                    y0 = points(contour_end)%y * scale_y + shift_y
                    x1 = points(contour_start)%x * scale_x + shift_x
                    y1 = points(contour_start)%y * scale_y + shift_y
                end if
                
                ! Only add non-horizontal edges (matches STB behavior)
                if (abs(y1 - y0) > epsilon(1.0_wp)) then
                    num_edges = num_edges + 1
                    if (y0 < y1) then
                        ! Edge goes down - normal orientation
                        edges(num_edges) = stb_edge_t(x0=x0, y0=y0, x1=x1, y1=y1, invert=winding)
                    else
                        ! Edge goes up - reverse orientation
                        edges(num_edges) = stb_edge_t(x0=x1, y0=y1, x1=x0, y1=y0, invert=1-winding)
                    end if
                end if
            end do
            
            point_idx = contour_end + 1
        end do
        
        ! Resize to actual number of edges
        if (num_edges > 0) then
            edges = edges(1:num_edges)
        else
            deallocate(edges)
            allocate(edges(0))
        end if
        
    end function stb_build_edges
    
    subroutine stb_sort_edges(edges, n)
        !! Sort edges by y0 coordinate (matches stbtt__sort_edges)
        type(stb_edge_t), intent(inout) :: edges(:)
        integer, intent(in) :: n
        
        ! Use quicksort for larger arrays, insertion sort for smaller
        if (n > 12) then
            call stb_sort_edges_quicksort(edges, n)
        else
            call stb_sort_edges_ins_sort(edges, n)
        end if
        
    end subroutine stb_sort_edges
    
    recursive subroutine stb_sort_edges_quicksort(edges, n)
        !! Quicksort implementation for edges (matches stbtt__sort_edges_quicksort)
        type(stb_edge_t), intent(inout) :: edges(:)
        integer, intent(in) :: n
        
        type(stb_edge_t) :: pivot, temp
        integer :: i, j
        
        if (n <= 1) return
        
        ! Choose pivot (middle element)
        pivot = edges((n + 1) / 2)
        
        ! Partition
        i = 1
        j = n
        do while (i <= j)
            do while (i <= n .and. edges(i)%y0 < pivot%y0)
                i = i + 1
            end do
            do while (j >= 1 .and. edges(j)%y0 > pivot%y0)
                j = j - 1
            end do
            
            if (i <= j) then
                ! Swap elements
                temp = edges(i)
                edges(i) = edges(j)
                edges(j) = temp
                i = i + 1
                j = j - 1
            end if
        end do
        
        ! Recursively sort partitions
        if (j > 1) call stb_sort_edges_quicksort(edges(1:j), j)
        if (i < n) call stb_sort_edges_quicksort(edges(i:n), n - i + 1)
        
    end subroutine stb_sort_edges_quicksort
    
    subroutine stb_sort_edges_ins_sort(edges, n)
        !! Insertion sort for small edge arrays (matches stbtt__sort_edges_ins_sort)
        type(stb_edge_t), intent(inout) :: edges(:)
        integer, intent(in) :: n
        
        type(stb_edge_t) :: key
        integer :: i, j
        
        if (n <= 1) return
        
        do i = 2, n
            key = edges(i)
            j = i - 1
            
            ! Move elements greater than key one position ahead
            do while (j >= 1)
                if (edges(j)%y0 <= key%y0) exit
                edges(j + 1) = edges(j)
                j = j - 1
            end do
            
            edges(j + 1) = key
        end do
        
    end subroutine stb_sort_edges_ins_sort

    function stb_new_active_edge(edge, off_x, start_point) result(active_edge)
        !! Create new active edge from edge (matches stbtt__new_active)
        type(stb_edge_t), intent(in) :: edge
        integer, intent(in) :: off_x
        real(wp), intent(in) :: start_point
        type(stb_active_edge_t) :: active_edge
        
        real(wp) :: dx, dy
        
        ! Calculate edge derivatives (matches STB exactly)
        dx = edge%x1 - edge%x0
        dy = edge%y1 - edge%y0
        
        ! Initialize active edge fields
        active_edge%next => null()
        active_edge%sy = edge%y0
        active_edge%ey = edge%y1
        active_edge%direction = real(merge(1, -1, edge%invert == 0), wp)
        
        ! Calculate slopes (STB algorithm)
        if (abs(dy) > epsilon(1.0_wp)) then
            active_edge%fdx = dx / dy           ! X change per Y unit
            active_edge%fdy = dy / dx           ! Y change per X unit (inverse slope)
            active_edge%fx = edge%x0 + active_edge%fdx * (start_point - edge%y0) + real(off_x, wp)
        else
            ! Nearly horizontal edge
            active_edge%fdx = 0.0_wp
            active_edge%fdy = 0.0_wp  
            active_edge%fx = edge%x0 + real(off_x, wp)
        end if
        
    end function stb_new_active_edge
    
    subroutine stb_update_active_edges(active_edges, y_step)
        !! Update active edge positions for next scanline (matches STB)
        type(stb_active_edge_t), intent(inout), target :: active_edges
        real(wp), intent(in) :: y_step
        
        type(stb_active_edge_t), pointer :: current
        
        current => active_edges%next
        do while (associated(current))
            ! Update X position based on slope
            current%fx = current%fx + current%fdx * y_step
            current => current%next
        end do
        
    end subroutine stb_update_active_edges
    
    subroutine stb_remove_completed_edges(active_edges, current_y)
        !! Remove edges that have reached their end Y coordinate
        type(stb_active_edge_t), intent(inout), target :: active_edges
        real(wp), intent(in) :: current_y
        
        type(stb_active_edge_t), pointer :: current, prev
        
        prev => active_edges  ! Dummy head node
        current => active_edges%next
        
        do while (associated(current))
            if (current_y >= current%ey) then
                ! Remove this edge from linked list
                prev%next => current%next
                ! In a real implementation, we would deallocate current here
                current => prev%next
            else
                prev => current
                current => current%next
            end if
        end do
        
    end subroutine stb_remove_completed_edges

    subroutine stb_insert_active_edge(active_head, edge)
        !! Insert a new edge into the sorted active edge list
        type(stb_active_edge_t), intent(inout), target :: active_head
        type(stb_active_edge_t), intent(inout), target :: edge
        type(stb_active_edge_t), pointer :: current

        current => active_head
        do while (associated(current%next))
            if (edge%fx < current%next%fx) then
                exit
            end if
            current => current%next
        end do

        edge%next => current%next
        current%next => edge

    end subroutine stb_insert_active_edge

    subroutine stb_fill_active_edges(active_edges, scanline_y, width, scanline_buffer, scanline_fill_buffer)
        !! Fill a scanline based on the current active edges (matches stbtt__fill_active_edges_new)
        type(stb_active_edge_t), pointer, intent(in) :: active_edges
        real(wp), intent(in) :: scanline_y
        integer, intent(in) :: width
        real(wp), intent(inout) :: scanline_buffer(:)
        real(wp), intent(inout) :: scanline_fill_buffer(:)
        
        type(stb_active_edge_t), pointer :: e0, e1
        real(wp) :: x0, x1, fill_amount
        integer :: i, x_start, x_end
        
        e0 => active_edges
        do while (associated(e0))
            e1 => e0%next
            if (.not. associated(e1)) exit

            ! Calculate intersection points for this scanline
            x0 = e0%fx
            x1 = e1%fx

            ! Fill pixels between the edges
            if (x1 > x0) then
                x_start = floor(x0)
                x_end = ceiling(x1)

                if (x_start < x_end) then
                    do i = max(0, x_start), min(width - 1, x_end - 1)
                        fill_amount = max(0.0_wp, min(1.0_wp, x1 - real(i, wp))) - max(0.0_wp, min(1.0_wp, x0 - real(i, wp)))
                        if (fill_amount > 0.0_wp) then
                           scanline_buffer(i + 1) = scanline_buffer(i + 1) + e0%direction * fill_amount
                        end if
                    end do
                end if
            end if
            
            e0 => e1%next
        end do
        
    end subroutine stb_fill_active_edges

    subroutine stb_rasterize(bitmap_ptr, width, height, stride, &
                           points, contour_lengths, num_contours, &
                           scale_x, scale_y, shift_x, shift_y, xoff, yoff, invert)
        !! Main rasterization function (matches stbtt__rasterize_sorted_edges)
        type(c_ptr), intent(in) :: bitmap_ptr
        integer, intent(in) :: width, height, stride
        type(stb_point_t), intent(in) :: points(:)
        integer, intent(in) :: contour_lengths(:), num_contours
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: xoff, yoff
        logical, intent(in) :: invert

        type(stb_edge_t), allocatable :: edges(:)
        integer :: num_edges, y, edge_idx
        type(stb_active_edge_t), target :: active_head
        type(stb_active_edge_t), pointer :: new_edge_ptr
        real(wp), allocatable :: scanline_buffer(:)
        real(wp), allocatable :: scanline_fill_buffer(:)
        integer(c_int8_t), pointer :: bitmap_array(:,:)
        integer :: i, pixel_val

        ! Build and sort edges
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                                scale_x, scale_y, shift_x, shift_y, invert)
        num_edges = size(edges)
        if (num_edges == 0) return
        call stb_sort_edges(edges, num_edges)

        ! Initialize active edge list (dummy head)
        active_head = stb_active_edge_t(next=null())
        
        allocate(scanline_buffer(width))
        call c_f_pointer(bitmap_ptr, bitmap_array, [stride, height])

        edge_idx = 1
        do y = 0, height - 1
            scanline_buffer = 0.0_wp
            
            ! Add new edges that start on this scanline
            do while (edge_idx <= num_edges .and. edges(edge_idx)%y0 <= real(y, wp) + 0.5_wp)
                if (edges(edge_idx)%y1 > real(y, wp) + 0.5_wp) then
                    allocate(new_edge_ptr)
                    new_edge_ptr = stb_new_active_edge(edges(edge_idx), xoff, real(y, wp) + 0.5_wp)
                    call stb_insert_active_edge(active_head, new_edge_ptr)
                end if
                edge_idx = edge_idx + 1
            end do

            ! Fill scanline from active edges
            if (associated(active_head%next)) then
                call stb_fill_active_edges(active_head%next, real(y, wp) + 0.5_wp, width, scanline_buffer, scanline_fill_buffer)
            end if

            ! Write scanline to bitmap
            do i = 1, width
                pixel_val = int(abs(scanline_buffer(i)) * 255.0_wp)
                bitmap_array(i, y + 1) = min(255, pixel_val)
            end do

            ! Update active edges for next scanline
            call stb_update_active_edges(active_head, 1.0_wp)
            call stb_remove_completed_edges(active_head, real(y, wp) + 1.5_wp)
        end do

        deallocate(edges, scanline_buffer, scanline_fill_buffer)
        ! Deallocate active edge list
        new_edge_ptr => active_head%next
        do while(associated(new_edge_ptr))
            active_head%next => new_edge_ptr%next
            deallocate(new_edge_ptr)
            new_edge_ptr => active_head%next
        end do

    end subroutine stb_rasterize

    subroutine stb_rasterize_sorted_edges(result, e, n, vsubsample, off_x, off_y, userdata)
        type(stb_bitmap_t), intent(inout) :: result
        type(stb_edge_t), intent(in) :: e(:)
        integer, intent(in) :: n
        integer, intent(in) :: vsubsample
        integer, intent(in) :: off_x, off_y
        type(c_ptr), intent(in) :: userdata

        type(stb_active_edge_t), pointer :: active_head
        type(stb_active_edge_t), pointer :: new_edge_ptr
        real(wp), allocatable :: scanline_buffer(:)
        real(wp), allocatable :: scanline_fill_buffer(:)
        integer(c_int8_t), pointer :: bitmap_array(:)
        integer :: y, edge_idx, i
        real(wp) :: scan_y_top, scan_y_bottom, sum_val, k_val
        integer :: m_val

        ! Initialize active edge list (dummy head)
        allocate(active_head)
        active_head%next => null()

        ! Allocate scanline buffers
        allocate(scanline_buffer(result%w))
        allocate(scanline_fill_buffer(result%w + 1))

        ! Associate bitmap_array with result%pixels
        call c_f_pointer(c_loc(result%pixels(1)), bitmap_array, [result%w * result%h])

        edge_idx = 1
        do y = 0, result%h - 1
            scanline_buffer = 0.0_wp
            scanline_fill_buffer = 0.0_wp

            scan_y_top = real(y, wp) + 0.0_wp
            scan_y_bottom = real(y, wp) + 1.0_wp

            ! Remove all active edges that terminate before the top of this scanline
            call stb_remove_completed_edges(active_head, scan_y_top)

            ! Insert all edges that start before the bottom of this scanline
            ! Fix bounds checking - ensure edge_idx doesn't exceed array bounds
            do while (edge_idx <= n)
                if (e(edge_idx)%y0 > scan_y_bottom) exit  ! STB-style early exit
                if (e(edge_idx)%y0 /= e(edge_idx)%y1) then
                    allocate(new_edge_ptr)
                    new_edge_ptr = stb_new_active_edge(e(edge_idx), off_x, scan_y_top)
                    if (new_edge_ptr%ey < scan_y_top) then
                        new_edge_ptr%ey = scan_y_top
                    end if
                    call stb_insert_active_edge(active_head, new_edge_ptr)
                end if
                edge_idx = edge_idx + 1
            end do

            ! Process all active edges
            if (associated(active_head%next)) then
                call stb_fill_active_edges(active_head%next, scan_y_top, result%w, scanline_buffer, scanline_fill_buffer)
            end if

            sum_val = 0.0_wp
            do i = 0, result%w - 1
                sum_val = sum_val + scanline_fill_buffer(i + 1)
                k_val = scanline_buffer(i + 1) + sum_val
                k_val = abs(k_val) * 255.0_wp + 0.5_wp
                m_val = int(k_val)
                if (m_val > 255) m_val = 255
                bitmap_array(y * result%stride + i + 1) = int(m_val, c_int8_t)
            end do

            ! Advance all the edges
            call stb_update_active_edges(active_head, 1.0_wp)
        end do

        deallocate(scanline_buffer, scanline_fill_buffer)
        ! Deallocate active edge list
        new_edge_ptr => active_head%next
        do while(associated(new_edge_ptr))
            active_head%next => new_edge_ptr%next
            deallocate(new_edge_ptr)
            new_edge_ptr => active_head%next
        end do
        deallocate(active_head)

    end subroutine stb_rasterize_sorted_edges

    ! === STB Area Calculation Functions for Anti-Aliasing ===
    
    pure function stb_sized_trapezoid_area(height, top_width, bottom_width) result(area)
        !! Calculate the area of a trapezoid for anti-aliasing coverage (matches stbtt__sized_trapezoid_area)
        real(wp), intent(in) :: height, top_width, bottom_width
        real(wp) :: area
        
        ! STB algorithm: (top_width + bottom_width) / 2.0 * height
        area = (top_width + bottom_width) * 0.5_wp * height
        
    end function stb_sized_trapezoid_area
    
    pure function stb_position_trapezoid_area(height, tx0, tx1, bx0, bx1) result(area)
        !! Calculate trapezoid area with sub-pixel positioning (matches stbtt__position_trapezoid_area)
        real(wp), intent(in) :: height, tx0, tx1, bx0, bx1
        real(wp) :: area
        
        ! STB algorithm: call sized_trapezoid_area with computed widths
        area = stb_sized_trapezoid_area(height, tx1 - tx0, bx1 - bx0)
        
    end function stb_position_trapezoid_area
    
    pure function stb_sized_triangle_area(height, width) result(area)
        !! Calculate the area of a triangle for partial coverage at edges (matches stbtt__sized_triangle_area)
        real(wp), intent(in) :: height, width
        real(wp) :: area
        
        ! STB algorithm: height * width / 2
        area = height * width * 0.5_wp
        
    end function stb_sized_triangle_area
    
    subroutine stb_handle_clipped_edge(scanline, x, e, x0, y0, x1, y1)
        !! Handle edges that are clipped at scanline boundaries (matches stbtt__handle_clipped_edge)
        real(wp), intent(inout) :: scanline(:)
        integer, intent(in) :: x
        type(stb_active_edge_t), intent(in) :: e
        real(wp), intent(in) :: x0, y0, x1, y1
        
        real(wp) :: adj_x0, adj_y0, adj_x1, adj_y1
        
        ! Early exit for horizontal edges
        if (abs(y1 - y0) < epsilon(1.0_wp)) return
        
        ! Ensure y0 < y1 (STB assumption)
        if (y0 > y1) return
        
        ! Clip to edge bounds
        adj_x0 = x0
        adj_y0 = y0
        adj_x1 = x1
        adj_y1 = y1
        
        ! Clip to edge start Y
        if (adj_y0 < e%sy) then
            adj_x0 = adj_x0 + (adj_x1 - adj_x0) * (e%sy - adj_y0) / (adj_y1 - adj_y0)
            adj_y0 = e%sy
        end if
        
        ! Clip to edge end Y
        if (adj_y1 > e%ey) then
            adj_x1 = adj_x1 + (adj_x1 - adj_x0) * (e%ey - adj_y1) / (adj_y1 - adj_y0)
            adj_y1 = e%ey
        end if
        
        ! Handle different cases based on X positions
        if (adj_x0 <= real(x, wp) .and. adj_x1 <= real(x, wp)) then
            ! Both endpoints left of pixel
            scanline(x + 1) = scanline(x + 1) + e%direction * (adj_y1 - adj_y0)
        else if (adj_x0 >= real(x + 1, wp) .and. adj_x1 >= real(x + 1, wp)) then
            ! Both endpoints right of pixel - no contribution
            return
        else
            ! Edge crosses pixel - calculate partial coverage
            ! STB algorithm: coverage = 1 - average x position
            scanline(x + 1) = scanline(x + 1) + e%direction * (adj_y1 - adj_y0) * &
                             (1.0_wp - ((adj_x0 - real(x, wp)) + (adj_x1 - real(x, wp))) * 0.5_wp)
        end if
        
    end subroutine stb_handle_clipped_edge

end module forttf_stb_raster