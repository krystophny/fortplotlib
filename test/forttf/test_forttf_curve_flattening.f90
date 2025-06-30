program test_forttf_curve_flattening
    !! Test STB-compatible curve flattening algorithms for exact matching
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_curve_tessellation()

contains

    subroutine test_curve_tessellation()
        !! Test curve tessellation functions for STB compatibility
        type(stb_point_t), allocatable :: points(:)
        integer :: num_points, max_points
        real(wp), parameter :: flatness = TTF_FLATNESS_IN_PIXELS
        real(wp) :: flatness_squared
        
        write(*,*) "=== Curve Flattening Tests ==="
        
        flatness_squared = flatness * flatness
        max_points = 100
        allocate(points(max_points))
        
        ! Test 1: Simple quadratic curve tessellation
        write(*,*) "--- Test 1: Quadratic Curve Tessellation ---"
        num_points = 1
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)  ! Start point
        
        ! Test curve: (0,0) -> control(50,100) -> end(100,0)  
        call stb_tesselate_curve(points, num_points, max_points, &
                               0.0_wp, 0.0_wp, 50.0_wp, 100.0_wp, 100.0_wp, 0.0_wp, &
                               flatness_squared, 0)
        
        write(*,*) "Quadratic curve tessellated into", num_points, "points:"
        call print_points(points, min(num_points, 10))
        
        if (num_points > 1) then
            write(*,*) "✅ Quadratic tessellation produced multiple points"
        else
            write(*,*) "❌ Quadratic tessellation failed"
        end if
        
        ! Test 2: Simple cubic curve tessellation
        write(*,*) "--- Test 2: Cubic Curve Tessellation ---"
        num_points = 1
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)  ! Start point
        
        ! Test curve: (0,0) -> ctrl1(33,100) -> ctrl2(66,100) -> end(100,0)
        call stb_tesselate_cubic(points, num_points, max_points, &
                               0.0_wp, 0.0_wp, 33.0_wp, 100.0_wp, &
                               66.0_wp, 100.0_wp, 100.0_wp, 0.0_wp, &
                               flatness_squared, 0)
        
        write(*,*) "Cubic curve tessellated into", num_points, "points:"
        call print_points(points, min(num_points, 10))
        
        if (num_points > 1) then
            write(*,*) "✅ Cubic tessellation produced multiple points"
        else
            write(*,*) "❌ Cubic tessellation failed"
        end if
        
        ! Test 3: Flat curve (should not subdivide)
        write(*,*) "--- Test 3: Flat Curve (No Subdivision) ---"
        num_points = 1
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)  ! Start point
        
        ! Nearly straight line: (0,0) -> control(50,0.1) -> end(100,0)
        call stb_tesselate_curve(points, num_points, max_points, &
                               0.0_wp, 0.0_wp, 50.0_wp, 0.1_wp, 100.0_wp, 0.0_wp, &
                               flatness_squared, 0)
        
        write(*,*) "Flat curve tessellated into", num_points, "points:"
        call print_points(points, num_points)
        
        if (num_points == 2) then
            write(*,*) "✅ Flat curve correctly avoided subdivision"
        else
            write(*,*) "⚠️  Flat curve subdivision count:", num_points
        end if
        
        ! Test 4: Full vertex-to-points conversion
        write(*,*) "--- Test 4: Complete Vertex Flattening ---"
        call test_vertex_flattening()
        
        write(*,*) "=== Curve Flattening Tests Complete ==="
        
    end subroutine test_curve_tessellation
    
    subroutine test_vertex_flattening()
        !! Test complete vertex-to-points conversion pipeline
        type(ttf_vertex_t), allocatable :: vertices(:)
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_contours
        
        ! Create test vertices: simple quadratic curve path
        allocate(vertices(3))
        vertices(1) = ttf_vertex_t(x=10, y=10, type=TTF_VERTEX_MOVE)     ! Move to start
        vertices(2) = ttf_vertex_t(x=90, y=10, type=TTF_VERTEX_LINE)     ! Line to
        vertices(3) = ttf_vertex_t(x=50, y=90, cx=50, cy=50, type=TTF_VERTEX_CURVE)  ! Curve to
        
        ! Flatten curves using STB algorithm
        points = stb_flatten_curves(vertices, size(vertices), TTF_FLATNESS_IN_PIXELS, &
                                   contour_lengths, num_contours)
        
        write(*,*) "Vertex flattening results:"
        write(*,*) "  Input vertices:", size(vertices)
        write(*,*) "  Output points:", size(points)
        write(*,*) "  Contours:", num_contours
        if (num_contours > 0) then
            write(*,*) "  Contour lengths:", contour_lengths
        end if
        
        if (size(points) > size(vertices)) then
            write(*,*) "✅ Vertex flattening expanded curves to more points"
        else
            write(*,*) "⚠️  Vertex flattening point count:", size(points)
        end if
        
        ! Show first few points
        call print_points(points, min(size(points), 8))
        
    end subroutine test_vertex_flattening
    
    subroutine print_points(points, n)
        !! Helper to print point coordinates
        type(stb_point_t), intent(in) :: points(:)
        integer, intent(in) :: n
        integer :: i
        
        do i = 1, n
            if (i <= size(points)) then
                write(*,'("  Point", I3, ": (", F8.2, ",", F8.2, ")")') &
                    i, points(i)%x, points(i)%y
            end if
        end do
        if (n < size(points)) then
            write(*,*) "  ... (", size(points) - n, "more points)"
        end if
        
    end subroutine print_points

end program test_forttf_curve_flattening