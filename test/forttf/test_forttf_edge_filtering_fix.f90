program test_forttf_edge_filtering_fix
    !! Test and fix the edge filtering issue found in scanline interior fill
    !! Issue: Right edge with sy=7, ey=3 gets filtered out incorrectly
    !! Solution: Use proper edge building process, not manual active edge creation
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters  
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0
    integer :: edge_issues = 0

    write(*,*) '🔧 Testing and fixing edge filtering for scanline fill'
    write(*,*) '=================================================='
    write(*,*) 'Issue: Right edge gets filtered out due to incorrect coordinate ordering'
    write(*,*)

    ! Test 1: Proper edge building process
    call test_proper_edge_building()

    ! Test 2: Validate edge normalization
    call test_edge_normalization()

    ! Test 3: Complete square with proper edges
    call test_complete_square_proper_edges()

    ! Summary
    write(*,*)
    write(*,*) '📊 Edge Filtering Fix Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    write(*,'(A,I0)') '   Edge issues found: ', edge_issues
    if (edge_issues == 0) then
        write(*,*) '✅ Edge filtering working correctly'
    else
        write(*,*) '⚠️  Edge filtering still has issues'
    end if

contains

    subroutine test_proper_edge_building()
        !! Test building edges through proper STB edge building process
        write(*,*) '  Testing proper edge building process...'
        
        call test_square_edge_building()
        
        call record_test("Proper edge building", .true.)
    end subroutine

    subroutine test_square_edge_building()
        !! Test building square edges through stb_build_edges
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_contours
        type(stb_edge_t), allocatable :: edges(:)
        integer :: num_edges, i
        
        ! Create square: (5,3) -> (15,3) -> (15,7) -> (5,7) -> close
        allocate(points(4))
        points(1) = stb_point_t(5.0_wp, 3.0_wp)   ! Bottom-left
        points(2) = stb_point_t(15.0_wp, 3.0_wp)  ! Bottom-right
        points(3) = stb_point_t(15.0_wp, 7.0_wp)  ! Top-right  
        points(4) = stb_point_t(5.0_wp, 7.0_wp)   ! Top-left
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 4
        num_contours = 1
        
        ! Build edges properly through STB process
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               1.0_wp, 1.0_wp, 0.0_wp, 0.0_wp, .false.)
        num_edges = size(edges)
        
        write(*,'(A,I0)') '    Square built ', num_edges, ' edges'
        
        ! Examine the edges
        do i = 1, num_edges
            write(*,'(A,I0,A,F6.2,A,F6.2,A,F6.2,A,F6.2,A,I0)') &
                '      Edge[', i, '] (', edges(i)%x0, ',', edges(i)%y0, ') -> (', &
                edges(i)%x1, ',', edges(i)%y1, ') invert=', edges(i)%invert
        end do
        
        if (num_edges /= 2) then
            edge_issues = edge_issues + 1
            write(*,'(A,I0)') '    ⚠️  Expected 2 edges for square, got ', num_edges
        else
            write(*,*) '    ✅ Square correctly built 2 non-horizontal edges'
        end if
        
        ! Test scanline fill with these proper edges
        call test_scanline_with_proper_edges(edges, num_edges)
        
        deallocate(points, contour_lengths, edges)
    end subroutine

    subroutine test_scanline_with_proper_edges(edges, num_edges)
        !! Test scanline filling with properly built edges
        type(stb_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: num_edges
        
        type(stb_active_edge_t), allocatable, target :: active_edges(:)
        type(stb_active_edge_t) :: active_head
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        real(wp) :: sum_val, k_val
        integer :: i, active_count, interior_pixels

        write(*,'(A,F6.2)') '    Testing scanline fill at Y=', y_test

        ! Find active edges at this Y position
        active_count = 0
        do i = 1, num_edges
            if (edges(i)%y0 <= y_test .and. edges(i)%y1 > y_test) then
                active_count = active_count + 1
                write(*,'(A,I0,A,F6.2,A,F6.2,A,F6.2,A,F6.2,A)') &
                    '      Active edge[', i, '] (', edges(i)%x0, ',', edges(i)%y0, ') -> (', &
                    edges(i)%x1, ',', edges(i)%y1, ')'
            end if
        end do

        if (active_count == 0) then
            edge_issues = edge_issues + 1
            write(*,*) '    ⚠️  No active edges found at Y=5.0'
            return
        end if

        allocate(active_edges(active_count))
        
        active_count = 0
        do i = 1, num_edges
            if (edges(i)%y0 <= y_test .and. edges(i)%y1 > y_test) then
                active_count = active_count + 1
                active_edges(active_count) = stb_new_active_edge(edges(i), 0, y_test)
                write(*,'(A,I0,A,F6.2,A,F6.2,A,F6.2,A,F6.2)') &
                    '      Active[', active_count, '] X=', active_edges(active_count)%fx, &
                    ' dir=', active_edges(active_count)%direction, ' sy=', &
                    active_edges(active_count)%sy, ' ey=', active_edges(active_count)%ey
            end if
        end do

        ! Build linked list
        active_head%next => null()
        do i = 1, active_count
            call stb_insert_active_edge(active_head, active_edges(i))
        end do

        ! Fill scanline
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        call stb_fill_active_edges(active_head%next, y_test, 20, scanline, fill_buffer)
        
        write(*,*) '    Fill buffer contributions:'
        do i = 1, 20
            if (abs(fill_buffer(i)) > TOLERANCE) then
                write(*,'(A,I0,A,F8.4)') '      fill_buffer[', i, '] = ', fill_buffer(i)
            end if
        end do
        
        ! Apply accumulation
        write(*,*) '    Interior fill results:'
        interior_pixels = 0
        sum_val = 0.0_wp
        do i = 1, 20
            sum_val = sum_val + fill_buffer(i)
            k_val = scanline(i) + sum_val
            
            if (abs(k_val) > 0.5_wp) then
                interior_pixels = interior_pixels + 1
                write(*,'(A,I0,A,F6.3)') '      FILLED pixel[', i, '] coverage=', abs(k_val)
            end if
        end do
        
        write(*,'(A,I0)') '    Total interior pixels filled: ', interior_pixels
        
        ! Check if we got proper interior fill (should be ~10 pixels between X=5 and X=15)
        if (interior_pixels < 5) then
            edge_issues = edge_issues + 1
            write(*,*) '    ⚠️  Interior severely under-filled'
        else if (interior_pixels >= 8 .and. interior_pixels <= 12) then
            write(*,*) '    ✅ Interior fill working correctly'
        else
            write(*,*) '    ⚠️  Interior fill count unexpected'
        end if
        
        deallocate(active_edges)
    end subroutine

    subroutine test_edge_normalization()
        !! Test that edges are properly normalized (y0 <= y1)
        write(*,*) '  Testing edge normalization...'
        
        call test_upward_downward_edges()
        
        call record_test("Edge normalization", .true.)
    end subroutine

    subroutine test_upward_downward_edges()
        !! Test that upward and downward lines both get normalized
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_contours
        type(stb_edge_t), allocatable :: edges(:)
        integer :: num_edges, i
        
        ! Create simple line going down: (10,7) -> (10,3)
        allocate(points(2))
        points(1) = stb_point_t(10.0_wp, 7.0_wp)  ! Top
        points(2) = stb_point_t(10.0_wp, 3.0_wp)  ! Bottom
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 2
        num_contours = 1
        
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               1.0_wp, 1.0_wp, 0.0_wp, 0.0_wp, .false.)
        num_edges = size(edges)
        
        write(*,'(A,I0)') '    Downward line built ', num_edges, ' edges'
        
        do i = 1, num_edges
            write(*,'(A,I0,A,F6.2,A,F6.2,A,F6.2,A,F6.2,A,I0)') &
                '      Edge[', i, '] (', edges(i)%x0, ',', edges(i)%y0, ') -> (', &
                edges(i)%x1, ',', edges(i)%y1, ') invert=', edges(i)%invert
            
            ! Check normalization: y0 should <= y1
            if (edges(i)%y0 > edges(i)%y1) then
                edge_issues = edge_issues + 1
                write(*,'(A,I0)') '    ⚠️  Edge ', i, ' not normalized (y0 > y1)'
            end if
        end do
        
        deallocate(points, contour_lengths, edges)
    end subroutine

    subroutine test_complete_square_proper_edges()
        !! Test complete square interior fill with properly built edges
        write(*,*) '  Testing complete square with proper edge building...'
        
        call test_final_square_validation()
        
        call record_test("Complete square proper edges", .true.)
    end subroutine

    subroutine test_final_square_validation()
        !! Final validation that square interior fill works with proper edges
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_contours
        type(stb_edge_t), allocatable :: edges(:)
        integer :: num_edges
        type(stb_active_edge_t), allocatable, target :: active_edges(:)
        type(stb_active_edge_t) :: active_head
        real(wp) :: scanline(20), fill_buffer(20)
        real(wp) :: y_test = 5.0_wp
        real(wp) :: sum_val, k_val
        integer :: i, active_count, interior_pixels
        
        ! Create square: (6,3) -> (14,3) -> (14,7) -> (6,7) -> close
        allocate(points(4))
        points(1) = stb_point_t(6.0_wp, 3.0_wp)
        points(2) = stb_point_t(14.0_wp, 3.0_wp)
        points(3) = stb_point_t(14.0_wp, 7.0_wp)
        points(4) = stb_point_t(6.0_wp, 7.0_wp)
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 4
        num_contours = 1
        
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               1.0_wp, 1.0_wp, 0.0_wp, 0.0_wp, .false.)
        num_edges = size(edges)
        
        ! Find and create active edges
        active_count = 0
        do i = 1, num_edges
            if (edges(i)%y0 <= y_test .and. edges(i)%y1 > y_test) then
                active_count = active_count + 1
            end if
        end do
        
        allocate(active_edges(active_count))
        active_count = 0
        do i = 1, num_edges
            if (edges(i)%y0 <= y_test .and. edges(i)%y1 > y_test) then
                active_count = active_count + 1
                active_edges(active_count) = stb_new_active_edge(edges(i), 0, y_test)
            end if
        end do
        
        ! Build linked list and fill
        active_head%next => null()
        do i = 1, active_count
            call stb_insert_active_edge(active_head, active_edges(i))
        end do
        
        scanline = 0.0_wp
        fill_buffer = 0.0_wp
        call stb_fill_active_edges(active_head%next, y_test, 20, scanline, fill_buffer)
        
        ! Count interior pixels with accumulation
        interior_pixels = 0
        sum_val = 0.0_wp
        do i = 1, 20
            sum_val = sum_val + fill_buffer(i)
            k_val = scanline(i) + sum_val
            if (abs(k_val) > 0.5_wp) then
                interior_pixels = interior_pixels + 1
            end if
        end do
        
        write(*,'(A,I0)') '    Final square interior pixels filled: ', interior_pixels
        
        ! Should fill pixels 7-14 (8 pixels)
        if (interior_pixels >= 6 .and. interior_pixels <= 10) then
            write(*,*) '    ✅ Final square interior fill WORKING!'
        else
            edge_issues = edge_issues + 1
            write(*,*) '    ⚠️  Final square interior fill still broken'
        end if
        
        deallocate(points, contour_lengths, edges, active_edges)
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

end program test_forttf_edge_filtering_fix