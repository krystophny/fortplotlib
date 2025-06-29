program test_edge_sorting_stability  
    !! Test edge sorting stability for edges with identical y0 values
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    write(*,*) "=== Edge Sorting Stability Test ==="
    call test_sorting_with_identical_y0()
    
contains

    subroutine test_sorting_with_identical_y0()
        type(stb_edge_t), allocatable :: edges(:)
        integer :: i, num_edges
        
        ! Create edges with identical y0 values but different x0 values
        ! This tests the secondary sorting criteria and stability
        num_edges = 4
        allocate(edges(num_edges))
        
        ! Edges all starting at y=5.0 but different x positions
        edges(1) = stb_edge_t(x0=8.0_wp, y0=5.0_wp, x1=8.0_wp, y1=10.0_wp, invert=0)
        edges(2) = stb_edge_t(x0=2.0_wp, y0=5.0_wp, x1=2.0_wp, y1=10.0_wp, invert=1)  
        edges(3) = stb_edge_t(x0=5.0_wp, y0=5.0_wp, x1=5.0_wp, y1=10.0_wp, invert=0)
        edges(4) = stb_edge_t(x0=1.0_wp, y0=5.0_wp, x1=1.0_wp, y1=10.0_wp, invert=1)
        
        write(*,*) "Original edge order (all have y0=5.0):"
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": x0=", F4.1, " y0=", F4.1, " x1=", F4.1, " y1=", F5.1, " invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        write(*,*)
        
        ! Test insertion sort (used for small arrays)
        write(*,*) "After insertion sort:"
        call stb_sort_edges_ins_sort(edges, num_edges)
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": x0=", F4.1, " y0=", F4.1, " x1=", F4.1, " y1=", F5.1, " invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        write(*,*)
        
        ! Reset and test quicksort
        edges(1) = stb_edge_t(x0=8.0_wp, y0=5.0_wp, x1=8.0_wp, y1=10.0_wp, invert=0)
        edges(2) = stb_edge_t(x0=2.0_wp, y0=5.0_wp, x1=2.0_wp, y1=10.0_wp, invert=1)  
        edges(3) = stb_edge_t(x0=5.0_wp, y0=5.0_wp, x1=5.0_wp, y1=10.0_wp, invert=0)
        edges(4) = stb_edge_t(x0=1.0_wp, y0=5.0_wp, x1=1.0_wp, y1=10.0_wp, invert=1)
        
        write(*,*) "After quicksort:"
        call stb_sort_edges_quicksort(edges, num_edges)
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": x0=", F4.1, " y0=", F4.1, " x1=", F4.1, " y1=", F5.1, " invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        write(*,*)
        
        ! Test with different y0 values to verify primary sorting
        edges(1) = stb_edge_t(x0=1.0_wp, y0=8.0_wp, x1=1.0_wp, y1=10.0_wp, invert=0)
        edges(2) = stb_edge_t(x0=2.0_wp, y0=3.0_wp, x1=2.0_wp, y1=10.0_wp, invert=1)  
        edges(3) = stb_edge_t(x0=3.0_wp, y0=6.0_wp, x1=3.0_wp, y1=10.0_wp, invert=0)
        edges(4) = stb_edge_t(x0=4.0_wp, y0=1.0_wp, x1=4.0_wp, y1=10.0_wp, invert=1)
        
        write(*,*) "With different y0 values - before sort:"
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": x0=", F4.1, " y0=", F4.1, " x1=", F4.1, " y1=", F5.1, " invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        write(*,*) "After combined sort (quicksort + insertion):"
        call stb_sort_edges(edges, num_edges)
        do i = 1, num_edges
            write(*,'("  Edge", I1, ": x0=", F4.1, " y0=", F4.1, " x1=", F4.1, " y1=", F5.1, " invert=", I1)') &
                  i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        deallocate(edges)
        
    end subroutine test_sorting_with_identical_y0

end program test_edge_sorting_stability