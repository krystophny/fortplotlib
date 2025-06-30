program test_forttf_scanline_analysis
    !! Analyze specific scanline Y=8 where large difference occurs: (8,8) 160→7 (-153)
    !! Focus on multi-edge processing at this critical scanline
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
    use forttf_types, only: stb_edge_t, stb_bitmap_t
    use forttf_stb_raster, only: stb_rasterize_sorted_edges
    use fortplot_stb_truetype
    implicit none

    call analyze_problematic_scanline()

contains

    subroutine analyze_problematic_scanline()
        !! Analyze scanline Y=8 where we see (8,8) 160→7 (-153) difference
        
        write(*,*) "=== Scanline Y=8 Analysis - Large Difference Investigation ==="
        write(*,*) "Target: (8,8) STB=160 vs ForTTF=7 (difference -153)"
        write(*,*) ""
        
        ! From debug output, scanline Y=8 has these edges:
        write(*,*) "Edges active at scanline Y=8 (from debug output):"
        write(*,*) "Edge A: x0=16.275082 dx=-0.762295 y_top=8.000 y_bottom=9.000"
        write(*,*) "Edge B: x0=19.587133 dx=-0.191756 y_top=8.000 y_bottom=9.000"  
        write(*,*) "Edge C: x0=15.810886 dx=-0.196203 y_top=8.000 y_bottom=9.000"
        write(*,*) ""
        
        ! Test just this scanline configuration
        call test_isolated_scanline_y8()
        
        write(*,*) ""
        write(*,*) "=== Analysis Complete ==="
        write(*,*) "This helps identify if specific edge combinations cause"
        write(*,*) "the large discrepancies in multi-edge scenarios."
        
    end subroutine analyze_problematic_scanline
    
    subroutine test_isolated_scanline_y8()
        !! Test the specific edge configuration from scanline Y=8
        integer, parameter :: width = 20, height = 2  ! Just scanlines 8-9
        type(stb_edge_t) :: edges(3)
        integer(c_int8_t), allocatable :: forttf_bitmap(:), stb_bitmap(:)
        integer :: i, j, idx, forttf_val, stb_val
        
        write(*,*) "Testing isolated scanline Y=8 edge configuration:"
        write(*,*) ""
        
        ! Create edges based on debug output from scanline Y=8
        ! Edge A: Crosses Y=8 to Y=9
        edges(1)%y0 = 8.0_wp
        edges(1)%y1 = 9.0_wp  
        edges(1)%x0 = 16.275082_wp
        edges(1)%x1 = 16.275082_wp - 0.762295_wp  ! x0 + dx
        edges(1)%invert = 1
        
        ! Edge B: Crosses Y=8 to Y=9
        edges(2)%y0 = 8.0_wp
        edges(2)%y1 = 9.0_wp
        edges(2)%x0 = 19.587133_wp
        edges(2)%x1 = 19.587133_wp - 0.191756_wp  ! x0 + dx
        edges(2)%invert = 1
        
        ! Edge C: Crosses Y=8 to Y=9
        edges(3)%y0 = 8.0_wp
        edges(3)%y1 = 9.0_wp
        edges(3)%x0 = 15.810886_wp
        edges(3)%x1 = 15.810886_wp - 0.196203_wp  ! x0 + dx
        edges(3)%invert = 1
        
        write(*,*) "Edge definitions:"
        do i = 1, 3
            write(*,'(A,I0,A,F8.3,A,F8.3,A,F8.3,A,F8.3)') &
                "  Edge ", i, ": y0=", edges(i)%y0, " y1=", edges(i)%y1, &
                " x0=", edges(i)%x0, " x1=", edges(i)%x1
        end do
        write(*,*) ""
        
        ! Test ForTTF
        allocate(forttf_bitmap(width * height))
        forttf_bitmap = 0
        call rasterize_edges_with_offset(edges, 3, width, height, forttf_bitmap, -3, -8)
        
        ! Test STB (would need STB direct call - for now show ForTTF result)
        allocate(stb_bitmap(width * height))
        stb_bitmap = forttf_bitmap  ! Placeholder
        
        ! Focus on pixel (8,0) which corresponds to (8,8) in full bitmap
        write(*,*) "Results for scanline (Y=8 in full bitmap, Y=0 in this test):"
        write(*,'(A)', advance='no') "  "
        do i = 0, width-1
            idx = 0 * width + i + 1  ! Y=0 scanline
            forttf_val = int(forttf_bitmap(idx))
            if (forttf_val < 0) forttf_val = forttf_val + 256
            write(*,'(I4)', advance='no') forttf_val
        end do
        write(*,*) ""
        
        write(*,*) ""
        write(*,'(A,I0)') "ForTTF pixel (8,0): ", int(forttf_bitmap(9))  ! X=8 -> index 9
        write(*,*) "Expected STB value: 160 (from full test)"
        write(*,*) "This should help identify the multi-edge accumulation issue."
        
        deallocate(forttf_bitmap, stb_bitmap)
        
    end subroutine test_isolated_scanline_y8
    
    subroutine rasterize_edges_with_offset(edges, n_edges, width, height, bitmap, off_x, off_y)
        !! Rasterize edges with specific offset to match full glyph context
        type(stb_edge_t), intent(in) :: edges(:)
        integer, intent(in) :: n_edges, width, height, off_x, off_y
        integer(c_int8_t), intent(out), target :: bitmap(:)
        
        type(stb_bitmap_t) :: result
        type(c_ptr) :: userdata = c_null_ptr
        
        write(*,'(A,I0,A,I0)') "Rasterizing with offset: ", off_x, ", ", off_y
        
        ! Setup result structure
        result%w = width
        result%h = height  
        result%stride = width
        result%pixels => bitmap
        
        ! Initialize bitmap
        bitmap = 0
        
        ! Call ForTTF rasterizer with offset
        call stb_rasterize_sorted_edges(result, edges, n_edges, 1, off_x, off_y, userdata)
        
    end subroutine rasterize_edges_with_offset

end program test_forttf_scanline_analysis