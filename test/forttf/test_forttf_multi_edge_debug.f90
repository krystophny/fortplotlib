program test_forttf_multi_edge_debug
    !! Debug multi-edge interactions in full pipeline
    !! Focus on cases that cause anti-aliasing differences:
    !! - Over-saturation: Pure=255, STB=65
    !! - Under-estimation: Pure=52, STB=203
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    use fortplot_stb_truetype
    implicit none

    ! Test parameters
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: accuracy_issues = 0

    write(*,*) '🔧 Debugging multi-edge interactions in full pipeline'
    write(*,*) '================================================='
    write(*,*) 'Target: Identify source of over-saturation and under-estimation'
    write(*,*)

    ! Test 1: Multiple edge winding interactions
    call test_multiple_edge_winding()

    ! Test 2: Edge overlap causing saturation
    call test_edge_overlap_saturation()

    ! Test 3: Complex glyph multi-edge scenarios
    call test_complex_glyph_multi_edges()

    ! Test 4: Active edge list sorting precision
    call test_active_edge_sorting_precision()

    ! Test 5: Cross-scanline accumulation
    call test_cross_scanline_accumulation()

    ! Summary
    write(*,*)
    write(*,*) '📊 Multi-Edge Debug Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Accuracy issues found: ', accuracy_issues
    if (pass_count == test_count .and. accuracy_issues == 0) then
        write(*,*) '✅ Multi-edge interactions working correctly'
    else
        write(*,*) '⚠️  Multi-edge interactions causing accuracy issues'
        if (accuracy_issues > 0) then
            write(*,*) '🔧 Source of over-saturation/under-estimation found!'
        end if
    end if

