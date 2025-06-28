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
        real(wp), parameter :: scale = 0.5_wp
        
        ! STB variables
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        
        ! Pure Fortran variables  
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        
        ! Bitmap data
        integer(c_int8_t), pointer :: stb_bitmap(:), pure_bitmap(:)
        logical :: content_matches
        integer :: i, total_pixels, stb_nonzero, pure_nonzero
        
        write(*,*) "=== Testing Letter 'A' Bitmap Content ==="
        
        ! Try multiple common font paths for cross-distribution compatibility
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize test fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)
        
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
        
        ! Show dimensions and check if they match
        write(*,*) "   STB dimensions:", stb_width, "x", stb_height, " offset:", stb_xoff, stb_yoff  
        write(*,*) "   Pure dimensions:", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff
        
        if (stb_width /= pure_width .or. stb_height /= pure_height) then
            write(*,*) "❌ Bitmap dimensions mismatch - continuing anyway for comparison"
        end if
        
        ! Convert C pointers to Fortran arrays (use minimum dimensions for safety)
        total_pixels = min(stb_width * stb_height, pure_width * pure_height)
        if (total_pixels <= 0) then
            write(*,*) "❌ Invalid bitmap dimensions"
            error stop 1
        end if
        
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [pure_width * pure_height])
        
        ! Count non-zero pixels in each bitmap
        stb_nonzero = 0
        pure_nonzero = 0
        do i = 1, min(stb_width * stb_height, 10000)  ! Check first 10000 pixels
            if (stb_bitmap(i) /= 0) stb_nonzero = stb_nonzero + 1
        end do
        do i = 1, min(pure_width * pure_height, 10000)  ! Check first 10000 pixels  
            if (pure_bitmap(i) /= 0) pure_nonzero = pure_nonzero + 1
        end do
        write(*,*) "   STB non-zero pixels:", stb_nonzero
        write(*,*) "   Pure non-zero pixels:", pure_nonzero
        
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