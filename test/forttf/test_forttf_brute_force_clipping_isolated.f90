program test_forttf_brute_force_clipping_isolated
    !! Isolated unit test for stb_brute_force_edge_clipping() function
    !! Tests brute force clipping algorithm in complete isolation vs STB C reference
    !! Focus: edge intersection, clipping boundaries, precision at all pixel boundaries
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    integer, parameter :: BUFFER_SIZE = 8
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0

    write(*,*) '🧪 Testing stb_brute_force_edge_clipping() in isolation'
    write(*,*) '======================================================'
    write(*,*)

    ! Test 1: Simple diagonal edge
    call test_simple_diagonal()

    ! Test 2: Steep diagonal edge
    call test_steep_diagonal()

    ! Test 3: Shallow diagonal edge
    call test_shallow_diagonal()

    ! Test 4: Edge crossing multiple pixels
    call test_multi_pixel_cross()

    ! Test 5: Reverse direction edge
    call test_reverse_direction()

    ! Test 6: Edge at pixel boundaries
    call test_pixel_boundaries()

    ! Test 7: Nearly horizontal edge
    call test_nearly_horizontal()

    ! Test 8: Nearly vertical edge
    call test_nearly_vertical()

    ! Summary
    write(*,*)
    write(*,*) '📊 Test Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    if (pass_count == test_count) then
        write(*,*) '✅ All isolated brute force clipping tests PASSED'
    else
        write(*,*) '❌ Some isolated brute force clipping tests FAILED'
        stop 1
    end if

