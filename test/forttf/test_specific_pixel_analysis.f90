program test_specific_pixel_analysis
    !! Analyze specific pixels with differences to identify algorithmic discrepancies
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call analyze_specific_different_pixels()

contains

    subroutine analyze_specific_different_pixels()
        !! Focus on first few pixels with differences to understand root cause
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        integer, parameter :: codepoint_dollar = 36  ! '$' character
        real(wp), parameter :: scale = 0.02_wp

        ! Bitmap variables
        type(c_ptr) :: stb_bitmap_ptr, pure_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:), pure_bitmap(:)
        
        integer :: i, j, idx, stb_val, pure_val, diff
        integer :: diff_count
        
        ! Known problematic pixels from previous analysis
        integer, parameter :: problem_pixels(10, 2) = reshape([ &
            8, 5,   & ! (8,5) STB→Pure difference
            14, 5,  & ! (14,5) 
            5, 6,   & ! (5,6)
            6, 6,   & ! (6,6) 
            17, 6,  & ! (17,6)
            2, 7,   & ! (2,7)
            3, 7,   & ! (3,7)
            2, 8,   & ! (2,8)
            8, 8,   & ! (8,8)
            14, 8   & ! (14,8)
        ], [10, 2])
        
        write(*,*) "=== Analyzing Specific Different Pixels ==="
        write(*,*) "Focus: First 10 pixels with differences to understand algorithmic cause"
        write(*,*) ""

        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts"
            return
        end if

        ! Get bitmaps
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint_dollar, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint_dollar, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        
        if (.not. c_associated(stb_bitmap_ptr) .or. .not. c_associated(pure_bitmap_ptr)) then
            write(*,*) "❌ Failed to render bitmaps"
            return
        end if
        
        ! Map C pointers to Fortran arrays
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [pure_width * pure_height])
        
        write(*,*) "--- Analyzing Specific Problem Pixels ---"
        write(*,*) "Format: (x,y) STB→Pure (difference) [analysis]"
        write(*,*) ""
        
        ! Analyze each known problem pixel
        do i = 1, 10
            j = problem_pixels(i, 1)  ! x coordinate
            idx = problem_pixels(i, 2)  ! y coordinate
            
            ! Convert (x,y) to linear index
            idx = idx * stb_width + j + 1
            
            if (idx <= stb_width * stb_height) then
                stb_val = int(stb_bitmap(idx))
                pure_val = int(pure_bitmap(idx))
                
                ! Convert signed to unsigned for display
                if (stb_val < 0) stb_val = stb_val + 256
                if (pure_val < 0) pure_val = pure_val + 256
                
                diff = pure_val - stb_val
                
                write(*,'(A,I2,A,I2,A,I3,A,I3,A,I4,A)') &
                    "(", j, ",", problem_pixels(i, 2), ") ", stb_val, "→", pure_val, " (", diff, ")"
                
                ! Analyze the pattern
                call analyze_pixel_context(j, problem_pixels(i, 2), stb_bitmap, pure_bitmap, stb_width, stb_height)
            end if
        end do
        
        write(*,*) ""
        write(*,*) "--- Key Observations ---"
        write(*,*) "1. Focus on edge intersection areas where antialiasing occurs"
        write(*,*) "2. Look for systematic bias in coverage calculation"
        write(*,*) "3. Identify if differences cluster around specific edge types"
        write(*,*) "4. Check for accumulation order differences in multi-edge regions"
        
        ! Clean up
        call stb_free_bitmap(stb_bitmap_ptr)
        call stb_free_bitmap_pure(pure_bitmap_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine analyze_specific_different_pixels
    
    subroutine analyze_pixel_context(x, y, stb_bitmap, pure_bitmap, width, height)
        !! Analyze the 3x3 context around a problem pixel
        integer, intent(in) :: x, y, width, height
        integer(c_int8_t), intent(in) :: stb_bitmap(:), pure_bitmap(:)
        
        integer :: i, j, idx, stb_val, pure_val
        
        write(*,*) "    Context (3x3 around problem pixel):"
        write(*,*) "    STB values:"
        do j = max(0, y-1), min(height-1, y+1)
            write(*,'(A)', advance='no') "      "
            do i = max(0, x-1), min(width-1, x+1)
                idx = j * width + i + 1
                stb_val = int(stb_bitmap(idx))
                if (stb_val < 0) stb_val = stb_val + 256
                write(*,'(I4)', advance='no') stb_val
            end do
            write(*,*)
        end do
        
        write(*,*) "    ForTTF values:"
        do j = max(0, y-1), min(height-1, y+1)
            write(*,'(A)', advance='no') "      "
            do i = max(0, x-1), min(width-1, x+1)
                idx = j * width + i + 1
                pure_val = int(pure_bitmap(idx))
                if (pure_val < 0) pure_val = pure_val + 256
                write(*,'(I4)', advance='no') pure_val
            end do
            write(*,*)
        end do
        write(*,*)
        
    end subroutine analyze_pixel_context

end program test_specific_pixel_analysis