program test_forttf_coordinate_transforms
    use iso_fortran_env, only: int32, real32
    use iso_c_binding, only: c_ptr, c_null_ptr, c_int, c_float, c_char, c_null_char
    use fortplot_stb_truetype
    use forttf
    use forttf_outline, only: stb_get_glyph_shape_pure, stb_free_shape_pure
    use forttf_bitmap, only: stb_get_glyph_bitmap_box_pure
    use forttf_types, only: ttf_vertex_t
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! Constants
    integer(c_int), parameter :: GLYPH_INDEX = 36  ! '$' character
    real(c_float), parameter :: SCALE_X = 4.0
    real(c_float), parameter :: SCALE_Y = 4.0
    real(c_float), parameter :: SHIFT_X = 0.0
    real(c_float), parameter :: SHIFT_Y = 0.0

    ! Variables
    character(len=*), parameter :: FONT_PATH = "/System/Library/Fonts/Monaco.ttf"
    type(c_ptr) :: font_info
    integer(c_int) :: result

    ! STB variables
    integer(c_int) :: stb_x0, stb_y0, stb_x1, stb_y1
    integer(c_int) :: stb_width, stb_height, stb_xoff, stb_yoff
    type(c_ptr) :: stb_bitmap

    ! Pure Fortran variables
    type(stb_fontinfo_pure_t) :: pure_font
    type(ttf_vertex_t), allocatable :: vertices(:)
    integer :: num_vertices
    integer :: pure_ix0, pure_iy0, pure_ix1, pure_iy1
    integer :: pure_width, pure_height, pure_xoff, pure_yoff
    integer :: i
    real(wp) :: scaled_x, scaled_y, bitmap_x, bitmap_y

    write(*,*) "=== Coordinate Transform Analysis ==="
    write(*,*) "✅ Using font:" // FONT_PATH

    ! Initialize STB font
    result = stbtt_init_font(font_info, FONT_PATH)
    if (result == 0) then
        write(*,*) "❌ Failed to initialize STB font"
        stop 1
    end if

    ! Initialize Pure Fortran font
    call stb_init_font_pure(pure_font, FONT_PATH)
    if (.not. pure_font%initialized) then
        write(*,*) "❌ Failed to initialize Pure font"
        stop 1
    end if

    write(*,*) "--- STB Glyph Bounding Box ---"
    call stbtt_get_glyph_box(font_info, GLYPH_INDEX, stb_x0, stb_y0, stb_x1, stb_y1)
    write(*,*) "Glyph box (font units):", stb_x0, stb_y0, stb_x1, stb_y1

    call stbtt_get_glyph_bitmap_box(font_info, GLYPH_INDEX, SCALE_X, SCALE_Y, SHIFT_X, SHIFT_Y, &
                                   stb_x0, stb_y0, stb_x1, stb_y1)
    write(*,*) "Bitmap box (pixels):", stb_x0, stb_y0, stb_x1, stb_y1

    stb_width = stb_x1 - stb_x0
    stb_height = stb_y1 - stb_y0
    stb_xoff = stb_x0
    stb_yoff = stb_y0
    write(*,*) "STB dimensions:", stb_width, "x", stb_height, " offset:", stb_xoff, stb_yoff

    write(*,*) "--- Pure Fortran Glyph Bounding Box ---"
    call stb_get_glyph_bitmap_box_pure(pure_font, GLYPH_INDEX, real(SCALE_X, wp), real(SCALE_Y, wp), &
                                      pure_ix0, pure_iy0, pure_ix1, pure_iy1)
    write(*,*) "Bitmap box (pixels):", pure_ix0, pure_iy0, pure_ix1, pure_iy1

    pure_width = pure_ix1 - pure_ix0
    pure_height = pure_iy1 - pure_iy0
    pure_xoff = pure_ix0
    pure_yoff = pure_iy0
    write(*,*) "Pure dimensions:", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff

    ! Check if bounding boxes match
    if (stb_x0 /= pure_ix0 .or. stb_y0 /= pure_iy0 .or. stb_x1 /= pure_ix1 .or. stb_y1 /= pure_iy1) then
        write(*,*) "❌ Bounding boxes don't match!"
        write(*,*) "STB: (", stb_x0, ",", stb_y0, ") to (", stb_x1, ",", stb_y1, ")"
        write(*,*) "Pure: (", pure_ix0, ",", pure_iy0, ") to (", pure_ix1, ",", pure_iy1, ")"
    else
        write(*,*) "✅ Bounding boxes match"
    end if

    ! Get vertex data from Pure Fortran
    num_vertices = stb_get_glyph_shape_pure(pure_font, GLYPH_INDEX, vertices)
    write(*,*) "--- Vertex Data (first 10 vertices) ---"
    do i = 1, min(10, num_vertices)
        write(*, '(A,I3,A,I2,A,F8.1,A,F8.1,A,F8.1,A,F8.1)') &
            "Vertex ", i, ": type=", vertices(i)%type, &
            " x=", real(vertices(i)%x), " y=", real(vertices(i)%y), &
            " cx=", real(vertices(i)%cx), " cy=", real(vertices(i)%cy)
    end do

    ! Apply coordinate transforms to see what happens to vertex positions
    write(*,*) "--- Transformed Vertex Positions (scaled, bitmap space) ---"
    do i = 1, min(5, num_vertices)
        scaled_x = real(vertices(i)%x, wp) * real(SCALE_X, wp) + real(SHIFT_X, wp)
        scaled_y = real(vertices(i)%y, wp) * real(SCALE_Y, wp) + real(SHIFT_Y, wp)
        ! Apply coordinate system transform (font coordinates -> bitmap coordinates)
        bitmap_x = scaled_x - real(pure_xoff, wp)
        bitmap_y = -scaled_y - real(pure_yoff, wp)  ! Note: Y is flipped
        write(*, '(A,I3,A,F8.1,A,F8.1,A,F8.1,A,F8.1)') &
            "Vertex ", i, ": scaled=(", scaled_x, ",", scaled_y, &
            ") bitmap=(", bitmap_x, ",", bitmap_y, ")"
    end do

    ! Clean up
    call stb_free_shape_pure(vertices)
    call stb_cleanup_font_pure(pure_font)
    call stbtt_free_font(font_info)

end program test_forttf_coordinate_transforms
