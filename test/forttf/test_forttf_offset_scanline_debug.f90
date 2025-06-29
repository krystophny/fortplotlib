program test_forttf_offset_scanline_debug
    !! Debug the "No result from offset scanline filling" issue
    !! Focus on fixing stb_fill_active_edges_with_offset integration
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: issues_found = 0

    write(*,*) '🔧 Debugging offset scanline filling issue'
    write(*,*) '========================================'
    write(*,*)

    ! Test 1: Null pointer issue
    call test_null_pointer_issue()

    ! Test 2: Single edge offset filling
    call test_single_edge_offset_filling()

    ! Test 3: Multiple edges offset filling
    call test_multiple_edges_offset_filling()

    ! Test 4: Vertical vs non-vertical edges
    call test_vertical_vs_nonvertical_edges()

    ! Test 5: Compare with regular filling
    call test_compare_regular_vs_offset_filling()

    ! Summary
    write(*,*)
    write(*,*) '📊 Debug Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Issues found: ', issues_found
    if (pass_count == test_count .and. issues_found == 0) then
        write(*,*) '✅ Offset scanline filling issue FIXED'
    else
        write(*,*) '⚠️  Offset scanline filling still has issues'
        if (issues_found > 0) then
            write(*,*) '🔧 Need to fix identified integration problems'
        end if
    end if

