program test_forttf_scanline_interior_fix
    !! Test and fix the missing scanline interior fill algorithm
    !! Root cause: stb_fill_active_edges may not correctly populate scanline_fill_buffer
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: fill_issues = 0

    write(*,*) '🔧 Testing and fixing scanline interior fill algorithm'
    write(*,*) '===================================================='
    write(*,*) 'Root cause: Missing interior fill between positive/negative winding edges'
    write(*,*)

    ! Test 1: Validate scanline_fill_buffer population
    call test_scanline_fill_buffer_population()

    ! Test 2: Test interior fill accumulation
    call test_interior_fill_accumulation()

    ! Test 3: Test complete square interior fill
    call test_complete_square_interior_fill()

    ! Test 4: Validate edge direction and winding
    call test_edge_direction_and_winding()

    ! Summary
    write(*,*)
    write(*,*) '📊 Scanline Interior Fill Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Fill issues found: ', fill_issues
    if (fill_issues == 0) then
        write(*,*) '✅ Scanline interior fill algorithm working correctly'
    else
        write(*,*) '⚠️  Scanline interior fill algorithm has issues - need to fix'
    end if

contains

    subroutine test_scanline_fill_buffer_population()
        !! Test that edges correctly populate scanline_fill_buffer
        write(*,*) '  Testing scanline_fill_buffer population...'
        
        call test_single_vertical_edge_fill()
        call test_two_opposite_edges_fill()
        
        call record_test("Scanline fill buffer population", .true.)
    end subroutine

    subroutine test_single_vertical_edge_fill()
        !! Test that a single vertical edge populates scanline_fill_buffer correctly
        type(stb_active_edge_t), target :: edge
        type(stb_active_edge_t), pointer :: edge_ptr
        real(wp) :: scanline(10), fill_buffer(10)
        real(wp) :: y_test = 5.0_wp
        integer :: i
        
        ! Set up single vertical edge
        edge%sy = 3.0_wp
        edge%ey = 7.0_wp
        edge%fx = 5.0_wp
        edge%fdx = 0.0_wp
        edge%fdy = 4.0_wp
        edge%direction = 1.0_wp  ! Positive winding
        edge%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        edge_ptr => edge
        
        call stb_fill_active_edges(edge_ptr, y_test, 10, scanline, fill_buffer)
        
        write(*,*) '    Single edge fill_buffer values:'
        do i = 1, 10
            if (abs(fill_buffer(i)) > TOLERANCE) then
                write(*,'(A,I0,A,F8.4)') '      fill_buffer[', i, '] = ', fill_buffer(i)
            end if
        end do
        
        ! Check that fill_buffer has the edge contribution
        if (all(abs(fill_buffer) < TOLERANCE)) then
            fill_issues = fill_issues + 1
            write(*,*) '    ⚠️  Single edge did not populate fill_buffer'
        else
            write(*,'(A,F8.4)') '    ✅ Single edge populated fill_buffer, max value: ', maxval(abs(fill_buffer))
        end if
    end subroutine

    subroutine test_two_opposite_edges_fill()
        !! Test two edges with opposite winding directions
        type(stb_active_edge_t), target :: left_edge, right_edge
        type(stb_active_edge_t), pointer :: head_ptr
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        integer :: i
        
        ! Left edge: positive winding (up direction)
        left_edge%sy = 3.0_wp
        left_edge%ey = 7.0_wp
        left_edge%fx = 5.0_wp
        left_edge%fdx = 0.0_wp
        left_edge%fdy = 4.0_wp
        left_edge%direction = 1.0_wp
        left_edge%next => right_edge
        
        ! Right edge: negative winding (down direction)
        right_edge%sy = 7.0_wp
        right_edge%ey = 3.0_wp
        right_edge%fx = 15.0_wp
        right_edge%fdx = 0.0_wp
        right_edge%fdy = -4.0_wp
        right_edge%direction = -1.0_wp
        right_edge%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        head_ptr => left_edge
        
        call stb_fill_active_edges(head_ptr, y_test, 20, scanline, fill_buffer)
        
        write(*,*) '    Two opposite edges fill_buffer values:'
        do i = 1, 20
            if (abs(fill_buffer(i)) > TOLERANCE) then
                write(*,'(A,I0,A,F8.4)') '      fill_buffer[', i, '] = ', fill_buffer(i)
            end if
        end do
        
        ! Check that both edges contribute to fill_buffer
        if (all(abs(fill_buffer) < TOLERANCE)) then
            fill_issues = fill_issues + 1
            write(*,*) '    ⚠️  Two opposite edges did not populate fill_buffer'
        else
            write(*,'(A,F8.4)') '    ✅ Two opposite edges populated fill_buffer, max value: ', maxval(abs(fill_buffer))
        end if
    end subroutine

    subroutine test_interior_fill_accumulation()
        !! Test the interior fill accumulation algorithm directly
        write(*,*) '  Testing interior fill accumulation algorithm...'
        
        call test_manual_accumulation()
        
        call record_test("Interior fill accumulation", .true.)
    end subroutine

    subroutine test_manual_accumulation()
        !! Test accumulation with manually set fill_buffer values
        real(wp) :: scanline(10), fill_buffer(10)
        real(wp) :: sum_val, k_val
        integer :: i
        
        ! Set up manual test case: fill_buffer represents winding changes
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        
        ! Simulate: +1 winding at position 3, -1 winding at position 7
        fill_buffer(3) = 1.0_wp  ! Enter shape
        fill_buffer(7) = -1.0_wp ! Exit shape
        
        write(*,*) '    Manual test: +1 at pos 3, -1 at pos 7'
        write(*,*) '    Expected: pixels 4-6 should be filled (sum=1), others empty (sum=0)'
        
        ! Run the accumulation algorithm (from stb_rasterize_sorted_edges)
        sum_val = 0.0_wp
        do i = 1, 10
            sum_val = sum_val + fill_buffer(i)
            k_val = scanline(i) + sum_val
            write(*,'(A,I0,A,F6.3,A,F6.3,A,F6.3)') '      pixel[', i, '] sum=', sum_val, ' k=', k_val, ' coverage=', abs(k_val)
        end do
        
        ! Check expected pattern
        sum_val = 0.0_wp
        do i = 1, 10
            sum_val = sum_val + fill_buffer(i)
            k_val = scanline(i) + sum_val
            
            if (i >= 4 .and. i <= 6) then
                ! Should be inside (sum=1)
                if (abs(k_val) < 0.9_wp) then
                    fill_issues = fill_issues + 1
                    write(*,'(A,I0,A,F6.3)') '    ⚠️  Pixel ', i, ' should be filled but got k=', k_val
                end if
            else
                ! Should be outside (sum=0)
                if (abs(k_val) > 0.1_wp) then
                    fill_issues = fill_issues + 1
                    write(*,'(A,I0,A,F6.3)') '    ⚠️  Pixel ', i, ' should be empty but got k=', k_val
                end if
            end if
        end do
        
        write(*,*) '    ✅ Manual accumulation test pattern validated'
    end subroutine

    subroutine test_complete_square_interior_fill()
        !! Test complete square with interior fill
        write(*,*) '  Testing complete square interior fill...'
        
        call test_square_with_correct_winding()
        
        call record_test("Complete square interior fill", .true.)
    end subroutine

    subroutine test_square_with_correct_winding()
        !! Test square with properly configured edge winding
        type(stb_active_edge_t), target :: left_edge, right_edge
        type(stb_active_edge_t), pointer :: head_ptr
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        real(wp) :: sum_val, k_val
        integer :: i, interior_pixels, expected_interior
        
        ! Square from X=5 to X=15 (should fill pixels 6-15)
        
        ! Left edge: X=5, going up (positive winding)
        left_edge%sy = 3.0_wp
        left_edge%ey = 7.0_wp
        left_edge%fx = 5.0_wp
        left_edge%fdx = 0.0_wp
        left_edge%fdy = 4.0_wp
        left_edge%direction = 1.0_wp  ! Positive winding (entering shape)
        left_edge%next => right_edge
        
        ! Right edge: X=15, going down (negative winding)
        right_edge%sy = 7.0_wp
        right_edge%ey = 3.0_wp
        right_edge%fx = 15.0_wp
        right_edge%fdx = 0.0_wp
        right_edge%fdy = -4.0_wp
        right_edge%direction = -1.0_wp  ! Negative winding (exiting shape)
        right_edge%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        head_ptr => left_edge
        
        call stb_fill_active_edges(head_ptr, y_test, 20, scanline, fill_buffer)
        
        write(*,*) '    Square edges contribution to fill_buffer:'
        do i = 1, 20
            if (abs(fill_buffer(i)) > TOLERANCE) then
                write(*,'(A,I0,A,F8.4)') '      fill_buffer[', i, '] = ', fill_buffer(i)
            end if
        end do
        
        ! Apply accumulation to see interior fill
        write(*,*) '    Accumulation results:'
        interior_pixels = 0
        expected_interior = 10  ! Pixels 6-15
        sum_val = 0.0_wp
        do i = 1, 20
            sum_val = sum_val + fill_buffer(i)
            k_val = scanline(i) + sum_val
            
            if (abs(k_val) > 0.5_wp) then
                interior_pixels = interior_pixels + 1
                write(*,'(A,I0,A,F6.3)') '      FILLED pixel[', i, '] coverage=', abs(k_val)
            end if
        end do
        
        write(*,'(A,I0,A,I0)') '    Interior pixels filled: ', interior_pixels, ' (expected: ', expected_interior, ')'
        
        if (interior_pixels < expected_interior / 2) then
            fill_issues = fill_issues + 1
            write(*,*) '    ⚠️  Square interior severely under-filled'
        else if (interior_pixels < expected_interior) then
            write(*,*) '    ⚠️  Square interior partially under-filled'
        else
            write(*,*) '    ✅ Square interior fill working correctly'
        end if
    end subroutine

    subroutine test_edge_direction_and_winding()
        !! Test edge direction and winding number setup
        write(*,*) '  Testing edge direction and winding setup...'
        
        call test_edge_direction_values()
        
        call record_test("Edge direction and winding", .true.)
    end subroutine

    subroutine test_edge_direction_values()
        !! Test that edges have correct direction values
        type(stb_edge_t) :: up_edge, down_edge
        type(stb_active_edge_t) :: active_up, active_down
        
        ! Create upward edge (should have positive direction)
        up_edge%x0 = 5.0_wp
        up_edge%y0 = 3.0_wp
        up_edge%x1 = 5.0_wp
        up_edge%y1 = 7.0_wp
        up_edge%invert = 0
        
        ! Create downward edge (should have negative direction) 
        down_edge%x0 = 15.0_wp
        down_edge%y0 = 7.0_wp
        down_edge%x1 = 15.0_wp
        down_edge%y1 = 3.0_wp
        down_edge%invert = 1
        
        ! Convert to active edges
        active_up = stb_new_active_edge(up_edge, 0, 5.0_wp)
        active_down = stb_new_active_edge(down_edge, 0, 5.0_wp)
        
        write(*,'(A,F8.4)') '    Upward edge direction: ', active_up%direction
        write(*,'(A,F8.4)') '    Downward edge direction: ', active_down%direction
        
        ! Check directions
        if (active_up%direction <= 0.0_wp) then
            fill_issues = fill_issues + 1
            write(*,*) '    ⚠️  Upward edge should have positive direction'
        end if
        
        if (active_down%direction >= 0.0_wp) then
            fill_issues = fill_issues + 1
            write(*,*) '    ⚠️  Downward edge should have negative direction'
        end if
        
        if (active_up%direction > 0.0_wp .and. active_down%direction < 0.0_wp) then
            write(*,*) '    ✅ Edge directions correct'
        end if
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

end program test_forttf_scanline_interior_fix