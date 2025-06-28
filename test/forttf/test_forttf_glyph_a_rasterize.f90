! filepath: /home/ert/code/fortplotlib/test/forttf/test_forttf_glyph_a_rasterize.f90
program test_forttf_glyph_a_rasterize
    !! Test rasterization of character 'A' to debug pixel count mismatch
    use forttf_types
    use forttf_stb_raster
    use forttf_core, only: stb_init_font_pure, stb_cleanup_font_pure
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    ! STB C interface for comparison
    interface
        subroutine stb_test_complete_rasterize_exact(vertices, num_verts, &
                    scale_x, scale_y, shift_x, shift_y, &
                    width, height, x_off, y_off, invert, &
                    bitmap_out, pixel_count_out) bind(c)
            import :: c_ptr, c_int, c_float
            type(c_ptr), value :: vertices
            integer(c_int), value :: num_verts, width, height, x_off, y_off, invert
            real(c_float), value :: scale_x, scale_y, shift_x, shift_y
            type(c_ptr), intent(out) :: bitmap_out
            integer(c_int), intent(out) :: pixel_count_out
        end subroutine
        
        subroutine stb_free_bitmap(bitmap) bind(c)
            import :: c_ptr
            type(c_ptr), value :: bitmap
        end subroutine
    end interface

    call test_letter_a_rasterization()

contains

    subroutine test_letter_a_rasterization()
        type(stb_fontinfo_pure_t) :: font_info
        type(ttf_vertex_t), allocatable, target :: vertices(:)
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        type(stb_edge_t), allocatable :: edges(:)
        type(stb_bitmap_t) :: fortran_bitmap
        integer(c_int8_t), allocatable, target :: fortran_pixels(:)
        integer :: num_vertices, num_contours, num_edges, fortran_pixel_count, i
        
        ! STB C results
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_pixel_count
        
        ! Test parameters for letter 'A'
        real(wp), parameter :: scale_x = 0.5_wp, scale_y = 0.5_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        real(wp), parameter :: flatness = 0.35_wp
        integer, parameter :: width = 684, height = 747
        integer, parameter :: x_off = 8, y_off = -747
        logical, parameter :: invert = .true.
        integer, parameter :: char_code = 65  ! ASCII 'A'
        
        write(*,*) "=== Letter 'A' Rasterization Test ==="
        
        ! Initialize font
        if (.not. stb_init_font_pure(font_info, "/usr/share/fonts/TTF/DejaVuSans.ttf")) then
            write(*,*) "❌ Failed to initialize font"
            return
        end if
        
        ! Get glyph vertices
        num_vertices = stb_get_glyph_shape_pure(font_info, char_code, vertices)
        write(*,*) "  Glyph 'A' has", num_vertices, "vertices"
        
        ! Flatten curves to points
        points = stb_flatten_curves(vertices, num_vertices, flatness, &
                                  contour_lengths, num_contours)
        write(*,*) "  Flattened to", size(points), "points in", num_contours, "contours"
        
        ! Build edges
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               scale_x, scale_y, shift_x, shift_y, invert)
        num_edges = size(edges)
        write(*,*) "  Built", num_edges, "edges"
        
        ! Sort edges
        call stb_sort_edges(edges, num_edges)
        write(*,*) "  Edges sorted"
        
        ! Create Fortran bitmap
        allocate(fortran_pixels(width * height))
        fortran_pixels = 0
        
        fortran_bitmap%w = width
        fortran_bitmap%h = height
        fortran_bitmap%stride = width
        fortran_bitmap%pixels => fortran_pixels
        
        ! Rasterize using Fortran implementation
        call stb_rasterize_sorted_edges(fortran_bitmap, edges, num_edges, 1, x_off, y_off, c_null_ptr)
        
        ! Count Fortran pixels
        fortran_pixel_count = 0
        do i = 1, width * height
            if (fortran_pixels(i) /= 0) fortran_pixel_count = fortran_pixel_count + 1
        end do
        
        ! Test STB C implementation for comparison
        call stb_test_complete_rasterize_exact(c_loc(vertices(1)), num_vertices, &
                                             real(scale_x, c_float), real(scale_y, c_float), &
                                             real(shift_x, c_float), real(shift_y, c_float), &
                                             width, height, x_off, y_off, 1, &
                                             stb_bitmap_ptr, stb_pixel_count)
        
        write(*,*) "  Fortran pixels: ", fortran_pixel_count
        write(*,*) "  STB C pixels:   ", stb_pixel_count
        write(*,*) "  Difference:     ", abs(fortran_pixel_count - stb_pixel_count)
        write(*,*) "  Ratio:          ", real(fortran_pixel_count) / real(max(1, stb_pixel_count))
        
        ! Show debug info for edge algorithm
        write(*,*) "  First 5 edges:"
        do i = 1, min(5, num_edges)
            write(*,'("    Edge", I3, ": (", F7.2, ",", F7.2, ") -> (", F7.2, ",", F7.2, "), invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        ! Cleanup
        call stb_free_bitmap(stb_bitmap_ptr)
        call stb_free_shape_pure(vertices)
        call stb_cleanup_font_pure(font_info)
        deallocate(fortran_pixels, points, contour_lengths, edges)
        
    end subroutine test_letter_a_rasterization

end program test_forttf_glyph_a_rasterize
