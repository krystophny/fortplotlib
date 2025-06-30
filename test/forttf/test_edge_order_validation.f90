program test_edge_order_validation
    !! Test edge processing order differences between STB and ForTTF
    !! Focus on multi-edge scenarios with specific edge insertion order
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
    use forttf_types, only: stb_edge_t, stb_bitmap_t
    use forttf_stb_raster, only: stb_rasterize_sorted_edges
    use fortplot_stb_truetype  ! For STB comparison if available
    implicit none

    call test_edge_processing_order()

contains

    subroutine test_edge_processing_order()
        !! Test edge processing order with two specific intersecting edges
        integer, parameter :: width = 5, height = 5
        type(stb_edge_t) :: edges(2)
        integer(c_int8_t), allocatable :: forttf_bitmap(:)
        integer :: i, j, idx, pixel_val
        
        write(*,*) "=== Edge Processing Order Analysis ==="
        write(*,*) "Testing two intersecting diagonal edges for order dependency"
        write(*,*) ""
        
        ! Test Case 1: Edge order A-B
        write(*,*) "TEST 1: Edge order (0.5,0.5)→(3.5,3.5) then (3.5,0.5)→(0.5,3.5)"
        call test_edge_order_ab(edges, width, height, forttf_bitmap)
        deallocate(forttf_bitmap)
        
        write(*,*) ""
        write(*,*) "------------------------------------------------"
        write(*,*) ""
        
        ! Test Case 2: Edge order B-A (reversed)
        write(*,*) "TEST 2: Edge order (3.5,0.5)→(0.5,3.5) then (0.5,0.5)→(3.5,3.5)"
        call test_edge_order_ba(edges, width, height, forttf_bitmap)
        deallocate(forttf_bitmap)
        
        write(*,*) ""
        write(*,*) "=== Analysis Summary ==="
        write(*,*) "If results differ between Test 1 and Test 2, edge processing"
        write(*,*) "order affects final output, confirming our hypothesis."
        write(*,*) ""
        write(*,*) "Expected: STB uses specific edge ordering that differs from"
        write(*,*) "ForTTF LIFO insertion order in multi-edge scenarios."
        
    end subroutine test_edge_processing_order
    
    subroutine test_edge_order_ab(edges, width, height, bitmap)
        !! Test with edge order: A then B
        type(stb_edge_t), intent(out) :: edges(:)
        integer, intent(in) :: width, height
        integer(c_int8_t), allocatable, intent(out) :: bitmap(:)
        integer :: i, j, idx, pixel_val
        
        ! Edge A: (0.5, 0.5) → (3.5, 3.5) - diagonal down-right
        edges(1)%y0 = 0.5_wp ; edges(1)%y1 = 3.5_wp 
        edges(1)%x0 = 0.5_wp ; edges(1)%x1 = 3.5_wp
        edges(1)%invert = 1
        
        ! Edge B: (3.5, 0.5) → (0.5, 3.5) - diagonal down-left  
        edges(2)%y0 = 0.5_wp ; edges(2)%y1 = 3.5_wp
        edges(2)%x0 = 3.5_wp ; edges(2)%x1 = 0.5_wp
        edges(2)%invert = 1
        
        ! Rasterize
        allocate(bitmap(width * height))
        call rasterize_edges_debug(edges, 2, width, height, bitmap, "A-B")
        
        ! Display result
        write(*,*) "Result matrix (A-B order):"
        do j = 0, height-1
            write(*,'(A)', advance='no') "  "
            do i = 0, width-1
                idx = j * width + i + 1
                pixel_val = int(bitmap(idx))
                if (pixel_val < 0) pixel_val = pixel_val + 256
                write(*,'(I4)', advance='no') pixel_val
            end do
            write(*,*)
        end do
        
    end subroutine test_edge_order_ab
    
    subroutine test_edge_order_ba(edges, width, height, bitmap)
        !! Test with edge order: B then A (reversed)
        type(stb_edge_t), intent(out) :: edges(:)
        integer, intent(in) :: width, height
        integer(c_int8_t), allocatable, intent(out) :: bitmap(:)
        integer :: i, j, idx, pixel_val
        
        ! Edge B: (3.5, 0.5) → (0.5, 3.5) - diagonal down-left (first this time)
        edges(1)%y0 = 0.5_wp ; edges(1)%y1 = 3.5_wp
        edges(1)%x0 = 3.5_wp ; edges(1)%x1 = 0.5_wp
        edges(1)%invert = 1
        
        ! Edge A: (0.5, 0.5) → (3.5, 3.5) - diagonal down-right (second this time)
        edges(2)%y0 = 0.5_wp ; edges(2)%y1 = 3.5_wp 
        edges(2)%x0 = 0.5_wp ; edges(2)%x1 = 3.5_wp
        edges(2)%invert = 1
        
        ! Rasterize
        allocate(bitmap(width * height))
        call rasterize_edges_debug(edges, 2, width, height, bitmap, "B-A")
        
        ! Display result
        write(*,*) "Result matrix (B-A order):"
        do j = 0, height-1
            write(*,'(A)', advance='no') "  "
            do i = 0, width-1
                idx = j * width + i + 1
                pixel_val = int(bitmap(idx))
                if (pixel_val < 0) pixel_val = pixel_val + 256
                write(*,'(I4)', advance='no') pixel_val
            end do
            write(*,*)
        end do
        
    end subroutine test_edge_order_ba
    
    subroutine rasterize_edges_debug(edges, n_edges, width, height, bitmap, label)
        !! Rasterize edges with debug output for processing order
        type(stb_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: n_edges, width, height
        integer(c_int8_t), intent(out), target :: bitmap(:)
        character(len=*), intent(in) :: label
        
        type(stb_bitmap_t) :: result
        type(c_ptr) :: userdata = c_null_ptr
        
        write(*,'(A,A)') "Rasterizing with edge order: ", label
        write(*,*) "Edge 1: y0=", edges(1)%y0, " y1=", edges(1)%y1, &
                   " x0=", edges(1)%x0, " x1=", edges(1)%x1
        write(*,*) "Edge 2: y0=", edges(2)%y0, " y1=", edges(2)%y1, &
                   " x0=", edges(2)%x0, " x1=", edges(2)%x1
        write(*,*) ""
        
        ! Setup result structure
        result%w = width
        result%h = height  
        result%stride = width
        result%pixels => bitmap
        
        ! Initialize bitmap
        bitmap = 0
        
        ! Call ForTTF rasterizer
        call stb_rasterize_sorted_edges(result, edges, n_edges, 1, 0, 0, userdata)
        
    end subroutine rasterize_edges_debug

end program test_edge_order_validation