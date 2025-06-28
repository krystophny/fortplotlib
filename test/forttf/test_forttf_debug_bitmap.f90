program test_debug_bitmap
    !! Debug test to understand bitmap rendering pipeline
    use test_forttf_utils
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call debug_bitmap_pipeline()

contains

    subroutine debug_bitmap_pipeline()
        !! Debug the entire bitmap rendering pipeline step by step
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: pure_success, font_found
        
        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.5_wp
        
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: pure_bitmap(:)
        integer :: total_pixels, non_zero_count, i
        
        type(ttf_vertex_t), allocatable :: vertices(:)
        integer :: num_vertices, glyph_index
        
        write(*,*) "=== Debug Bitmap Pipeline ==="
        
        ! Find font
        call discover_system_fonts_simple(font_path, font_found)
        if (.not. font_found) then
            write(*,*) "❌ No fonts found"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)
        
        ! Initialize font
        pure_success = stb_init_font_pure(pure_font, font_path)
        if (.not. pure_success) then
            write(*,*) "❌ Failed to initialize font"
            return
        end if
        write(*,*) "✅ Font initialized"
        
        ! Test glyph index lookup
        glyph_index = stb_find_glyph_index_pure(pure_font, codepoint_a)
        write(*,*) "✅ Glyph index for 'A':", glyph_index
        
        ! Test vertex parsing
        num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint_a, vertices)
        write(*,*) "✅ Vertices parsed:", num_vertices
        if (num_vertices > 0) then
            write(*,*) "   First vertex: type=", vertices(1)%type, "x=", vertices(1)%x, "y=", vertices(1)%y
        end if
        
        ! Test bitmap creation
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint_a, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        write(*,*) "✅ Bitmap created:", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff
        
        if (.not. c_associated(pure_bitmap_ptr)) then
            write(*,*) "❌ Bitmap pointer is null"
        else
            ! Check bitmap content
            total_pixels = pure_width * pure_height
            call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [total_pixels])
            
            non_zero_count = 0
            do i = 1, min(total_pixels, 50000)  ! Check first 50k pixels
                if (pure_bitmap(i) /= 0) then
                    non_zero_count = non_zero_count + 1
                end if
            end do
            
            write(*,*) "✅ Non-zero pixels in first 50k:", non_zero_count
            write(*,*) "   First 20 pixel values:", (int(pure_bitmap(i)), i=1,min(20,total_pixels))
        end if
        
        ! Cleanup
        if (allocated(vertices)) call stb_free_shape_pure(vertices)
        if (c_associated(pure_bitmap_ptr)) call stb_free_bitmap_pure(pure_bitmap_ptr)
        call stb_cleanup_font_pure(pure_font)
        
    end subroutine debug_bitmap_pipeline

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

end program test_debug_bitmap