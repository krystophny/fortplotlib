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
        !! Parse a simple glyph (non-composite) into vertices
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyf_table_idx, glyph_index
        type(ttf_glyf_header_t), intent(in) :: glyph_header
        type(ttf_vertex_t), allocatable, intent(out) :: vertices(:)
        integer :: num_vertices
        
        ! TODO: Implement actual glyph outline parsing
        ! For now, create a simple placeholder vertex array
        num_vertices = 4
        allocate(vertices(num_vertices))
        
        ! Create a simple square outline as placeholder
        vertices(1) = ttf_vertex_t(x=0, y=0, type=TTF_VERTEX_MOVE)
        vertices(2) = ttf_vertex_t(x=100, y=0, type=TTF_VERTEX_LINE)
        vertices(3) = ttf_vertex_t(x=100, y=100, type=TTF_VERTEX_LINE)  
        vertices(4) = ttf_vertex_t(x=0, y=100, type=TTF_VERTEX_LINE)

    end function parse_simple_glyph

end module forttf_outline