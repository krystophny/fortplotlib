program test_isolated_single_edge
    !! Test isolated single diagonal edge antialiasing STB vs ForTTF
    !! Purpose: Isolate core edge antialiasing without multi-edge complexity
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_single_diagonal_edge()

contains

    subroutine test_single_diagonal_edge()
        !! Create minimal test case with single diagonal edge crossing 2-3 pixels
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        ! Test parameters - simple diagonal edge
        integer, parameter :: test_width = 4, test_height = 4
        real(wp), parameter :: scale = 1.0_wp
        
        ! Synthetic glyph data for single diagonal edge
        ! Edge from (0.5, 0.5) to (2.5, 2.5) - crosses multiple pixels
        
        write(*,*) "=== Testing Isolated Single Diagonal Edge Antialiasing ==="
        write(*,*) "Purpose: Compare STB vs ForTTF on single edge without multi-edge complexity"
        write(*,*) ""
        
        ! Find fonts for infrastructure
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts - using synthetic test"
        end if
        
        ! Create synthetic test case
        call test_synthetic_diagonal_edge()
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_single_diagonal_edge

    subroutine test_synthetic_diagonal_edge()
        !! Test single diagonal edge using synthetic vertex data
        integer, parameter :: width = 5, height = 5
        
        ! Define single diagonal edge from (0.5, 0.5) to (3.5, 3.5)
        type :: test_vertex_t
            real(wp) :: x, y
            integer :: vertex_type  ! 1=move, 2=line
        end type test_vertex_t
        
        type(test_vertex_t) :: vertices(3)
        integer :: i, j, pixel_idx
        
        write(*,*) "--- Synthetic Diagonal Edge Test ---"
        write(*,*) "Edge: (0.5, 0.5) → (3.5, 3.5) crossing 5x5 pixel grid"
        write(*,*) ""
        
        ! Define vertices for single diagonal line
        vertices(1) = test_vertex_t(0.5_wp, 0.5_wp, 1)  ! Move to start
        vertices(2) = test_vertex_t(3.5_wp, 3.5_wp, 2)  ! Line to end
        vertices(3) = test_vertex_t(0.5_wp, 0.5_wp, 2)  ! Close contour
        
        write(*,*) "Diagonal edge vertices:"
        do i = 1, 3
            write(*,'(A,I0,A,F4.1,A,F4.1,A,I0)') &
                "  Vertex ", i, ": (", vertices(i)%x, ", ", vertices(i)%y, ") type=", vertices(i)%vertex_type
        end do
        write(*,*) ""
        
        ! This would require implementing a minimal rasterizer for this specific test
        ! For now, document the test approach
        write(*,*) "TEST APPROACH:"
        write(*,*) "1. Create minimal contour with single diagonal edge"
        write(*,*) "2. Rasterize using both STB and ForTTF with identical parameters"
        write(*,*) "3. Compare pixel coverage values pixel-by-pixel"
        write(*,*) "4. Identify exact algorithmic differences in edge processing"
        write(*,*) ""
        write(*,*) "Expected antialiasing pattern for diagonal edge:"
        write(*,*) "  Pixels should have partial coverage based on edge intersection"
        write(*,*) "  Any differences reveal core antialiasing algorithm discrepancies"
        write(*,*) ""
        write(*,*) "⚠️  This test needs implementation of synthetic glyph rasterization"
        write(*,*) "    to isolate single edge processing without font complexity"
        
    end subroutine test_synthetic_diagonal_edge

end program test_isolated_single_edge