program test_forttf_trace_stb_full_pipeline
    !! Trace the complete STB bitmap export pipeline to find what produces final=114
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call trace_complete_stb_pipeline()

contains

    subroutine trace_complete_stb_pipeline()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        ! Test parameters - same as bitmap export test
        integer, parameter :: codepoint = 36  ! Character '$' (as used in bitmap export test)
        real(wp), parameter :: scale = 0.02_wp
        integer, parameter :: debug_row = 5, debug_col = 8
        
        ! STB C bitmap variables
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:)
        
        ! ForTTF bitmap variables
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: pure_bitmap(:)
        
        integer :: pixel_index, stb_pixel, pure_pixel
        
        write(*,*) '=== TRACING COMPLETE STB BITMAP PIPELINE ==='
        write(*,*) 'Goal: Find what produces final=114 for Row 5, Col 8'
        write(*,*)
        
        ! Find and initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*) 'Rendering character $ (codepoint=36) at scale=0.02'
        write(*,*)
        
        ! Generate STB C bitmap
        write(*,*) '=== STB C BITMAP GENERATION ==='
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        
        if (.not. c_associated(stb_bitmap_ptr)) then
            write(*,*) 'ERROR: STB C failed to render A'
            return
        end if
        
        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])
        
        write(*,'(A,I0,A,I0)') 'STB bitmap size: ', stb_width, 'x', stb_height
        write(*,'(A,I0,A,I0)') 'STB offset: (', stb_xoff, ',', stb_yoff, ')'
        write(*,*)
        
        ! Generate ForTTF bitmap
        write(*,*) '=== ForTTF BITMAP GENERATION ==='
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint, &
                                                        pure_width, pure_height, pure_xoff, pure_yoff)
        
        if (.not. c_associated(pure_bitmap_ptr)) then
            write(*,*) 'ERROR: ForTTF failed to render A'
            call stb_free_bitmap(stb_bitmap_ptr)
            return
        end if
        
        call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [pure_width * pure_height])
        
        write(*,'(A,I0,A,I0)') 'ForTTF bitmap size: ', pure_width, 'x', pure_height
        write(*,'(A,I0,A,I0)') 'ForTTF offset: (', pure_xoff, ',', pure_yoff, ')'
        write(*,*)
        
        ! Analyze the critical pixel (Row 5, Col 8)
        write(*,*) '=== CRITICAL PIXEL ANALYSIS ==='
        write(*,'(A,I0,A,I0,A)') 'Analyzing Row ', debug_row, ', Col ', debug_col, ':'
        write(*,*)
        
        ! Calculate pixel indices (convert from 0-based to 1-based indexing)
        if (debug_row < stb_height .and. debug_col < stb_width) then
            pixel_index = debug_row * stb_width + debug_col + 1  ! 1-based for Fortran
            stb_pixel = int(stb_bitmap(pixel_index))
            if (stb_pixel < 0) stb_pixel = stb_pixel + 256  ! Convert signed to unsigned
            
            write(*,'(A,I0)') 'STB pixel value = ', stb_pixel
        else
            write(*,*) 'STB: Pixel out of bounds'
            stb_pixel = -1
        end if
        
        if (debug_row < pure_height .and. debug_col < pure_width) then
            pixel_index = debug_row * pure_width + debug_col + 1  ! 1-based for Fortran
            pure_pixel = int(pure_bitmap(pixel_index))
            if (pure_pixel < 0) pure_pixel = pure_pixel + 256  ! Convert signed to unsigned
            
            write(*,'(A,I0)') 'ForTTF pixel value = ', pure_pixel
        else
            write(*,*) 'ForTTF: Pixel out of bounds'
            pure_pixel = -1
        end if
        
        write(*,*)
        write(*,*) 'COMPARISON:'
        write(*,'(A,I0)') 'Expected value = 114'
        if (stb_pixel >= 0) then
            write(*,'(A,I0,A)') 'STB actual = ', stb_pixel, &
                merge(' ✓', ' ✗', stb_pixel == 114)
        end if
        if (pure_pixel >= 0) then
            write(*,'(A,I0,A)') 'ForTTF actual = ', pure_pixel, &
                merge(' ✓', ' ✗', pure_pixel == 114)
        end if
        
        if (stb_pixel >= 0 .and. pure_pixel >= 0) then
            write(*,'(A,I0)') 'Difference = ', abs(stb_pixel - pure_pixel)
        end if
        
        write(*,*)
        
        ! Show surrounding pixels for context
        write(*,*) '=== SURROUNDING PIXELS (3x3 context) ==='
        call show_pixel_context(stb_bitmap, stb_width, stb_height, debug_row, debug_col, 'STB')
        write(*,*)
        call show_pixel_context(pure_bitmap, pure_width, pure_height, debug_row, debug_col, 'ForTTF')
        
        write(*,*)
        write(*,*) '=== CONCLUSION ==='
        if (stb_pixel == 114) then
            write(*,*) 'SUCCESS: STB produces the expected value 114'
            write(*,*) 'The STB bitmap generation is working correctly'
            if (pure_pixel /= 114) then
                write(*,*) 'The issue is in ForTTF rasterization pipeline'
            end if
        else if (stb_pixel >= 0) then
            write(*,'(A,I0,A)') 'UNEXPECTED: STB produces ', stb_pixel, ' instead of expected 114'
            write(*,*) 'This suggests the expected value might be wrong'
        else
            write(*,*) 'ERROR: Cannot analyze - pixel out of bounds'
        end if
        
        ! Clean up
        call stb_free_bitmap(stb_bitmap_ptr)
        call stb_free_bitmap_pure(pure_bitmap_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine trace_complete_stb_pipeline
    
    subroutine show_pixel_context(bitmap, width, height, center_row, center_col, label)
        integer(c_int8_t), intent(in) :: bitmap(:)
        integer, intent(in) :: width, height, center_row, center_col
        character(len=*), intent(in) :: label
        
        integer :: r, c, pixel_idx, pixel_val
        
        write(*,'(A,A,A)') label, ' pixels (Row ', merge('5', '?', center_row == 5), '):'
        do r = center_row - 1, center_row + 1
            do c = center_col - 1, center_col + 1
                if (r >= 0 .and. r < height .and. c >= 0 .and. c < width) then
                    pixel_idx = r * width + c + 1  ! 1-based indexing
                    pixel_val = int(bitmap(pixel_idx))
                    if (pixel_val < 0) pixel_val = pixel_val + 256
                    write(*,'(I3,1X)', advance='no') pixel_val
                else
                    write(*,'(A,1X)', advance='no') '---'
                end if
            end do
            write(*,*)
        end do
        
    end subroutine show_pixel_context

end program test_forttf_trace_stb_full_pipeline