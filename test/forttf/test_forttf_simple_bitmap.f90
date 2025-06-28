program test_simple_bitmap
    !! Simple test to verify bitmap creation works
    use test_forttf_utils
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_basic_bitmap_creation()

contains

    subroutine test_basic_bitmap_creation()
        !! Test that we can create a basic bitmap with non-zero content
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: pure_success, font_found
        
        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.5_wp  ! Larger scale
        
        ! Pure Fortran variables  
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        
        ! Bitmap data
        integer(c_int8_t), pointer :: pure_bitmap(:)
        integer :: i, total_pixels, non_zero_count
        
        write(*,*) "=== Testing Basic Bitmap Creation ==="
        
        ! Find a working font
        call discover_system_fonts_simple(font_path, font_found)
        if (.not. font_found) then
            write(*,*) "❌ No fonts found - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)
        
        ! Initialize Pure Fortran font
        pure_success = stb_init_font_pure(pure_font, font_path)
        if (.not. pure_success) then
            write(*,*) "❌ Failed to initialize Pure Fortran font"
            return
        end if
        
        ! Get Pure Fortran bitmap for 'A' with larger scale
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint_a, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        if (.not. c_associated(pure_bitmap_ptr)) then
            write(*,*) "❌ Pure Fortran failed to render 'A'"
            call stb_cleanup_font_pure(pure_font)
            return
        end if
        
        write(*,*) "✅ Created bitmap: ", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff
        
        ! Convert C pointer to Fortran array
        total_pixels = pure_width * pure_height
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [total_pixels])
        
        ! Count non-zero pixels
        non_zero_count = 0
        do i = 1, total_pixels
            if (pure_bitmap(i) /= 0) then
                non_zero_count = non_zero_count + 1
            end if
        end do
        
        write(*,*) "✅ Non-zero pixels:", non_zero_count, "out of", total_pixels
        if (total_pixels > 0) then
            write(*,*) "   First 10 pixel values:", (int(pure_bitmap(i)), i=1,min(10,total_pixels))
        end if
        
        if (non_zero_count > 0) then
            write(*,*) "✅ SUCCESS: Bitmap contains rendered content!"
        else
            write(*,*) "❌ FAILURE: Bitmap is all zeros"
        end if
        
        ! Cleanup
        if (c_associated(pure_bitmap_ptr)) call stb_free_bitmap_pure(pure_bitmap_ptr)
        call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_basic_bitmap_creation

    subroutine discover_system_fonts_simple(font_path, found)
        !! Simple font discovery for testing
        character(len=256), intent(out) :: font_path
        logical, intent(out) :: found
        
        character(len=256) :: candidates(5)
        logical :: exists
        integer :: i
        
        candidates(1) = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        candidates(2) = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
        candidates(3) = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        candidates(4) = "/System/Library/Fonts/Arial.ttf"
        candidates(5) = "/System/Library/Fonts/Helvetica.ttc"
        
        found = .false.
        do i = 1, size(candidates)
            inquire(file=trim(candidates(i)), exist=exists)
            if (exists) then
                font_path = candidates(i)
                found = .true.
                return
            end if
        end do
        
    end subroutine discover_system_fonts_simple

end program test_simple_bitmap