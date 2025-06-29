program test_forttf_vertex_analysis
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_vertex_coordinate_analysis()

contains

    subroutine test_vertex_coordinate_analysis()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        integer, parameter :: glyph_index = 36  ! '$' character
        real(wp), parameter :: scale_x = 4.0_wp, scale_y = 4.0_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp

        ! STB variables
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:)

        ! Pure Fortran variables
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: pure_bitmap(:)

        ! Vertex analysis
        type(ttf_vertex_t), allocatable :: vertices(:)
        integer :: num_vertices, i
        real(wp) :: min_x, max_x, min_y, max_y
        real(wp) :: scaled_min_x, scaled_max_x, scaled_min_y, scaled_max_y

        write(*,*) "=== Vertex Coordinate Analysis ==="

        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)

        ! Get bitmap information from both implementations
        call get_stb_glyph_bitmap(stb_font, glyph_index, scale_x, scale_y, shift_x, shift_y, &
                                 stb_width, stb_height, stb_xoff, stb_yoff, stb_bitmap_ptr)
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])

        call get_pure_glyph_bitmap(pure_font, glyph_index, scale_x, scale_y, shift_x, shift_y, &
                                  pure_width, pure_height, pure_xoff, pure_yoff, pure_bitmap_ptr)
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [pure_width * pure_height])

        write(*,*) "--- Bitmap Information ---"
        write(*,*) "STB:  ", stb_width, "x", stb_height, " offset:", stb_xoff, stb_yoff
        write(*,*) "Pure: ", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff

        ! Get vertex data
        num_vertices = stb_get_glyph_shape_pure(pure_font, glyph_index, vertices)
        write(*,*) "Number of vertices:", num_vertices

        if (num_vertices > 0) then
            ! Analyze vertex bounds in font coordinate space
            min_x = real(vertices(1)%x, wp)
            max_x = real(vertices(1)%x, wp)
            min_y = real(vertices(1)%y, wp)
            max_y = real(vertices(1)%y, wp)

            do i = 2, num_vertices
                min_x = min(min_x, real(vertices(i)%x, wp))
                max_x = max(max_x, real(vertices(i)%x, wp))
                min_y = min(min_y, real(vertices(i)%y, wp))
                max_y = max(max_y, real(vertices(i)%y, wp))
            end do

            write(*,*) "--- Vertex Bounds (font space) ---"
            write(*,*) "X range:", min_x, "to", max_x
            write(*,*) "Y range:", min_y, "to", max_y

            ! Apply scaling to see scaled bounds
            scaled_min_x = min_x * scale_x + shift_x
            scaled_max_x = max_x * scale_x + shift_x
            scaled_min_y = min_y * scale_y + shift_y  ! Note: no Y flip yet
            scaled_max_y = max_y * scale_y + shift_y

            write(*,*) "--- Vertex Bounds (scaled, font Y orientation) ---"
            write(*,*) "X range:", scaled_min_x, "to", scaled_max_x
            write(*,*) "Y range:", scaled_min_y, "to", scaled_max_y

            ! Apply Y flip for bitmap space
            write(*,*) "--- Vertex Bounds (bitmap space, Y flipped) ---"
            write(*,*) "X range:", scaled_min_x, "to", scaled_max_x
            write(*,*) "Y range:", -scaled_max_y, "to", -scaled_min_y

            ! Compare with bitmap offsets
            write(*,*) "--- Offset Analysis ---"
            write(*,*) "Expected bitmap X offset (floor of min scaled X):", int(floor(scaled_min_x))
            write(*,*) "Actual STB X offset:", stb_xoff
            write(*,*) "Expected bitmap Y offset (floor of -max scaled Y):", int(floor(-scaled_max_y))
            write(*,*) "Actual STB Y offset:", stb_yoff

            call stb_free_shape_pure(vertices)
        end if

        ! Find and report some specific pixel differences
        call analyze_pixel_differences(stb_bitmap, pure_bitmap, stb_width, stb_height)

        ! Cleanup
        call stbtt_free_bitmap(stb_bitmap_ptr)
        call stbtt_free_bitmap(pure_bitmap_ptr)

    end subroutine test_vertex_coordinate_analysis

    subroutine analyze_pixel_differences(stb_bitmap, pure_bitmap, width, height)
        integer(c_int8_t), intent(in) :: stb_bitmap(:), pure_bitmap(:)
        integer, intent(in) :: width, height
        integer :: differences, i, stb_val, pure_val
        integer :: first_diff_idx, stb_nonzero, pure_nonzero
        integer :: row, col

        differences = 0
        stb_nonzero = 0
        pure_nonzero = 0
        first_diff_idx = -1

        do i = 1, width * height
            stb_val = int(stb_bitmap(i))
            pure_val = int(pure_bitmap(i))

            if (stb_val /= 0) stb_nonzero = stb_nonzero + 1
            if (pure_val /= 0) pure_nonzero = pure_nonzero + 1

            if (stb_val /= pure_val) then
                differences = differences + 1
                if (first_diff_idx == -1) first_diff_idx = i
            end if
        end do

        write(*,*) "--- Quick Pixel Analysis ---"
        write(*,*) "STB non-zero pixels:", stb_nonzero
        write(*,*) "Pure non-zero pixels:", pure_nonzero
        write(*,*) "Total differences:", differences

        if (first_diff_idx > 0) then
            row = (first_diff_idx - 1) / width
            col = mod(first_diff_idx - 1, width)
            write(*,*) "First difference at pixel", first_diff_idx, "-> row", row, "col", col
            write(*,*) "STB value:", int(stb_bitmap(first_diff_idx))
            write(*,*) "Pure value:", int(pure_bitmap(first_diff_idx))
        end if

    end subroutine analyze_pixel_differences

end program test_forttf_vertex_analysis
