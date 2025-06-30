program test_direct_stb_comparison
    !! Direct STB vs ForTTF comparison using same exact glyph and parameters
    !! This eliminates any wrapper or setup differences
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
    use forttf_types, only: stb_bitmap_t
    ! Framework test - no actual dependencies needed for now
    use fortplot_stb_truetype
    implicit none

    call test_exact_same_parameters()

contains

    subroutine test_exact_same_parameters()
        !! Test STB and ForTTF with identical parameters and vertices
        
        write(*,*) "=== Direct STB vs ForTTF Comparison ==="
        write(*,*) "Using identical vertices, scale, shift, and bitmap parameters"
        write(*,*) ""
        
        ! Test with same font, glyph, and parameters as bitmap export test
        call compare_same_glyph_different_implementations()
        
    end subroutine test_exact_same_parameters
    
    subroutine compare_same_glyph_different_implementations()
        !! Compare STB and ForTTF using the exact same implementation path
        character(len=256) :: font_path
        integer :: glyph_index, result_code
        integer, parameter :: bitmap_w = 20, bitmap_h = 39
        real(wp), parameter :: scale_x = 0.02_wp, scale_y = 0.02_wp
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        integer, parameter :: x_off = 3, y_off = -32
        
        ! Glyph data arrays - placeholder for now
        integer :: num_vertices
        
        ! Bitmap results
        integer(c_int8_t), allocatable :: stb_bitmap(:), forttf_bitmap(:)
        integer :: i, j, idx, stb_val, forttf_val, diff_count
        
        num_vertices = 0
        
        ! Use same font and glyph as main test
        font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        glyph_index = 7  ! Same as bitmap export test
        
        write(*,*) "Font: ", trim(font_path)
        write(*,'(A,I0)') "Glyph index: ", glyph_index
        write(*,'(A,I0,A,I0)') "Bitmap: ", bitmap_w, "x", bitmap_h
        write(*,'(A,F6.3,A,F6.3)') "Scale: ", scale_x, ", ", scale_y
        write(*,'(A,I0,A,I0)') "Offset: ", x_off, ", ", y_off
        write(*,*) ""
        
        write(*,*) "Note: This test framework needs vertex extraction implementation"
        write(*,*) "For now, just testing compilation and structure"
        write(*,*) ""
        
        ! Allocate bitmaps
        allocate(stb_bitmap(bitmap_w * bitmap_h))
        allocate(forttf_bitmap(bitmap_w * bitmap_h))
        
        ! Initialize test bitmaps
        stb_bitmap = 0
        forttf_bitmap = 0
        
        write(*,*) ""
        
        ! Compare results - focus on problematic pixel (8,8)
        idx = 8 * bitmap_w + 8 + 1  ! Y=8, X=8
        stb_val = int(stb_bitmap(idx))
        forttf_val = int(forttf_bitmap(idx))
        if (stb_val < 0) stb_val = stb_val + 256
        if (forttf_val < 0) forttf_val = forttf_val + 256
        
        write(*,'(A,I0,A,I0,A,I0)') "Critical pixel (8,8): STB=", stb_val, " ForTTF=", forttf_val, &
                                    " diff=", forttf_val - stb_val
        
        ! Count total differences
        diff_count = 0
        do i = 1, bitmap_w * bitmap_h
            stb_val = int(stb_bitmap(i))
            forttf_val = int(forttf_bitmap(i))
            if (stb_val < 0) stb_val = stb_val + 256
            if (forttf_val < 0) forttf_val = forttf_val + 256
            if (stb_val /= forttf_val) diff_count = diff_count + 1
        end do
        
        write(*,'(A,I0,A,I0,A,F5.1,A)') "Total differences: ", diff_count, " / ", &
                                        bitmap_w * bitmap_h, " (", &
                                        real(diff_count) * 100.0 / real(bitmap_w * bitmap_h), "%)"
        
        ! Show first few differences for analysis
        write(*,*) ""
        write(*,*) "First 10 differences:"
        diff_count = 0
        do j = 0, bitmap_h-1
            do i = 0, bitmap_w-1
                idx = j * bitmap_w + i + 1
                stb_val = int(stb_bitmap(idx))
                forttf_val = int(forttf_bitmap(idx))
                if (stb_val < 0) stb_val = stb_val + 256
                if (forttf_val < 0) forttf_val = forttf_val + 256
                
                if (stb_val /= forttf_val) then
                    diff_count = diff_count + 1
                    write(*,'(A,I0,A,I0,A,I0,A,I0,A,I0,A)') &
                        "  (", i, ",", j, ") STB=", stb_val, " ForTTF=", forttf_val, &
                        " diff=", forttf_val - stb_val
                    if (diff_count >= 10) exit
                end if
            end do
            if (diff_count >= 10) exit
        end do
        
        deallocate(stb_bitmap, forttf_bitmap)
        
    end subroutine compare_same_glyph_different_implementations
    
    subroutine get_glyph_vertices(font_path, glyph_index, num_vertices, result_code)
        !! Get glyph vertices using ForTTF parsing
        character(len=*), intent(in) :: font_path
        integer, intent(in) :: glyph_index
        integer, intent(out) :: num_vertices, result_code
        
        ! This would use the existing ForTTF glyph parsing
        ! For now, indicate that this needs implementation
        write(*,*) "Note: get_glyph_vertices needs implementation to extract"
        write(*,*) "      vertices using same path as bitmap export test"
        
        ! Placeholder to prevent compilation errors
        num_vertices = 10
        result_code = 1  ! Indicate not implemented
        
    end subroutine get_glyph_vertices
    
    subroutine rasterize_with_stb(width, height, bitmap)
        !! Rasterize using STB directly
        integer, intent(in) :: width, height
        integer(c_int8_t), intent(out) :: bitmap(:)
        
        ! This would call STB rasterization directly
        write(*,*) "Note: rasterize_with_stb needs STB wrapper implementation"
        bitmap = 0  ! Placeholder
        
    end subroutine rasterize_with_stb
    
    subroutine rasterize_with_forttf(width, height, bitmap)
        !! Rasterize using ForTTF
        integer, intent(in) :: width, height
        integer(c_int8_t), intent(out) :: bitmap(:)
        
        ! This would call ForTTF rasterization
        write(*,*) "Note: rasterize_with_forttf needs implementation"
        bitmap = 0  ! Placeholder
        
    end subroutine rasterize_with_forttf

end program test_direct_stb_comparison