program test_forttf_bitmap_export
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none


    call test_export_bitmaps()

contains

    subroutine test_export_bitmaps()
        !! Export STB and Pure Fortran bitmaps for visual analysis
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        integer, parameter :: codepoint_dollar = 36  ! '$' character
        real(wp), parameter :: scale = 0.02_wp

        ! STB C variables
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:)

        ! Pure Fortran variables
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: pure_bitmap(:)

        ! Analysis variables
        integer :: total_pixels, i, j, pixel_idx, stb_val, pure_val

        write(*,*) "=== Exporting STB vs Pure Fortran Bitmaps ==="

        ! Find and initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)

        ! Get STB C bitmap
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint_dollar, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        if (.not. c_associated(stb_bitmap_ptr)) then
            write(*,*) "❌ STB C failed to render '$'"
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        ! Get Pure Fortran bitmap
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint_dollar, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        if (.not. c_associated(pure_bitmap_ptr)) then
            write(*,*) "❌ Pure Fortran failed to render '$'"
            call stb_free_bitmap(stb_bitmap_ptr)
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        write(*,*) "--- Bitmap Dimensions ---"
        write(*,*) "STB:  ", stb_width, "x", stb_height, " offset:", stb_xoff, stb_yoff
        write(*,*) "Pure: ", pure_width, "x", pure_height, " offset:", pure_xoff, pure_yoff

        ! Verify dimensions match
        if (stb_width /= pure_width .or. stb_height /= pure_height .or. &
            stb_xoff /= pure_xoff .or. stb_yoff /= pure_yoff) then
            write(*,*) "❌ DIMENSIONS MISMATCH - Cannot export bitmaps"
            call stb_free_bitmap(stb_bitmap_ptr)
            call stb_free_bitmap_pure(pure_bitmap_ptr)
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        ! Convert to arrays for processing
        total_pixels = stb_width * stb_height
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [total_pixels])
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [total_pixels])

        ! Export STB bitmap as PGM (Portable Grayscale Map)
        open(unit=10, file='stb_bitmap.pgm', status='replace')
        write(10, '(A)') 'P2'
        write(10, '(I0, 1X, I0)') stb_width, stb_height
        write(10, '(A)') '255'
        pixel_idx = 1
        do j = 1, stb_height
            do i = 1, stb_width
                stb_val = int(stb_bitmap(pixel_idx))
                write(10, '(I0, 1X)', advance='no') stb_val
                pixel_idx = pixel_idx + 1
            end do
            write(10, *)  ! newline
        end do
        close(10)

        ! Export Pure Fortran bitmap as PGM
        open(unit=11, file='pure_bitmap.pgm', status='replace')
        write(11, '(A)') 'P2'
        write(11, '(I0, 1X, I0)') pure_width, pure_height
        write(11, '(A)') '255'
        pixel_idx = 1
        do j = 1, pure_height
            do i = 1, pure_width
                pure_val = int(pure_bitmap(pixel_idx))
                write(11, '(I0, 1X)', advance='no') pure_val
                pixel_idx = pixel_idx + 1
            end do
            write(11, *)  ! newline
        end do
        close(11)

        ! Export difference bitmap as PGM
        open(unit=12, file='diff_bitmap.pgm', status='replace')
        write(12, '(A)') 'P2'
        write(12, '(I0, 1X, I0)') stb_width, stb_height
        write(12, '(A)') '255'
        pixel_idx = 1
        do j = 1, stb_height
            do i = 1, stb_width
                stb_val = int(stb_bitmap(pixel_idx))
                pure_val = int(pure_bitmap(pixel_idx))
                ! Map difference to visible range: -255 to +255 -> 0 to 255
                ! Neutral gray (128) = no difference
                write(12, '(I0, 1X)', advance='no') min(255, max(0, 128 + (pure_val - stb_val)/2))
                pixel_idx = pixel_idx + 1
            end do
            write(12, *)  ! newline
        end do
        close(12)

        write(*,*) "✅ Exported bitmap files:"
        write(*,*) "   - stb_bitmap.pgm (STB reference)"
        write(*,*) "   - pure_bitmap.pgm (Pure Fortran implementation)"
        write(*,*) "   - diff_bitmap.pgm (difference visualization)"
        write(*,*) "📋 Use an image viewer to open these PGM files for visual comparison"

        ! Clean up
        call stb_free_bitmap(stb_bitmap_ptr)
        call stb_free_bitmap_pure(pure_bitmap_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)

    end subroutine test_export_bitmaps

end program test_forttf_bitmap_export