contains

    subroutine test_simple_diagonal()
        !! Test simple diagonal edge
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        ! Setup edge parameters
        edge%direction = 1.0_wp
        x0 = 1.5_wp
        dx = 2.0_wp
        xb = x0 + dx
        y_top = 0.0_wp
        y_bottom = 1.0_wp

        call run_test("Simple diagonal", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine test_steep_diagonal()
        !! Test steep diagonal edge
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        edge%direction = 1.0_wp
        x0 = 2.0_wp
        dx = 0.5_wp
        xb = x0 + dx
        y_top = 0.0_wp
        y_bottom = 1.0_wp

        call run_test("Steep diagonal", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine test_shallow_diagonal()
        !! Test shallow diagonal edge
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        edge%direction = 1.0_wp
        x0 = 1.0_wp
        dx = 4.0_wp
        xb = x0 + dx
        y_top = 0.0_wp
        y_bottom = 1.0_wp

        call run_test("Shallow diagonal", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine test_multi_pixel_cross()
        !! Test edge crossing multiple pixels
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        edge%direction = 1.0_wp
        x0 = 0.5_wp
        dx = 5.0_wp
        xb = x0 + dx
        y_top = 0.0_wp
        y_bottom = 1.0_wp

        call run_test("Multi-pixel crossing", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine test_reverse_direction()
        !! Test reverse direction edge
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        edge%direction = -1.0_wp
        x0 = 3.5_wp
        dx = -2.0_wp
        xb = x0 + dx
        y_top = 0.0_wp
        y_bottom = 1.0_wp

        call run_test("Reverse direction", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine test_pixel_boundaries()
        !! Test edge at exact pixel boundaries
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        edge%direction = 1.0_wp
        x0 = 2.0_wp
        dx = 2.0_wp
        xb = x0 + dx
        y_top = 0.0_wp
        y_bottom = 1.0_wp

        call run_test("Pixel boundaries", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine test_nearly_horizontal()
        !! Test nearly horizontal edge
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        edge%direction = 1.0_wp
        x0 = 1.0_wp
        dx = 3.0_wp
        xb = x0 + dx
        y_top = 0.1_wp
        y_bottom = 0.9_wp

        call run_test("Nearly horizontal", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine test_nearly_vertical()
        !! Test nearly vertical edge
        type(stb_active_edge_t) :: edge
        real(wp) :: scanline_buf(BUFFER_SIZE), scanline_fill_buf(BUFFER_SIZE)
        real(wp) :: x0, dx, xb, y_top, y_bottom
        
        edge%direction = 1.0_wp
        x0 = 2.5_wp
        dx = 0.01_wp
        xb = x0 + dx
        y_top = 0.0_wp
        y_bottom = 1.0_wp

        call run_test("Nearly vertical", edge, scanline_buf, scanline_fill_buf, &
                      x0, dx, xb, y_top, y_bottom)
    end subroutine

    subroutine run_test(test_name, edge, scanline_buf, scanline_fill_buf, &
                        x0, dx, xb, y_top, y_bottom)
        character(len=*), intent(in) :: test_name
        type(stb_active_edge_t), intent(in) :: edge
        real(wp), intent(out) :: scanline_buf(:), scanline_fill_buf(:)
        real(wp), intent(in) :: x0, dx, xb, y_top, y_bottom

        real(wp) :: reference_buf(BUFFER_SIZE), reference_fill_buf(BUFFER_SIZE)
        logical :: matches
        real(wp) :: max_diff
        integer :: i

        test_count = test_count + 1

        ! Initialize buffers
        scanline_buf = 0.0_wp
        scanline_fill_buf = 0.0_wp
        reference_buf = 0.0_wp
        reference_fill_buf = 0.0_wp

        ! Run our implementation
        call stb_brute_force_edge_clipping(scanline_buf, scanline_fill_buf, BUFFER_SIZE, &
                                         edge, y_top, y_bottom, x0, dx, xb)

        ! Create reference by manually calling stb_handle_clipped_edge for each pixel
        ! (This simulates what STB does in its brute force loop)
        call create_reference_result(reference_buf, reference_fill_buf, edge, &
                                   x0, dx, xb, y_top, y_bottom)

        ! Compare results
        matches = .true.
        max_diff = 0.0_wp
        do i = 1, BUFFER_SIZE
            max_diff = max(max_diff, abs(scanline_buf(i) - reference_buf(i)))
            max_diff = max(max_diff, abs(scanline_fill_buf(i) - reference_fill_buf(i)))
            if (abs(scanline_buf(i) - reference_buf(i)) > TOLERANCE .or. &
                abs(scanline_fill_buf(i) - reference_fill_buf(i)) > TOLERANCE) then
                matches = .false.
            end if
        end do

        ! Report results
        write(*,'(A,A,A)', advance='no') '  ', test_name, ': '
        if (matches) then
            write(*,*) '✅ PASS'
            pass_count = pass_count + 1
        else
            write(*,'(A,ES12.5)') '❌ FAIL (max diff: ', max_diff, ')'
            write(*,'(A)', advance='no') '     Our buf:  ['
            do i = 1, min(4, BUFFER_SIZE)
                write(*,'(F7.4,A)', advance='no') scanline_buf(i), ' '
            end do
            write(*,'(A)') ']'
            write(*,'(A)', advance='no') '     Ref buf:  ['
            do i = 1, min(4, BUFFER_SIZE)
                write(*,'(F7.4,A)', advance='no') reference_buf(i), ' '
            end do
            write(*,'(A)') ']'
        end if
    end subroutine

    subroutine create_reference_result(ref_buf, ref_fill_buf, edge, x0, dx, xb, y_top, y_bottom)
        !! Create reference result by manually implementing STB brute force algorithm
        real(wp), intent(out) :: ref_buf(:), ref_fill_buf(:)
        type(stb_active_edge_t), intent(in) :: edge
        real(wp), intent(in) :: x0, dx, xb, y_top, y_bottom

        integer :: x
        real(wp) :: x1, x2, x3, y0, y3, y1, y2

        ! Manual implementation of STB brute force algorithm for reference
        do x = 0, size(ref_buf) - 1
            y0 = y_top
            x1 = real(x, wp)
            x2 = real(x + 1, wp)
            x3 = xb
            y3 = y_bottom

            ! STB intersection calculation
            y1 = (x1 - x0) / dx + y_top
            y2 = (x2 - x0) / dx + y_top

            ! STB clipping logic - exact conditional structure
            if (x0 < x1 .and. x3 > x2) then
                call stb_handle_clipped_edge(ref_buf, x, edge, x0, y0, x1, y1)
                call stb_handle_clipped_edge(ref_buf, x, edge, x1, y1, x2, y2)
                call stb_handle_clipped_edge(ref_buf, x, edge, x2, y2, x3, y3)
            else if (x3 < x1 .and. x0 > x2) then
                call stb_handle_clipped_edge(ref_buf, x, edge, x0, y0, x2, y2)
                call stb_handle_clipped_edge(ref_buf, x, edge, x2, y2, x1, y1)
                call stb_handle_clipped_edge(ref_buf, x, edge, x1, y1, x3, y3)
            else if (x0 < x1 .and. x3 > x1) then
                call stb_handle_clipped_edge(ref_buf, x, edge, x0, y0, x1, y1)
                call stb_handle_clipped_edge(ref_buf, x, edge, x1, y1, x3, y3)
            else if (x3 < x1 .and. x0 > x1) then
                call stb_handle_clipped_edge(ref_buf, x, edge, x0, y0, x1, y1)
                call stb_handle_clipped_edge(ref_buf, x, edge, x1, y1, x3, y3)
            else if (x0 < x2 .and. x3 > x2) then
                call stb_handle_clipped_edge(ref_buf, x, edge, x0, y0, x2, y2)
                call stb_handle_clipped_edge(ref_buf, x, edge, x2, y2, x3, y3)
            else if (x3 < x2 .and. x0 > x2) then
                call stb_handle_clipped_edge(ref_buf, x, edge, x0, y0, x2, y2)
                call stb_handle_clipped_edge(ref_buf, x, edge, x2, y2, x3, y3)
            else
                call stb_handle_clipped_edge(ref_buf, x, edge, x0, y0, x3, y3)
            end if
        end do
    end subroutine

end program test_forttf_brute_force_clipping_isolated