module forttf_outline
    !! Pure Fortran implementation of TrueType glyph outline parsing (derived from stb_truetype.h)
    !! Handles parsing of glyph outlines from the glyf table into vertex arrays
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_glyph_parser
    use forttf_mapping
    use forttf_file_io, only: read_be_uint16
    implicit none

    private

    ! Public interface for glyph outline parsing
    public :: stb_get_glyph_shape_pure
    public :: stb_get_codepoint_shape_pure
    public :: stb_free_shape_pure


contains

    function stb_get_codepoint_shape_pure(font_info, codepoint, vertices) result(num_vertices)
        !! Get glyph outline vertices for a codepoint
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        type(ttf_vertex_t), allocatable, intent(out) :: vertices(:)
        integer :: num_vertices
        integer :: glyph_index

        if (.not. font_info%initialized) then
            num_vertices = 0
            return
        end if

        ! Get glyph index for codepoint
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)
        if (glyph_index == 0) then
            num_vertices = 0
            return
        end if

        ! Delegate to glyph function
        num_vertices = stb_get_glyph_shape_pure(font_info, glyph_index, vertices)

    end function stb_get_codepoint_shape_pure

    recursive function stb_get_glyph_shape_pure(font_info, glyph_index, vertices) result(num_vertices)
        !! Get glyph outline vertices for a glyph index
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        type(ttf_vertex_t), allocatable, intent(out) :: vertices(:)
        integer :: num_vertices

        ! --- Parameter declarations must be at the top ---
        integer, parameter :: ARG_1_AND_2_ARE_WORDS = 1
        integer, parameter :: MORE_COMPONENTS = 32

        type(ttf_glyf_header_t) :: glyph_header
        logical :: success
        integer :: glyf_table_idx, i
        ! Composite glyph variables (must be declared at top)
        integer :: comp_offset, flags, comp_glyph_idx, comp_num_vertices, comp_count
        type(ttf_vertex_t), allocatable :: comp_vertices(:)
        integer :: comp_vertices_start, comp_vertices_end

        num_vertices = 0

        if (.not. font_info%initialized) then
            return
        end if

        ! Find glyf table
        glyf_table_idx = 0
        do i = 1, size(font_info%tables)
            if (font_info%tables(i)%tag == 'glyf') then
                glyf_table_idx = i
                exit
            end if
        end do

        if (glyf_table_idx == 0) then
            ! No glyf table found
            return
        end if

        ! Parse glyph header to check if glyph exists
        if (glyph_index <= 0 .or. glyph_index > size(font_info%loca_table%offsets) - 1) then
            return
        end if

        success = parse_glyf_header(font_info%font_data, &
                                   font_info%tables(glyf_table_idx)%offset, &
                                   font_info%loca_table%offsets(glyph_index + 1), &
                                   glyph_header)
        if (.not. success) then
            return
        end if

        ! Parse the actual glyph outline
        if (glyph_header%num_contours >= 0) then
            ! Simple glyph
            num_vertices = parse_simple_glyph(font_info, glyf_table_idx, glyph_index, glyph_header, vertices)
        else
            ! Composite glyph: recursively collect outlines from components
            comp_offset = font_info%tables(glyf_table_idx)%offset + font_info%loca_table%offsets(glyph_index + 1) + 10
            num_vertices = 0
            comp_count = 0
            do
                ! Read flags and glyph index
                flags = read_be_uint16(font_info%font_data, comp_offset)
                comp_glyph_idx = read_be_uint16(font_info%font_data, comp_offset + 2)
                comp_offset = comp_offset + 4
                ! TODO: handle arguments, transforms, etc. For now, ignore and just collect outlines
                comp_num_vertices = stb_get_glyph_shape_pure(font_info, comp_glyph_idx, comp_vertices)
                if (comp_num_vertices > 0) then
                    if (num_vertices == 0) then
                        allocate(vertices(comp_num_vertices))
                        vertices = comp_vertices
                        num_vertices = comp_num_vertices
                    else
                        comp_vertices_start = 1
                        comp_vertices_end = comp_num_vertices
                        call append_vertices(vertices, num_vertices, comp_vertices(comp_vertices_start:comp_vertices_end))
                    end if
                end if
                comp_count = comp_count + 1
                if (iand(flags, MORE_COMPONENTS) == 0) exit
            end do
            ! Defensive: ensure vertices is always allocated
            if (.not. allocated(vertices)) then
                allocate(vertices(0))
            end if
            ! Debug: print number of vertices for composite glyphs
            print *, 'Composite glyph', glyph_index, 'num_vertices:', num_vertices
        end if

    end function stb_get_glyph_shape_pure

    subroutine stb_free_shape_pure(vertices)
        !! Free allocated vertex array
        type(ttf_vertex_t), allocatable, intent(inout) :: vertices(:)

        if (allocated(vertices)) then
            deallocate(vertices)
        end if

    end subroutine stb_free_shape_pure

    function parse_simple_glyph(font_info, glyf_table_idx, glyph_index, glyph_header, vertices) result(num_vertices)
        !! Parse a simple glyph (non-composite) into vertices following STB algorithm
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyf_table_idx, glyph_index
        type(ttf_glyf_header_t), intent(in) :: glyph_header
        type(ttf_vertex_t), allocatable, intent(out) :: vertices(:)
        integer :: num_vertices

        integer :: glyph_offset, data_offset, i, j
        integer :: num_contours, num_points, instruction_length
        integer(1), allocatable :: flags(:)
        integer, allocatable :: x_coords(:), y_coords(:), contour_ends(:)
        logical :: success

        num_vertices = 0

        if (glyph_header%num_contours <= 0) then
            allocate(vertices(0))
            print *, 'parse_simple_glyph: no contours for glyph', glyph_index
            return ! No contours
        end if

        num_contours = glyph_header%num_contours

        ! Calculate glyph data offset
        glyph_offset = font_info%tables(glyf_table_idx)%offset + &
                      font_info%loca_table%offsets(glyph_index + 1)

        ! Parse contour endpoints
        allocate(contour_ends(num_contours))
        data_offset = glyph_offset + 10  ! Skip glyph header

        do i = 1, num_contours
            if (data_offset + 1 >= size(font_info%font_data)) then
                allocate(vertices(0))
                print *, 'parse_simple_glyph: data_offset out of bounds for glyph', glyph_index
                return
            end if
            contour_ends(i) = parse_uint16(font_info%font_data, data_offset)
            data_offset = data_offset + 2
        end do

        ! Get total number of points
        num_points = contour_ends(num_contours) + 1  ! TrueType uses 0-based indexing
        print *, 'parse_simple_glyph: glyph', glyph_index, 'num_contours', num_contours, 'num_points', num_points

        ! Skip instruction length and instructions
        if (data_offset + 1 >= size(font_info%font_data)) then
            allocate(vertices(0))
            print *, 'parse_simple_glyph: instruction length out of bounds for glyph', glyph_index
            return
        end if
        instruction_length = parse_uint16(font_info%font_data, data_offset)
        data_offset = data_offset + 2 + instruction_length

        ! Parse coordinate data using simplified approach
        success = parse_glyph_coordinates(font_info%font_data, data_offset, num_points, &
                                        flags, x_coords, y_coords)
        if (.not. success) then
            allocate(vertices(0))
            print *, 'parse_simple_glyph: parse_glyph_coordinates failed for glyph', glyph_index
            return
        end if
        print *, 'parse_simple_glyph: flags(1:5)=', flags(1:min(5,num_points))
        print *, 'parse_simple_glyph: x_coords(1:5)=', x_coords(1:min(5,num_points))
        print *, 'parse_simple_glyph: y_coords(1:5)=', y_coords(1:min(5,num_points))

        ! Convert coordinates to vertices
        call convert_coords_to_vertices(x_coords, y_coords, flags, contour_ends, &
                                       num_contours, vertices, num_vertices)
        if (num_vertices == 0) then
            print *, 'parse_simple_glyph: convert_coords_to_vertices returned 0 vertices for glyph', glyph_index
        end if
    end function parse_simple_glyph

    function parse_uint16(data, offset) result(value)
        !! Parse big-endian 16-bit unsigned integer
        integer(1), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value

        if (offset + 1 > size(data)) then
            value = 0
            return
        end if

        value = iand(int(data(offset), kind=4), 255) * 256 + &
               iand(int(data(offset + 1), kind=4), 255)

    end function parse_uint16

    function parse_glyph_coordinates(data, start_offset, num_points, flags, x_coords, y_coords) result(success)
        !! Parse glyph coordinate data following TrueType specification
        integer(1), intent(in) :: data(:)
        integer, intent(in) :: start_offset, num_points
        integer(1), allocatable, intent(out) :: flags(:)
        integer, allocatable, intent(out) :: x_coords(:), y_coords(:)
        logical :: success

        integer :: offset, i, j, x, y, flag_byte, repeat_count
        logical :: x_short, y_short, x_same, y_same
        integer :: dx, dy

        success = .false.
        offset = start_offset

        if (num_points <= 0 .or. offset >= size(data)) return

        allocate(flags(num_points))
        allocate(x_coords(num_points))
        allocate(y_coords(num_points))

        ! Parse flags array following TrueType specification
        i = 1
        do while (i <= num_points .and. offset < size(data))
            flag_byte = iand(int(data(offset), kind=4), 255)
            offset = offset + 1
            flags(i) = int(flag_byte, kind=1)

            ! Check for repeat flag (bit 3)
            if (iand(flag_byte, 8) /= 0) then
                ! Next byte contains repeat count
                if (offset >= size(data)) exit
                repeat_count = iand(int(data(offset), kind=4), 255)
                offset = offset + 1

                ! Repeat the flag for the specified count
                do j = 1, repeat_count
                    if (i + j <= num_points) then
                        flags(i + j) = flags(i)
                    end if
                end do
                i = i + repeat_count + 1
            else
                i = i + 1
            end if
        end do

        ! Parse X coordinates
        x = 0
        do i = 1, num_points
            flag_byte = iand(int(flags(i), kind=4), 255)
            x_short = iand(flag_byte, 2) /= 0     ! Bit 1: X_SHORT_VECTOR
            x_same = iand(flag_byte, 16) /= 0     ! Bit 4: THIS_X_IS_SAME

            if (x_short) then
                ! X coordinate is stored as unsigned byte
                if (offset >= size(data)) exit
                dx = iand(int(data(offset), kind=4), 255)
                offset = offset + 1
                if (.not. x_same) dx = -dx  ! If not same, delta is negative
            else if (.not. x_same) then
                ! X coordinate is stored as signed short
                if (offset + 1 >= size(data)) exit
                dx = parse_int16(data, offset)
                offset = offset + 2
            else
                ! X coordinate is the same as previous (delta = 0)
                dx = 0
            end if

            x = x + dx
            x_coords(i) = x
        end do

        ! Parse Y coordinates
        y = 0
        do i = 1, num_points
            flag_byte = iand(int(flags(i), kind=4), 255)
            y_short = iand(flag_byte, 4) /= 0     ! Bit 2: Y_SHORT_VECTOR
            y_same = iand(flag_byte, 32) /= 0     ! Bit 5: THIS_Y_IS_SAME

            if (y_short) then
                ! Y coordinate is stored as unsigned byte
                if (offset >= size(data)) exit
                dy = iand(int(data(offset), kind=4), 255)
                offset = offset + 1
                if (.not. y_same) dy = -dy  ! If not same, delta is negative
            else if (.not. y_same) then
                ! Y coordinate is stored as signed short
                if (offset + 1 >= size(data)) exit
                dy = parse_int16(data, offset)
                offset = offset + 2
            else
                ! Y coordinate is the same as previous (delta = 0)
                dy = 0
            end if

            y = y + dy
            y_coords(i) = y
        end do

        success = .true.
        print *, 'parse_glyph_coordinates: num_points', num_points
        print *, 'parse_glyph_coordinates: flags(1:5)=', flags(1:min(5,num_points))
        print *, 'parse_glyph_coordinates: x_coords(1:5)=', x_coords(1:min(5,num_points))
        print *, 'parse_glyph_coordinates: y_coords(1:5)=', y_coords(1:min(5,num_points))

    end function parse_glyph_coordinates

    function parse_int16(data, offset) result(value)
        !! Parse big-endian 16-bit signed integer
        integer(1), intent(in) :: data(:)
        integer, intent(in) :: offset
        integer :: value

        if (offset + 1 > size(data)) then
            value = 0
            return
        end if

        value = iand(int(data(offset), kind=4), 255) * 256 + &
               iand(int(data(offset + 1), kind=4), 255)

        ! Convert to signed 16-bit value
        if (value >= 32768) then
            value = value - 65536
        end if

    end function parse_int16

    subroutine convert_coords_to_vertices(x_coords, y_coords, flags, contour_ends, &
                                         num_contours, vertices, num_vertices)
        !! Convert parsed coordinates to vertex array handling on/off curve points
        integer, intent(in) :: x_coords(:), y_coords(:), contour_ends(:), num_contours
        integer(1), intent(in) :: flags(:)
        type(ttf_vertex_t), allocatable, intent(out) :: vertices(:)
        integer, intent(out) :: num_vertices

        integer :: max_vertices, i, contour, point_idx, contour_start, contour_end
        logical :: prev_was_off, was_off, start_off
        logical, allocatable :: is_on_curve(:)
        integer :: sx, sy, cx, cy, scx, scy, qx, qy
        integer, allocatable :: px(:), py(:)
        integer :: flag_byte, n, m, j, k

        ! Allocate maximum possible vertices (conservative estimate)
        max_vertices = size(x_coords) * 2 + num_contours  ! Points + curves + moves
        allocate(vertices(max_vertices))
        num_vertices = 0

        point_idx = 1
        do contour = 1, num_contours
            if (contour == 1) then
                contour_start = 1
            else
                contour_start = contour_ends(contour - 1) + 2  ! +1 for 0-based, +1 for next
            end if
            contour_end = contour_ends(contour) + 1  ! Convert to 1-based
            if (contour_start > size(x_coords) .or. contour_end > size(x_coords)) exit
            n = contour_end - contour_start + 1
            if (n <= 0) cycle

            ! Build list of points for this contour
            m = n
            allocate(px(m), py(m))
            do j = 1, m
                px(j) = x_coords(contour_start + j - 1)
                py(j) = y_coords(contour_start + j - 1)
            end do

            ! Build list of on-curve flags
            allocate(is_on_curve(m))
            do j = 1, m
                is_on_curve(j) = iand(int(flags(contour_start + j - 1), kind=4), 1) /= 0
            end do

            ! STB logic: walk through points, handling on/off curve transitions
            ! Remember the starting point for contour closure
            sx = px(1)
            sy = py(1)

            j = 1
            do while (j <= m)
                if (is_on_curve(j)) then
                    ! On-curve point: move or line
                    if (j == 1) then
                        num_vertices = num_vertices + 1
                        vertices(num_vertices) = ttf_vertex_t(x=px(j), y=py(j), type=TTF_VERTEX_MOVE)
                    else
                        num_vertices = num_vertices + 1
                        vertices(num_vertices) = ttf_vertex_t(x=px(j), y=py(j), type=TTF_VERTEX_LINE)
                    end if
                    j = j + 1
                else
                    ! Off-curve point: quadratic curve
                    k = j + 1
                    if (k > m) k = 1
                    if (is_on_curve(k)) then
                        ! Next is on-curve: curve to it
                        num_vertices = num_vertices + 1
                        vertices(num_vertices) = ttf_vertex_t(x=px(k), y=py(k), cx=px(j), cy=py(j), type=TTF_VERTEX_CURVE)
                        j = j + 2
                    else
                        ! Next is also off-curve: curve to midpoint
                        qx = (px(j) + px(k)) / 2
                        qy = (py(j) + py(k)) / 2
                        num_vertices = num_vertices + 1
                        vertices(num_vertices) = ttf_vertex_t(x=qx, y=qy, cx=px(j), cy=py(j), type=TTF_VERTEX_CURVE)
                        j = j + 1
                    end if
                end if
            end do

            ! SELECTIVE: Close contour only if it doesn't already end at starting point
            ! Analysis showed ForTTF=38 vs STB=39, missing exactly 1 vertex
            ! Only Contour 1 needs closing: starts (692,-301), ends (692,2) - different points
            ! Contours 2&3 already closed: both end at same point as start
            if (m > 0) then
                ! Check if last vertex is different from starting point
                if (px(m) /= sx .or. py(m) /= sy) then
                    write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0,A)') &
                        'DEBUG: Closing contour ', contour, ' from (', px(m), ',', py(m), &
                        ') to (', sx, ',', sy, ')'
                    num_vertices = num_vertices + 1
                    vertices(num_vertices) = ttf_vertex_t(x=sx, y=sy, type=TTF_VERTEX_LINE)
                else
                    write(*,'(A,I0,A,I0,A,I0,A)') &
                        'DEBUG: NOT closing contour ', contour, ' - already ends at start (', sx, ',', sy, ')'
                end if
            end if

            deallocate(px, py, is_on_curve)
        end do

        ! Resize to actual number of vertices
        if (num_vertices > 0) then
            vertices = vertices(1:num_vertices)
        else
            deallocate(vertices)
            allocate(vertices(0))
        end if
        ! Debug: print vertex types
        print *, 'convert_coords_to_vertices: num_vertices=', num_vertices
        do i = 1, min(num_vertices, 10)
            print *, '  vertex', i, ': type=', vertices(i)%type, &
     &               'x=', vertices(i)%x, 'y=', vertices(i)%y, &
     &               'cx=', vertices(i)%cx, 'cy=', vertices(i)%cy
        end do
    end subroutine convert_coords_to_vertices

    subroutine append_vertices(vertices, num_vertices, new_vertices)
        type(ttf_vertex_t), allocatable, intent(inout) :: vertices(:)
        integer, intent(inout) :: num_vertices
        type(ttf_vertex_t), intent(in) :: new_vertices(:)
        integer :: old_n, new_n
        old_n = num_vertices
        new_n = size(new_vertices)
        if (new_n == 0) return
        if (old_n == 0) then
            allocate(vertices(new_n))
            vertices = new_vertices
            num_vertices = new_n
        else
            vertices = [vertices, new_vertices]
            num_vertices = old_n + new_n
        end if
    end subroutine append_vertices

end module forttf_outline
