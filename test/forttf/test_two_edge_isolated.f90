program test_two_edge_isolated
    !! Isolated test for two-edge coordination to verify fixes
    !! Creates minimal test case with exactly 2 edges to debug multi-edge algorithm
    use forttf_types
    use forttf_stb_raster
    use test_forttf_utils, only: export_pgm_bitmap
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    ! Simple test focuses just on ForTTF rasterization for now
    ! STB comparison can be added later once linker issues are resolved

    call test_minimal_two_edges()

contains

    subroutine test_minimal_two_edges()
        !! Create minimal geometry with exactly 2 edges to test coordination
        type(stb_bitmap_t) :: forttf_bitmap
        type(stb_edge_t), allocatable :: edges(:)
        integer(c_int8_t), allocatable, target :: forttf_pixels(:)
        integer, parameter :: width = 10, height = 10
        integer :: i, j, pixel_count
        logical :: test_passed
        integer :: expected_pixels, actual_filled_pixels, pixel_val
        
        write(*,*) '=== ISOLATED TWO-EDGE TEST ==='
        write(*,*) 'Testing minimal case with exactly 2 edges'
        write(*,*) 'Goal: Verify multi-edge coordination fixes work correctly'
        write(*,*) ''
        
        ! Create simple rectangle with 2 edges on same scanline
        allocate(edges(2))
        allocate(forttf_pixels(width * height))
        forttf_pixels = 0
        
        ! Edge 1: Left edge going down (x=2, y=2 to y=8)
        edges(1)%x0 = 2.0_wp
        edges(1)%y0 = 2.0_wp
        edges(1)%x1 = 2.0_wp
        edges(1)%y1 = 8.0_wp
        edges(1)%invert = 1  ! Winding +1
        
        ! Edge 2: Right edge going down (x=6, y=2 to y=8)  
        edges(2)%x0 = 6.0_wp
        edges(2)%y0 = 2.0_wp
        edges(2)%x1 = 6.0_wp
        edges(2)%y1 = 8.0_wp
        edges(2)%invert = 0  ! Winding -1
        
        write(*,*) 'Created 2 edges:'
        write(*,*) '  Edge 1: (2,2) -> (2,8), invert=1 (left edge, +winding)'
        write(*,*) '  Edge 2: (6,2) -> (6,8), invert=0 (right edge, -winding)'
        write(*,*) '  Expected: Rectangle filled between x=2 and x=6, y=2 to y=8'
        write(*,*) ''
        
        ! Setup ForTTF bitmap
        forttf_bitmap%w = width
        forttf_bitmap%h = height  
        forttf_bitmap%stride = width
        forttf_bitmap%pixels => forttf_pixels
        
        ! Sort edges by Y (required for rasterization)
        call stb_sort_edges(edges, 2)
        
        write(*,*) ''
        write(*,*) '=== FORTTF RASTERIZATION ==='
        ! Rasterize with ForTTF multi-edge coordination
        call stb_rasterize_sorted_edges(forttf_bitmap, edges, 2, 1, 0, 0, c_null_ptr)
        
        ! Export PGM file for visual inspection
        call export_pgm_bitmap(forttf_pixels, width, height, 'two_edge_forttf.pgm')
        write(*,*) '📁 Exported PGM file: two_edge_forttf.pgm'
        write(*,*) ''
        
        ! Display ForTTF bitmap
        write(*,*) 'ForTTF bitmap:'
        do j = 0, min(height-1, 7)
            write(*,'(A,I1,A)', advance='no') 'Row ', j, ': '
            do i = 0, min(width-1, 7)
                pixel_val = int(forttf_pixels(j * width + i + 1))
                if (pixel_val < 0) pixel_val = pixel_val + 256
                write(*,'(I4)', advance='no') pixel_val
            end do
            write(*,*)
        end do
        write(*,*) ''
        
        ! Count non-zero pixels
        pixel_count = 0
        do i = 1, width * height
            if (forttf_pixels(i) /= 0) pixel_count = pixel_count + 1
        end do
        
        ! FINAL TEST: Check if rectangle is properly filled
        write(*,*) '=== FINAL TEST ==='
        
        ! Expected: Rectangle from x=2 to x=5, y=2 to y=7 (4 pixels wide, 6 pixels tall = 24 pixels)
        expected_pixels = 24
        actual_filled_pixels = 0
        
        ! Count pixels in expected rectangle area
        do j = 2, 7
            do i = 2, 5
                pixel_val = int(forttf_pixels(j * width + i + 1))
                if (pixel_val < 0) pixel_val = pixel_val + 256  ! Convert signed to unsigned
                if (pixel_val > 0) actual_filled_pixels = actual_filled_pixels + 1
            end do
        end do
        
        test_passed = (actual_filled_pixels == expected_pixels)
        
        write(*,'(A,I0)') 'Expected filled pixels: ', expected_pixels
        write(*,'(A,I0)') 'Actual filled pixels: ', actual_filled_pixels
        write(*,'(A,I0)') 'Total non-zero pixels: ', pixel_count
        
        if (test_passed) then
            write(*,*) '✅ TEST PASSED: Rectangle correctly filled'
            write(*,*) '   Multi-edge coordination working perfectly'
        else
            write(*,*) '❌ TEST FAILED: Rectangle not properly filled'
            write(*,*) '   Multi-edge coordination needs debugging'
            stop 1
        end if
        
        deallocate(edges, forttf_pixels)
        
    end subroutine test_minimal_two_edges

end program test_two_edge_isolated