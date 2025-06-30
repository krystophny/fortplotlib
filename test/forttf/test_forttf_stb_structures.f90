program test_forttf_stb_structures
    !! Test STB-specific data structures for exact compatibility
    use forttf_types
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_stb_data_structures()

contains

    subroutine test_stb_data_structures()
        !! Test all STB data structures for correct layout and functionality
        type(stb_point_t) :: point
        type(stb_edge_t) :: edge
        type(stb_active_edge_t) :: active_edge
        type(stb_bitmap_t) :: bitmap
        
        write(*,*) "=== STB Data Structure Tests ==="
        
        ! Test stb_point_t
        write(*,*) "--- Testing stb_point_t ---"
        point = stb_point_t(x=12.5_wp, y=34.7_wp)
        write(*,*) "Point:", point%x, point%y
        if (abs(point%x - 12.5_wp) < epsilon(1.0_wp) .and. &
            abs(point%y - 34.7_wp) < epsilon(1.0_wp)) then
            write(*,*) "✅ stb_point_t works correctly"
        else
            write(*,*) "❌ stb_point_t failed"
        end if
        
        ! Test stb_edge_t
        write(*,*) "--- Testing stb_edge_t ---"
        edge = stb_edge_t(x0=10.0_wp, y0=20.0_wp, x1=30.0_wp, y1=40.0_wp, invert=1)
        write(*,*) "Edge: (", edge%x0, ",", edge%y0, ") to (", edge%x1, ",", edge%y1, "), invert=", edge%invert
        if (abs(edge%x0 - 10.0_wp) < epsilon(1.0_wp) .and. &
            abs(edge%y0 - 20.0_wp) < epsilon(1.0_wp) .and. &
            abs(edge%x1 - 30.0_wp) < epsilon(1.0_wp) .and. &
            abs(edge%y1 - 40.0_wp) < epsilon(1.0_wp) .and. &
            edge%invert == 1) then
            write(*,*) "✅ stb_edge_t works correctly"
        else
            write(*,*) "❌ stb_edge_t failed"
        end if
        
        ! Test stb_active_edge_t
        write(*,*) "--- Testing stb_active_edge_t ---"
        active_edge = stb_active_edge_t(fx=5.5_wp, fdx=2.0_wp, fdy=0.5_wp, &
                                       direction=1.0_wp, sy=10.0_wp, ey=50.0_wp)
        write(*,*) "Active edge: fx=", active_edge%fx, " fdx=", active_edge%fdx, " fdy=", active_edge%fdy
        write(*,*) "             direction=", active_edge%direction, " sy=", active_edge%sy, " ey=", active_edge%ey
        if (abs(active_edge%fx - 5.5_wp) < epsilon(1.0_wp) .and. &
            abs(active_edge%fdx - 2.0_wp) < epsilon(1.0_wp) .and. &
            abs(active_edge%fdy - 0.5_wp) < epsilon(1.0_wp)) then
            write(*,*) "✅ stb_active_edge_t works correctly"
        else
            write(*,*) "❌ stb_active_edge_t failed"
        end if
        
        ! Test constants
        write(*,*) "--- Testing STB Constants ---"
        write(*,*) "TTF_FLATNESS_IN_PIXELS =", TTF_FLATNESS_IN_PIXELS
        write(*,*) "TTF_MAX_RECURSION_DEPTH =", TTF_MAX_RECURSION_DEPTH
        write(*,*) "TTF_COVERAGE_SCALE =", TTF_COVERAGE_SCALE
        write(*,*) "TTF_STACK_BUFFER_SIZE =", TTF_STACK_BUFFER_SIZE
        
        if (abs(TTF_FLATNESS_IN_PIXELS - 0.35_wp) < epsilon(1.0_wp) .and. &
            TTF_MAX_RECURSION_DEPTH == 16 .and. &
            TTF_COVERAGE_SCALE == 255 .and. &
            TTF_STACK_BUFFER_SIZE == 64) then
            write(*,*) "✅ STB constants match expected values"
        else
            write(*,*) "❌ STB constants are incorrect"
        end if
        
        ! Test vertex type constants
        write(*,*) "--- Testing Vertex Type Constants ---"
        write(*,*) "TTF_VERTEX_MOVE =", TTF_VERTEX_MOVE
        write(*,*) "TTF_VERTEX_LINE =", TTF_VERTEX_LINE  
        write(*,*) "TTF_VERTEX_CURVE =", TTF_VERTEX_CURVE
        write(*,*) "TTF_VERTEX_CUBIC =", TTF_VERTEX_CUBIC
        
        if (TTF_VERTEX_MOVE == 1 .and. TTF_VERTEX_LINE == 2 .and. &
            TTF_VERTEX_CURVE == 3 .and. TTF_VERTEX_CUBIC == 4) then
            write(*,*) "✅ Vertex type constants match STB exactly"
        else
            write(*,*) "❌ Vertex type constants are incorrect"
        end if
        
        write(*,*) "=== STB Data Structure Tests Complete ==="
        
    end subroutine test_stb_data_structures

end program test_forttf_stb_structures