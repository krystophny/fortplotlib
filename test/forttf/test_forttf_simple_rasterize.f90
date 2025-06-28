! filepath: /home/ert/code/fortplotlib/test/forttf/test_forttf_simple_rasterize.f90
program test_forttf_simple_rasterize
    !! Simple rasterization test of the entire pipeline
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_triangle_rasterization()

contains

    subroutine test_triangle_rasterization()
        ! Define a simple triangle shape
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        type(stb_edge_t), allocatable :: edges(:)
        type(stb_bitmap_t) :: bitmap
        integer(c_int8_t), allocatable, target :: pixels(:)
        integer :: i, j, num_edges, non_zero_count
        
        ! Bitmap dimensions
        integer, parameter :: width = 20, height = 20
        
        ! Parameters for rasterization
        real(wp), parameter :: scale_x = 1.0_wp, scale_y = 1.0_wp
        real(wp), parameter :: shift_x = 5.0_wp, shift_y = 5.0_wp
        logical, parameter :: invert = .false.
        
        write(*,*) "=== Simple Triangle Rasterization Test ==="
        
        ! Create triangle points
        allocate(points(3))
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)    ! Bottom-left
        points(2) = stb_point_t(x=10.0_wp, y=0.0_wp)   ! Bottom-right
        points(3) = stb_point_t(x=5.0_wp, y=10.0_wp)   ! Top-center
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 3  ! 3 points in the contour
        
        ! Build edges
        edges = stb_build_edges(points, contour_lengths, 1, &
                               scale_x, scale_y, shift_x, shift_y, invert)
        num_edges = size(edges)
        
        write(*,*) "Created", num_edges, "edges for triangle"
        
        ! Sort edges
        call stb_sort_edges(edges, num_edges)
        
        ! Create bitmap
        allocate(pixels(width * height))
        pixels = 0
        
        bitmap%w = width
        bitmap%h = height
        bitmap%stride = width
        bitmap%pixels => pixels
        
        ! Rasterize triangle
        call stb_rasterize_sorted_edges(bitmap, edges, num_edges, 1, 0, 0, c_null_ptr)
        
        ! Count non-zero pixels
        non_zero_count = 0
        do i = 1, width * height
            if (pixels(i) /= 0) non_zero_count = non_zero_count + 1
        end do
        
        write(*,*) "Rasterized", non_zero_count, "non-zero pixels out of", width * height
        
        ! Print the bitmap for visual inspection
        write(*,*) "Bitmap output (non-zero shown as X):"
        do i = 1, height
            write(*, '(20A1)') (merge('X', '.', pixels((i-1)*width+j) /= 0), j = 1, width)
        end do
        
        deallocate(points, contour_lengths, edges, pixels)
        
    end subroutine test_triangle_rasterization

end program test_forttf_simple_rasterize