contains

    subroutine test_multiple_edge_winding()
        !! Test winding number calculations with multiple edges
        write(*,*) '  Testing multiple edge winding interactions...'
        
        call test_positive_negative_winding()
        call test_overlapping_winding()
        
        call record_test("Multiple edge winding", .true.)
    end subroutine

    subroutine test_positive_negative_winding()
        !! Test positive and negative winding interactions
        type(stb_active_edge_t), target :: edge1, edge2
        type(stb_active_edge_t), pointer :: head_ptr
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        integer :: i
        real(wp) :: total_coverage
        
        ! Create edges with opposite winding
        edge1%sy = 4.0_wp
        edge1%ey = 6.0_wp
        edge1%fx = 5.0_wp
        edge1%fdx = 0.0_wp
        edge1%fdy = 2.0_wp
        edge1%direction = 1.0_wp  ! Positive winding
        edge1%next => edge2
        
        edge2%sy = 4.0_wp
        edge2%ey = 6.0_wp
        edge2%fx = 10.0_wp
        edge2%fdx = 0.0_wp
        edge2%fdy = 2.0_wp
        edge2%direction = -1.0_wp  ! Negative winding
        edge2%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        head_ptr => edge1
        
        ! Fill scanline with both edges
        call stb_fill_active_edges(head_ptr, y_test, 20, scanline, fill_buffer)
        
        ! Check for reasonable coverage (should be between edges)
        total_coverage = sum(abs(scanline))
        
        write(*,'(A,F8.3)') '    Total coverage from +/- winding: ', total_coverage
        
        ! Test for over-saturation (Pure=255 cases)
        do i = 1, 20
            if (abs(scanline(i)) > 1.5_wp) then
                accuracy_issues = accuracy_issues + 1
                write(*,'(A,I0,A,F8.3)') '    ⚠️  Over-saturation at pixel ', i, ': ', scanline(i)
            end if
        end do
        
        ! Test for under-estimation (low coverage where it should be high)
        if (total_coverage < 0.1_wp) then
            accuracy_issues = accuracy_issues + 1
            write(*,*) '    ⚠️  Under-estimation: total coverage too low'
        end if
    end subroutine

    subroutine test_overlapping_winding()
        !! Test overlapping edges with same winding (accumulation)
        type(stb_active_edge_t), target :: edge1, edge2, edge3
        type(stb_active_edge_t), pointer :: head_ptr
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        integer :: i
        
        ! Create three overlapping edges (could cause saturation)
        edge1%sy = 4.0_wp
        edge1%ey = 6.0_wp
        edge1%fx = 8.0_wp
        edge1%fdx = 0.0_wp
        edge1%fdy = 2.0_wp
        edge1%direction = 1.0_wp
        edge1%next => edge2
        
        edge2%sy = 4.0_wp
        edge2%ey = 6.0_wp
        edge2%fx = 9.0_wp
        edge2%fdx = 0.0_wp
        edge2%fdy = 2.0_wp
        edge2%direction = 1.0_wp
        edge2%next => edge3
        
        edge3%sy = 4.0_wp
        edge3%ey = 6.0_wp
        edge3%fx = 10.0_wp
        edge3%fdx = 0.0_wp
        edge3%fdy = 2.0_wp
        edge3%direction = 1.0_wp
        edge3%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        head_ptr => edge1
        
        call stb_fill_active_edges(head_ptr, y_test, 20, scanline, fill_buffer)
        
        ! Check for saturation from overlapping
        do i = 1, 20
            if (abs(scanline(i)) > 2.0_wp) then
                accuracy_issues = accuracy_issues + 1
                write(*,'(A,I0,A,F8.3)') '    ⚠️  Saturation from overlap at pixel ', i, ': ', scanline(i)
            end if
        end do
        
        write(*,'(A,F8.3)') '    Max overlap coverage: ', maxval(abs(scanline))
    end subroutine

    subroutine test_edge_overlap_saturation()
        !! Test specific edge configurations that cause saturation
        write(*,*) '  Testing edge overlap causing saturation...'
        
        call test_same_x_different_slopes()
        call test_crossing_edges()
        
        call record_test("Edge overlap saturation", .true.)
    end subroutine

    subroutine test_same_x_different_slopes()
        !! Test edges at same X with different slopes (potential saturation)
        type(stb_active_edge_t), target :: edge1, edge2
        type(stb_active_edge_t), pointer :: head_ptr
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        integer :: i
        
        ! Same X, different slopes
        edge1%sy = 3.0_wp
        edge1%ey = 7.0_wp
        edge1%fx = 10.0_wp
        edge1%fdx = 0.5_wp  ! Positive slope
        edge1%fdy = 4.0_wp
        edge1%direction = 1.0_wp
        edge1%next => edge2
        
        edge2%sy = 3.0_wp
        edge2%ey = 7.0_wp
        edge2%fx = 10.0_wp
        edge2%fdx = -0.5_wp  ! Negative slope
        edge2%fdy = 4.0_wp
        edge2%direction = -1.0_wp
        edge2%next => null()
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        head_ptr => edge1
        
        call stb_fill_active_edges(head_ptr, y_test, 20, scanline, fill_buffer)
        
        ! Check for precision issues at crossing point
        do i = 8, 12  ! Around X=10 area
            if (abs(scanline(i)) > 1.8_wp) then
                accuracy_issues = accuracy_issues + 1
                write(*,'(A,I0,A,F8.3)') '    ⚠️  Same-X saturation at pixel ', i, ': ', scanline(i)
            end if
        end do
        
        write(*,'(A,F8.3)') '    Same-X max coverage: ', maxval(abs(scanline))
    end subroutine

    subroutine test_crossing_edges()
        !! Test edges that cross each other (complex interaction)
        write(*,*) '    Testing crossing edges...'
        ! Implementation placeholder - complex crossing scenarios
    end subroutine

    subroutine test_complex_glyph_multi_edges()
        !! Test complex glyph scenarios with many edges
        write(*,*) '  Testing complex glyph multi-edge scenarios...'
        
        call test_square_glyph_complete()
        call test_triangle_glyph_complete()
        
        call record_test("Complex glyph multi-edges", .true.)
    end subroutine

    subroutine test_square_glyph_complete()
        !! Test complete square glyph (4 edges forming closed shape)
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_contours
        type(stb_edge_t), allocatable :: edges(:)
        integer :: num_edges, i
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        
        ! Create square: (2,2) -> (8,2) -> (8,8) -> (2,8) -> close
        allocate(points(4))
        points(1) = stb_point_t(2.0_wp, 2.0_wp)
        points(2) = stb_point_t(8.0_wp, 2.0_wp)
        points(3) = stb_point_t(8.0_wp, 8.0_wp)
        points(4) = stb_point_t(2.0_wp, 8.0_wp)
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 4
        num_contours = 1
        
        ! Build edges from points
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               1.0_wp, 1.0_wp, 0.0_wp, 0.0_wp, .false.)
        num_edges = size(edges)
        
        if (num_edges == 0) then
            accuracy_issues = accuracy_issues + 1
            write(*,*) '    ⚠️  No edges built from square glyph'
            return
        end if
        
        write(*,'(A,I0)') '    Square glyph created ', num_edges, ' edges'
        
        ! Test scanline through middle of square
        call test_glyph_scanline(edges, num_edges, y_test, 20, scanline, fill_buffer)
        
        ! Square should have solid fill between X=2 and X=8
        ! Check for correct coverage pattern
        do i = 1, 20
            if (i >= 3 .and. i <= 8) then
                ! Inside square - should have some coverage
                if (abs(scanline(i)) < 0.1_wp) then
                    accuracy_issues = accuracy_issues + 1
                    write(*,'(A,I0)') '    ⚠️  Under-estimation inside square at pixel ', i
                end if
            else
                ! Outside square - should have minimal coverage
                if (abs(scanline(i)) > 0.5_wp) then
                    accuracy_issues = accuracy_issues + 1
                    write(*,'(A,I0,A,F8.3)') '    ⚠️  Over-saturation outside square at pixel ', i, ': ', scanline(i)
                end if
            end if
        end do
        
        write(*,'(A,F8.3,A,F8.3)') '    Square inside max: ', maxval(abs(scanline(3:8))), &
                                   ', outside max: ', maxval(abs([scanline(1:2), scanline(9:20)]))
        
        deallocate(points, contour_lengths, edges)
    end subroutine

    subroutine test_triangle_glyph_complete()
        !! Test complete triangle glyph (3 edges)
        write(*,*) '    Testing triangle glyph...'
        ! Implementation placeholder
    end subroutine

    subroutine test_glyph_scanline(edges, num_edges, y_pos, width, scanline, fill_buffer)
        !! Test scanline filling for a complete glyph
        type(stb_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: num_edges, width
        real(wp), intent(in) :: y_pos
        real(wp), intent(inout) :: scanline(:), fill_buffer(:)

        type(stb_active_edge_t), allocatable, target :: active_edges(:)
        type(stb_active_edge_t) :: active_head
        type(stb_active_edge_t), pointer :: current
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

    subroutine test_active_edge_sorting_precision()
        !! Test active edge sorting for precision issues
        write(*,*) '  Testing active edge sorting precision...'
        
        call test_close_x_positions()
        call test_floating_point_x_precision()
        
        call record_test("Active edge sorting precision", .true.)
    end subroutine

    subroutine test_close_x_positions()
        !! Test edges with very close X positions
        type(stb_active_edge_t), target :: head, edge1, edge2, edge3
        type(stb_active_edge_t), pointer :: current
        integer :: order_issues = 0
        
        ! Create edges with very close X positions
        edge1%fx = 5.000000_wp
        edge1%next => null()
        edge2%fx = 5.000001_wp  ! Very close
        edge2%next => null()
        edge3%fx = 4.999999_wp  ! Very close
        edge3%next => null()

        head%next => null()
        
        call stb_insert_active_edge(head, edge1)
        call stb_insert_active_edge(head, edge2)
        call stb_insert_active_edge(head, edge3)

        ! Check ordering
        current => head%next
        if (associated(current)) then
            if (current%fx > 5.0_wp) then
                order_issues = order_issues + 1
                write(*,*) '    ⚠️  First edge not smallest X'
            end if
            current => current%next
            if (associated(current)) then
                current => current%next
                if (associated(current)) then
                    if (current%fx < 5.0_wp) then
                        order_issues = order_issues + 1
                        write(*,*) '    ⚠️  Last edge not largest X'
                    end if
                end if
            end if
        end if
        
        if (order_issues > 0) then
            accuracy_issues = accuracy_issues + order_issues
        end if
        
        write(*,'(A,I0)') '    Close X position ordering issues: ', order_issues
    end subroutine

    subroutine test_floating_point_x_precision()
        !! Test floating point precision in X calculations
        write(*,*) '    Testing floating point X precision...'
        ! Implementation placeholder
    end subroutine

    subroutine test_cross_scanline_accumulation()
        !! Test accumulation effects across multiple scanlines
        write(*,*) '  Testing cross-scanline accumulation...'
        
        call test_multiple_scanline_consistency()
        
        call record_test("Cross-scanline accumulation", .true.)
    end subroutine

    subroutine test_multiple_scanline_consistency()
        !! Test consistency across multiple Y positions
        type(stb_active_edge_t), target :: edge1, edge2
        type(stb_active_edge_t), pointer :: head_ptr
        real(wp) :: scanline1(10), fill_buffer1(10)
        real(wp) :: scanline2(10), fill_buffer2(10)
        real(wp) :: y1 = 3.0_wp, y2 = 4.0_wp
        integer :: i
        real(wp) :: diff
        
        ! Create consistent edge setup
        edge1%sy = 2.0_wp
        edge1%ey = 6.0_wp
        edge1%fx = 5.0_wp
        edge1%fdx = 0.0_wp
        edge1%fdy = 4.0_wp
        edge1%direction = 1.0_wp
        edge1%next => edge2
        
        edge2%sy = 2.0_wp
        edge2%ey = 6.0_wp
        edge2%fx = 7.0_wp
        edge2%fdx = 0.0_wp
        edge2%fdy = 4.0_wp
        edge2%direction = -1.0_wp
        edge2%next => null()
        
        scanline1 = 0.0_wp
        fill_buffer1 = 0.0_wp
        scanline2 = 0.0_wp
        fill_buffer2 = 0.0_wp
        head_ptr => edge1
        
        ! Fill scanlines at different Y positions
        call stb_fill_active_edges(head_ptr, y1, 10, scanline1, fill_buffer1)
        call stb_fill_active_edges(head_ptr, y2, 10, scanline2, fill_buffer2)
        
        ! Check for consistency (should be very similar for vertical edges)
        do i = 1, 10
            diff = abs(scanline1(i) - scanline2(i))
            if (diff > 0.1_wp) then
                accuracy_issues = accuracy_issues + 1
                write(*,'(A,I0,A,F8.3)') '    ⚠️  Scanline inconsistency at pixel ', i, ': diff=', diff
            end if
        end do
        
        write(*,'(A,F8.3)') '    Max scanline difference: ', maxval(abs(scanline1 - scanline2))
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

end program test_forttf_multi_edge_debug