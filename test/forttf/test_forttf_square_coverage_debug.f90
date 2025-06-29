program test_forttf_square_coverage_debug
    !! Debug the specific square coverage issue found in multi-edge test
    !! Focus on why pixels 4-8 show under-estimation and pixel 9 shows over-saturation
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: coverage_issues = 0

    write(*,*) '🔧 Debugging square coverage under-estimation and over-saturation'
    write(*,*) '================================================================'
    write(*,*) 'Target: Fix pixels 4-8 under-estimation and pixel 9 over-saturation'
    write(*,*)

    ! Test 1: Manual square edge setup
    call test_manual_square_edges()

    ! Test 2: Two-edge square simulation
    call test_two_edge_square()

    ! Test 3: Edge X position validation
    call test_edge_x_positions()

    ! Test 4: Coverage calculation validation
    call test_coverage_calculation()

    ! Summary
    write(*,*)
    write(*,*) '📊 Square Coverage Debug Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Coverage issues found: ', coverage_issues
    if (coverage_issues == 0) then
        write(*,*) '✅ Square coverage calculation fixed'
    else
        write(*,*) '⚠️  Square coverage calculation still has issues'
    end if

contains

    subroutine test_manual_square_edges()
        !! Test manually created square edges
        write(*,*) '  Testing manually created square edges...'
        
        ! Create left and right vertical edges of square manually
        call test_left_right_square_edges()
        
        call record_test("Manual square edges", .true.)
    end subroutine

    subroutine test_left_right_square_edges()
        !! Test left and right edges of square (2,2)-(8,8)
        type(stb_edge_t) :: left_edge, right_edge
        type(stb_edge_t), allocatable :: edges(:)
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp  ! Middle of square
        integer :: i
        
        ! Left edge: (2,2) -> (2,8)
        left_edge%x0 = 2.0_wp
        left_edge%y0 = 2.0_wp
        left_edge%x1 = 2.0_wp
        left_edge%y1 = 8.0_wp
        left_edge%invert = 0  ! Positive winding
        
        ! Right edge: (8,8) -> (8,2) (reverse for proper winding)
        right_edge%x0 = 8.0_wp
        right_edge%y0 = 8.0_wp
        right_edge%x1 = 8.0_wp
        right_edge%y1 = 2.0_wp
        right_edge%invert = 1  ! Negative winding
        
        allocate(edges(2))
        edges(1) = left_edge
        edges(2) = right_edge
        
        write(*,*) '    Created left edge: (2,2)->(2,8), right edge: (8,8)->(8,2)'
        
        ! Test scanline filling
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        call test_glyph_scanline(edges, 2, y_test, 20, scanline, fill_buffer)
        
        ! Analyze results
        write(*,*) '    Scanline coverage analysis:'
        do i = 1, 20
            if (abs(scanline(i)) > TOLERANCE) then
                write(*,'(A,I0,A,F8.4)') '      Pixel ', i, ': ', scanline(i)
            end if
        end do
        
        ! Check expectations
        do i = 1, 20
            if (i >= 3 .and. i <= 7) then
                ! Inside square (between X=2 and X=8)
                if (abs(scanline(i)) < 0.1_wp) then
                    coverage_issues = coverage_issues + 1
                    write(*,'(A,I0,A,F8.4)') '    ⚠️  Under-estimation inside at pixel ', i, ': ', scanline(i)
                end if
            else
                ! Outside square
                if (abs(scanline(i)) > 0.1_wp) then
                    coverage_issues = coverage_issues + 1
                    write(*,'(A,I0,A,F8.4)') '    ⚠️  Over-saturation outside at pixel ', i, ': ', scanline(i)
                end if
            end if
        end do
        
        deallocate(edges)
    end subroutine

    subroutine test_two_edge_square()
        !! Test two-edge square using active edge processing
        write(*,*) '  Testing two-edge square with active edge processing...'
        
        call test_active_edge_square()
        
        call record_test("Two-edge square", .true.)
    end subroutine

    subroutine test_active_edge_square()
        !! Test square using active edge list
        type(stb_active_edge_t), target :: left_edge, right_edge
        type(stb_active_edge_t), pointer :: head_ptr
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        integer :: i
        
        ! Set up left edge (going up)
        left_edge%sy = 2.0_wp
        left_edge%ey = 8.0_wp
        left_edge%fx = 2.0_wp
        left_edge%fdx = 0.0_wp  ! Vertical
        left_edge%fdy = 6.0_wp
        left_edge%direction = 1.0_wp  ! Positive
        left_edge%next => right_edge
        
        ! Set up right edge (going down)
        right_edge%sy = 8.0_wp
        right_edge%ey = 2.0_wp
        right_edge%fx = 8.0_wp
        right_edge%fdx = 0.0_wp  ! Vertical
        right_edge%fdy = -6.0_wp
        right_edge%direction = -1.0_wp  ! Negative
        right_edge%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        head_ptr => left_edge
        
        write(*,*) '    Active edges: left=(2,2)->(2,8), right=(8,8)->(8,2)'
        
        call stb_fill_active_edges(head_ptr, y_test, 20, scanline, fill_buffer)
        
        ! Analyze results
        write(*,*) '    Active edge scanline coverage:'
        do i = 1, 20
            if (abs(scanline(i)) > TOLERANCE) then
                write(*,'(A,I0,A,F8.4)') '      Pixel ', i, ': ', scanline(i)
            end if
        end do
        
        ! Detailed analysis of the filling
        write(*,'(A,F8.4,A,F8.4)') '    Left edge X: ', left_edge%fx, ', Right edge X: ', right_edge%fx
        write(*,'(A,F8.4,A,F8.4)') '    Sum pixels 3-7: ', sum(abs(scanline(3:7))), &
                                   ', Sum outside: ', sum(abs(scanline(1:2))) + sum(abs(scanline(8:20)))
    end subroutine

    subroutine test_edge_x_positions()
        !! Test edge X position calculations
        write(*,*) '  Testing edge X position calculations...'
        
        call test_vertical_edge_x()
        call test_sloped_edge_x()
        
        call record_test("Edge X positions", .true.)
    end subroutine

    subroutine test_vertical_edge_x()
        !! Test vertical edge X position stays constant
        type(stb_active_edge_t) :: edge
        real(wp) :: original_x, updated_x
        
        edge%sy = 2.0_wp
        edge%ey = 8.0_wp
        edge%fx = 5.0_wp
        edge%fdx = 0.0_wp  ! Vertical
        edge%fdy = 6.0_wp
        edge%direction = 1.0_wp
        edge%next => null()
        
        original_x = edge%fx
        
        ! Update edge for next scanline
        call stb_update_active_edges(edge%next, 1.0_wp)  ! This should have no effect on X
        
        updated_x = edge%fx
        
        if (abs(updated_x - original_x) > TOLERANCE) then
            coverage_issues = coverage_issues + 1
            write(*,'(A,F8.4,A,F8.4)') '    ⚠️  Vertical edge X changed: ', original_x, ' -> ', updated_x
        else
            write(*,'(A,F8.4)') '    ✅ Vertical edge X constant: ', original_x
        end if
    end subroutine

    subroutine test_sloped_edge_x()
        !! Test sloped edge X position updates correctly
        type(stb_active_edge_t) :: edge
        real(wp) :: original_x, expected_x, updated_x
        
        edge%sy = 2.0_wp
        edge%ey = 8.0_wp
        edge%fx = 3.0_wp
        edge%fdx = 0.5_wp  ! Slope of 0.5 per scanline
        edge%fdy = 6.0_wp
        edge%direction = 1.0_wp
        edge%next => null()
        
        original_x = edge%fx
        expected_x = original_x + edge%fdx  ! Should advance by fdx
        
        ! Update edge for next scanline
        call stb_update_active_edges(edge%next, 1.0_wp)
        
        updated_x = edge%fx
        
        if (abs(updated_x - expected_x) > TOLERANCE) then
            coverage_issues = coverage_issues + 1
            write(*,'(A,F8.4,A,F8.4,A,F8.4)') '    ⚠️  Sloped edge X wrong: expected ', &
                                           expected_x, ', got ', updated_x, ' (was ', original_x
        else
            write(*,'(A,F8.4,A,F8.4)') '    ✅ Sloped edge X correct: ', original_x, ' -> ', updated_x
        end if
    end subroutine

    subroutine test_coverage_calculation()
        !! Test coverage calculation functions directly
        write(*,*) '  Testing coverage calculation functions...'
        
        call test_trapezoid_coverage()
        call test_triangle_coverage()
        
        call record_test("Coverage calculation", .true.)
    end subroutine

    subroutine test_trapezoid_coverage()
        !! Test trapezoid area calculation
        real(wp) :: area
        real(wp) :: x0 = 3.0_wp, x1 = 7.0_wp  ! 4 pixel wide trapezoid
        real(wp) :: h = 1.0_wp  ! 1 scanline high
        
        area = stb_sized_trapezoid_area(h, x0, x1)
        
        write(*,'(A,F8.4,A,F8.4,A,F8.4,A,F8.4)') '    Trapezoid area: h=', h, ', x0=', x0, ', x1=', x1, ', area=', area
        
        ! For a rectangle from X=3 to X=7, area should be 4.0
        if (abs(area - 4.0_wp) > TOLERANCE) then
            coverage_issues = coverage_issues + 1
            write(*,'(A,F8.4)') '    ⚠️  Trapezoid area wrong, expected 4.0, got ', area
        else
            write(*,*) '    ✅ Trapezoid area correct'
        end if
    end subroutine

    subroutine test_triangle_coverage()
        !! Test triangle area calculation
        real(wp) :: area
        real(wp) :: x0 = 3.0_wp, x1 = 7.0_wp  ! 4 pixel wide triangle
        real(wp) :: h = 0.5_wp  ! Half height
        
        area = stb_sized_triangle_area(h, x1 - x0)
        
        write(*,'(A,F8.4,A,F8.4,A,F8.4,A,F8.4)') '    Triangle area: h=', h, ', x0=', x0, ', x1=', x1, ', area=', area
        
        ! For a triangle from X=3 to X=7 with height 0.5, area should be 0.5 * 4.0 = 2.0
        if (abs(area - 2.0_wp) > TOLERANCE) then
            coverage_issues = coverage_issues + 1
            write(*,'(A,F8.4)') '    ⚠️  Triangle area wrong, expected 2.0, got ', area
        else
            write(*,*) '    ✅ Triangle area correct'
        end if
    end subroutine

    subroutine test_glyph_scanline(edges, num_edges, y_pos, width, scanline, fill_buffer)
        !! Test scanline filling for a complete glyph
        type(stb_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: num_edges, width
        real(wp), intent(in) :: y_pos
        real(wp), intent(inout) :: scanline(:), fill_buffer(:)

        type(stb_active_edge_t), allocatable, target :: active_edges(:)
        type(stb_active_edge_t) :: active_head
        integer :: i, active_count

        ! Find active edges at this Y position
        active_count = 0
        do i = 1, num_edges
            if (edges(i)%y0 <= y_pos .and. edges(i)%y1 > y_pos) then
                active_count = active_count + 1
            end if
        end do

        if (active_count > 0) then
            allocate(active_edges(active_count))
            
            active_count = 0
            do i = 1, num_edges
                if (edges(i)%y0 <= y_pos .and. edges(i)%y1 > y_pos) then
                    active_count = active_count + 1
                    active_edges(active_count) = stb_new_active_edge(edges(i), 0, y_pos)
                end if
            end do

            ! Build linked list
            active_head%next => null()
            do i = 1, active_count
                call stb_insert_active_edge(active_head, active_edges(i))
            end do

            ! Fill scanline with all active edges
            call stb_fill_active_edges(active_head%next, y_pos, width, scanline, fill_buffer)
            
            deallocate(active_edges)
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

end program test_forttf_square_coverage_debug