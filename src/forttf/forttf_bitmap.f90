module forttf_bitmap
    !! Pure Fortran implementation of TrueType font bitmap rendering functionality (derived from stb_truetype.h)
    !! Handles bitmap rendering, subpixel rendering, and bounding box calculations
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_parser
    use forttf_mapping
    use forttf_metrics
    use forttf_glyph_parser
    use forttf_outline
    implicit none

    ! C memory management interface
    interface
        function c_malloc(size) bind(C, name="malloc")
            import :: c_ptr, c_size_t
            integer(c_size_t), value :: size
            type(c_ptr) :: c_malloc
        end function c_malloc

        subroutine c_free(ptr) bind(C, name="free")
            import :: c_ptr
            type(c_ptr), value :: ptr
        end subroutine c_free
    end interface

    ! Internal types for rasterization
    type :: ttf_point_t
        real(wp) :: x, y
    end type ttf_point_t

    type :: ttf_edge_t
        real(wp) :: x0, y0, x1, y1
        logical :: invert
    end type ttf_edge_t

    type :: ttf_active_edge_t
        real(wp) :: fx, fdx, direction
        real(wp) :: sy, ey
        type(ttf_active_edge_t), pointer :: next => null()
    end type ttf_active_edge_t

    private

    ! Public interface
    public :: stb_get_codepoint_bitmap_box_pure
    public :: stb_get_codepoint_bitmap_pure
    public :: stb_make_codepoint_bitmap_pure
    public :: stb_free_bitmap_pure
    public :: stb_get_glyph_bitmap_pure
    public :: stb_get_glyph_bitmap_box_pure
    public :: stb_make_glyph_bitmap_pure
    public :: stb_get_codepoint_bitmap_subpixel_pure
    public :: stb_get_glyph_bitmap_subpixel_pure
    public :: stb_make_glyph_bitmap_subpixel_pure
    public :: stb_make_codepoint_bitmap_subpixel_pure
    public :: stb_get_glyph_bitmap_box_subpixel_pure
    public :: stb_get_codepoint_bitmap_box_subpixel_pure

