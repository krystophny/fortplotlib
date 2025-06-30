program test_forttf_edge_processing
    !! Test STB-compatible edge building and sorting algorithms
    use forttf_types
    use forttf_stb_raster
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_edge_building_and_sorting()

contains

    subroutine test_edge_building_and_sorting()
        !! Test edge building and sorting for STB compatibility
        type(stb_point_t), allocatable :: points(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer, allocatable :: contour_lengths(:)
        integer :: i
        
        write(*,*) "=== Edge Processing Tests ==="
        
        ! Test 1: Simple square edge building
        write(*,*) "--- Test 1: Square Edge Building ---"
        call test_square_edges()
        
        ! Test 2: Edge sorting validation
        write(*,*) "--- Test 2: Edge Sorting ---"
        call test_edge_sorting()
        
        ! Test 3: Complex shape edge building
        write(*,*) "--- Test 3: Complex Shape Edges ---"
        call test_complex_edges()
        
        write(*,*) "=== Edge Processing Tests Complete ==="
        
    end subroutine test_edge_building_and_sorting
    
    subroutine test_square_edges()
        !! Test edge building for a simple square
        type(stb_point_t), allocatable :: points(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer, allocatable :: contour_lengths(:)
        real(wp), parameter :: scale_x = 1.0_wp, scale_y = 1.0_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        integer :: i
        
        ! Create square points: (0,0) -> (10,0) -> (10,10) -> (0,10) -> (0,0)
        allocate(points(4))
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)
        points(2) = stb_point_t(x=10.0_wp, y=0.0_wp)
        points(3) = stb_point_t(x=10.0_wp, y=10.0_wp)
        points(4) = stb_point_t(x=0.0_wp, y=10.0_wp)
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 4
        
        ! Build edges
        edges = stb_build_edges(points, contour_lengths, 1, &
                               scale_x, scale_y, shift_x, shift_y, .false.)
        
        write(*,*) "Square edge building:"
        write(*,*) "  Input points:", size(points)
        write(*,*) "  Output edges:", size(edges)
        
        ! Print edges
        do i = 1, min(size(edges), 6)
            write(*,'("  Edge", I2, ": (", F6.1, ",", F6.1, ") to (", F6.1, ",", F6.1, "), invert=", I1)') &
                i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        ! Square should produce 2 vertical edges (horizontal edges filtered out)
        if (size(edges) == 2) then
            write(*,*) "✅ Square edge building correct (2 vertical edges)"
        else
            write(*,*) "❌ Square edge building failed - expected 2 edges, got", size(edges)
        end if
        
    end subroutine test_square_edges
    
    subroutine test_edge_sorting()
        !! Test edge sorting algorithms
        type(stb_edge_t), allocatable :: edges(:)
        integer :: i
        logical :: is_sorted
        
        ! Create unsorted edges with different y0 values
        allocate(edges(8))
        edges(1) = stb_edge_t(x0=0.0_wp, y0=5.0_wp, x1=1.0_wp, y1=6.0_wp, invert=0)
        edges(2) = stb_edge_t(x0=0.0_wp, y0=2.0_wp, x1=1.0_wp, y1=3.0_wp, invert=0)
        edges(3) = stb_edge_t(x0=0.0_wp, y0=8.0_wp, x1=1.0_wp, y1=9.0_wp, invert=0)
        edges(4) = stb_edge_t(x0=0.0_wp, y0=1.0_wp, x1=1.0_wp, y1=2.0_wp, invert=0)
        edges(5) = stb_edge_t(x0=0.0_wp, y0=7.0_wp, x1=1.0_wp, y1=8.0_wp, invert=0)
        edges(6) = stb_edge_t(x0=0.0_wp, y0=3.0_wp, x1=1.0_wp, y1=4.0_wp, invert=0)
        edges(7) = stb_edge_t(x0=0.0_wp, y0=6.0_wp, x1=1.0_wp, y1=7.0_wp, invert=0)
        edges(8) = stb_edge_t(x0=0.0_wp, y0=4.0_wp, x1=1.0_wp, y1=5.0_wp, invert=0)
        
        write(*,*) "Before sorting:"
        do i = 1, size(edges)
            write(*,'("  Edge", I2, ": y0=", F4.1)') i, edges(i)%y0
        end do
        
        ! Sort edges
        call stb_sort_edges(edges, size(edges))
        
        write(*,*) "After sorting:"
        do i = 1, size(edges)
            write(*,'("  Edge", I2, ": y0=", F4.1)') i, edges(i)%y0
        end do
        
        ! Verify sorting
        is_sorted = .true.
        do i = 2, size(edges)
            if (edges(i)%y0 < edges(i-1)%y0) then
                is_sorted = .false.
                exit
            end if
        end do
        
        if (is_sorted) then
            write(*,*) "✅ Edge sorting worked correctly"
        else
            write(*,*) "❌ Edge sorting failed"
        end if
        
    end subroutine test_edge_sorting
    
    subroutine test_complex_edges()
        !! Test edge building for a more complex shape
        type(stb_point_t), allocatable :: points(:)
        type(stb_edge_t), allocatable :: edges(:)
        integer, allocatable :: contour_lengths(:)
        real(wp), parameter :: scale_x = 0.5_wp, scale_y = 0.5_wp
        real(wp), parameter :: shift_x = 5.0_wp, shift_y = 5.0_wp
        integer :: i
        logical :: transform_correct
        
        ! Create triangle with scaling and shifting
        allocate(points(3))
        points(1) = stb_point_t(x=0.0_wp, y=0.0_wp)
        points(2) = stb_point_t(x=20.0_wp, y=0.0_wp)
        points(3) = stb_point_t(x=10.0_wp, y=20.0_wp)
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 3
        
        ! Build edges with scaling and shifting
        edges = stb_build_edges(points, contour_lengths, 1, &
                               scale_x, scale_y, shift_x, shift_y, .false.)
        
        write(*,*) "Triangle with scaling (0.5x) and shifting (+5,+5):"
        write(*,*) "  Input points:", size(points)
        write(*,*) "  Output edges:", size(edges)
        
        do i = 1, size(edges)
            write(*,'("  Edge", I2, ": (", F6.1, ",", F6.1, ") to (", F6.1, ",", F6.1, "), invert=", I1)') &
                i, edges(i)%x0, edges(i)%y0, edges(i)%x1, edges(i)%y1, edges(i)%invert
        end do
        
        ! Verify scaling and shifting was applied
        transform_correct = .true.
        do i = 1, size(edges)
            ! Check if coordinates are in expected range (scaled and shifted)
            if (edges(i)%x0 < 4.0_wp .or. edges(i)%x0 > 16.0_wp .or. &
                edges(i)%y0 < 4.0_wp .or. edges(i)%y0 > 16.0_wp) then
                transform_correct = .false.
            end if
        end do
        
        if (transform_correct .and. size(edges) >= 2) then
            write(*,*) "✅ Complex edge building with transforms works"
        else
            write(*,*) "❌ Complex edge building failed"
        end if
        
    end subroutine test_complex_edges

end program test_forttf_edge_processing