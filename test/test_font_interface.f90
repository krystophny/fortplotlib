program test_font_interface
    use fortplot_font_interface
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    call test_font_renderer_creation()
    call test_font_loading()
    call test_glyph_metrics()
    call test_glyph_rendering()
    call test_font_factory()
    
    print *, "All font interface tests passed!"
    
contains

    subroutine test_font_renderer_creation()
        class(font_renderer_t), allocatable :: renderer
        
        ! Test that we can create font renderers
        allocate(stb_font_renderer_t :: renderer)
        
        if (.not. allocated(renderer)) then
            error stop "Failed to allocate STB font renderer"
        end if
        
        deallocate(renderer)
        
        ! Test FreeType renderer creation
        allocate(freetype_font_renderer_t :: renderer)
        
        if (.not. allocated(renderer)) then
            error stop "Failed to allocate FreeType font renderer"
        end if
        
        deallocate(renderer)
    end subroutine test_font_renderer_creation
    
    subroutine test_font_loading()
        class(font_renderer_t), allocatable :: renderer
        logical :: success
        character(len=256) :: font_path
        
        ! Test with STB renderer
        allocate(stb_font_renderer_t :: renderer)
        
        ! Try to find a font
        success = renderer%find_system_font("Liberation Sans", font_path)
        if (success) then
            success = renderer%load_font(font_path)
            if (.not. success) then
                error stop "Failed to load font with STB renderer"
            end if
        end if
        
        call renderer%cleanup()
        deallocate(renderer)
    end subroutine test_font_loading
    
    subroutine test_glyph_metrics()
        class(font_renderer_t), allocatable :: renderer
        logical :: success
        character(len=256) :: font_path
        integer :: advance_width, left_bearing
        real(wp) :: ascent, descent, line_gap
        
        allocate(stb_font_renderer_t :: renderer)
        
        success = renderer%find_system_font("Liberation Sans", font_path)
        if (success) then
            success = renderer%load_font(font_path)
            if (success) then
                ! Set font size
                call renderer%set_pixel_height(16.0_wp)
                
                ! Get metrics for letter 'A'
                call renderer%get_codepoint_metrics(65, advance_width, left_bearing)
                if (advance_width <= 0) then
                    error stop "Invalid advance width for glyph"
                end if
                
                ! Get font vertical metrics
                call renderer%get_font_metrics(ascent, descent, line_gap)
                if (ascent <= 0.0_wp) then
                    error stop "Invalid font ascent"
                end if
            end if
        end if
        
        call renderer%cleanup()
        deallocate(renderer)
    end subroutine test_glyph_metrics
    
    subroutine test_glyph_rendering()
        class(font_renderer_t), allocatable :: renderer
        type(glyph_bitmap_t) :: bitmap
        logical :: success
        character(len=256) :: font_path
        
        allocate(stb_font_renderer_t :: renderer)
        
        success = renderer%find_system_font("Liberation Sans", font_path)
        if (success) then
            success = renderer%load_font(font_path)
            if (success) then
                call renderer%set_pixel_height(16.0_wp)
                
                ! Render letter 'A'
                call renderer%render_glyph(65, bitmap)
                
                if (bitmap%width <= 0 .or. bitmap%height <= 0) then
                    error stop "Invalid glyph bitmap dimensions"
                end if
                
                if (.not. associated(bitmap%data)) then
                    error stop "Glyph bitmap data not allocated"
                end if
                
                ! Clean up bitmap
                call renderer%free_glyph_bitmap(bitmap)
            end if
        end if
        
        call renderer%cleanup()
        deallocate(renderer)
    end subroutine test_glyph_rendering
    
    subroutine test_font_factory()
        class(font_renderer_t), allocatable :: renderer
        
        ! Test creating renderer through factory
        renderer = create_font_renderer("stb")
        if (.not. allocated(renderer)) then
            error stop "Failed to create STB renderer through factory"
        end if
        deallocate(renderer)
        
        renderer = create_font_renderer("freetype")
        if (.not. allocated(renderer)) then
            error stop "Failed to create FreeType renderer through factory"
        end if
        deallocate(renderer)
        
        ! Test default renderer
        renderer = create_font_renderer()
        if (.not. allocated(renderer)) then
            error stop "Failed to create default renderer through factory"
        end if
        deallocate(renderer)
    end subroutine test_font_factory

end program test_font_interface