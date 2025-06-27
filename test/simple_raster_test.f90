program simple_raster_test
    use iso_fortran_env, only: int8, real64
    implicit none

    integer, parameter :: wp = real64

    type :: edge_t
        real(wp) :: x0, y0, x1, y1
        logical :: invert
    end type edge_t

    integer, parameter :: width = 16, height = 16
    integer(int8) :: bitmap(width * height)
    type(edge_t) :: edges(2)
    integer :: i, j, pixel_idx
    real(wp) :: y_top, y_bottom, coverage

    ! Create two simple vertical edges for testing
    ! Edge 1: from (6, 0) to (6, 16) - should be inside the glyph
    edges(1)%x0 = 6.0_wp
    edges(1)%y0 = 0.0_wp
    edges(1)%x1 = 6.0_wp
    edges(1)%y1 = 16.0_wp
    edges(1)%invert = .false.

    ! Edge 2: from (10, 0) to (10, 16) - should close the glyph
    edges(2)%x0 = 10.0_wp
    edges(2)%y0 = 0.0_wp
    edges(2)%x1 = 10.0_wp
    edges(2)%y1 = 16.0_wp
    edges(2)%invert = .true.

    ! Clear bitmap
    bitmap = 0_int8

    ! Simple scanline rasterizer
    do j = 0, height - 1
        y_top = real(j, wp)
        y_bottom = y_top + 1.0_wp

        ! Calculate winding number for each pixel in this scanline
        do i = 0, width - 1
            coverage = 0.0_wp

            ! Check each edge
            do pixel_idx = 1, 2
                if (edges(pixel_idx)%y0 <= y_bottom .and. edges(pixel_idx)%y1 > y_top) then
                    ! Edge crosses this scanline
                    if (int(edges(pixel_idx)%x0) == i) then
                        ! Edge is at this pixel
                        if (edges(pixel_idx)%invert) then
                            coverage = coverage + 1.0_wp
                        else
                            coverage = coverage - 1.0_wp
                        end if
                    end if
                end if
            end do

            ! Convert coverage to pixel value
            pixel_idx = j * width + i + 1
            if (abs(coverage) > 0.5_wp) then
                bitmap(pixel_idx) = 127_int8  ! Inside
            else
                bitmap(pixel_idx) = 0_int8    ! Outside
            end if
        end do
    end do

    ! Print result
    print *, "Simple rasterizer test result:"
    do j = 0, height - 1
        write(*, '(A)', advance='no') "Row "
        write(*, '(I2)', advance='no') j
        write(*, '(A)', advance='no') ": "
        do i = 0, width - 1
            pixel_idx = j * width + i + 1
            if (bitmap(pixel_idx) > 0) then
                write(*, '(A)', advance='no') "X"
            else
                write(*, '(A)', advance='no') "."
            end if
        end do
        print *
    end do

end program simple_raster_test
