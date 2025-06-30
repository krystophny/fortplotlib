program test_forttf_compare_edge_building
    !! Compare edge building between STB and ForTTF for character '$'
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_bitmap
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call compare_edge_building_process()

contains

    subroutine compare_edge_building_process()
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        ! Test parameters
        integer, parameter :: codepoint = 36  ! '$'
        real(wp), parameter :: scale = 0.02_wp
        
        write(*,*) '=== COMPARING EDGE BUILDING: STB vs ForTTF ==='
        write(*,*) 'Character: $ (codepoint=36), scale=0.02'
        write(*,*)
        
        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) 'ERROR: Failed to initialize fonts'
            return
        end if
        
        write(*,*) 'Using font:', trim(font_path)
        write(*,*)
        
        ! Generate STB bitmap - this shows the edge debug info from ForTTF
        write(*,*) '=== STB BITMAP GENERATION (reference) ==='
        block
            type(c_ptr) :: stb_bitmap_ptr
            integer :: stb_width, stb_height, stb_xoff, stb_yoff
            
            stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint, &
                                                     stb_width, stb_height, stb_xoff, stb_yoff)
            
            if (c_associated(stb_bitmap_ptr)) then
                write(*,'(A,I0,A,I0,A,I0,A,I0,A)') 'STB: ', stb_width, 'x', stb_height, &
                    ' offset(', stb_xoff, ',', stb_yoff, ')'
                call stb_free_bitmap(stb_bitmap_ptr)
            end if
        end block
        write(*,*)
        
        ! Generate ForTTF bitmap - this will show our debug edge info
        write(*,*) '=== ForTTF BITMAP GENERATION (shows edge debug) ==='
        block
            type(c_ptr) :: pure_bitmap_ptr
            integer :: pure_width, pure_height, pure_xoff, pure_yoff
            
            pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint, &
                                                           pure_width, pure_height, pure_xoff, pure_yoff)
            
            if (c_associated(pure_bitmap_ptr)) then
                write(*,'(A,I0,A,I0,A,I0,A,I0,A)') 'ForTTF: ', pure_width, 'x', pure_height, &
                    ' offset(', pure_xoff, ',', pure_yoff, ')'
                call stb_free_bitmap_pure(pure_bitmap_ptr)
            end if
        end block
        
        write(*,*)
        write(*,*) 'ANALYSIS:'
        write(*,*) 'Compare the edge parameters shown above:'
        write(*,*) '1. Are the number of edges the same?'
        write(*,*) '2. Are the edge fx, fdx, fdy values the same?'
        write(*,*) '3. Are the sy, ey values the same?'
        write(*,*) '4. Are the direction values the same?'
        write(*,*)
        write(*,*) 'Key insight: If edge parameters differ, that explains'
        write(*,*) 'why ForTTF produces k≈±1.174 while STB produces k≈+0.447'
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine compare_edge_building_process

end program test_forttf_compare_edge_building