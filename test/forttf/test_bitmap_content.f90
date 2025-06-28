program test_bitmap_content
    !! Test that verifies actual bitmap content (not just dimensions)
    !! This test should FAIL until real glyph rendering is implemented
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_letter_a_bitmap_content()

contains

    subroutine test_letter_a_bitmap_content()
        !! Test that letter 'A' produces actual text bitmap, not placeholder shape
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.1_wp
        
        ! STB variables
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        
        ! Pure Fortran variables  
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        
        ! Bitmap data
        integer(c_int8_t), pointer :: stb_bitmap(:), pure_bitmap(:)
        logical :: content_matches
        integer :: i, total_pixels
        
        write(*,*) "=== Testing Letter 'A' Bitmap Content ==="
        
        ! Use a default test font path
        font_path = "/usr/share/fonts/TTF/DejaVuSerif.ttf"
        if (.not. init_both_fonts(font_path, stb_font, pure_font, stb_success, pure_success)) then
            write(*,*) "❌ Failed to initialize test fonts - skipping test"
            return
        end if
        
        ! Get STB bitmap for 'A'
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint_a, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        if (.not. c_associated(stb_bitmap_ptr)) then
            write(*,*) "❌ STB failed to render 'A'"
            error stop 1
        end if
        
        ! Get Pure Fortran bitmap for 'A'
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint_a, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        if (.not. c_associated(pure_bitmap_ptr)) then
            write(*,*) "❌ Pure Fortran failed to render 'A'"
            error stop 1
        end if
        
        ! Check dimensions match
        if (stb_width /= pure_width .or. stb_height /= pure_height) then
            write(*,*) "❌ Bitmap dimensions mismatch"
            write(*,*) "   STB:", stb_width, "x", stb_height
            write(*,*) "   Pure:", pure_width, "x", pure_height
            error stop 1
        end if
        
        ! Convert C pointers to Fortran arrays
        total_pixels = stb_width * stb_height
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [total_pixels])
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [total_pixels])
        
        ! Compare bitmap content pixel by pixel
        content_matches = .true.
        do i = 1, total_pixels
            if (abs(int(stb_bitmap(i)) - int(pure_bitmap(i))) > 5) then  ! Allow small differences
                content_matches = .false.
                exit
            end if
        end do
        
        if (content_matches) then
            write(*,*) "✅ Letter 'A' bitmap content matches STB reference"
        else
            write(*,*) "❌ Letter 'A' bitmap content does NOT match STB reference"
            write(*,*) "   This indicates placeholder shapes instead of real text"
            
            ! Output first few differing pixels for debugging
            write(*,*) "   First 10 pixel values:"
            write(*,*) "   STB:  ", (int(stb_bitmap(i)), i=1,min(10,total_pixels))
            write(*,*) "   Pure: ", (int(pure_bitmap(i)), i=1,min(10,total_pixels))
            
            error stop 1  ! This test SHOULD fail until real rendering is implemented
        end if
        
        ! Cleanup
        if (c_associated(stb_bitmap_ptr)) call stb_free_bitmap(stb_bitmap_ptr)
        if (c_associated(pure_bitmap_ptr)) call stb_free_bitmap_pure(pure_bitmap_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_letter_a_bitmap_content

end program test_bitmap_content