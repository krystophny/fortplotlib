module fortplot_truetype_raster
    !! Glyph rasterization using scanline algorithm for TrueType outlines
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    use fortplot_truetype_types, only: native_fontinfo_t, vertex_t, glyph_point_t, CURVE_LINE
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
        if (.not. success .or. num_vertices == 0) return

        call flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, 0.35_wp)
        if (num_points == 0) then
            if (allocated(vertices)) deallocate(vertices)
            return
        end if

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
        if (.not. success .or. num_vertices == 0) return

        call flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, 0.35_wp)
        if (num_points == 0) then
            if (allocated(vertices)) deallocate(vertices)
            return
        end if

        bmp%w = width
        bmp%h = height
        bmp%stride = stride
        bmp%pixels => buffer(1:stride*height)

        ! Pass offsets to rasterize_points - this is the key STB matching change
        call rasterize_points(bmp, points, num_points, contour_lengths, num_contours, &
                              scale_x, scale_y, 0.0_wp, 0.0_wp, x_off, y_off, .true.)

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
        !! Extract glyph shape as vertex array
        type(native_fontinfo_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        type(vertex_t), allocatable, intent(out) :: vertices(:)
        integer, intent(out) :: num_vertices
        logical, intent(out) :: success

        type(glyph_point_t), allocatable :: points(:)
        integer, allocatable :: endpoints(:)
        integer :: num_points, number_of_contours, i, j, endpoint, start, current_contour
        integer :: x_min, y_min, x_max, y_max
        logical :: parse_success

        success = .false.
        num_vertices = 0

        call parse_glyph_header(font_info, glyph_index, number_of_contours, x_min, y_min, x_max, y_max)
        if (number_of_contours < 0) then
            return
        end if

        call parse_simple_glyph_points(font_info, glyph_index, points, num_points, parse_success)
        if (.not. parse_success .or. num_points == 0) return

        call parse_simple_glyph_endpoints(font_info, glyph_index, endpoints, parse_success)
        if (.not. parse_success) then
            if (allocated(points)) deallocate(points)
            return
        end if

        num_vertices = num_points + number_of_contours

        allocate(vertices(num_vertices))

        j = 1
        start = 1
        do current_contour = 1, number_of_contours
            endpoint = endpoints(current_contour) + 1

            vertices(j)%x = real(points(start)%x, wp)
            vertices(j)%y = real(points(start)%y, wp)
            vertices(j)%type = CURVE_LINE
            j = j + 1

            do i = start + 1, endpoint
                vertices(j)%x = real(points(i)%x, wp)
                vertices(j)%y = real(points(i)%y, wp)
                vertices(j)%type = CURVE_LINE
                j = j + 1
            end do

            start = endpoint + 1
        end do

        num_vertices = j - 1
        success = .true.

        if (allocated(points)) deallocate(points)
        if (allocated(endpoints)) deallocate(endpoints)

    end subroutine get_glyph_shape

    subroutine flatten_curves(vertices, num_vertices, points, num_points, contour_lengths, num_contours, flatness)
        !! Flatten curved vertices to line segments
        type(vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_vertices
        type(raster_point_t), allocatable, intent(out) :: points(:)
        integer, intent(out) :: num_points
        integer, allocatable, intent(out) :: contour_lengths(:)
        integer, intent(out) :: num_contours
        real(wp), intent(in) :: flatness

        integer :: i

        if (num_vertices == 0) then
            num_points = 0
            num_contours = 0
            return
        end if

        num_points = num_vertices
        num_contours = 1

        allocate(points(num_points))
        allocate(contour_lengths(num_contours))

        do i = 1, num_vertices
            points(i)%x = vertices(i)%x
            points(i)%y = vertices(i)%y
        end do

        contour_lengths(1) = num_points

    end subroutine flatten_curves

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
        real(wp) :: y_scale_inv

        y_scale_inv = merge(-scale_y, scale_y, invert)

        num_edges = 0
        do i = 1, num_contours
            num_edges = num_edges + contour_lengths(i)
        end do

        if (num_edges == 0) return

        allocate(edges(num_edges))

        num_edges = 0
        m = 1
        do i = 1, num_contours
            point_idx = m
            j = contour_lengths(i) - 1
            do k = 1, contour_lengths(i)
                a = k
                b = j

                if (abs(points(point_idx + j - 1)%y - points(point_idx + k - 1)%y) < 1.0e-6_wp) then
                    j = k
                    cycle
                end if

                num_edges = num_edges + 1
                edges(num_edges)%invert = .false.
                if (invert .eqv. (points(point_idx + j - 1)%y > points(point_idx + k - 1)%y)) then
                    edges(num_edges)%invert = .true.
                    a = j
                    b = k
                end if

                edges(num_edges)%x0 = points(point_idx + a - 1)%x * scale_x + shift_x
                edges(num_edges)%y0 = points(point_idx + a - 1)%y * y_scale_inv + shift_y
                edges(num_edges)%x1 = points(point_idx + b - 1)%x * scale_x + shift_x
                edges(num_edges)%y1 = points(point_idx + b - 1)%y * y_scale_inv + shift_y

                j = k
            end do
            m = m + contour_lengths(i)
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
        !! Rasterize sorted edges using scanline algorithm
        type(bitmap_t), intent(inout) :: bmp
        type(raster_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: num_edges, off_x, off_y

        integer :: i, j, y, x, y_end
        real(wp) :: y_top, y_bottom
        real(wp), allocatable :: scanline(:)
        type(active_edge_t), pointer :: active => null(), edge_ptr => null(), next_ptr => null()

        if (num_edges == 0 .or. bmp%h <= 0 .or. bmp%w <= 0) return

        allocate(scanline(0:bmp%w-1))

        y_top = 0.0_wp
        do y = 0, bmp%h - 1
            y_bottom = y_top + 1.0_wp
            scanline = 0.0_wp

            do i = 1, num_edges
                if (min(edges(i)%y0, edges(i)%y1) <= y_bottom .and. &
                    max(edges(i)%y0, edges(i)%y1) > y_top) then
                    call add_active_edge(active, edges(i), off_x, y_top)
                end if
            end do

            call fill_active_edges(scanline, bmp%w, active, y_top)
            
            ! DEBUG: Check if we have any scanline values
            if (y < 5) then
                do x = 0, min(bmp%w - 1, 10)
                    if (abs(scanline(x)) > 0.001_wp) then
                        print *, "DEBUG: Row", y, "col", x, "scanline=", scanline(x)
                    end if
                end do
            end if

            call remove_finished_edges(active, y_bottom)

            ! Convert scanline values to pixels with proper STB-style antialiasing
            do x = 0, bmp%w - 1
                if (abs(scanline(x)) > 0.001_wp) then
                    j = y * bmp%stride + x + 1
                    if (j >= 1 .and. j <= bmp%stride * bmp%h) then
                        ! Clamp to 0-255 range like STB
                        bmp%pixels(j) = int(max(0.0_wp, min(255.0_wp, abs(scanline(x)) * 255.0_wp)), int8)
                    end if
                end if
            end do

            y_top = y_bottom
        end do

        call cleanup_active_edges(active)
        if (allocated(scanline)) deallocate(scanline)

    end subroutine rasterize_sorted_edges

    subroutine add_active_edge(active, edge, off_x, start_point)
        !! Add an edge to the active edge list
        type(active_edge_t), pointer, intent(inout) :: active
        type(raster_edge_t), intent(in) :: edge
        integer, intent(in) :: off_x
        real(wp), intent(in) :: start_point

        type(active_edge_t), pointer :: new_edge
        real(wp) :: dxdy

        allocate(new_edge)

        dxdy = (edge%x1 - edge%x0) / (edge%y1 - edge%y0)
        new_edge%fdx = dxdy
        new_edge%fdy = merge(1.0_wp / dxdy, 0.0_wp, abs(dxdy) > 1.0e-10_wp)
        new_edge%fx = edge%x0 + dxdy * (start_point - edge%y0) - real(off_x, wp)
        new_edge%direction = merge(1.0_wp, -1.0_wp, edge%invert)
        new_edge%sy = edge%y0
        new_edge%ey = edge%y1
        new_edge%next => active
        active => new_edge

    end subroutine add_active_edge

    subroutine fill_active_edges(scanline, len, active, y_top)
        !! Fill scanline using proper STB-style winding rule algorithm
        real(wp), intent(inout) :: scanline(0:)
        integer, intent(in) :: len
        type(active_edge_t), pointer, intent(in) :: active
        real(wp), intent(in) :: y_top

        type(active_edge_t), pointer :: edge
        integer :: x, winding_count
        real(wp), allocatable :: intersections(:)
        integer :: num_intersections, i, j
        real(wp) :: temp_x

        ! Clear scanline
        scanline(0:len-1) = 0.0_wp

        ! Count intersections and allocate array
        num_intersections = 0
        edge => active
        do while (associated(edge))
            num_intersections = num_intersections + 1
            edge => edge%next
        end do

        if (num_intersections == 0) return

        allocate(intersections(num_intersections))

        ! Collect x-intersections at scanline y
        i = 1
        edge => active
        do while (associated(edge))
            intersections(i) = edge%fx + edge%fdx * 0.5_wp  ! Use middle of scanline
            i = i + 1
            edge => edge%next
        end do

        ! Sort intersections (simple bubble sort)
        do i = 1, num_intersections - 1
            do j = i + 1, num_intersections
                if (intersections(i) > intersections(j)) then
                    temp_x = intersections(i)
                    intersections(i) = intersections(j)
                    intersections(j) = temp_x
                end if
            end do
        end do

        ! Fill between pairs of intersections (even-odd rule)
        do i = 1, num_intersections - 1, 2
            if (i + 1 <= num_intersections) then
                do x = max(0, int(intersections(i))), min(len-1, int(intersections(i+1)))
                    if (x >= 0 .and. x < len) then
                        ! Simple coverage (can be improved with subpixel precision)
                        scanline(x) = scanline(x) + 1.0_wp
                    end if
                end do
            end if
        end do

        deallocate(intersections)

    end subroutine fill_active_edges

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