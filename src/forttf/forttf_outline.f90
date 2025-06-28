module forttf_outline
    !! Pure Fortran implementation of TrueType glyph outline parsing (derived from stb_truetype.h)
    !! Handles parsing of glyph outlines from the glyf table into vertex arrays
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_glyph_parser
    use forttf_mapping
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

    function stb_get_glyph_shape_pure(font_info, glyph_index, vertices) result(num_vertices)
        !! Get glyph outline vertices for a glyph index
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        type(ttf_vertex_t), allocatable, intent(out) :: vertices(:)
        integer :: num_vertices
        
        type(ttf_glyf_header_t) :: glyph_header
        logical :: success
        integer :: glyf_table_idx, i

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
            ! Composite glyph (TODO: implement)
            num_vertices = 0
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
            if (data_offset + 1 >= size(font_info%font_data)) return
            contour_ends(i) = parse_uint16(font_info%font_data, data_offset)
            data_offset = data_offset + 2
        end do
        
        ! Get total number of points
        num_points = contour_ends(num_contours) + 1  ! TrueType uses 0-based indexing
        
        ! Skip instruction length and instructions
        if (data_offset + 1 >= size(font_info%font_data)) return
        instruction_length = parse_uint16(font_info%font_data, data_offset)
        data_offset = data_offset + 2 + instruction_length
        
        ! Parse coordinate data using simplified approach
        success = parse_glyph_coordinates(font_info%font_data, data_offset, num_points, &
                                        flags, x_coords, y_coords)
        if (.not. success) return
        
        ! Convert coordinates to vertices
        call convert_coords_to_vertices(x_coords, y_coords, flags, contour_ends, &
                                       num_contours, vertices, num_vertices)

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
        logical :: is_on_curve, prev_was_off, was_off, start_off
        integer :: sx, sy, cx, cy, scx, scy
        integer :: flag_byte
        
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
            
            ! Start new contour
            sx = x_coords(contour_start)
            sy = y_coords(contour_start)
            
            ! Add move to start of contour
            num_vertices = num_vertices + 1
            vertices(num_vertices) = ttf_vertex_t(x=sx, y=sy, type=TTF_VERTEX_MOVE)
            
            ! Process points in this contour (simplified approach - treat all as lines)
            do i = contour_start + 1, contour_end
                if (i <= size(x_coords)) then
                    num_vertices = num_vertices + 1
                    vertices(num_vertices) = ttf_vertex_t(x=x_coords(i), y=y_coords(i), &
                                                        type=TTF_VERTEX_LINE)
                end if
            end do
        end do
        
        ! Resize to actual number of vertices
        if (num_vertices > 0) then
            vertices = vertices(1:num_vertices)
        else
            deallocate(vertices)
            allocate(vertices(0))
        end if

    end subroutine convert_coords_to_vertices

end module forttf_outline