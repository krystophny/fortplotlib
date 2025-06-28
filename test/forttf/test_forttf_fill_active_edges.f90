program test_forttf_fill_active_edges
    !! Test STB-compatible fill_active_edges function using TDD methodology
    !! Validates Fortran implementation against STB C reference
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! C interface declarations for STB test wrapper
    interface
        subroutine stb_test_fill_active_edges_simple(scanline, scanline_fill, len, &
                    fx, fdx, fdy, direction, sy, ey, y_top) bind(c)
            import :: c_float, c_int
            real(c_float), intent(inout) :: scanline(*)
            real(c_float), intent(inout) :: scanline_fill(*)
            integer(c_int), value :: len
            real(c_float), value :: fx, fdx, fdy, direction, sy, ey, y_top
        end subroutine
    end interface

    logical :: all_tests_passed = .true.

    write(*,*) "=== STB Fill Active Edges TDD Tests ==="
    write(*,*) "Testing stb_fill_active_edges() against STB C reference..."
    write(*,*)

    call test_fill_active_edges_single_edge(all_tests_passed)

    write(*,*)
    if (all_tests_passed) then
        write(*,*) "✅ All STB fill_active_edges tests PASSED!"
        stop 0
    else
        write(*,*) "❌ Some STB fill_active_edges tests FAILED!"
        stop 1
    end if

contains

    subroutine test_fill_active_edges_single_edge(passed)
        logical, intent(inout) :: passed
        
        ! Test parameters
        integer, parameter :: width = 10
        real(wp), parameter :: y_top = 5.5_wp
        real(wp), parameter :: tolerance = 1e-5_wp
        
        ! Test data
        real(wp) :: fortran_scanline(width), fortran_scanline_fill(width + 1)
        real(c_float) :: c_scanline(width), c_scanline_fill(width + 1)
        
        ! Create a simple active edge: vertical line at x=3.5, direction=1
        type(stb_active_edge_t), target :: active_edge
        type(stb_active_edge_t), pointer :: edge_ptr
        
        write(*,*) "--- Test 1: Single Vertical Edge ---"
        
        ! Set up active edge (vertical line at x=3.5)
        active_edge = stb_active_edge_t( &
            fx = 3.5_wp, &
            fdx = 0.0_wp, &  ! Vertical line
            fdy = 0.0_wp, &
            direction = 1.0_wp, &
            sy = 4.0_wp, &
            ey = 7.0_wp &
        )
        active_edge%next => null()
        edge_ptr => active_edge
        
        ! Initialize buffers
        fortran_scanline = 0.0_wp
        fortran_scanline_fill = 0.0_wp
        c_scanline = 0.0
        c_scanline_fill = 0.0
        
        ! Test Fortran implementation
        call stb_fill_active_edges(edge_ptr, y_top, width, fortran_scanline, fortran_scanline_fill)
        
        ! Test STB C reference
        call stb_test_fill_active_edges_simple(c_scanline, c_scanline_fill, width, &
                    real(active_edge%fx, c_float), real(active_edge%fdx, c_float), &
                    real(active_edge%fdy, c_float), real(active_edge%direction, c_float), &
                    real(active_edge%sy, c_float), real(active_edge%ey, c_float), &
                    real(y_top, c_float))
        
        ! Compare results
        call compare_results("Single Vertical Edge", fortran_scanline, fortran_scanline_fill, &
                           c_scanline, c_scanline_fill, width, tolerance, passed)
        
    end subroutine test_fill_active_edges_single_edge

    subroutine compare_results(test_name, fort_scanline, fort_scanline_fill, &
                             c_scanline, c_scanline_fill, width, tolerance, passed)
        character(len=*), intent(in) :: test_name
        real(wp), intent(in) :: fort_scanline(:), fort_scanline_fill(:)
        real(c_float), intent(in) :: c_scanline(:), c_scanline_fill(:)
        integer, intent(in) :: width
        real(wp), intent(in) :: tolerance
        logical, intent(inout) :: passed
        
        logical :: scanline_match, scanline_fill_match
        integer :: i
        real(wp) :: max_diff_scanline, max_diff_fill
        real(wp) :: diff
        
        ! Compare scanline buffers
        scanline_match = .true.
        max_diff_scanline = 0.0_wp
        do i = 1, width
            diff = abs(fort_scanline(i) - real(c_scanline(i), wp))
            max_diff_scanline = max(max_diff_scanline, diff)
            if (diff > tolerance) scanline_match = .false.
        end do
        
        ! Compare scanline_fill buffers
        scanline_fill_match = .true.
        max_diff_fill = 0.0_wp
        do i = 1, width + 1
            diff = abs(fort_scanline_fill(i) - real(c_scanline_fill(i), wp))
            max_diff_fill = max(max_diff_fill, diff)
            if (diff > tolerance) scanline_fill_match = .false.
        end do
        
        ! Report results
        if (scanline_match .and. scanline_fill_match) then
            write(*,*) "  ✅ ", trim(test_name), " PASSED"
            write(*,*) "    Max diff scanline:", max_diff_scanline
            write(*,*) "    Max diff fill:", max_diff_fill
        else
            write(*,*) "  ❌ ", trim(test_name), " FAILED"
            write(*,*) "    Max diff scanline:", max_diff_scanline, " (match: ", scanline_match, ")"
            write(*,*) "    Max diff fill:", max_diff_fill, " (match: ", scanline_fill_match, ")"
            
            ! Print detailed comparison for debugging
            write(*,*) "    Fortran scanline:      ", fort_scanline(1:min(width,8))
            write(*,*) "    STB C scanline:        ", c_scanline(1:min(width,8))
            write(*,*) "    Fortran scanline_fill: ", fort_scanline_fill(1:min(width+1,8))
            write(*,*) "    STB C scanline_fill:   ", c_scanline_fill(1:min(width+1,8))
            
            passed = .false.
        end if
        
    end subroutine compare_results

end program test_forttf_fill_active_edges
