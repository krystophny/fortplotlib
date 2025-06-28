program test_active_edges
    !! Test STB-compatible active edge management algorithms
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_active_edge_management()

contains

    subroutine test_active_edge_management()
        !! Test active edge creation, updating, and removal
        
        write(*,*) "=== Active Edge Management Tests ==="
        
        ! Test 1: Active edge creation
        write(*,*) "--- Test 1: Active Edge Creation ---"
        call test_active_edge_creation()
        
        ! Test 2: Active edge position updates
        write(*,*) "--- Test 2: Active Edge Updates ---"
        call test_active_edge_updates()
        
        ! Test 3: Active edge removal
        write(*,*) "--- Test 3: Active Edge Removal ---"
        call test_active_edge_removal()
        
        write(*,*) "=== Active Edge Management Tests Complete ==="
        
    end subroutine test_active_edge_management
    
    subroutine test_active_edge_creation()
        !! Test creation of active edges from regular edges
        type(stb_edge_t) :: edge
        type(stb_active_edge_t) :: active_edge
        real(wp), parameter :: start_point = 5.0_wp
        integer, parameter :: off_x = 10
        
        ! Create test edge: (0,0) to (20,10) - slope = 2.0
        edge = stb_edge_t(x0=0.0_wp, y0=0.0_wp, x1=20.0_wp, y1=10.0_wp, invert=0)
        
        ! Create active edge
        active_edge = stb_new_active_edge(edge, off_x, start_point)
        
        write(*,*) "Test edge: (0,0) to (20,10) with off_x=10, start_point=5"
        write(*,*) "Active edge results:"
        write(*,*) "  fx (X position):", active_edge%fx
        write(*,*) "  fdx (X step):", active_edge%fdx
        write(*,*) "  fdy (Y step):", active_edge%fdy
        write(*,*) "  direction:", active_edge%direction
        write(*,*) "  sy (start Y):", active_edge%sy
        write(*,*) "  ey (end Y):", active_edge%ey
        
        ! Verify calculations
        ! Expected: fdx = (20-0)/(10-0) = 2.0
        ! Expected: fx = 0 + 2.0 * (5-0) + 10 = 20.0
        if (abs(active_edge%fdx - 2.0_wp) < epsilon(1.0_wp) .and. &
            abs(active_edge%fx - 20.0_wp) < epsilon(1.0_wp) .and. &
            abs(active_edge%direction - 1.0_wp) < epsilon(1.0_wp)) then
            write(*,*) "✅ Active edge creation works correctly"
        else
            write(*,*) "❌ Active edge creation failed"
        end if
        
    end subroutine test_active_edge_creation
    
    subroutine test_active_edge_updates()
        !! Test updating active edge positions during scanline progression
        type(stb_edge_t) :: edge1, edge2
        type(stb_active_edge_t), target :: head, active1, active2
        real(wp), parameter :: y_step = 1.0_wp
        
        ! Create test edges with different slopes
        edge1 = stb_edge_t(x0=0.0_wp, y0=0.0_wp, x1=10.0_wp, y1=10.0_wp, invert=0)  ! slope = 1.0
        edge2 = stb_edge_t(x0=20.0_wp, y0=0.0_wp, x1=30.0_wp, y1=5.0_wp, invert=0)   ! slope = 2.0
        
        ! Create active edges
        active1 = stb_new_active_edge(edge1, 0, 0.0_wp)
        active2 = stb_new_active_edge(edge2, 0, 0.0_wp)
        
        ! Set up linked list: head -> active1 -> active2 -> null
        head%next => active1
        active1%next => active2
        active2%next => null()
        
        write(*,*) "Before update (Y step = 1.0):"
        write(*,*) "  Active1 fx:", active1%fx, " fdx:", active1%fdx
        write(*,*) "  Active2 fx:", active2%fx, " fdx:", active2%fdx
        
        ! Store initial positions
        real(wp) :: initial_fx1, initial_fx2
        initial_fx1 = active1%fx
        initial_fx2 = active2%fx
        
        ! Update positions
        call stb_update_active_edges(head, y_step)
        
        write(*,*) "After update:"
        write(*,*) "  Active1 fx:", active1%fx, " (expected:", initial_fx1 + active1%fdx, ")"
        write(*,*) "  Active2 fx:", active2%fx, " (expected:", initial_fx2 + active2%fdx, ")"
        
        ! Verify updates
        if (abs(active1%fx - (initial_fx1 + active1%fdx)) < epsilon(1.0_wp) .and. &
            abs(active2%fx - (initial_fx2 + active2%fdx)) < epsilon(1.0_wp)) then
            write(*,*) "✅ Active edge updates work correctly"
        else
            write(*,*) "❌ Active edge updates failed"
        end if
        
    end subroutine test_active_edge_updates
    
    subroutine test_active_edge_removal()
        !! Test removal of completed active edges
        type(stb_edge_t) :: edge1, edge2, edge3
        type(stb_active_edge_t), target :: head, active1, active2, active3
        type(stb_active_edge_t), pointer :: current
        real(wp), parameter :: current_y = 8.0_wp
        integer :: count_before, count_after
        
        ! Create test edges with different end Y coordinates
        edge1 = stb_edge_t(x0=0.0_wp, y0=0.0_wp, x1=10.0_wp, y1=5.0_wp, invert=0)   ! ends at Y=5
        edge2 = stb_edge_t(x0=20.0_wp, y0=0.0_wp, x1=30.0_wp, y1=10.0_wp, invert=0) ! ends at Y=10  
        edge3 = stb_edge_t(x0=40.0_wp, y0=0.0_wp, x1=50.0_wp, y1=7.0_wp, invert=0)  ! ends at Y=7
        
        ! Create active edges
        active1 = stb_new_active_edge(edge1, 0, 0.0_wp)
        active2 = stb_new_active_edge(edge2, 0, 0.0_wp)
        active3 = stb_new_active_edge(edge3, 0, 0.0_wp)
        
        ! Set up linked list: head -> active1 -> active2 -> active3 -> null
        head%next => active1
        active1%next => active2
        active2%next => active3
        active3%next => null()
        
        ! Count edges before removal
        count_before = 0
        current => head%next
        do while (associated(current))
            count_before = count_before + 1
            current => current%next
        end do
        
        write(*,*) "Before removal (current Y =", current_y, "):"
        write(*,*) "  Active edges:", count_before
        write(*,*) "  Edge1 ends at Y=5 (should be removed)"
        write(*,*) "  Edge2 ends at Y=10 (should remain)"
        write(*,*) "  Edge3 ends at Y=7 (should be removed)"
        
        ! Remove completed edges
        call stb_remove_completed_edges(head, current_y)
        
        ! Count edges after removal
        count_after = 0
        current => head%next
        do while (associated(current))
            count_after = count_after + 1
            write(*,*) "  Remaining edge ends at Y=", current%ey
            current => current%next
        end do
        
        write(*,*) "After removal:"
        write(*,*) "  Active edges:", count_after
        
        ! Should have 1 remaining edge (the one ending at Y=10)
        if (count_after == 1) then
            write(*,*) "✅ Active edge removal works correctly"
        else
            write(*,*) "❌ Active edge removal failed - expected 1, got", count_after
        end if
        
    end subroutine test_active_edge_removal

end program test_active_edges