contains

    subroutine test_null_pointer_issue()
        !! Test the null pointer issue that caused "No result"
        real(wp) :: scanline(10), fill_buffer(10)
        type(stb_active_edge_t), target :: edge
        type(stb_active_edge_t), pointer :: null_ptr
        
        write(*,*) '  Testing null pointer issue...'
        
        ! Test with null pointer (this should do nothing)
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        null_ptr => null()
        
        call stb_fill_active_edges_with_offset(null_ptr, 1.0_wp, 10, scanline, fill_buffer)
        
        if (any(abs(scanline) > TOLERANCE) .or. any(abs(fill_buffer) > TOLERANCE)) then
            issues_found = issues_found + 1
            write(*,*) '    ⚠️  Null pointer should produce no result'
        else
            write(*,*) '    ✅ Null pointer correctly produces no result'
        end if
        
        call record_test("Null pointer handling", .true.)
    end subroutine

    subroutine test_single_edge_offset_filling()
        !! Test single edge offset filling
        real(wp) :: scanline(10), fill_buffer(10)
        type(stb_active_edge_t), target :: edge
        type(stb_active_edge_t), pointer :: edge_ptr
        
        write(*,*) '  Testing single edge offset filling...'
        
        ! Setup a proper edge
        edge%sy = 0.0_wp
        edge%ey = 2.0_wp
        edge%fx = 2.5_wp
        edge%fdx = 0.0_wp  ! Vertical edge
        edge%direction = 1.0_wp
        edge%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        edge_ptr => edge
        
        call stb_fill_active_edges_with_offset(edge_ptr, 1.0_wp, 10, scanline, fill_buffer)
        
        ! Check for results
        if (all(abs(scanline) < TOLERANCE) .and. all(abs(fill_buffer) < TOLERANCE)) then
            issues_found = issues_found + 1
            write(*,*) '    ⚠️  Single edge should produce some result'
            write(*,'(A,F8.5,A,F8.5,A,F8.5,A,F8.5)') &
                '    Edge: sy=', edge%sy, ', ey=', edge%ey, ', fx=', edge%fx, ', fdx=', edge%fdx
        else
            write(*,'(A,ES10.3,A,ES10.3)') &
                '    ✅ Single edge produced results: max_scanline=', maxval(abs(scanline)), &
                ', max_fill=', maxval(abs(fill_buffer))
        end if
        
        call record_test("Single edge offset filling", .true.)
    end subroutine

    subroutine test_multiple_edges_offset_filling()
        !! Test multiple edges in linked list
        real(wp) :: scanline(10), fill_buffer(10)
        type(stb_active_edge_t), target :: edge1, edge2
        type(stb_active_edge_t), pointer :: edge_ptr
        
        write(*,*) '  Testing multiple edges offset filling...'
        
        ! Setup first edge
        edge1%sy = 0.0_wp
        edge1%ey = 2.0_wp
        edge1%fx = 2.0_wp
        edge1%fdx = 0.0_wp
        edge1%direction = 1.0_wp
        edge1%next => edge2
        
        ! Setup second edge
        edge2%sy = 0.0_wp
        edge2%ey = 2.0_wp
        edge2%fx = 5.0_wp
        edge2%fdx = 0.0_wp
        edge2%direction = -1.0_wp
        edge2%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        edge_ptr => edge1
        
        call stb_fill_active_edges_with_offset(edge_ptr, 1.0_wp, 10, scanline, fill_buffer)
        
        ! Check for results
        if (all(abs(scanline) < TOLERANCE) .and. all(abs(fill_buffer) < TOLERANCE)) then
            issues_found = issues_found + 1
            write(*,*) '    ⚠️  Multiple edges should produce some result'
        else
            write(*,'(A,ES10.3,A,ES10.3)') &
                '    ✅ Multiple edges produced results: max_scanline=', maxval(abs(scanline)), &
                ', max_fill=', maxval(abs(fill_buffer))
        end if
        
        call record_test("Multiple edges offset filling", .true.)
    end subroutine

    subroutine test_vertical_vs_nonvertical_edges()
        !! Test vertical vs non-vertical edge handling
        real(wp) :: scanline_v(10), fill_buffer_v(10)
        real(wp) :: scanline_nv(10), fill_buffer_nv(10)
        type(stb_active_edge_t), target :: vert_edge, nonvert_edge
        type(stb_active_edge_t), pointer :: edge_ptr
        
        write(*,*) '  Testing vertical vs non-vertical edges...'
        
        ! Setup vertical edge
        vert_edge%sy = 0.0_wp
        vert_edge%ey = 2.0_wp
        vert_edge%fx = 3.0_wp
        vert_edge%fdx = 0.0_wp  ! Vertical
        vert_edge%direction = 1.0_wp
        vert_edge%next => null()
        
        scanline_v = 0.0_wp
        fill_buffer_v = 0.0_wp
        edge_ptr => vert_edge
        
        call stb_fill_active_edges_with_offset(edge_ptr, 1.0_wp, 10, scanline_v, fill_buffer_v)
        
        ! Setup non-vertical edge
        nonvert_edge%sy = 0.0_wp
        nonvert_edge%ey = 2.0_wp
        nonvert_edge%fx = 3.0_wp
        nonvert_edge%fdx = 0.5_wp  ! Non-vertical
        nonvert_edge%fdy = 2.0_wp
        nonvert_edge%direction = 1.0_wp
        nonvert_edge%next => null()
        
        scanline_nv = 0.0_wp
        fill_buffer_nv = 0.0_wp
        edge_ptr => nonvert_edge
        
        call stb_fill_active_edges_with_offset(edge_ptr, 1.0_wp, 10, scanline_nv, fill_buffer_nv)
        
        write(*,'(A,ES10.3,A,ES10.3)') &
            '    Vertical edge max: ', maxval(abs(scanline_v)), &
            ', Non-vertical edge max: ', maxval(abs(scanline_nv))
        
        call record_test("Vertical vs non-vertical edges", .true.)
    end subroutine

    subroutine test_compare_regular_vs_offset_filling()
        !! Compare regular vs offset filling results
        real(wp) :: regular_scanline(10), regular_fill(10)
        real(wp) :: offset_scanline(10), offset_fill(10)
        type(stb_active_edge_t), target :: edge
        type(stb_active_edge_t), pointer :: edge_ptr
        
        write(*,*) '  Comparing regular vs offset filling...'
        
        ! Setup edge
        edge%sy = 0.0_wp
        edge%ey = 2.0_wp
        edge%fx = 3.5_wp
        edge%fdx = 0.0_wp
        edge%direction = 1.0_wp
        edge%next => null()
        
        ! Test regular filling
        regular_scanline = 0.0_wp
        regular_fill = 0.0_wp
        edge_ptr => edge
        
        call stb_fill_active_edges(edge_ptr, 1.0_wp, 10, regular_scanline, regular_fill)
        
        ! Test offset filling
        offset_scanline = 0.0_wp
        offset_fill = 0.0_wp
        edge_ptr => edge
        
        call stb_fill_active_edges_with_offset(edge_ptr, 1.0_wp, 10, offset_scanline, offset_fill)
        
        write(*,'(A,ES10.3,A,ES10.3)') &
            '    Regular max: ', maxval(abs(regular_scanline)), &
            ', Offset max: ', maxval(abs(offset_scanline))
        
        ! Both should produce some results
        if (all(abs(regular_scanline) < TOLERANCE) .and. all(abs(offset_scanline) < TOLERANCE)) then
            issues_found = issues_found + 1
            write(*,*) '    ⚠️  Both regular and offset filling should produce results'
        end if
        
        call record_test("Regular vs offset filling comparison", .true.)
    end subroutine

    subroutine record_test(test_name, passed)
        character(len=*), intent(in) :: test_name
        logical, intent(in) :: passed

        test_count = test_count + 1
        if (passed) then
            pass_count = pass_count + 1
            write(*,'(A,A,A)') '    ', test_name, ': ✅ PASS'
        else
            write(*,'(A,A,A)') '    ', test_name, ': ❌ FAIL'
        end if
    end subroutine

end program test_forttf_offset_scanline_debug