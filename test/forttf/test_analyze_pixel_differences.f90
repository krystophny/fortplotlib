program test_analyze_pixel_differences
    !! Analyze exact pixel differences between STB and ForTTF to find the root cause
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call analyze_differences()

contains

    subroutine analyze_differences()
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
        integer :: diff_count, max_diff, sum_diff
        integer :: diff_histogram(-255:255)
        
        write(*,*) "=== Analyzing Pixel Differences STB vs ForTTF ==="

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
        
        ! Analyze differences
        diff_count = 0
        max_diff = 0
        sum_diff = 0
        diff_histogram = 0
        
        write(*,*) "--- Detailed Pixel Differences ---"
        write(*,*) "Format: (x,y) STB→Pure (difference)"
        
        do j = 1, stb_height
            do i = 1, stb_width
                idx = (j-1) * stb_width + i
                stb_val = int(stb_bitmap(idx))
                pure_val = int(pure_bitmap(idx))
                
                ! Convert signed to unsigned for display
                if (stb_val < 0) stb_val = stb_val + 256
                if (pure_val < 0) pure_val = pure_val + 256
                
                diff = pure_val - stb_val
                
                if (diff /= 0) then
                    diff_count = diff_count + 1
                    sum_diff = sum_diff + abs(diff)
                    if (abs(diff) > max_diff) max_diff = abs(diff)
                    diff_histogram(diff) = diff_histogram(diff) + 1
                    
                    ! Print first 10 differences for analysis
                    if (diff_count <= 10) then
                        write(*,'(A,I2,A,I2,A,I3,A,I3,A,I4,A)') &
                            "(", i-1, ",", j-1, ") ", stb_val, "→", pure_val, " (", diff, ")"
                    end if
                end if
            end do
        end do
        
        write(*,*) ""
        write(*,*) "--- Difference Summary ---"
        write(*,'(A,I0,A,I0,A,F5.1,A)') "Total differences: ", diff_count, " / ", &
            stb_width*stb_height, " pixels (", 100.0*diff_count/(stb_width*stb_height), "%)"
        write(*,'(A,I0)') "Maximum difference: ±", max_diff
        write(*,'(A,F6.2)') "Average difference: ", real(sum_diff)/real(max(1,diff_count))
        
        write(*,*) ""
        write(*,*) "--- Difference Distribution ---"
        do i = -255, 255
            if (diff_histogram(i) > 0) then
                write(*,'(A,I4,A,I4,A)') "Difference ", i, ": ", diff_histogram(i), " pixels"
            end if
        end do
        
        ! Clean up
        call stb_free_bitmap(stb_bitmap_ptr)
        call stb_free_bitmap_pure(pure_bitmap_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine analyze_differences

end program test_analyze_pixel_differences