contains

    subroutine stb_get_codepoint_bitmap_box_pure(font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer :: char_x0, char_y0, char_x1, char_y1
        integer :: success

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Get character bounding box from glyf/head tables
        call stb_get_codepoint_box_pure(font_info, codepoint, &
                                       char_x0, char_y0, char_x1, char_y1)

        if (char_x0 == 0 .and. char_y0 == 0 .and. char_x1 == 0 .and. char_y1 == 0) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Scale the bounding box to bitmap coordinates
        ! Note: Y coordinates are flipped in bitmap space (top-down vs bottom-up)
        ix0 = floor(real(char_x0) * scale_x)
        iy0 = floor(real(-char_y1) * scale_y)  ! Flip Y and swap y0<->y1
        ix1 = ceiling(real(char_x1) * scale_x)
        iy1 = ceiling(real(-char_y0) * scale_y) ! Flip Y and swap y0<->y1

    end subroutine stb_get_codepoint_bitmap_box_pure

    function stb_get_codepoint_bitmap_pure(font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer :: ix0, iy0, ix1, iy1
        integer :: glyph_index

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Get glyph index for the codepoint
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)
        if (glyph_index == 0) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Get bitmap bounding box
        call stb_get_codepoint_bitmap_box_pure(font_info, codepoint, scale_x, scale_y, &
                                              ix0, iy0, ix1, iy1)

        ! Calculate dimensions and offset
        width = ix1 - ix0
        height = iy1 - iy0
        xoff = ix0
        yoff = iy0

        ! Check if bitmap has valid dimensions
        if (width <= 0 .or. height <= 0) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Allocate bitmap buffer using C malloc for compatibility with STB interface
        bitmap_ptr = c_malloc(int(width * height, c_size_t))
        if (.not. c_associated(bitmap_ptr)) then
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Render the glyph into the bitmap
        call render_glyph_to_bitmap(font_info, glyph_index, scale_x, scale_y, 0.0_wp, 0.0_wp, &
                                   bitmap_ptr, width, height, xoff, yoff)

    end function stb_get_codepoint_bitmap_pure

    subroutine stb_make_codepoint_bitmap_pure(font_info, output_buffer, out_w, out_h, out_stride, scale_x, scale_y, codepoint)
        !! Render character into provided buffer
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: codepoint
        integer :: glyph_index

        if (.not. font_info%initialized) return

        ! Get glyph index for the codepoint
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)
        if (glyph_index == 0) return

        ! Delegate to glyph function
        call stb_make_glyph_bitmap_pure(font_info, output_buffer, out_w, out_h, out_stride, &
                                       scale_x, scale_y, glyph_index)

    end subroutine stb_make_codepoint_bitmap_pure

    subroutine stb_free_bitmap_pure(bitmap_ptr)
        !! Free bitmap allocated by stb_get_codepoint_bitmap_pure
        type(c_ptr), intent(in) :: bitmap_ptr

        ! Free C-allocated bitmap memory
        if (c_associated(bitmap_ptr)) then
            call c_free(bitmap_ptr)
        end if

    end subroutine stb_free_bitmap_pure

    function stb_get_glyph_bitmap_pure(font_info, scale_x, scale_y, glyph, &
                                      width, height, xoff, yoff) &
             result(bitmap_ptr)
        !! Allocate and render glyph bitmap by glyph index
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: glyph
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Get bitmap bounding box for glyph
        call stb_get_glyph_bitmap_box_pure(font_info, glyph, scale_x, scale_y, &
                                           ix0, iy0, ix1, iy1)

        ! Calculate dimensions and offset
        width = ix1 - ix0
        height = iy1 - iy0
        xoff = ix0
        yoff = iy0

        ! Check if bitmap has valid dimensions
        if (width <= 0 .or. height <= 0) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Allocate bitmap buffer using C malloc for compatibility with STB interface
        bitmap_ptr = c_malloc(int(width * height, c_size_t))
        if (.not. c_associated(bitmap_ptr)) then
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Render the glyph into the bitmap
        call render_glyph_to_bitmap(font_info, glyph, scale_x, scale_y, 0.0_wp, 0.0_wp, &
                                   bitmap_ptr, width, height, xoff, yoff)

    end function stb_get_glyph_bitmap_pure

    subroutine stb_get_glyph_bitmap_box_pure(font_info, glyph, scale_x, &
                                            scale_y, ix0, iy0, ix1, iy1)
        !! Get bounding box for glyph bitmap
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer :: glyph_x0, glyph_y0, glyph_x1, glyph_y1

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Get glyph bounding box from glyf/head tables
        call stb_get_glyph_box_pure(font_info, glyph, &
                                   glyph_x0, glyph_y0, glyph_x1, glyph_y1)

        if (glyph_x0 == 0 .and. glyph_y0 == 0 .and. glyph_x1 == 0 .and. glyph_y1 == 0) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Scale the bounding box to bitmap coordinates
        ! Note: Y coordinates are flipped in bitmap space (top-down vs bottom-up)
        ix0 = floor(real(glyph_x0) * scale_x)
        iy0 = floor(real(-glyph_y1) * scale_y)  ! Flip Y and swap y0<->y1
        ix1 = ceiling(real(glyph_x1) * scale_x)
        iy1 = ceiling(real(-glyph_y0) * scale_y) ! Flip Y and swap y0<->y1

    end subroutine stb_get_glyph_bitmap_box_pure

    subroutine stb_make_glyph_bitmap_pure(font_info, output_buffer, out_w, &
                                         out_h, out_stride, scale_x, scale_y, &
                                         glyph)
        !! Render glyph into provided buffer
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y
        integer, intent(in) :: glyph
        type(c_ptr) :: buffer_ptr

        if (.not. font_info%initialized) return

        ! Convert array to C pointer for compatibility with rendering function
        buffer_ptr = c_loc(output_buffer(1))

        ! Render glyph using existing rendering infrastructure
        ! Note: out_stride is ignored for now (assuming packed buffer)
        call render_glyph_to_bitmap(font_info, glyph, scale_x, scale_y, 0.0_wp, 0.0_wp, &
                                   buffer_ptr, out_w, out_h, 0, 0)

    end subroutine stb_make_glyph_bitmap_pure

    function stb_get_codepoint_bitmap_subpixel_pure(font_info, scale_x, &
                                                   scale_y, shift_x, &
                                                   shift_y, codepoint, &
                                                   width, height, xoff, &
                                                   yoff) result(bitmap_ptr)
        !! Allocate and render character bitmap with subpixel positioning
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: codepoint
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer :: glyph_index

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Get glyph index for the codepoint
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)
        if (glyph_index == 0) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Delegate to glyph function (following STB pattern)
        bitmap_ptr = stb_get_glyph_bitmap_subpixel_pure(font_info, scale_x, scale_y, &
                                                       shift_x, shift_y, glyph_index, &
                                                       width, height, xoff, yoff)

    end function stb_get_codepoint_bitmap_subpixel_pure

    function stb_get_glyph_bitmap_subpixel_pure(font_info, scale_x, scale_y, &
                                               shift_x, shift_y, glyph, &
                                               width, height, xoff, yoff) &
             result(bitmap_ptr)
        !! Allocate and render glyph bitmap with subpixel positioning
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: glyph
        integer, intent(out) :: width, height, xoff, yoff
        type(c_ptr) :: bitmap_ptr
        integer :: ix0, iy0, ix1, iy1

        if (.not. font_info%initialized) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Get subpixel bitmap bounding box
        call stb_get_glyph_bitmap_box_subpixel_pure(font_info, glyph, &
                                                   scale_x, scale_y, shift_x, shift_y, &
                                                   ix0, iy0, ix1, iy1)

        ! Calculate dimensions and offset
        width = ix1 - ix0
        height = iy1 - iy0
        xoff = ix0
        yoff = iy0

        ! Check if bitmap has valid dimensions
        if (width <= 0 .or. height <= 0) then
            bitmap_ptr = c_null_ptr
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Allocate bitmap buffer using C malloc for compatibility with STB interface
        bitmap_ptr = c_malloc(int(width * height, c_size_t))
        if (.not. c_associated(bitmap_ptr)) then
            width = 0; height = 0; xoff = 0; yoff = 0
            return
        end if

        ! Render the glyph into the bitmap with subpixel positioning
        call render_glyph_to_bitmap(font_info, glyph, scale_x, scale_y, shift_x, shift_y, &
                                   bitmap_ptr, width, height, xoff, yoff)

    end function stb_get_glyph_bitmap_subpixel_pure

    subroutine stb_make_glyph_bitmap_subpixel_pure(font_info, output_buffer, &
                                                  out_w, out_h, out_stride, &
                                                  scale_x, scale_y, shift_x, &
                                                  shift_y, glyph)
        !! Render glyph into provided buffer with subpixel positioning
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: glyph
        type(c_ptr) :: buffer_ptr

        if (.not. font_info%initialized) return

        ! Convert array to C pointer for compatibility with rendering function
        buffer_ptr = c_loc(output_buffer(1))

        ! Render glyph with subpixel positioning using existing rendering infrastructure
        ! Note: out_stride is ignored for now (assuming packed buffer)
        call render_glyph_to_bitmap(font_info, glyph, scale_x, scale_y, shift_x, shift_y, &
                                   buffer_ptr, out_w, out_h, 0, 0)

    end subroutine stb_make_glyph_bitmap_subpixel_pure

    subroutine stb_make_codepoint_bitmap_subpixel_pure(font_info, &
                                                      output_buffer, out_w, &
                                                      out_h, out_stride, &
                                                      scale_x, scale_y, &
                                                      shift_x, shift_y, &
                                                      codepoint)
        !! Render character into provided buffer with subpixel positioning
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer(c_int8_t), intent(inout), target :: output_buffer(*)
        integer, intent(in) :: out_w, out_h, out_stride
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: codepoint
        integer :: glyph_index

        if (.not. font_info%initialized) return

        ! Get glyph index for the codepoint
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)
        if (glyph_index == 0) return

        ! Delegate to glyph function
        call stb_make_glyph_bitmap_subpixel_pure(font_info, output_buffer, out_w, out_h, &
                                                out_stride, scale_x, scale_y, shift_x, shift_y, &
                                                glyph_index)

    end subroutine stb_make_codepoint_bitmap_subpixel_pure

    subroutine stb_get_glyph_bitmap_box_subpixel_pure(font_info, glyph, &
                                                     scale_x, scale_y, &
                                                     shift_x, shift_y, &
                                                     ix0, iy0, ix1, iy1)
        !! Get bounding box for glyph bitmap with subpixel positioning
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer :: glyph_x0, glyph_y0, glyph_x1, glyph_y1

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Get glyph bounding box from glyf/head tables
        call stb_get_glyph_box_pure(font_info, glyph, &
                                   glyph_x0, glyph_y0, glyph_x1, glyph_y1)

        if (glyph_x0 == 0 .and. glyph_y0 == 0 .and. glyph_x1 == 0 .and. glyph_y1 == 0) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Scale and shift the bounding box to bitmap coordinates (following STB algorithm exactly)
        ! Note: Y coordinates are flipped in bitmap space (top-down vs bottom-up)
        ix0 = floor(real(glyph_x0) * scale_x + shift_x)
        iy0 = floor(real(-glyph_y1) * scale_y + shift_y)  ! Flip Y and swap y0<->y1
        ix1 = ceiling(real(glyph_x1) * scale_x + shift_x)
        iy1 = ceiling(real(-glyph_y0) * scale_y + shift_y) ! Flip Y and swap y0<->y1

    end subroutine stb_get_glyph_bitmap_box_subpixel_pure

    subroutine stb_get_codepoint_bitmap_box_subpixel_pure(font_info, &
                                                         codepoint, &
                                                         scale_x, scale_y, &
                                                         shift_x, shift_y, &
                                                         ix0, iy0, ix1, iy1)
        !! Get bounding box for character bitmap with subpixel positioning
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(out) :: ix0, iy0, ix1, iy1
        integer :: glyph_index

        if (.not. font_info%initialized) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Get glyph index for the codepoint
        glyph_index = stb_find_glyph_index_pure(font_info, codepoint)
        if (glyph_index == 0) then
            ix0 = 0; iy0 = 0; ix1 = 0; iy1 = 0
            return
        end if

        ! Delegate to glyph function (following STB pattern)
        call stb_get_glyph_bitmap_box_subpixel_pure(font_info, glyph_index, &
                                                   scale_x, scale_y, shift_x, shift_y, &
                                                   ix0, iy0, ix1, iy1)

    end subroutine stb_get_codepoint_bitmap_box_subpixel_pure

    subroutine create_simple_bitmap(width, height, bitmap_ptr)
        !! Create a simple filled rectangle bitmap using C malloc for compatibility
        integer, intent(in) :: width, height
        type(c_ptr), intent(out) :: bitmap_ptr

        integer :: total_pixels, i, j, pixel_idx
        integer :: border_width
        integer(c_int8_t), pointer :: bitmap_array(:)

        total_pixels = width * height
        
        ! Allocate bitmap buffer using C malloc for compatibility with STB interface
        bitmap_ptr = c_malloc(int(total_pixels, c_size_t))
        if (.not. c_associated(bitmap_ptr)) then
            return  ! Allocation failed
        end if

        ! Convert C pointer to Fortran pointer for easier manipulation
        call c_f_pointer(bitmap_ptr, bitmap_array, [total_pixels])

        ! Create a simple filled rectangle with border
        ! This simulates a basic glyph shape for testing
        border_width = max(1, min(width, height) / 8)  ! 1/8 of smallest dimension

        do j = 0, height - 1
            do i = 0, width - 1
                pixel_idx = j * width + i + 1  ! 1-based indexing for Fortran

                ! Create a border pattern to simulate a character
                if (i < border_width .or. i >= width - border_width .or. &
                    j < border_width .or. j >= height - border_width) then
                    bitmap_array(pixel_idx) = 127_c_int8_t  ! Solid pixel (max for signed)
                else
                    bitmap_array(pixel_idx) = 0_c_int8_t    ! Transparent pixel
                end if
            end do
        end do

    end subroutine create_simple_bitmap

    subroutine render_glyph_to_bitmap(font_info, glyph_index, scale_x, scale_y, shift_x, shift_y, &
                                     bitmap_ptr, width, height, xoff, yoff)
        !! Render a glyph into the provided bitmap buffer using vertex-based rasterization
        type(stb_fontinfo_pure_t), intent(in) :: font_info
        integer, intent(in) :: glyph_index
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        type(c_ptr), intent(in) :: bitmap_ptr
        integer, intent(in) :: width, height, xoff, yoff
        
        integer(c_int8_t), pointer :: bitmap_array(:)
        type(ttf_vertex_t), allocatable :: vertices(:)
        integer :: num_vertices, total_pixels

        ! Convert bitmap pointer to Fortran array
        total_pixels = width * height
        call c_f_pointer(bitmap_ptr, bitmap_array, [total_pixels])

        ! Initialize bitmap to transparent
        bitmap_array = 0_c_int8_t
        
        ! Get glyph outline vertices
        num_vertices = stb_get_glyph_shape_pure(font_info, glyph_index, vertices)
        if (num_vertices <= 0) then
            ! No vertices, create fallback bitmap
            call create_fallback_bitmap(bitmap_array, width, height)
            return
        end if

        ! Rasterize the vertices into the bitmap
        call rasterize_vertices(vertices, num_vertices, bitmap_array, width, height, &
                               scale_x, scale_y, shift_x, shift_y, xoff, yoff)

        ! Cleanup
        call stb_free_shape_pure(vertices)

    end subroutine render_glyph_to_bitmap

    subroutine create_fallback_bitmap(bitmap_array, width, height)
        !! Create a fallback bitmap for missing glyphs
        integer(c_int8_t), intent(inout) :: bitmap_array(:)
        integer, intent(in) :: width, height
        integer :: i, j, pixel_idx
        integer :: border_width

        border_width = max(1, min(width, height) / 8)

        do j = 0, height - 1
            do i = 0, width - 1
                pixel_idx = j * width + i + 1

                ! Create a simple rectangle outline
                if ((i < border_width .or. i >= width - border_width) .or. &
                    (j < border_width .or. j >= height - border_width)) then
                    bitmap_array(pixel_idx) = 127_c_int8_t  ! Solid pixel
                else
                    bitmap_array(pixel_idx) = 0_c_int8_t    ! Transparent pixel
                end if
            end do
        end do

    end subroutine create_fallback_bitmap

    subroutine create_glyph_shape_bitmap(bitmap_array, width, height, glyph_header)
        !! Create a bitmap based on glyph shape information
        integer(c_int8_t), intent(inout) :: bitmap_array(:)
        integer, intent(in) :: width, height
        type(ttf_glyf_header_t), intent(in) :: glyph_header
        integer :: i, j, pixel_idx
        real(wp) :: cx, cy, radius

        ! For simple glyphs, create a filled shape based on contour count
        if (glyph_header%num_contours > 0) then
            ! Simple glyph - create filled shape
            cx = real(width, wp) * 0.5_wp
            cy = real(height, wp) * 0.5_wp
            radius = min(real(width, wp), real(height, wp)) * 0.3_wp

            do j = 0, height - 1
                do i = 0, width - 1
                    pixel_idx = j * width + i + 1

                    ! Create circular/elliptical shape
                    if (distance_to_center(real(i, wp), real(j, wp), cx, cy) <= radius) then
                        bitmap_array(pixel_idx) = 127_c_int8_t  ! Solid pixel
                    else
                        bitmap_array(pixel_idx) = 0_c_int8_t    ! Transparent pixel
                    end if
                end do
            end do
        else
            ! Composite glyph or empty - create outline
            call create_fallback_bitmap(bitmap_array, width, height)
        end if

    end subroutine create_glyph_shape_bitmap

    real(wp) function distance_to_center(x, y, cx, cy) result(dist)
        !! Calculate distance from point to center
        real(wp), intent(in) :: x, y, cx, cy
        dist = sqrt((x - cx)**2 + (y - cy)**2)
    end function distance_to_center

    subroutine rasterize_vertices(vertices, num_vertices, bitmap_array, width, height, &
                                 scale_x, scale_y, shift_x, shift_y, xoff, yoff)
        !! Rasterize vertex outline using exact STB pipeline for pixel-perfect matching
        use forttf_stb_raster, only: stbtt_rasterize
        type(ttf_vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_vertices
        integer(c_int8_t), intent(inout), target :: bitmap_array(:)
        integer, intent(in) :: width, height
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: xoff, yoff
        
        type(stb_bitmap_t) :: bitmap
        real(wp), parameter :: flatness_in_pixels = 0.35_wp  ! STB default
        
        if (num_vertices <= 0) then
            call create_fallback_bitmap(bitmap_array, width, height)
            return
        end if
        
        ! Set up STB bitmap structure
        bitmap%w = width
        bitmap%h = height
        bitmap%stride = width
        bitmap%pixels => bitmap_array
        
        ! Use exact STB rasterization pipeline (matches stbtt_Rasterize)
        call stbtt_rasterize(bitmap, flatness_in_pixels, vertices, num_vertices, &
                            scale_x, scale_y, shift_x, shift_y, xoff, yoff, .true., c_null_ptr)

    end subroutine rasterize_vertices
    
    subroutine vertices_to_edges(vertices, num_vertices, scale_x, scale_y, &
                                shift_x, shift_y, xoff, yoff, edges, num_edges)
        !! Convert vertex outline to edges for scanline rasterization
        type(ttf_vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_vertices
        real(wp), intent(in) :: scale_x, scale_y, shift_x, shift_y
        integer, intent(in) :: xoff, yoff
        type(ttf_edge_t), allocatable, intent(out) :: edges(:)
        integer, intent(out) :: num_edges
        
        integer :: i, contour_start
        real(wp) :: x0, y0, x1, y1
        real(wp) :: prev_x, prev_y, curr_x, curr_y
        logical :: in_contour
        
        ! Allocate maximum possible edges (one per vertex)
        allocate(edges(num_vertices))
        num_edges = 0
        in_contour = .false.
        contour_start = 0
        
        do i = 1, num_vertices
            ! Scale coordinates to bitmap space
            curr_x = real(vertices(i)%x, wp) * scale_x + shift_x - real(xoff, wp)
            curr_y = real(-vertices(i)%y, wp) * scale_y + shift_y - real(yoff, wp)  ! Flip Y
            
            if (vertices(i)%type == TTF_VERTEX_MOVE) then
                ! Start new contour
                in_contour = .true.
                contour_start = i
                prev_x = curr_x
                prev_y = curr_y
            else if (in_contour .and. vertices(i)%type == TTF_VERTEX_LINE) then
                ! Add line edge
                if (abs(curr_y - prev_y) > 0.01_wp) then  ! Avoid horizontal lines
                    num_edges = num_edges + 1
                    if (prev_y < curr_y) then
                        edges(num_edges) = ttf_edge_t(x0=prev_x, y0=prev_y, x1=curr_x, y1=curr_y, invert=.false.)
                    else
                        edges(num_edges) = ttf_edge_t(x0=curr_x, y0=curr_y, x1=prev_x, y1=prev_y, invert=.true.)
                    end if
                end if
                prev_x = curr_x
                prev_y = curr_y
            end if
        end do
        
        ! Resize to actual number of edges
        if (num_edges > 0) then
            edges = edges(1:num_edges)
        else
            deallocate(edges)
            allocate(edges(0))
        end if
        
    end subroutine vertices_to_edges
    
    subroutine scanline_rasterize(edges, num_edges, bitmap_array, width, height)
        !! Scanline rasterization algorithm for precise shape filling
        type(ttf_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: num_edges
        integer(c_int8_t), intent(inout) :: bitmap_array(:)
        integer, intent(in) :: width, height
        
        real(wp), allocatable :: intersections(:)
        integer :: num_intersections, y, i, j, pixel_idx
        real(wp) :: edge_x, edge_y
        integer :: x_start, x_end
        logical :: inside
        
        if (num_edges == 0) return
        
        allocate(intersections(num_edges))
        
        ! Process each scanline
        do y = 0, height - 1
            edge_y = real(y, wp) + 0.5_wp  ! Sample at pixel center
            num_intersections = 0
            
            ! Find intersections with all edges
            do i = 1, num_edges
                if (edges(i)%y0 <= edge_y .and. edge_y < edges(i)%y1) then
                    ! Edge intersects this scanline
                    if (abs(edges(i)%y1 - edges(i)%y0) > 0.001_wp) then
                        edge_x = edges(i)%x0 + (edge_y - edges(i)%y0) * &
                                (edges(i)%x1 - edges(i)%x0) / (edges(i)%y1 - edges(i)%y0)
                        
                        if (edge_x >= 0.0_wp .and. edge_x <= real(width, wp)) then
                            num_intersections = num_intersections + 1
                            intersections(num_intersections) = edge_x
                        end if
                    end if
                end if
            end do
            
            ! Sort intersections
            if (num_intersections > 1) then
                call sort_intersections(intersections, num_intersections)
            end if
            
            ! Fill between pairs of intersections (even-odd rule)
            do i = 1, num_intersections - 1, 2
                x_start = max(0, int(intersections(i)))
                x_end = min(width - 1, int(intersections(i + 1)))
                
                do j = x_start, x_end
                    pixel_idx = y * width + j + 1
                    bitmap_array(pixel_idx) = 127_c_int8_t
                end do
            end do
        end do
        
    end subroutine scanline_rasterize
    
    subroutine sort_intersections(intersections, n)
        !! Simple bubble sort for intersection array
        real(wp), intent(inout) :: intersections(:)
        integer, intent(in) :: n
        
        integer :: i, j
        real(wp) :: temp
        
        do i = 1, n - 1
            do j = 1, n - i
                if (intersections(j) > intersections(j + 1)) then
                    temp = intersections(j)
                    intersections(j) = intersections(j + 1)
                    intersections(j + 1) = temp
                end if
            end do
        end do
        
    end subroutine sort_intersections

end module forttf_bitmap