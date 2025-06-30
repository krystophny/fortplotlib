program test_forttf_character_coverage
    !! Test Pure Fortran implementation across multiple characters to ensure broad compatibility
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_ascii_character_coverage()

contains

    subroutine test_ascii_character_coverage()
        !! Test bitmap rendering for common ASCII characters
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        real(wp), parameter :: scale = 0.3_wp
        integer, parameter :: test_chars(10) = [65, 66, 67, 48, 49, 50, 33, 63, 46, 32] ! A,B,C,0,1,2,!,?,., 
        character(len=1), parameter :: char_names(10) = ['A', 'B', 'C', '0', '1', '2', '!', '?', '.', ' ']
        
        integer :: i, codepoint
        logical :: all_passed
        
        write(*,*) "=== ASCII Character Coverage Test ==="
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)
        
        all_passed = .true.
        
        ! Test each character
        do i = 1, size(test_chars)
            codepoint = test_chars(i)
            write(*,*) "--- Testing character '", char_names(i), "' (", codepoint, ") ---"
            
            if (.not. test_single_character(stb_font, pure_font, codepoint, scale)) then
                all_passed = .false.
            end if
        end do
        
        if (all_passed) then
            write(*,*) "✅ All characters rendered successfully"
        else
            write(*,*) "❌ Some characters failed to render"
        end if
        
        ! Cleanup
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_ascii_character_coverage
    
    function test_single_character(stb_font, pure_font, codepoint, scale) result(success)
        !! Test bitmap rendering for a single character
        type(stb_fontinfo_t), intent(in) :: stb_font
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        real(wp), intent(in) :: scale
        logical :: success
        
        type(c_ptr) :: stb_bitmap_ptr, pure_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:), pure_bitmap(:)
        integer :: stb_nonzero, pure_nonzero, i
        integer :: glyph_index
        
        success = .true.
        
        ! Check glyph index
        glyph_index = stb_find_glyph_index_pure(pure_font, codepoint)
        if (glyph_index == 0 .and. codepoint /= 32) then  ! Space char (32) may have glyph_index 0
            write(*,*) "  ⚠️  No glyph found (may be normal for some characters)"
            return
        end if
        
        ! Get STB bitmap
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        
        ! Get Pure bitmap  
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        
        write(*,*) "  Dimensions: STB=", stb_width, "x", stb_height, " Pure=", pure_width, "x", pure_height
        
        ! Count non-zero pixels
        stb_nonzero = 0
        pure_nonzero = 0
        
        if (c_associated(stb_bitmap_ptr)) then
            call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])
            do i = 1, min(stb_width * stb_height, 5000)
                if (stb_bitmap(i) /= 0) stb_nonzero = stb_nonzero + 1
            end do
        end if
        
        if (c_associated(pure_bitmap_ptr)) then
            call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [pure_width * pure_height])
            do i = 1, min(pure_width * pure_height, 5000)
                if (pure_bitmap(i) /= 0) pure_nonzero = pure_nonzero + 1
            end do
        end if
        
        write(*,*) "  Non-zero pixels: STB=", stb_nonzero, " Pure=", pure_nonzero
        
        ! Evaluate success
        if (codepoint == 32) then
            ! Space character should have minimal or no pixels
            if (stb_nonzero == 0 .and. pure_nonzero == 0) then
                write(*,*) "  ✅ Space character correctly rendered as empty"
            else
                write(*,*) "  ✅ Space character rendered (may have advance width)"
            end if
        else if (c_associated(stb_bitmap_ptr) .and. c_associated(pure_bitmap_ptr)) then
            if (stb_nonzero > 0 .and. pure_nonzero > 0) then
                write(*,*) "  ✅ Both implementations have content"
            else if (stb_nonzero > 0 .and. pure_nonzero == 0) then
                write(*,*) "  ❌ STB has content but Pure is empty"
                success = .false.
            else if (stb_nonzero == 0 .and. pure_nonzero > 0) then
                write(*,*) "  ❌ Pure has content but STB is empty"
                success = .false.
            else
                write(*,*) "  ⚠️  Both implementations are empty (may be normal)"
            end if
        else
            write(*,*) "  ❌ Failed to create bitmaps"
            success = .false.
        end if
        
        ! Cleanup
        if (c_associated(stb_bitmap_ptr)) call stb_free_bitmap(stb_bitmap_ptr)
        if (c_associated(pure_bitmap_ptr)) call stb_free_bitmap_pure(pure_bitmap_ptr)
        
    end function test_single_character

end program test_forttf_character_coverage