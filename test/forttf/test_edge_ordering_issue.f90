program test_edge_ordering_issue
    !! Test to identify the specific edge ordering difference between STB and ForTTF
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    write(*,*) "=== Edge Ordering Issue Investigation ==="
    call test_stb_vs_forttf_edge_building()
    
contains

    subroutine test_stb_vs_forttf_edge_building()
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer :: i, num_edges
        real(wp), parameter :: scale_x = 1.0_wp, scale_y = 1.0_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        logical, parameter :: invert = .false.
        
        ! Create simple triangle with known points
        allocate(points(3))
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)   ! P0
        points(2) = stb_point_t(x=10.0_wp, y=0.0_wp)  ! P1  
        points(3) = stb_point_t(x=5.0_wp, y=10.0_wp)  ! P2
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 3
        
        write(*,*) "Input triangle points:"
        do i = 1, 3
            write(*,'("  P", I1, ": (", F5.1, ",", F5.1, ")")') i-1, points(i)%x, points(i)%y
        end do
        write(*,*)
        
        ! Manually trace STB algorithm:
        ! For contour with 3 points: j = wcount[i]-1 = 3-1 = 2
        ! Loop: k=0,1,2 with j starting at 2
        ! 
        ! Iteration 1: k=0, j=2 -> edge from P[2] to P[0] -> (5,10) to (0,0)
        !              Then j=k=0
        ! Iteration 2: k=1, j=0 -> edge from P[0] to P[1] -> (0,0) to (10,0)  
        !              Then j=k=1
        ! Iteration 3: k=2, j=1 -> edge from P[1] to P[2] -> (10,0) to (5,10)
        !              Then j=k=2
        
        write(*,*) "STB C algorithm would build edges in this order:"
        write(*,*) "  Edge 1: P[2] -> P[0] = (5.0, 10.0) -> (0.0, 0.0)"
        write(*,*) "  Edge 2: P[0] -> P[1] = (0.0, 0.0) -> (10.0, 0.0)  [horizontal, skipped]"
        write(*,*) "  Edge 3: P[1] -> P[2] = (10.0, 0.0) -> (5.0, 10.0)"
        write(*,*)
        
        ! Now trace ForTTF algorithm:
        ! For contour with 3 points: j = contour_lengths(contour) = 3
        ! Loop: k=1,2,3 with j starting at 3
        !
        ! Iteration 1: k=1, j=3 -> a=0, b=2  -> edge from P[2] to P[0] -> (5,10) to (0,0)
        !              Then j=k=1  
        ! Iteration 2: k=2, j=1 -> a=1, b=0  -> edge from P[0] to P[1] -> (0,0) to (10,0)
        !              Then j=k=2
        ! Iteration 3: k=3, j=2 -> a=2, b=1  -> edge from P[1] to P[2] -> (10,0) to (5,10)
        !              Then j=k=3
        
        write(*,*) "ForTTF algorithm builds edges in this order:"
        edges = stb_build_edges(points, contour_lengths, 1, &
                               scale_x, scale_y, shift_x, shift_y, invert)
        num_edges = size(edges)
        
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": (", F5.1, ",", F5.1, ") -> (", F5.1, ",", F5.1, "), invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        write(*,*)
        
        write(*,*) "After sorting by y0:"
        call stb_sort_edges(edges, num_edges)
        
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": (", F5.1, ",", F5.1, ") -> (", F5.1, ",", F5.1, "), invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        deallocate(points, contour_lengths, edges)
        
    end subroutine test_stb_vs_forttf_edge_building

end program test_edge_ordering_issue