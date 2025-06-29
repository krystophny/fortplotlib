program test_forttf_bitmap_export
    use iso_fortran_env, only: int32, real32
    use iso_c_binding, only: c_ptr, c_null_ptr, c_int, c_float, c_char, c_null_char
    use fortplot_stb_truetype
    use forttf_outline, only: parse_glyph, vertex_t
    use forttf_bitmap, only: get_glyph_bitmap, get_stb_glyph_bitmap
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
    integer(c_int) :: result, width, height, xoff, yoff
    integer(c_int) :: width_stb, height_stb, xoff_stb, yoff_stb
    type(c_ptr) :: bitmap_stb, bitmap_pure
    type(vertex_t), allocatable :: vertices(:)
    integer :: num_vertices
    integer :: i, j, row, col
    integer(c_int) :: pixel_stb, pixel_pure

    write(*,*) "=== Exporting STB vs Pure Fortran Bitmaps ==="
    write(*,*) "✅ Using font:" // FONT_PATH

    ! Initialize font
    result = stbtt_init_font(font_info, FONT_PATH)
    if (result == 0) then
        write(*,*) "❌ Failed to initialize font"
        stop 1
    end if

    ! Parse glyph to get vertices
    call parse_glyph(font_info, GLYPH_INDEX, vertices, num_vertices)
    if (num_vertices == 0) then
        write(*,*) "❌ Failed to parse glyph"
        stop 1
    end if

    ! Get STB bitmap
    call get_stb_glyph_bitmap(font_info, GLYPH_INDEX, SCALE_X, SCALE_Y, SHIFT_X, SHIFT_Y, &
                              width_stb, height_stb, xoff_stb, yoff_stb, bitmap_stb)

    ! Get Pure Fortran bitmap
    call get_glyph_bitmap(font_info, vertices, num_vertices, SCALE_X, SCALE_Y, SHIFT_X, SHIFT_Y, &
                          width, height, xoff, yoff, bitmap_pure)

    write(*,*) "--- Bitmap Dimensions ---"
    write(*,*) "STB:  ", width_stb, "x", height_stb, " offset:", xoff_stb, yoff_stb
    write(*,*) "Pure: ", width, "x", height, " offset:", xoff, yoff

    if (width /= width_stb .or. height /= height_stb) then
        write(*,*) "❌ Bitmap dimensions don't match!"
        stop 1
    end if

    ! Export STB bitmap to file
    open(unit=10, file='stb_bitmap.pgm', status='replace')
    write(10, '(A)') 'P2'
    write(10, '(I0, 1X, I0)') width_stb, height_stb
    write(10, '(A)') '255'
    do row = 1, height_stb
        do col = 1, width_stb
            call stbtt_get_bitmap_pixel(bitmap_stb, col-1, row-1, pixel_stb)
            write(10, '(I0, 1X)', advance='no') pixel_stb
        end do
        write(10, *)  ! newline
    end do
    close(10)

    ! Export Pure Fortran bitmap to file
    open(unit=11, file='pure_bitmap.pgm', status='replace')
    write(11, '(A)') 'P2'
    write(11, '(I0, 1X, I0)') width, height
    write(11, '(A)') '255'
    do row = 1, height
        do col = 1, width
            call stbtt_get_bitmap_pixel(bitmap_pure, col-1, row-1, pixel_pure)
            write(11, '(I0, 1X)', advance='no') pixel_pure
        end do
        write(11, *)  ! newline
    end do
    close(11)

    ! Export difference bitmap
    open(unit=12, file='diff_bitmap.pgm', status='replace')
    write(12, '(A)') 'P2'
    write(12, '(I0, 1X, I0)') width, height
    write(12, '(A)') '255'
    do row = 1, height
        do col = 1, width
            call stbtt_get_bitmap_pixel(bitmap_stb, col-1, row-1, pixel_stb)
            call stbtt_get_bitmap_pixel(bitmap_pure, col-1, row-1, pixel_pure)
            ! Map difference to visible range: -255 to +255 -> 0 to 255
            write(12, '(I0, 1X)', advance='no') min(255, max(0, 128 + (pixel_pure - pixel_stb)/2))
        end do
        write(12, *)  ! newline
    end do
    close(12)

    write(*,*) "✅ Exported bitmaps:"
    write(*,*) "   - stb_bitmap.pgm (STB reference)"
    write(*,*) "   - pure_bitmap.pgm (Pure Fortran)"
    write(*,*) "   - diff_bitmap.pgm (difference visualization)"

    ! Clean up
    call stbtt_free_bitmap(bitmap_stb)
    call stbtt_free_bitmap(bitmap_pure)
    deallocate(vertices)
    call stbtt_free_font(font_info)

end program test_forttf_bitmap_export
