program test_forttf_handle_clipped_edge_isolated
    !! Isolated unit test for stb_handle_clipped_edge() function
    !! Tests edge clipping logic in complete isolation vs STB C reference
    !! Focus: coverage calculation precision, boundary conditions, single edge scenarios
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    use forttf_stb_raster
    implicit none

    ! Test parameters
    integer, parameter :: SCANLINE_SIZE = 10
    real(wp), parameter :: TOLERANCE = 1.0e-6_wp
    integer :: test_count = 0
    integer :: pass_count = 0

    ! C interface for STB reference
    interface
        subroutine test_stb_handle_clipped_edge_c(scanline, x, sy, ey, direction, &
                                                  x0, y0, x1, y1) bind(c, name='test_stb_handle_clipped_edge_c')
            import :: c_float, c_int
            real(c_float), intent(inout) :: scanline(*)
            integer(c_int), intent(in) :: x
            real(c_float), intent(in) :: sy, ey, direction
            real(c_float), intent(in) :: x0, y0, x1, y1
        end subroutine
    end interface

    write(*,*) '🧪 Testing stb_handle_clipped_edge() in isolation'
    write(*,*) '================================================='
    write(*,*)

    ! Test 1: Simple vertical edge completely left of pixel
    call test_edge_left_of_pixel()

    ! Test 2: Simple vertical edge completely right of pixel
    call test_edge_right_of_pixel()

    ! Test 3: Edge crossing pixel horizontally
    call test_edge_crossing_pixel()

    ! Test 4: Edge with Y clipping at start
    call test_y_clipping_start()

    ! Test 5: Edge with Y clipping at end
    call test_y_clipping_end()

    ! Test 6: Edge with both Y clippings
    call test_y_clipping_both()

    ! Test 7: Horizontal edge (should be ignored)
    call test_horizontal_edge()

    ! Test 8: Edge direction effects
    call test_direction_effects()

    ! Test 9: Boundary precision cases
    call test_boundary_precision()

    ! Test 10: Over-saturation case from debugging
    call test_over_saturation_case()

    ! Summary
    write(*,*)
    write(*,*) '📊 Test Summary:'
    write(*,'(A,I0,A,I0)') '   Tests passed: ', pass_count, ' / ', test_count
    if (pass_count == test_count) then
        write(*,*) '✅ All isolated edge clipping tests PASSED'
    else
        write(*,*) '❌ Some isolated edge clipping tests FAILED'
        stop 1
    end if

contains

    subroutine test_edge_left_of_pixel()
        !! Test edge completely left of pixel
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        type(stb_active_edge_t) :: edge
        integer :: x = 3
        real(wp) :: x0 = 1.0_wp, y0 = 1.0_wp, x1 = 2.0_wp, y1 = 3.0_wp

        call run_test("Edge left of pixel", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_edge_right_of_pixel()
        !! Test edge completely right of pixel
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 5.0_wp, y0 = 1.0_wp, x1 = 6.0_wp, y1 = 3.0_wp

        call run_test("Edge right of pixel", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_edge_crossing_pixel()
        !! Test edge crossing pixel (critical anti-aliasing case)
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.2_wp, y0 = 1.0_wp, x1 = 3.8_wp, y1 = 3.0_wp

        call run_test("Edge crossing pixel", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_y_clipping_start()
        !! Test Y clipping at edge start
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.2_wp, y0 = 0.5_wp, x1 = 3.8_wp, y1 = 3.0_wp

        call run_test("Y clipping at start", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_y_clipping_end()
        !! Test Y clipping at edge end
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.2_wp, y0 = 1.0_wp, x1 = 3.8_wp, y1 = 3.5_wp

        call run_test("Y clipping at end", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_y_clipping_both()
        !! Test Y clipping at both ends
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.2_wp, y0 = 0.5_wp, x1 = 3.8_wp, y1 = 3.5_wp

        call run_test("Y clipping both ends", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_horizontal_edge()
        !! Test horizontal edge (should be ignored)
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.2_wp, y0 = 2.0_wp, x1 = 3.8_wp, y1 = 2.0_wp

        call run_test("Horizontal edge", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_direction_effects()
        !! Test different edge directions
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.2_wp, y0 = 1.0_wp, x1 = 3.8_wp, y1 = 3.0_wp

        call run_test("Negative direction", x, 1.0_wp, 3.0_wp, -1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_boundary_precision()
        !! Test precision at exact pixel boundaries
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.0_wp, y0 = 1.0_wp, x1 = 4.0_wp, y1 = 3.0_wp

        call run_test("Boundary precision", x, 1.0_wp, 3.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine test_over_saturation_case()
        !! Test case that causes over-saturation (Pure=255, STB=65)
        real(wp) :: fortran_scanline(SCANLINE_SIZE)
        real(c_float) :: stb_scanline(SCANLINE_SIZE)
        integer :: x = 3
        real(wp) :: x0 = 3.1_wp, y0 = 1.0_wp, x1 = 3.9_wp, y1 = 2.0_wp

        call run_test("Over-saturation case", x, 1.0_wp, 2.0_wp, 1.0_wp, &
                      x0, y0, x1, y1, fortran_scanline, stb_scanline)
    end subroutine

    subroutine run_test(test_name, x, sy, ey, direction, x0, y0, x1, y1, &
                        fortran_scanline, stb_scanline)
        character(len=*), intent(in) :: test_name
        integer, intent(in) :: x
        real(wp), intent(in) :: sy, ey, direction, x0, y0, x1, y1
        real(wp), intent(out) :: fortran_scanline(:)
        real(c_float), intent(out) :: stb_scanline(:)

        type(stb_active_edge_t) :: edge
        integer :: i
        logical :: matches
        real(wp) :: max_diff

        test_count = test_count + 1

        ! Initialize scanlines
        fortran_scanline = 0.0_wp
        stb_scanline = 0.0_c_float

        ! Setup edge
        edge%sy = sy
        edge%ey = ey
        edge%direction = direction

        ! Run Fortran implementation
        call stb_handle_clipped_edge(fortran_scanline, x, edge, x0, y0, x1, y1)

        ! Run STB C implementation
        call test_stb_handle_clipped_edge_c(stb_scanline, x, &
                                            real(sy, c_float), real(ey, c_float), &
                                            real(direction, c_float), &
                                            real(x0, c_float), real(y0, c_float), &
                                            real(x1, c_float), real(y1, c_float))

        ! Compare results
        matches = .true.
        max_diff = 0.0_wp
        do i = 1, size(fortran_scanline)
            max_diff = max(max_diff, abs(fortran_scanline(i) - real(stb_scanline(i), wp)))
            if (abs(fortran_scanline(i) - real(stb_scanline(i), wp)) > TOLERANCE) then
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
            write(*,'(A)', advance='no') '     Fortran: ['
            do i = 1, min(5, size(fortran_scanline))
                write(*,'(F8.5,A)', advance='no') fortran_scanline(i), ' '
            end do
            write(*,'(A)') ']'
            write(*,'(A)', advance='no') '     STB C:   ['
            do i = 1, min(5, size(stb_scanline))
                write(*,'(F8.5,A)', advance='no') stb_scanline(i), ' '
            end do
            write(*,'(A)') ']'
        end if
    end subroutine

end program test_forttf_handle_clipped_edge_isolated