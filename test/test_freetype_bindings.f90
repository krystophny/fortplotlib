program test_freetype_bindings
    use fortplot_freetype_bindings
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    call test_library_init_cleanup()
    call test_face_loading()
    call test_glyph_metrics()
    call test_glyph_rendering()
    call test_dynamic_loading()
    
    print *, "All FreeType binding tests passed!"
    
contains

    subroutine test_library_init_cleanup()
        type(c_ptr) :: library
        integer(c_int) :: error
        
        ! Test library initialization
        error = ft_init_freetype(library)
        if (error /= 0) then
            print *, "Note: FreeType library not available, skipping tests"
            return
        end if
        
        if (.not. c_associated(library)) then
            error stop "FreeType library pointer not associated after init"
        end if
        
        ! Test library cleanup
        call ft_done_freetype(library)
    end subroutine test_library_init_cleanup
    
    subroutine test_face_loading()
        type(c_ptr) :: library, face
        integer(c_int) :: error
        character(len=256) :: font_path
        logical :: found
        
        error = ft_init_freetype(library)
        if (error /= 0) return
        
        ! Try to find a system font
        call find_system_font("Liberation Sans", font_path, found)
        if (.not. found) then
            call find_system_font("DejaVu Sans", font_path, found)
        end if
        
        if (found) then
            error = ft_new_face(library, trim(font_path)//c_null_char, 0_c_long, face)
            if (error == 0 .and. c_associated(face)) then
                ! Successfully loaded face
                call ft_done_face(face)
            end if
        end if
        
        call ft_done_freetype(library)
    end subroutine test_face_loading
    
    subroutine test_glyph_metrics()
        type(c_ptr) :: library, face
        integer(c_int) :: error
        character(len=256) :: font_path
        logical :: found
        integer(c_int) :: glyph_index
        type(ft_glyph_metrics_t) :: metrics
        
        error = ft_init_freetype(library)
        if (error /= 0) return
        
        call find_system_font("Liberation Sans", font_path, found)
        if (found) then
            error = ft_new_face(library, trim(font_path)//c_null_char, 0_c_long, face)
            if (error == 0) then
                ! Set character size
                error = ft_set_pixel_sizes(face, 0_c_int, 16_c_int)
                
                ! Get glyph index for 'A'
                glyph_index = ft_get_char_index(face, 65_c_long)
                if (glyph_index > 0) then
                    ! Load glyph
                    error = ft_load_glyph(face, glyph_index, FT_LOAD_DEFAULT)
                    if (error == 0) then
                        ! Get metrics
                        call ft_get_glyph_metrics(face, metrics)
                        if (metrics%width <= 0 .or. metrics%height <= 0) then
                            error stop "Invalid glyph metrics"
                        end if
                    end if
                end if
                
                call ft_done_face(face)
            end if
        end if
        
        call ft_done_freetype(library)
    end subroutine test_glyph_metrics
    
    subroutine test_glyph_rendering()
        type(c_ptr) :: library, face
        integer(c_int) :: error
        character(len=256) :: font_path
        logical :: found
        integer(c_int) :: glyph_index
        type(ft_bitmap_t) :: bitmap
        
        error = ft_init_freetype(library)
        if (error /= 0) return
        
        call find_system_font("Liberation Sans", font_path, found)
        if (found) then
            error = ft_new_face(library, trim(font_path)//c_null_char, 0_c_long, face)
            if (error == 0) then
                error = ft_set_pixel_sizes(face, 0_c_int, 16_c_int)
                
                glyph_index = ft_get_char_index(face, 65_c_long)
                if (glyph_index > 0) then
                    ! Load and render glyph
                    error = ft_load_glyph(face, glyph_index, FT_LOAD_RENDER)
                    if (error == 0) then
                        ! Get bitmap
                        call ft_get_glyph_bitmap(face, bitmap)
                        if (bitmap%width > 0 .and. bitmap%rows > 0) then
                            if (.not. c_associated(bitmap%buffer)) then
                                error stop "Glyph bitmap buffer not associated"
                            end if
                        end if
                    end if
                end if
                
                call ft_done_face(face)
            end if
        end if
        
        call ft_done_freetype(library)
    end subroutine test_glyph_rendering
    
    subroutine test_dynamic_loading()
        logical :: available
        
        ! Test if FreeType can be dynamically loaded
        available = ft_library_available()
        
        if (.not. available) then
            print *, "FreeType library not dynamically loadable"
        end if
    end subroutine test_dynamic_loading
    
    subroutine find_system_font(font_name, font_path, found)
        character(len=*), intent(in) :: font_name
        character(len=*), intent(out) :: font_path
        logical, intent(out) :: found
        character(len=256) :: candidates(4)
        integer :: i
        
        found = .false.
        
        select case (trim(font_name))
        case ("Liberation Sans")
            candidates(1) = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
            candidates(2) = "/usr/share/fonts/liberation-fonts/LiberationSans-Regular.ttf"
            candidates(3) = "/usr/share/fonts/TTF/LiberationSans-Regular.ttf"
            candidates(4) = "/usr/local/share/fonts/LiberationSans-Regular.ttf"
        case ("DejaVu Sans")
            candidates(1) = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            candidates(2) = "/usr/share/fonts/TTF/DejaVuSans.ttf"
            candidates(3) = "/usr/share/fonts/dejavu-fonts/DejaVuSans.ttf"
            candidates(4) = "/usr/local/share/fonts/DejaVuSans.ttf"
        case default
            return
        end select
        
        do i = 1, 4
            inquire(file=trim(candidates(i)), exist=found)
            if (found) then
                font_path = candidates(i)
                return
            end if
        end do
    end subroutine find_system_font

end program test_freetype_bindings