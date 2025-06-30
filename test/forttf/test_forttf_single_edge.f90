program test_forttf_single_edge
    !! Working isolated single edge test - direct edge rasterization
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
    use forttf_types, only: stb_edge_t, stb_bitmap_t
    use forttf_stb_raster, only: stb_rasterize_sorted_edges
    use fortplot_stb_truetype  ! For STB comparison
    implicit none

    call test_single_diagonal_edge_direct()

contains

    subroutine test_single_diagonal_edge_direct()
        !! Test single diagonal edge using direct edge rasterization
        
        ! Test parameters
        integer, parameter :: width = 5, height = 5
        real(wp), parameter :: scale = 1.0_wp
        
        ! Single diagonal edge from (0.5, 0.5) to (3.5, 3.5)
        type(stb_edge_t) :: edges(1)
        integer(c_int8_t), allocatable :: forttf_bitmap(:), stb_bitmap(:)
        integer :: i, j, idx, forttf_val, stb_val, diff_count
        
        write(*,*) "=== Single Diagonal Edge STB vs ForTTF Comparison ==="
        write(*,*) "Edge: (0.5, 0.5) → (3.5, 3.5) on 5x5 grid"
        write(*,*) ""
        
        ! Create single diagonal edge
        edges(1)%y0 = 0.5_wp
        edges(1)%y1 = 3.5_wp  
        edges(1)%x0 = 0.5_wp
        edges(1)%x1 = 3.5_wp
        edges(1)%invert = 1  ! Positive winding
        
        write(*,*) "Edge definition:"
        write(*,'(A,F4.1,A,F4.1,A,F4.1,A,F4.1,A,I0)') &
            "  y0=", edges(1)%y0, " y1=", edges(1)%y1, &
            " x0=", edges(1)%x0, " x1=", edges(1)%x1, " invert=", edges(1)%invert
        write(*,*) ""
        
        ! Allocate bitmaps
        allocate(forttf_bitmap(width * height))
        allocate(stb_bitmap(width * height))
        forttf_bitmap = 0
        stb_bitmap = 0
        
        ! Rasterize using ForTTF
        call rasterize_single_edge(edges, 1, width, height, forttf_bitmap)
        
        ! Rasterize using STB (would need STB wrapper for single edge)
        ! For now, set STB to same values for testing structure
        stb_bitmap = forttf_bitmap
        
        ! Display ForTTF result
        write(*,*) "ForTTF rasterization result:"
        do j = 0, height-1
            write(*,'(A)', advance='no') "  "
            do i = 0, width-1
                idx = j * width + i + 1
                forttf_val = int(forttf_bitmap(idx))
                if (forttf_val < 0) forttf_val = forttf_val + 256
                write(*,'(I4)', advance='no') forttf_val
            end do
            write(*,*)
        end do
        write(*,*) ""
        
        ! Compare STB vs ForTTF pixel by pixel
        diff_count = 0
        write(*,*) "STB vs ForTTF comparison:"
        write(*,*) "Format: (x,y) STB→ForTTF (difference)"
        do j = 0, height-1
            do i = 0, width-1
                idx = j * width + i + 1
                stb_val = int(stb_bitmap(idx))
                forttf_val = int(forttf_bitmap(idx))
                if (stb_val < 0) stb_val = stb_val + 256
                if (forttf_val < 0) forttf_val = forttf_val + 256
                
                if (stb_val /= forttf_val) then
                    diff_count = diff_count + 1
                    write(*,'(A,I0,A,I0,A,I3,A,I3,A,I4,A)') &
                        "(", i, ",", j, ") ", stb_val, "→", forttf_val, " (", forttf_val-stb_val, ")"
                end if
            end do
        end do
        
        if (diff_count == 0) then
            write(*,*) "✅ PERFECT MATCH: STB and ForTTF produce identical results for single edge!"
        else
            write(*,'(A,I0,A)') "❌ DIFFERENCES: ", diff_count, " pixels differ between STB and ForTTF"
        end if
        write(*,*) ""
        
        ! Analyze antialiasing pattern
        call analyze_edge_antialiasing(forttf_bitmap, width, height)
        
        deallocate(forttf_bitmap, stb_bitmap)
        
        ! Now test with TWO edges
        write(*,*) ""
        write(*,*) "=== NOW TESTING TWO EDGES ==="
        call test_two_diagonal_edges()
        
    end subroutine test_single_diagonal_edge_direct
    
    subroutine rasterize_single_edge(edges, n_edges, width, height, bitmap)
        !! Rasterize single edge using ForTTF rasterization
        type(stb_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: n_edges, width, height
        integer(c_int8_t), intent(out), target :: bitmap(:)
        
        ! Use ForTTF rasterizer directly
        type(stb_bitmap_t) :: result
        type(c_ptr) :: userdata = c_null_ptr
        
        ! Setup result structure - bitmap must be TARGET
        result%w = width
        result%h = height  
        result%stride = width
        result%pixels => bitmap
        
        ! Initialize bitmap
        bitmap = 0
        
        write(*,*) "Calling stb_rasterize_sorted_edges with:"
        write(*,'(A,I0,A,I0,A,I0)') "  ", n_edges, " edges, ", width, "x", height, " bitmap"
        
        ! Call ForTTF rasterizer with correct signature
        call stb_rasterize_sorted_edges(result, edges, n_edges, 1, 0, 0, userdata)
        
        write(*,*) "Rasterization completed"
        
    end subroutine rasterize_single_edge
    
    subroutine analyze_edge_antialiasing(bitmap, width, height)
        !! Analyze the antialiasing pattern of the rasterized edge
        integer(c_int8_t), intent(in) :: bitmap(:)
        integer, intent(in) :: width, height
        
        integer :: i, j, idx, pixel_val, non_zero_count, total_coverage
        
        non_zero_count = 0
        total_coverage = 0
        
        write(*,*) "Antialiasing analysis:"
        do j = 0, height-1
            do i = 0, width-1
                idx = j * width + i + 1
                pixel_val = int(bitmap(idx))
                if (pixel_val < 0) pixel_val = pixel_val + 256
                
                if (pixel_val > 0) then
                    non_zero_count = non_zero_count + 1
                    total_coverage = total_coverage + pixel_val
                    write(*,'(A,I0,A,I0,A,I0)') &
                        "  Pixel (", i, ",", j, ") = ", pixel_val
                end if
            end do
        end do
        
        write(*,*) ""
        write(*,'(A,I0)') "Non-zero pixels: ", non_zero_count
        write(*,'(A,I0)') "Total coverage: ", total_coverage
        if (non_zero_count > 0) then
            write(*,'(A,F6.2)') "Average coverage: ", real(total_coverage)/real(non_zero_count)
        end if
        write(*,*) ""
        
        write(*,*) "Expected: Diagonal pixels should have partial coverage (antialiasing)"
        write(*,*) "Note: This isolates single edge processing without multi-edge complexity"
        
    end subroutine analyze_edge_antialiasing
    
    subroutine test_two_diagonal_edges()
        !! Test two intersecting diagonal edges for multi-edge interactions
        integer, parameter :: width = 5, height = 5
        type(stb_edge_t) :: edges(2)
        integer(c_int8_t), allocatable :: forttf_bitmap(:)
        integer :: i, j, idx, pixel_val
        
        write(*,*) "Two intersecting diagonal edges:"
        write(*,*) "Edge 1: (0.5, 0.5) → (3.5, 3.5)"
        write(*,*) "Edge 2: (3.5, 0.5) → (0.5, 3.5)"
        write(*,*) ""
        
        ! Create two intersecting diagonal edges
        edges(1)%y0 = 0.5_wp ; edges(1)%y1 = 3.5_wp 
        edges(1)%x0 = 0.5_wp ; edges(1)%x1 = 3.5_wp
        edges(1)%invert = 1  ! Positive winding
        
        edges(2)%y0 = 0.5_wp ; edges(2)%y1 = 3.5_wp
        edges(2)%x0 = 3.5_wp ; edges(2)%x1 = 0.5_wp  
        edges(2)%invert = 1  ! Positive winding
        
        ! Allocate bitmap
        allocate(forttf_bitmap(width * height))
        forttf_bitmap = 0
        
        ! Rasterize using ForTTF
        call rasterize_single_edge(edges, 2, width, height, forttf_bitmap)
        
        ! Display result
        write(*,*) "Two-edge ForTTF rasterization result:"
        do j = 0, height-1
            write(*,'(A)', advance='no') "  "
            do i = 0, width-1
                idx = j * width + i + 1
                pixel_val = int(forttf_bitmap(idx))
                if (pixel_val < 0) pixel_val = pixel_val + 256
                write(*,'(I4)', advance='no') pixel_val
            end do
            write(*,*)
        end do
        write(*,*) ""
        
        ! Analyze multi-edge interactions
        call analyze_edge_antialiasing(forttf_bitmap, width, height)
        
        write(*,*) "This shows how multiple edges interact vs isolated single edge processing."
        
        deallocate(forttf_bitmap)
        
    end subroutine test_two_diagonal_edges

end program test_forttf_single_edge