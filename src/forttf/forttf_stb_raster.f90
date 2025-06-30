module forttf_stb_raster
    !! STB TrueType-compatible rasterization pipeline
    !! Implements exact algorithms from stb_truetype.h for pixel-perfect matching
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
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
    public :: stb_fill_active_edges_with_offset
    public :: stb_rasterize
    public :: stbtt_rasterize
    public :: stb_rasterize_sorted_edges
    ! Area calculation functions for anti-aliasing
    public :: stb_sized_trapezoid_area
    public :: stb_position_trapezoid_area
    public :: stb_sized_triangle_area
    public :: stb_handle_clipped_edge
    public :: stb_brute_force_edge_clipping
    public :: stb_process_non_vertical_edge

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
        integer :: i, contour_start
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
        integer :: j, k, a, b
        real(wp) :: x0, y0, x1, y1
        integer :: winding

        ! Estimate maximum edges (one per point minus one per contour)
        max_edges = size(points)
        allocate(edges(max_edges))
        num_edges = 0
        
        ! DEBUG: Log edge building start
        write(*,'(A,I0,A,I0)') 'DEBUG EDGE BUILD: Starting with ', size(points), ' points, ', num_contours, ' contours'

        ! Set winding direction based on invert flag
        winding = merge(1, 0, invert)

        point_idx = 1
        do contour = 1, num_contours
            contour_start = point_idx
            contour_end = point_idx + contour_lengths(contour) - 1

            ! STB pattern: j = wcount[i]-1; for (k=0; k < wcount[i]; j=k++)
            j = contour_lengths(contour)  ! j starts at wcount[i]-1 (but 1-based, so just wcount[i])
            do k = 1, contour_lengths(contour)
                a = contour_start + k - 1   ! k (0-based in STB, 1-based here)
                b = contour_start + j - 1   ! j (0-based in STB, 1-based here)

                x0 = points(b)%x  ! p[j]
                y0 = points(b)%y
                x1 = points(a)%x  ! p[k]
                y1 = points(a)%y

                j = k  ! j=k++ in STB

                ! Skip horizontal edges (STB: if (p[j].y == p[k].y) continue;)
                if (abs(y1 - y0) > epsilon(1.0_wp)) then
                    num_edges = num_edges + 1

                    ! STB exact algorithm
                    edges(num_edges)%invert = 0
                    if (invert) then
                        if (y0 > y1) then  ! p[j].y > p[k].y when invert=true
                            edges(num_edges)%invert = 1
                            ! a=j, b=k
                            edges(num_edges)%x0 = x0 * scale_x + shift_x  ! p[a].x = p[j].x
                            edges(num_edges)%y0 = y0 * scale_y + shift_y  ! p[a].y = p[j].y
                            edges(num_edges)%x1 = x1 * scale_x + shift_x  ! p[b].x = p[k].x
                            edges(num_edges)%y1 = y1 * scale_y + shift_y  ! p[b].y = p[k].y
                        else
                            ! a=k, b=j
                            edges(num_edges)%x0 = x1 * scale_x + shift_x  ! p[a].x = p[k].x
                            edges(num_edges)%y0 = y1 * scale_y + shift_y  ! p[a].y = p[k].y
                            edges(num_edges)%x1 = x0 * scale_x + shift_x  ! p[b].x = p[j].x
                            edges(num_edges)%y1 = y0 * scale_y + shift_y  ! p[b].y = p[j].y
                        end if
                    else
                        if (y0 < y1) then  ! p[j].y < p[k].y when invert=false
                            edges(num_edges)%invert = 1
                            ! a=j, b=k
                            edges(num_edges)%x0 = x0 * scale_x + shift_x  ! p[a].x = p[j].x
                            edges(num_edges)%y0 = y0 * scale_y + shift_y  ! p[a].y = p[j].y
                            edges(num_edges)%x1 = x1 * scale_x + shift_x  ! p[b].x = p[k].x
                            edges(num_edges)%y1 = y1 * scale_y + shift_y  ! p[b].y = p[k].y
                        else
                            ! a=k, b=j
                            edges(num_edges)%x0 = x1 * scale_x + shift_x  ! p[a].x = p[k].x
                            edges(num_edges)%y0 = y1 * scale_y + shift_y  ! p[a].y = p[k].y
                            edges(num_edges)%x1 = x0 * scale_x + shift_x  ! p[b].x = p[j].x
                            edges(num_edges)%y1 = y0 * scale_y + shift_y  ! p[b].y = p[j].y
                        end if
                    end if
                end if
            end do

            point_idx = contour_end + 1
        end do

        ! Resize to actual number of edges
        if (num_edges > 0) then
            edges = edges(1:num_edges)
            
            ! DEBUG: Log edge building results
            write(*,'(A,I0,A)') 'DEBUG EDGE BUILD: Built ', num_edges, ' edges'
            ! Show first few edges for validation
            do i = 1, min(5, num_edges)
                write(*,'(A,I0,A,F8.3,A,F8.3,A,F8.3,A,F8.3,A,I0)') &
                    'DEBUG EDGE ', i, ': y0=', edges(i)%y0, ' y1=', edges(i)%y1, &
                    ' x0=', edges(i)%x0, ' x1=', edges(i)%x1, ' invert=', edges(i)%invert
            end do
            
            ! Sort edges to match STB behavior (matches stbtt__sort_edges call in STB)
            call stb_sort_edges(edges, num_edges)
        else
            deallocate(edges)
            allocate(edges(0))
        end if

    end function stb_build_edges

    subroutine stb_sort_edges(edges, n)
        !! Sort edges by y0 coordinate (matches stbtt__sort_edges EXACTLY)
        !! STB ALWAYS runs quicksort + insertion sort for deterministic ordering
        type(stb_edge_t), intent(inout) :: edges(:)
        integer, intent(in) :: n

        ! CRITICAL FIX: Match STB exactly - always run both sorts
        ! STB runs quicksort followed by insertion sort for stable edge ordering
        call stb_sort_edges_quicksort(edges, n)
        call stb_sort_edges_ins_sort(edges, n)

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
        active_edge%direction = real(merge(-1, 1, edge%invert == 0), wp)

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

        type(stb_active_edge_t), pointer :: e
        real(wp) :: y_bottom, x0, height
        integer :: x

        y_bottom = scanline_y + 1.0_wp

        e => active_edges
        do while (associated(e))
            ! Assert that edge extends at least to scanline_y (STB requirement)
            ! This matches STBTT_assert(e->ey >= y_top) in STB
            if (e%ey <= scanline_y) then
                ! Skip edges that end before this scanline
                e => e%next
                cycle
            end if

            if (abs(e%fdx) < epsilon(1.0_wp)) then
                ! Vertical edge case (fdx == 0) - matches STB exactly
                x0 = e%fx
                if (x0 < real(width, wp)) then
                    if (x0 >= 0.0_wp) then
                        ! STB: stbtt__handle_clipped_edge(scanline,(int) x0,e, x0,y_top, x0,y_bottom);
                        call stb_handle_clipped_edge(scanline_buffer, int(x0), e, x0, scanline_y, x0, y_bottom)
                        ! STB: stbtt__handle_clipped_edge(scanline_fill-1,(int) x0+1,e, x0,y_top, x0,y_bottom);
                        ! Need to handle clipping and use logic_x = (int)x0+1, target = scanline_fill_buffer(int(x0)+1)
                        block
                            real(wp) :: adj_x0, adj_y0, adj_x1, adj_y1
                            integer :: logic_x

                            ! Same clipping logic as stb_handle_clipped_edge
                            adj_x0 = x0
                            adj_y0 = scanline_y
                            adj_x1 = x0  ! Vertical edge
                            adj_y1 = y_bottom
                            logic_x = int(x0) + 1

                            ! Clip to edge bounds (STB algorithm)
                            if (adj_y0 < e%sy) then
                                adj_x0 = adj_x0 + (adj_x1 - adj_x0) * (e%sy - adj_y0) / (adj_y1 - adj_y0)
                                adj_y0 = e%sy
                            end if
                            if (adj_y1 > e%ey) then
                                adj_x1 = adj_x1 + (adj_x1 - adj_x0) * (e%ey - adj_y1) / (adj_y1 - adj_y0)
                                adj_y1 = e%ey
                            end if

                            ! Apply STB logic with logic_x=4 to write to scanline_fill[x0]
                            if (adj_x0 <= real(logic_x, wp) .and. adj_x1 <= real(logic_x, wp)) then
                                ! x0=x1=3.5 <= logic_x=4: TRUE - first case
                                scanline_fill_buffer(int(x0) + 1) = scanline_fill_buffer(int(x0) + 1) + &
                                    e%direction * (adj_y1 - adj_y0)
                            else if (adj_x0 >= real(logic_x + 1, wp) .and. adj_x1 >= real(logic_x + 1, wp)) then
                                ! No contribution
                                continue
                            else
                                ! Coverage calculation
                                scanline_fill_buffer(int(x0) + 1) = scanline_fill_buffer(int(x0) + 1) + &
                                    e%direction * (adj_y1 - adj_y0) * &
                                    (1.0_wp - ((adj_x0 - real(logic_x, wp)) + (adj_x1 - real(logic_x, wp))) * 0.5_wp)
                            end if
                        end block
                    else
                        ! STB: stbtt__handle_clipped_edge(scanline_fill-1,0,e, x0,y_top, x0,y_bottom);
                        ! This calls handle_clipped_edge with scanline_fill and x = 0
                        call stb_handle_clipped_edge(scanline_fill_buffer, 0, e, x0, scanline_y, x0, y_bottom)
                    end if
                end if
            else
                ! Non-vertical edge - use full STB algorithm
                call stb_process_non_vertical_edge(scanline_buffer, scanline_fill_buffer, width, &
                                                 e, scanline_y, y_bottom)
            end if

            e => e%next
        end do

    end subroutine stb_fill_active_edges

    subroutine stb_fill_active_edges_with_offset(active_edges, scanline_y, width, scanline_buffer, scanline_fill_buffer)
        !! Fill a scanline with offset pattern for stb_rasterize_sorted_edges context
        !! Handles STB's scanline2+1 buffer offset pattern
        type(stb_active_edge_t), pointer, intent(in) :: active_edges
        real(wp), intent(in) :: scanline_y
        integer, intent(in) :: width
        real(wp), intent(inout) :: scanline_buffer(:)
        real(wp), intent(inout) :: scanline_fill_buffer(:)

        type(stb_active_edge_t), pointer :: e
        real(wp) :: y_bottom, x0, height
        integer :: x

        y_bottom = scanline_y + 1.0_wp

        e => active_edges
        do while (associated(e))
            ! Assert that edge extends at least to scanline_y (STB requirement)
            if (e%ey <= scanline_y) then
                e => e%next
                cycle
            end if

            if (abs(e%fdx) < epsilon(1.0_wp)) then
                ! Vertical edge case (fdx == 0) - matches STB exactly
                x0 = e%fx
                if (x0 < real(width, wp)) then
                    if (x0 >= 0.0_wp) then
                        ! STB: stbtt__handle_clipped_edge(scanline,(int) x0,e, x0,y_top, x0,y_bottom);
                        call stb_handle_clipped_edge(scanline_buffer, int(x0), e, x0, scanline_y, x0, y_bottom)
                        ! STB: stbtt__handle_clipped_edge(scanline_fill-1,(int) x0+1,e, x0,y_top, x0,y_bottom);
                        ! STB effective index: scanline_fill-1[(int) x0+1] = scanline_fill[x0]
                        ! ForTTF equivalent with 1-based indexing: scanline_fill_buffer[int(x0) + 1]
                        ! CRITICAL FIX: Use int(x0) + 1 to match STB's effective x0 index
                        if (int(x0) + 1 <= width) then
                            call stb_handle_clipped_edge(scanline_fill_buffer, int(x0) + 1, e, x0, scanline_y, x0, y_bottom)
                        end if
                    else
                        ! STB: stbtt__handle_clipped_edge(scanline2+1-1,0,e, x0,y_top, x0,y_bottom);
                        call stb_handle_clipped_edge(scanline_fill_buffer, 0, e, x0, scanline_y, x0, y_bottom)
                    end if
                end if
            else
                ! Non-vertical edge - implement full STB algorithm
                x0 = e%fx
                height = min(e%ey, y_bottom) - max(e%sy, scanline_y)
                if (height > 0.0_wp) then
                    call stb_process_non_vertical_edge(scanline_buffer, scanline_fill_buffer, width, &
                                                     e, scanline_y, y_bottom)
                end if
            end if

            e => e%next
        end do

    end subroutine stb_fill_active_edges_with_offset

    subroutine stb_process_non_vertical_edge(scanline_buffer, scanline_fill_buffer, width, &
                                           active_edge, y_top, y_bottom)
        !! Process non-vertical edges with EXACT STB implementation
        !! Implements complete stbtt__fill_active_edges_new logic including clipping
        real(wp), intent(inout) :: scanline_buffer(:), scanline_fill_buffer(:)
        integer, intent(in) :: width
        type(stb_active_edge_t), intent(in) :: active_edge
        real(wp), intent(in) :: y_top, y_bottom

        real(wp) :: x0, dx, xb, x_top, x_bottom, sy0, sy1, dy
        real(wp) :: y_crossing, y_final, step, sign, area, height, t
        integer :: x, x1, x2

        x0 = active_edge%fx
        dx = active_edge%fdx
        xb = x0 + dx
        dy = active_edge%fdy

        ! DEBUG: Log input parameters
        if (active_edge%fx > 0.0_wp .and. active_edge%fx < 20.0_wp) then
            write(*,'(A,F12.6,A,F12.6,A,F8.3,A,F8.3)') &
                'DEBUG NON-VERTICAL: x0=', x0, ' dx=', dx, ' y_top=', y_top, ' y_bottom=', y_bottom
        end if

        ! Compute endpoints of line segment clipped to this scanline
        ! Use 32-bit precision to exactly match STB float arithmetic
        if (active_edge%sy > y_top) then
            x_top = real(real(x0, real32) + real(dx, real32) * (real(active_edge%sy, real32) - real(y_top, real32)), wp)
            sy0 = active_edge%sy
        else
            x_top = x0
            sy0 = y_top
        end if

        if (active_edge%ey < y_bottom) then
            x_bottom = real(real(x0, real32) + real(dx, real32) * (real(active_edge%ey, real32) - real(y_top, real32)), wp)
            sy1 = active_edge%ey
        else
            x_bottom = xb
            sy1 = y_bottom
        end if

        ! DEBUG: Log computed coordinates
        if (active_edge%fx > 0.0_wp .and. active_edge%fx < 20.0_wp) then
            write(*,'(A,F12.6,A,F12.6,A,F8.3,A,F8.3)') &
                'DEBUG COORDS: x_top=', x_top, ' x_bottom=', x_bottom, ' sy0=', sy0, ' sy1=', sy1
        end if

        ! EXACT STB bounds check - use STB's exact condition  
        if (x_top >= 0.0_wp .and. x_bottom >= 0.0_wp .and. &
            x_top < real(width, wp) .and. x_bottom < real(width, wp)) then
            ! Fast path - exact STB algorithm

            if (int(x_top) == int(x_bottom)) then
                ! Simple case, only spans one pixel
                x = int(x_top)
                height = (sy1 - sy0) * active_edge%direction
                area = stb_position_trapezoid_area(height, x_top, real(x + 1, wp), x_bottom, real(x + 1, wp))
                
                ! DEBUG: Log single pixel coverage
                if (active_edge%fx > 0.0_wp .and. active_edge%fx < 20.0_wp) then
                    write(*,'(A,I3,A,F12.8,A,F12.8)') &
                        'DEBUG SINGLE: x=', x, ' area=', area, ' height=', height
                end if
                
                scanline_buffer(x + 1) = scanline_buffer(x + 1) + area
                scanline_fill_buffer(x + 1) = scanline_fill_buffer(x + 1) + height
            else
                ! Covers 2+ pixels
                if (x_top > x_bottom) then
                    ! Flip scanline vertically; signed area is the same
                    sy0 = y_bottom - (sy0 - y_top)
                    sy1 = y_bottom - (sy1 - y_top)
                    t = sy0; sy0 = sy1; sy1 = t
                    t = x_bottom; x_bottom = x_top; x_top = t
                    dx = -dx
                    dy = -dy
                    t = x0; x0 = xb; xb = t
                end if

                x1 = int(x_top)
                x2 = int(x_bottom)

                y_crossing = y_top + dy * (real(x1 + 1, wp) - x0)
                y_final = y_top + dy * (real(x2, wp) - x0)

                if (y_crossing > y_bottom) y_crossing = y_bottom
                if (y_final > y_bottom) then
                    y_final = y_bottom
                    if (x2 - (x1 + 1) > 0) then
                        dy = (y_final - y_crossing) / real(x2 - (x1 + 1), wp)
                    end if
                end if

                sign = active_edge%direction
                area = sign * (y_crossing - sy0)

                scanline_buffer(x1 + 1) = scanline_buffer(x1 + 1) + &
                    stb_sized_triangle_area(area, real(x1 + 1, wp) - x_top)

                step = sign * dy
                do x = x1 + 1, x2 - 1
                    scanline_buffer(x + 1) = scanline_buffer(x + 1) + area + step * 0.5_wp
                    area = area + step
                end do

                scanline_buffer(x2 + 1) = scanline_buffer(x2 + 1) + area + &
                    sign * stb_position_trapezoid_area(sy1 - y_final, real(x2, wp), real(x2 + 1, wp), &
                                                     x_bottom, real(x2 + 1, wp))
                ! STB L3228: scanline_fill[x2] += sign * (sy1-sy0);
                scanline_fill_buffer(x2 + 1) = scanline_fill_buffer(x2 + 1) + sign * (sy1 - sy0)
            end if
        else
            ! Slow path - STB brute force clipping algorithm  
            ! STB brute force clipping - no additional boundary check needed
            call stb_brute_force_edge_clipping(scanline_buffer, scanline_fill_buffer, width, &
                                             active_edge, y_top, y_bottom, x0, dx, xb)
        end if

    end subroutine stb_process_non_vertical_edge

    subroutine stb_brute_force_edge_clipping(scanline_buffer, scanline_fill_buffer, width, &
                                           active_edge, y_top, y_bottom, x0, dx, xb)
        !! EXACT STB brute force clipping algorithm
        !! Implements stbtt__fill_active_edges_new slow path lines 3238-3294
        real(wp), intent(inout) :: scanline_buffer(:), scanline_fill_buffer(:)
        integer, intent(in) :: width
        type(stb_active_edge_t), intent(in) :: active_edge
        real(wp), intent(in) :: y_top, y_bottom, x0, dx, xb

        integer :: x
        real(wp) :: x1, x2, x3, y0, y3, y1, y2

        ! STB brute force - process every pixel, but ensure we don't exceed bounds
        do x = 0, width - 1
            ! Exact STB variable assignments
            y0 = y_top
            x1 = real(x, wp)
            x2 = real(x + 1, wp)
            x3 = xb
            y3 = y_bottom

            ! Exact STB intersection calculation
            ! y = (x - e->x) / e->dx + y_top
            y1 = (x1 - x0) / dx + y_top
            y2 = (x2 - x0) / dx + y_top

            ! STB clipping logic - exact conditional structure
            if (x0 < x1 .and. x3 > x2) then
                ! Three segments descending down-right
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x0, y0, x1, y1)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x1, y1, x2, y2)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x2, y2, x3, y3)
            else if (x3 < x1 .and. x0 > x2) then
                ! Three segments descending down-left
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x0, y0, x2, y2)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x2, y2, x1, y1)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x1, y1, x3, y3)
            else if (x0 < x1 .and. x3 > x1) then
                ! Two segments across x, down-right
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x0, y0, x1, y1)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x1, y1, x3, y3)
            else if (x3 < x1 .and. x0 > x1) then
                ! Two segments across x, down-left
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x0, y0, x1, y1)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x1, y1, x3, y3)
            else if (x0 < x2 .and. x3 > x2) then
                ! Two segments across x+1, down-right
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x0, y0, x2, y2)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x2, y2, x3, y3)
            else if (x3 < x2 .and. x0 > x2) then
                ! Two segments across x+1, down-left
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x0, y0, x2, y2)
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x2, y2, x3, y3)
            else
                ! One segment
                call stb_handle_clipped_edge(scanline_buffer, x, active_edge, x0, y0, x3, y3)
            end if
        end do

    end subroutine stb_brute_force_edge_clipping

    subroutine stb_rasterize(result, points, contour_lengths, num_contours, &
                           scale_x, scale_y, shift_x, shift_y, off_x, off_y, invert, userdata)
        !! Main rasterization function (matches stbtt__rasterize exactly)
        type(stb_bitmap_t), intent(inout) :: result
        type(stb_point_t), intent(in) :: points(:)
        integer, intent(in) :: contour_lengths(:), num_contours
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: off_x, off_y
        logical, intent(in) :: invert
        type(c_ptr), intent(in) :: userdata

        real(wp) :: y_scale_inv
        type(stb_edge_t), allocatable :: edges(:)
        integer :: n, i, j, k, vsubsample
        integer :: edge_count, point_idx
        integer :: a, b

        ! STB: float y_scale_inv = invert ? -scale_y : scale_y;
        y_scale_inv = merge(-scale_y, scale_y, invert)

        ! STB: int vsubsample = 1; (STBTT_RASTERIZER_VERSION == 2)
        vsubsample = 1

        ! Use stb_build_edges but apply y_scale_inv and vsubsample manually
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               scale_x, y_scale_inv, shift_x, shift_y, invert)
        edge_count = size(edges)

        ! Apply vsubsample to y-coordinates (STB does this after scaling)
        do i = 1, edge_count
            edges(i)%y0 = edges(i)%y0 * real(vsubsample, wp)
            edges(i)%y1 = edges(i)%y1 * real(vsubsample, wp)
        end do

        ! Sort edges by highest point
        call stb_sort_edges(edges, edge_count)

        ! Rasterize sorted edges
        call stb_rasterize_sorted_edges(result, edges, edge_count, vsubsample, off_x, off_y, userdata)

        deallocate(edges)

    end subroutine stb_rasterize

    subroutine stbtt_rasterize(result, flatness_in_pixels, vertices, num_verts, &
                              scale_x, scale_y, shift_x, shift_y, x_off, y_off, invert, userdata)
        !! Main rasterization entry point (matches stbtt_Rasterize exactly)
        type(stb_bitmap_t), intent(inout) :: result
        real(wp), intent(in) :: flatness_in_pixels
        type(ttf_vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_verts
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: x_off, y_off
        logical, intent(in) :: invert
        type(c_ptr), intent(in) :: userdata

        real(wp) :: scale, objspace_flatness
        type(stb_point_t), allocatable :: windings(:)
        integer, allocatable :: winding_lengths(:)
        integer :: winding_count

        write(*,*) "DEBUG stbtt_rasterize: received x_off=", x_off, " y_off=", y_off
        write(*,*) "DEBUG stbtt_rasterize: bitmap dimensions=", result%w, "x", result%h

        ! STB: float scale = scale_x > scale_y ? scale_y : scale_x;
        scale = min(scale_x, scale_y)

        ! Calculate objspace flatness
        objspace_flatness = flatness_in_pixels / scale

        ! Flatten curves
        windings = stb_flatten_curves(vertices, num_verts, objspace_flatness, &
                                     winding_lengths, winding_count)

        if (allocated(windings)) then
            write(*,*) "DEBUG stbtt_rasterize: calling stb_rasterize with x_off=", x_off, " y_off=", y_off
            call stb_rasterize(result, windings, winding_lengths, winding_count, &
                              scale_x, scale_y, shift_x, shift_y, x_off, y_off, invert, userdata)
            deallocate(winding_lengths, windings)
        end if

    end subroutine stbtt_rasterize

    subroutine stb_rasterize_sorted_edges(result, e, n, vsubsample, off_x, off_y, userdata)
        type(stb_bitmap_t), intent(inout) :: result
        type(stb_edge_t), intent(in) :: e(:)
        integer, intent(in) :: n
        integer, intent(in) :: vsubsample ! Unused in current implementation
        integer, intent(in) :: off_x, off_y
        type(c_ptr), intent(in) :: userdata ! Unused in current implementation

        type(stb_active_edge_t), pointer :: active_head
        type(stb_active_edge_t), pointer :: new_edge_ptr
        real(wp), allocatable :: scanline_buffer(:)
        real(wp), allocatable :: scanline_fill_buffer(:)
        logical :: has_nonzero
        integer(c_int8_t), pointer :: bitmap_array(:)
        integer :: y, edge_idx, i
        real(wp) :: scan_y_top, scan_y_bottom, sum_val, k_val
        integer :: m_val

        write(*,*) "DEBUG stb_rasterize_sorted_edges: received off_x=", off_x, " off_y=", off_y
        write(*,*) "DEBUG stb_rasterize_sorted_edges: bitmap dimensions=", result%w, "x", result%h, " stride=", result%stride

        ! Initialize active edge list (dummy head)
        allocate(active_head)
        active_head%next => null()

        ! Allocate scanline buffers - exact STB sizing
        allocate(scanline_buffer(result%w))
        allocate(scanline_fill_buffer(result%w))

        ! Clear bitmap to background (matches STB)
        result%pixels = 0_c_int8_t

        ! Associate bitmap_array with result%pixels
        call c_f_pointer(c_loc(result%pixels(1)), bitmap_array, [result%w * result%h])

        edge_idx = 1
        do y = 0, result%h - 1
            scanline_buffer = 0.0_wp
            scanline_fill_buffer = 0.0_wp

            ! Apply off_y offset to match STB's coordinate system
            ! STB: y = off_y; scan_y_top = y + 0.0f
            scan_y_top = real(y + off_y, wp) + 0.0_wp
            scan_y_bottom = real(y + off_y, wp) + 1.0_wp

            if (y < 3) then  ! Debug first few scanlines
                write(*,*) "DEBUG scanline y=", y, " scan_y_top=", scan_y_top, " off_y=", off_y
            end if

            ! Remove all active edges that terminate before the top of this scanline
            call stb_remove_completed_edges(active_head, scan_y_top)

            ! Insert all edges that start before the bottom of this scanline
            ! Fix bounds checking - ensure edge_idx doesn't exceed array bounds
            do while (edge_idx <= n)
                if (e(edge_idx)%y0 > scan_y_bottom) exit  ! STB-style early exit
                if (e(edge_idx)%y0 /= e(edge_idx)%y1) then
                    allocate(new_edge_ptr)
                    new_edge_ptr = stb_new_active_edge(e(edge_idx), off_x, scan_y_top)
                    if (edge_idx <= 3) then  ! Debug first few edges
                        write(*,*) "DEBUG edge", edge_idx, ": y0=", e(edge_idx)%y0, " y1=", e(edge_idx)%y1
                        write(*,*) "DEBUG edge", edge_idx, ": sy=", new_edge_ptr%sy, " ey=", new_edge_ptr%ey
                        write(*,*) "DEBUG edge", edge_idx, ": scan_y_top=", scan_y_top, " off_x=", off_x
                    end if
                    ! STB: if (j == 0 && off_y != 0) { if (z->ey < scan_y_top) z->ey = scan_y_top; }
                    if (y == 0 .and. off_y /= 0) then
                        if (new_edge_ptr%ey < scan_y_top) then
                            if (edge_idx <= 3) then
                                write(*,*) "DEBUG extending edge", edge_idx, " ey from", new_edge_ptr%ey, " to", scan_y_top
                            end if
                            new_edge_ptr%ey = scan_y_top
                        end if
                    end if
                    ! CRITICAL FIX: STB inserts at FRONT (LIFO), not sorted order
                    ! STB: z->next = active; active = z;
                    new_edge_ptr%next => active_head%next
                    active_head%next => new_edge_ptr
                end if
                edge_idx = edge_idx + 1
            end do

            ! Process all active edges (matches STB scanline_fill-1 pattern)
            if (associated(active_head%next)) then
                
                call stb_fill_active_edges_with_offset(active_head%next, scan_y_top, &
     &                                                 result%w, scanline_buffer, scanline_fill_buffer)
            end if

            ! DEBUG: Removed excessive buffer debug output

            sum_val = 0.0_wp
            do i = 0, result%w - 1
                sum_val = sum_val + scanline_fill_buffer(i + 1)
                k_val = scanline_buffer(i + 1) + sum_val
                
                
                k_val = abs(k_val) * 255.0_wp + 0.5_wp
                m_val = int(k_val)
                if (m_val > 255) m_val = 255
                
                if (m_val < 0) m_val = 0  ! Ensure non-negative values for bitmap
                
                ! DEBUG: Log pixel conversion for analysis (limited to avoid spam)
                if (y <= 5 .and. i <= 15 .and. m_val /= 0) then
                    write(*,'(A,I0,A,I0,A,F12.8,A,I0)') &
                        'DEBUG PIXEL y=', y, ' x=', i, ' coverage=', k_val/255.0_wp, ' pixel=', m_val
                end if
                
                ! Keep Y coordinate flipping for our coordinate system
                ! Convert 0-255 range to c_int8_t, handling unsigned->signed mapping
                ! STB uses unsigned char, we use signed c_int8_t, so values 128-255 become negative
                bitmap_array((result%h - 1 - y) * result%stride + i + 1) = int(m_val, c_int8_t)
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

        ! Use 32-bit precision arithmetic to exactly match STB's float calculations
        real(real32) :: h32, tw32, bw32, a32
        real(real32) :: safe_top_width, safe_bottom_width
        
        ! Convert to 32-bit precision
        h32 = real(height, real32)
        tw32 = real(top_width, real32)
        bw32 = real(bottom_width, real32)
        
        ! STB assertions: ensure widths are non-negative
        safe_top_width = max(0.0_real32, tw32)
        safe_bottom_width = max(0.0_real32, bw32)

        ! STB algorithm: (top_width + bottom_width) / 2.0 * height
        ! Use exact 32-bit float arithmetic to match STB
        a32 = (safe_top_width + safe_bottom_width) * 0.5_real32 * h32

        ! STB bounds check: STBTT_assert(STBTT_fabs(area) <= 1.01f)
        a32 = max(-1.01_real32, min(1.01_real32, a32))

        ! Convert back to working precision
        area = real(a32, wp)

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

        ! Use 32-bit precision arithmetic to exactly match STB's float calculations
        real(real32) :: h32, w32, a32
        
        ! Convert to 32-bit precision
        h32 = real(height, real32)
        w32 = real(width, real32)

        ! STB algorithm: height * width / 2
        ! Use exact 32-bit float arithmetic to match STB
        a32 = h32 * w32 * 0.5_real32

        ! STB bounds check: STBTT_assert(STBTT_fabs(area) <= 1.01f)
        a32 = max(-1.01_real32, min(1.01_real32, a32))

        ! Convert back to working precision
        area = real(a32, wp)

    end function stb_sized_triangle_area

    subroutine stb_handle_clipped_edge_with_offset(scanline, target_idx, logic_x, e, x0, y0, x1, y1)
        !! Handle edges with separate target index and logic x (for scanline_fill-1 case)
        real(wp), intent(inout) :: scanline(:)
        integer, intent(in) :: target_idx, logic_x
        type(stb_active_edge_t), intent(in) :: e
        real(wp), intent(in) :: x0, y0, x1, y1

        real(wp) :: adj_x0, adj_y0, adj_x1, adj_y1

        ! Early exit for horizontal edges (matches STB)
        if (abs(y1 - y0) < epsilon(1.0_wp)) return

        ! Ensure y0 < y1 (STB assertion)
        if (y0 >= y1) return

        ! Check edge bounds (STB assertions)
        if (e%sy > e%ey) return
        if (y0 > e%ey) return
        if (y1 < e%sy) return

        ! Clip to edge bounds (exact STB algorithm)
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

        ! Apply STB logic with logic_x but write to target_idx
        if (adj_x0 <= real(logic_x, wp) .and. adj_x1 <= real(logic_x, wp)) then
            ! Both endpoints left of pixel
            scanline(target_idx) = scanline(target_idx) + e%direction * (adj_y1 - adj_y0)
        else if (adj_x0 >= real(logic_x + 1, wp) .and. adj_x1 >= real(logic_x + 1, wp)) then
            ! Both endpoints right of pixel - no contribution
            return
        else
            ! Edge crosses pixel - STB coverage calculation
            ! coverage = 1 - average x position
            scanline(target_idx) = scanline(target_idx) + e%direction * (adj_y1 - adj_y0) * &
                             (1.0_wp - ((adj_x0 - real(logic_x, wp)) + (adj_x1 - real(logic_x, wp))) * 0.5_wp)
        end if

    end subroutine stb_handle_clipped_edge_with_offset

    subroutine stb_handle_clipped_edge(scanline, x, e, x0, y0, x1, y1)
        !! Handle edges that are clipped at scanline boundaries (matches stbtt__handle_clipped_edge)
        real(wp), intent(inout) :: scanline(:)
        integer, intent(in) :: x
        type(stb_active_edge_t), intent(in) :: e
        real(wp), intent(in) :: x0, y0, x1, y1

        real(wp) :: adj_x0, adj_y0, adj_x1, adj_y1


        ! Early exit for horizontal edges (matches STB)
        if (abs(y1 - y0) < epsilon(1.0_wp)) return

        ! Ensure y0 < y1 (STB assertion)
        if (y0 >= y1) return

        ! Check edge bounds (STB assertions)
        if (e%sy > e%ey) return
        if (y0 > e%ey) return
        if (y1 < e%sy) return

        ! Clip to edge bounds (exact STB algorithm)
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

        ! Apply STB logic exactly
        if (adj_x0 <= real(x, wp) .and. adj_x1 <= real(x, wp)) then
            ! Both endpoints left of pixel
            scanline(x + 1) = scanline(x + 1) + e%direction * (adj_y1 - adj_y0)
        else if (adj_x0 >= real(x + 1, wp) .and. adj_x1 >= real(x + 1, wp)) then
            ! Both endpoints right of pixel - no contribution
            return
        else
            ! Edge crosses pixel - STB coverage calculation
            ! coverage = 1 - average x position
            scanline(x + 1) = scanline(x + 1) + e%direction * (adj_y1 - adj_y0) * &
                             (1.0_wp - ((adj_x0 - real(x, wp)) + (adj_x1 - real(x, wp))) * 0.5_wp)
        end if

    end subroutine stb_handle_clipped_edge

end module forttf_stb_raster
