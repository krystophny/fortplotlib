program test_direct_single_edge
    !! Direct single edge test using simple edge processing
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_simple_diagonal_edge()

contains

    subroutine test_simple_diagonal_edge()
        !! Test single diagonal edge with simplified rasterization
        
        integer, parameter :: width = 5, height = 5
        real(wp) :: bitmap(width, height)
        integer :: i, j
        
        write(*,*) "=== Direct Single Diagonal Edge Test ==="
        write(*,*) "Edge: (0.5, 0.5) → (3.5, 3.5) on 5x5 grid"
        write(*,*) ""
        
        ! Initialize bitmap
        bitmap = 0.0_wp
        
        ! Rasterize single diagonal edge manually for testing
        call rasterize_diagonal_edge(bitmap, width, height, 0.5_wp, 0.5_wp, 3.5_wp, 3.5_wp)
        
        ! Display result
        write(*,*) "Manual rasterization result (coverage values):"
        do j = 1, height
            write(*,'(A)', advance='no') "  "
            do i = 1, width
                write(*,'(F6.2)', advance='no') bitmap(i, j)
            end do
            write(*,*)
        end do
        write(*,*) ""
        
        ! Convert to integer pixel values
        write(*,*) "Integer pixel values (0-255):"
        do j = 1, height
            write(*,'(A)', advance='no') "  "
            do i = 1, width
                write(*,'(I4)', advance='no') min(255, max(0, int(bitmap(i, j) * 255.0_wp + 0.5_wp)))
            end do
            write(*,*)
        end do
        write(*,*) ""
        
        ! Create two-edge test case
        write(*,*) "=== Two Edge Test Case ==="
        call test_two_edges()
        
    end subroutine test_simple_diagonal_edge
    
    subroutine rasterize_diagonal_edge(bitmap, width, height, x0, y0, x1, y1)
        !! Simple diagonal edge rasterization for testing
        real(wp), intent(inout) :: bitmap(:,:)
        integer, intent(in) :: width, height
        real(wp), intent(in) :: x0, y0, x1, y1
        
        integer :: i, j
        real(wp) :: edge_x, edge_coverage, pixel_center_x, pixel_center_y
        real(wp) :: dx, dy, slope
        
        ! Calculate edge slope
        dy = y1 - y0
        dx = x1 - x0
        if (abs(dx) < 1e-10_wp) return  ! Vertical edge, skip for simplicity
        slope = dy / dx
        
        write(*,'(A,F6.3)') "Edge slope: ", slope
        
        ! For each pixel, calculate coverage
        do j = 1, height
            do i = 1, width
                pixel_center_x = real(i-1, wp) + 0.5_wp
                pixel_center_y = real(j-1, wp) + 0.5_wp
                
                ! Calculate where edge intersects this pixel's Y center
                if (pixel_center_y >= min(y0, y1) .and. pixel_center_y <= max(y0, y1)) then
                    edge_x = x0 + (pixel_center_y - y0) / slope
                    
                    ! Simple coverage calculation based on edge position
                    if (edge_x >= pixel_center_x - 0.5_wp .and. edge_x <= pixel_center_x + 0.5_wp) then
                        ! Edge crosses this pixel
                        edge_coverage = abs(edge_x - pixel_center_x + 0.5_wp)
                        bitmap(i, j) = edge_coverage
                    end if
                end if
            end do
        end do
        
    end subroutine rasterize_diagonal_edge
    
    subroutine test_two_edges()
        !! Test two intersecting edges
        integer, parameter :: width = 5, height = 5
        real(wp) :: bitmap(width, height)
        integer :: i, j
        
        write(*,*) "Two intersecting diagonal edges:"
        write(*,*) "Edge 1: (0.5, 0.5) → (3.5, 3.5)"
        write(*,*) "Edge 2: (3.5, 0.5) → (0.5, 3.5)"
        write(*,*) ""
        
        ! Initialize bitmap
        bitmap = 0.0_wp
        
        ! Rasterize first edge
        call rasterize_diagonal_edge(bitmap, width, height, 0.5_wp, 0.5_wp, 3.5_wp, 3.5_wp)
        
        ! Rasterize second edge (additive)
        call rasterize_diagonal_edge(bitmap, width, height, 3.5_wp, 0.5_wp, 0.5_wp, 3.5_wp)
        
        ! Display result
        write(*,*) "Two-edge result (coverage values):"
        do j = 1, height
            write(*,'(A)', advance='no') "  "
            do i = 1, width
                write(*,'(F6.2)', advance='no') bitmap(i, j)
            end do
            write(*,*)
        end do
        write(*,*) ""
        
        write(*,*) "Two-edge integer pixel values (0-255):"
        do j = 1, height
            write(*,'(A)', advance='no') "  "
            do i = 1, width
                write(*,'(I4)', advance='no') min(255, max(0, int(bitmap(i, j) * 255.0_wp + 0.5_wp)))
            end do
            write(*,*)
        end do
        write(*,*) ""
        
        write(*,*) "This demonstrates edge interaction effects vs isolated single edge."
        
    end subroutine test_two_edges

end program test_direct_single_edge