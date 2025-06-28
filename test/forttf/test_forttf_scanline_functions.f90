program test_forttf_scanline_functions
    !! Test STB scanline rasterization functions in isolation
    use forttf_stb_raster, only: stb_rasterize_sorted_edges
    use forttf_types, only: stb_bitmap_t, stb_edge_t
    use iso_c_binding, only: c_null_ptr, c_int8_t
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    logical :: all_passed

    all_passed = .true.
    
    ! Test each scanline function in isolation
    call test_rasterize_sorted_edges_simple_triangle(all_passed)
    call test_rasterize_sorted_edges_empty_array(all_passed)

    if (all_passed) then
        print *, "✅ All STB scanline function tests passed!"
    else
        print *, "❌ Some STB scanline function tests failed!"
        error stop 1
    end if

contains

    subroutine test_rasterize_sorted_edges_simple_triangle(passed)
        logical, intent(inout) :: passed
        type(stb_bitmap_t) :: bitmap
        type(stb_edge_t), allocatable :: edges(:)
        integer(c_int8_t), allocatable, target :: pixels(:)
        integer :: i

        print *, "Testing stb_rasterize_sorted_edges with simple triangle..."
        
        ! Create a 10x10 bitmap
        allocate(pixels(10*10))
        pixels = 0

        bitmap%w = 10
        bitmap%h = 10
        bitmap%stride = 10
        bitmap%pixels => pixels

        ! Create a simple triangle: 3 edges forming a small triangle
        allocate(edges(3))
        
        ! Triangle vertices: (2,2), (7,2), (4.5,7)
        ! Edge 1: (2,2) -> (7,2) (horizontal bottom)
        edges(1) = stb_edge_t(x0=2.0_wp, y0=2.0_wp, x1=7.0_wp, y1=2.0_wp, invert=0)
        
        ! Edge 2: (7,2) -> (4.5,7) (right side going up-left)  
        edges(2) = stb_edge_t(x0=7.0_wp, y0=2.0_wp, x1=4.5_wp, y1=7.0_wp, invert=0)
        
        ! Edge 3: (4.5,7) -> (2,2) (left side going down-left)
        edges(3) = stb_edge_t(x0=4.5_wp, y0=7.0_wp, x1=2.0_wp, y1=2.0_wp, invert=0)

        ! Test the function
        call stb_rasterize_sorted_edges(bitmap, edges, 3, 1, 0, 0, c_null_ptr)

        ! Check that some pixels were modified (triangle should have area > 0)
        if (any(pixels /= 0)) then
            print *, "✅ Triangle rasterization test passed - pixels were modified"
            
            ! Print simple visualization for debugging
            print *, "Triangle rasterization result:"
            do i = 1, 10
                write(*,'(10I4)') pixels((i-1)*10+1:i*10)
            end do
        else
            print *, "❌ Triangle rasterization test failed - no pixels modified"
            passed = .false.
        end if

        deallocate(pixels, edges)
        
    end subroutine test_rasterize_sorted_edges_simple_triangle

    subroutine test_rasterize_sorted_edges_empty_array(passed)
        logical, intent(inout) :: passed
        type(stb_bitmap_t) :: bitmap
        type(stb_edge_t), allocatable :: edges(:)
        integer(c_int8_t), allocatable, target :: pixels(:)

        print *, "Testing stb_rasterize_sorted_edges with empty edge array..."
        
        allocate(pixels(5*5))
        pixels = 0

        bitmap%w = 5
        bitmap%h = 5
        bitmap%stride = 5
        bitmap%pixels => pixels

        allocate(edges(0))  ! Empty array

        ! This should not crash and should not modify any pixels
        call stb_rasterize_sorted_edges(bitmap, edges, 0, 1, 0, 0, c_null_ptr)

        if (all(pixels == 0)) then
            print *, "✅ Empty array test passed - no pixels modified"
        else
            print *, "❌ Empty array test failed - pixels were unexpectedly modified"
            passed = .false.
        end if

        deallocate(pixels, edges)
        
    end subroutine test_rasterize_sorted_edges_empty_array

end program test_forttf_scanline_functions
