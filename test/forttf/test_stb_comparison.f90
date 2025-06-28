program test_stb_comparison
    !! Comprehensive test comparing STB and Pure Fortran implementations function by function
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_all_functions_comparison()

contains

    subroutine test_all_functions_comparison()
        !! Test every function against STB equivalent to find differences
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.5_wp
        
        write(*,*) "=== STB vs Pure Fortran Function Comparison ==="
        
        ! Initialize both fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)
        
        ! Test basic font properties
        call test_font_properties(stb_font, pure_font)
        
        ! Test glyph index lookup
        call test_glyph_index(stb_font, pure_font, codepoint_a)
        
        ! Test glyph metrics
        call test_glyph_metrics(stb_font, pure_font, codepoint_a)
        
        ! Test glyph bounding box
        call test_glyph_box(stb_font, pure_font, codepoint_a)
        
        ! Test bitmap bounding box
        call test_bitmap_box(stb_font, pure_font, codepoint_a, scale)
        
        ! Test glyph outline vertices (Pure only for now)
        call test_glyph_vertices(pure_font, codepoint_a)
        
        ! Test actual bitmap rendering
        call test_bitmap_rendering(stb_font, pure_font, codepoint_a, scale)
        
        ! Cleanup
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_all_functions_comparison
    
    subroutine test_font_properties(stb_font, pure_font)
        !! Compare font-level properties
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        
        integer :: stb_ascent, stb_descent, stb_linegap
        integer :: pure_ascent, pure_descent, pure_linegap
        
        write(*,*) "--- Font Properties ---"
        
        ! Get vertical metrics
        call stb_get_font_vmetrics(stb_font, stb_ascent, stb_descent, stb_linegap)
        call stb_get_font_vmetrics_pure(pure_font, pure_ascent, pure_descent, pure_linegap)
        
        write(*,*) "Font vertical metrics:"
        write(*,*) "  STB:  ascent=", stb_ascent, " descent=", stb_descent, " linegap=", stb_linegap
        write(*,*) "  Pure: ascent=", pure_ascent, " descent=", pure_descent, " linegap=", pure_linegap
        
        if (stb_ascent == pure_ascent .and. stb_descent == pure_descent .and. stb_linegap == pure_linegap) then
            write(*,*) "✅ Font vertical metrics match"
        else
            write(*,*) "❌ Font vertical metrics differ"
        end if
        
    end subroutine test_font_properties
    
    subroutine test_glyph_index(stb_font, pure_font, codepoint)
        !! Compare glyph index lookup
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        
        integer :: stb_index, pure_index
        
        write(*,*) "--- Glyph Index Lookup ---"
        
        stb_index = stb_find_glyph_index(stb_font, codepoint)
        pure_index = stb_find_glyph_index_pure(pure_font, codepoint)
        
        write(*,*) "Glyph index for codepoint", codepoint, ":"
        write(*,*) "  STB: ", stb_index
        write(*,*) "  Pure:", pure_index
        
        if (stb_index == pure_index) then
            write(*,*) "✅ Glyph indices match"
        else
            write(*,*) "❌ Glyph indices differ"
        end if
        
    end subroutine test_glyph_index
    
    subroutine test_glyph_metrics(stb_font, pure_font, codepoint)
        !! Compare glyph horizontal metrics
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        
        integer :: stb_advanceWidth, stb_leftSideBearing
        integer :: pure_advanceWidth, pure_leftSideBearing
        
        write(*,*) "--- Glyph Horizontal Metrics ---"
        
        call stb_get_codepoint_hmetrics(stb_font, codepoint, stb_advanceWidth, stb_leftSideBearing)
        call stb_get_codepoint_hmetrics_pure(pure_font, codepoint, pure_advanceWidth, pure_leftSideBearing)
        
        write(*,*) "Horizontal metrics for codepoint", codepoint, ":"
        write(*,*) "  STB:  advanceWidth=", stb_advanceWidth, " leftSideBearing=", stb_leftSideBearing
        write(*,*) "  Pure: advanceWidth=", pure_advanceWidth, " leftSideBearing=", pure_leftSideBearing
        
        if (stb_advanceWidth == pure_advanceWidth .and. stb_leftSideBearing == pure_leftSideBearing) then
            write(*,*) "✅ Glyph horizontal metrics match"
        else
            write(*,*) "❌ Glyph horizontal metrics differ"
        end if
        
    end subroutine test_glyph_metrics
    
    subroutine test_glyph_box(stb_font, pure_font, codepoint)
        !! Compare glyph bounding box
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        
        integer :: stb_x0, stb_y0, stb_x1, stb_y1
        integer :: pure_x0, pure_y0, pure_x1, pure_y1
        
        write(*,*) "--- Glyph Bounding Box ---"
        
        call stb_get_codepoint_box(stb_font, codepoint, stb_x0, stb_y0, stb_x1, stb_y1)
        call stb_get_codepoint_box_pure(pure_font, codepoint, pure_x0, pure_y0, pure_x1, pure_y1)
        
        write(*,*) "Bounding box for codepoint", codepoint, ":"
        write(*,*) "  STB:  (", stb_x0, ",", stb_y0, ") to (", stb_x1, ",", stb_y1, ")"
        write(*,*) "  Pure: (", pure_x0, ",", pure_y0, ") to (", pure_x1, ",", pure_y1, ")"
        
        if (stb_x0 == pure_x0 .and. stb_y0 == pure_y0 .and. stb_x1 == pure_x1 .and. stb_y1 == pure_y1) then
            write(*,*) "✅ Glyph bounding boxes match"
        else
            write(*,*) "❌ Glyph bounding boxes differ"
        end if
        
    end subroutine test_glyph_box
    
    subroutine test_bitmap_box(stb_font, pure_font, codepoint, scale)
        !! Compare bitmap bounding box
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale
        
        integer :: stb_ix0, stb_iy0, stb_ix1, stb_iy1
        integer :: pure_ix0, pure_iy0, pure_ix1, pure_iy1
        
        write(*,*) "--- Bitmap Bounding Box ---"
        
        call stb_get_codepoint_bitmap_box(stb_font, codepoint, scale, scale, stb_ix0, stb_iy0, stb_ix1, stb_iy1)
        call stb_get_codepoint_bitmap_box_pure(pure_font, codepoint, scale, scale, pure_ix0, pure_iy0, pure_ix1, pure_iy1)
        
        write(*,*) "Bitmap box for codepoint", codepoint, " at scale", scale, ":"
        write(*,*) "  STB:  (", stb_ix0, ",", stb_iy0, ") to (", stb_ix1, ",", stb_iy1, ")"
        write(*,*) "  Pure: (", pure_ix0, ",", pure_iy0, ") to (", pure_ix1, ",", pure_iy1, ")"
        write(*,*) "  STB dimensions: ", stb_ix1 - stb_ix0, "x", stb_iy1 - stb_iy0
        write(*,*) "  Pure dimensions:", pure_ix1 - pure_ix0, "x", pure_iy1 - pure_iy0
        
        if (stb_ix0 == pure_ix0 .and. stb_iy0 == pure_iy0 .and. stb_ix1 == pure_ix1 .and. stb_iy1 == pure_iy1) then
            write(*,*) "✅ Bitmap bounding boxes match"
        else
            write(*,*) "❌ Bitmap bounding boxes differ"
        end if
        
    end subroutine test_bitmap_box
    
    subroutine test_glyph_vertices(pure_font, codepoint)
        !! Test glyph outline vertices (Pure Fortran only)
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        
        type(ttf_vertex_t), allocatable :: vertices(:)
        integer :: num_vertices, i
        
        write(*,*) "--- Glyph Outline Vertices ---"
        
        num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint, vertices)
        
        write(*,*) "Outline vertices for codepoint", codepoint, ":"
        write(*,*) "  Number of vertices:", num_vertices
        
        if (num_vertices > 0) then
            write(*,*) "  First 5 vertices:"
            do i = 1, min(5, num_vertices)
                write(*,*) "    ", i, ": type=", vertices(i)%type, " x=", vertices(i)%x, " y=", vertices(i)%y
            end do
        end if
        
        ! Cleanup
        if (allocated(vertices)) call stb_free_shape_pure(vertices)
        
    end subroutine test_glyph_vertices
    
    subroutine test_bitmap_rendering(stb_font, pure_font, codepoint, scale)
        !! Compare actual bitmap rendering
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale
        
        type(c_ptr) :: stb_bitmap_ptr, pure_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:), pure_bitmap(:)
        integer :: stb_nonzero, pure_nonzero, i
        
        write(*,*) "--- Bitmap Rendering ---"
        
        ! Get STB bitmap
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        
        ! Get Pure bitmap  
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        
        write(*,*) "Bitmap rendering for codepoint", codepoint, " at scale", scale, ":"
        write(*,*) "  STB bitmap:", stb_width, "x", stb_height, " offset:", stb_xoff, stb_yoff
        write(*,*) "  Pure bitmap:", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff
        
        if (.not. c_associated(stb_bitmap_ptr)) then
            write(*,*) "  ❌ STB bitmap is null"
        else
            call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])
            stb_nonzero = 0
            do i = 1, min(stb_width * stb_height, 10000)
                if (stb_bitmap(i) /= 0) stb_nonzero = stb_nonzero + 1
            end do
            write(*,*) "  STB non-zero pixels (first 10k):", stb_nonzero
        end if
        
        if (.not. c_associated(pure_bitmap_ptr)) then
            write(*,*) "  ❌ Pure bitmap is null"
        else
            call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [pure_width * pure_height])
            pure_nonzero = 0
            do i = 1, min(pure_width * pure_height, 10000)
                if (pure_bitmap(i) /= 0) pure_nonzero = pure_nonzero + 1
            end do
            write(*,*) "  Pure non-zero pixels (first 10k):", pure_nonzero
        end if
        
        if (c_associated(stb_bitmap_ptr) .and. c_associated(pure_bitmap_ptr)) then
            if (stb_nonzero > 0 .and. pure_nonzero > 0) then
                write(*,*) "✅ Both bitmaps have content"
            else if (stb_nonzero > 0 .and. pure_nonzero == 0) then
                write(*,*) "❌ STB has content but Pure is empty"
            else if (stb_nonzero == 0 .and. pure_nonzero > 0) then
                write(*,*) "❌ Pure has content but STB is empty"
            else
                write(*,*) "❌ Both bitmaps are empty"
            end if
        end if
        
        ! Cleanup
        if (c_associated(stb_bitmap_ptr)) call stb_free_bitmap(stb_bitmap_ptr)
        if (c_associated(pure_bitmap_ptr)) call stb_free_bitmap_pure(pure_bitmap_ptr)
        
    end subroutine test_bitmap_rendering

end program test_stb_comparison