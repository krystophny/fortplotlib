! filepath: /home/ert/code/fortplotlib/test/forttf/test_forttf_edge_building_basic.f90
program test_forttf_edge_building_basic
    !! Simple edge building test for debugging
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_basic_triangle_edges()
    call test_triangle_with_transforms()

contains

    subroutine test_basic_triangle_edges()
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer :: i, num_edges
        real(wp), parameter :: scale_x = 1.0_wp, scale_y = 1.0_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        logical, parameter :: invert = .false.
        
        ! Create a simple triangle (3 points)
        allocate(points(3))
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)   ! Bottom-left
        points(2) = stb_point_t(x=10.0_wp, y=0.0_wp)  ! Bottom-right
        points(3) = stb_point_t(x=5.0_wp, y=10.0_wp)  ! Top-center
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 3  ! 3 points in contour
        
        write(*,*) "=== Basic Triangle Edge Building Test ==="
        write(*,*) "Input points:"
        do i = 1, size(points)
            write(*,'("  Point", I1, ": (", F5.1, ",", F5.1, ")")') i, points(i)%x, points(i)%y
        end do
        
        ! Build edges using STB-compatible algorithm
        edges = stb_build_edges(points, contour_lengths, 1, &
                               scale_x, scale_y, shift_x, shift_y, invert)
        num_edges = size(edges)
        
        write(*,*) "Edges built:", num_edges
        
        ! Print edge details
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": (", F5.1, ",", F5.1, ") -> (", F5.1, ",", F5.1, "), invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        ! Sort edges
        call stb_sort_edges(edges, num_edges)
        
        write(*,*) "Sorted edges:"
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": (", F5.1, ",", F5.1, ") -> (", F5.1, ",", F5.1, "), invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        deallocate(points, contour_lengths, edges)
        
    end subroutine test_basic_triangle_edges
    
    subroutine test_triangle_with_transforms()
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer :: i, num_edges
        real(wp), parameter :: scale_x = 0.5_wp, scale_y = 0.5_wp
        real(wp), parameter :: shift_x = 10.0_wp, shift_y = 5.0_wp
        logical, parameter :: invert = .true.
        
        write(*,*) ""
        write(*,*) "=== Triangle With Transforms Test ==="
        write(*,*) "Using scale_x =", scale_x, ", scale_y =", scale_y
        write(*,*) "Using shift_x =", shift_x, ", shift_y =", shift_y
        write(*,*) "Using invert =", invert
        
        ! Create a simple triangle (3 points)
        allocate(points(3))
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)   ! Bottom-left
        points(2) = stb_point_t(x=10.0_wp, y=0.0_wp)  ! Bottom-right
        points(3) = stb_point_t(x=5.0_wp, y=10.0_wp)  ! Top-center
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 3  ! 3 points in contour
        
        ! Build edges using STB-compatible algorithm
        edges = stb_build_edges(points, contour_lengths, 1, &
                               scale_x, scale_y, shift_x, shift_y, invert)
        num_edges = size(edges)
        
        write(*,*) "Edges built:", num_edges
        
        ! Print edge details
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": (", F6.1, ",", F6.1, ") -> (", F6.1, ",", F6.1, "), invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        ! Sort edges
        call stb_sort_edges(edges, num_edges)
        
        write(*,*) "Sorted edges:"
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": (", F6.1, ",", F6.1, ") -> (", F6.1, ",", F6.1, "), invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        deallocate(points, contour_lengths, edges)
        
    end subroutine test_triangle_with_transforms

end program test_forttf_edge_building_basic
