module fortplot_text_interface
    use fortplot_font_interface
    use fortplot_unicode, only: utf8_to_codepoint, utf8_char_length
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    private
    public :: init_text_system, cleanup_text_system
    public :: render_text_to_image, render_rotated_text_to_image
    public :: calculate_text_width, calculate_text_height
    public :: get_font_metrics, get_font_ascent_ratio
    public :: set_font_backend_preference, get_current_font_backend
    public :: check_backend_availability, list_available_backends
    
    ! Module state
    class(font_renderer_t), allocatable :: global_renderer
    logical :: text_system_initialized = .false.
    character(len=32) :: preferred_backend = "stb"
    
    ! Constants
    integer, parameter :: DEFAULT_FONT_SIZE = 16
    real(wp), parameter :: PI = 3.14159265359_wp
    
contains

    function init_text_system() result(success)
        logical :: success
        character(len=256) :: font_path
        
        success = .false.
        
        if (text_system_initialized) then
            success = .true.
            return
        end if
        
        ! Create renderer based on preference
        call create_preferred_renderer()
        
        if (.not. allocated(global_renderer)) then
            return
        end if
        
        ! Try to find and load a font
        success = discover_and_load_font()
        
        if (success) then
            ! Set default font size
            call global_renderer%set_pixel_height(real(DEFAULT_FONT_SIZE, wp))
            text_system_initialized = .true.
        else
            deallocate(global_renderer)
        end if
    end function init_text_system
    
    subroutine cleanup_text_system()
        if (text_system_initialized .and. allocated(global_renderer)) then
            call global_renderer%cleanup()
            deallocate(global_renderer)
            text_system_initialized = .false.
        end if
    end subroutine cleanup_text_system
    
    subroutine create_preferred_renderer()
        ! Try preferred backend first
        global_renderer = create_font_renderer(preferred_backend)
        
        ! If preferred backend fails, try fallback
        if (.not. allocated(global_renderer)) then
            if (preferred_backend == "freetype") then
                global_renderer = create_font_renderer("stb")
            else
                global_renderer = create_font_renderer("freetype")
            end if
        end if
    end subroutine create_preferred_renderer
    
    function discover_and_load_font() result(success)
        logical :: success
        character(len=256) :: font_path
        
        success = .false.
        
        ! Try fonts in priority order
        if (global_renderer%find_system_font("Liberation Sans", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
        
        if (global_renderer%find_system_font("Helvetica", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
        
        if (global_renderer%find_system_font("Arial", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
        
        if (global_renderer%find_system_font("DejaVu Sans", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
        
        ! If we get here and the preferred backend failed, try fallback
        if (.not. success) then
            call try_fallback_backend()
            if (allocated(global_renderer)) then
                success = try_load_fonts_simple()  ! Non-recursive call
            end if
        end if
    end function discover_and_load_font
    
    subroutine try_fallback_backend()
        ! If current backend failed, try the other one
        if (allocated(global_renderer)) then
            call global_renderer%cleanup()
            deallocate(global_renderer)
        end if
        
        if (preferred_backend == "freetype") then
            global_renderer = create_font_renderer("stb")
        else if (preferred_backend == "stb") then
            global_renderer = create_font_renderer("freetype")
        else
            global_renderer = create_font_renderer("stb")  ! Default fallback
        end if
    end subroutine try_fallback_backend
    
    function try_load_fonts_simple() result(success)
        logical :: success
        character(len=256) :: font_path
        
        success = .false.
        
        ! Simple version without recursion
        if (global_renderer%find_system_font("Liberation Sans", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
        
        if (global_renderer%find_system_font("Helvetica", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
        
        if (global_renderer%find_system_font("Arial", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
        
        if (global_renderer%find_system_font("DejaVu Sans", font_path)) then
            success = global_renderer%load_font(font_path)
            if (success) return
        end if
    end function try_load_fonts_simple
    
    function calculate_text_width(text) result(width)
        character(len=*), intent(in) :: text
        integer :: width
        integer :: i, char_code, advance_width, left_bearing
        integer :: char_len
        
        width = 0
        
        if (.not. text_system_initialized) then
            if (.not. init_text_system()) then
                width = len_trim(text) * 8  ! Fallback estimate
                return
            end if
        end if
        
        i = 1
        do while (i <= len_trim(text))
            char_len = utf8_char_length(text(i:i))
            if (char_len == 0) then
                char_code = iachar(text(i:i))
                i = i + 1
            else
                char_code = utf8_to_codepoint(text, i)
                i = i + char_len
            end if
            
            call global_renderer%get_codepoint_metrics(char_code, advance_width, left_bearing)
            width = width + advance_width
        end do
    end function calculate_text_width
    
    function calculate_text_height(text) result(height)
        character(len=*), intent(in) :: text
        integer :: height
        real(wp) :: ascent, descent, line_gap
        
        ! Suppress unused parameter warnings
        associate(unused_text => text); end associate
        
        height = DEFAULT_FONT_SIZE  ! Default fallback
        
        if (.not. text_system_initialized) then
            if (.not. init_text_system()) then
                return
            end if
        end if
        
        call global_renderer%get_font_metrics(ascent, descent, line_gap)
        height = int(ascent + descent)
        
        if (height <= 0) height = DEFAULT_FONT_SIZE
    end function calculate_text_height
    
    subroutine render_text_to_image(image_data, width, height, x, y, text, r, g, b)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        character(len=*), intent(in) :: text
        integer(1), intent(in) :: r, g, b
        integer :: pen_x, pen_y, i, char_code
        integer :: advance_width, left_bearing
        type(glyph_bitmap_t) :: bitmap
        integer :: char_len
        
        if (.not. text_system_initialized) then
            if (.not. init_text_system()) then
                call render_simple_placeholder(image_data, width, height, x, y, r, g, b)
                return
            end if
        end if
        
        pen_x = x
        pen_y = y
        
        i = 1
        do while (i <= len_trim(text))
            char_len = utf8_char_length(text(i:i))
            if (char_len == 0) then
                char_code = iachar(text(i:i))
                i = i + 1
            else
                char_code = utf8_to_codepoint(text, i)
                i = i + char_len
            end if
            
            ! Render glyph
            call global_renderer%render_glyph(char_code, bitmap)
            
            if (bitmap%width > 0 .and. bitmap%height > 0) then
                call render_glyph_bitmap(image_data, width, height, pen_x, pen_y, &
                                       bitmap, r, g, b)
                call global_renderer%free_glyph_bitmap(bitmap)
            end if
            
            ! Advance pen position
            call global_renderer%get_codepoint_metrics(char_code, advance_width, left_bearing)
            pen_x = pen_x + advance_width
        end do
    end subroutine render_text_to_image
    
    subroutine render_glyph_bitmap(image_data, width, height, pen_x, pen_y, bitmap, r, g, b)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, pen_x, pen_y
        type(glyph_bitmap_t), intent(in) :: bitmap
        integer(1), intent(in) :: r, g, b
        integer :: glyph_x, glyph_y, img_x, img_y, row, col, pixel_idx
        integer :: alpha_int
        real :: alpha_f, bg_r, bg_g, bg_b
        
        if (.not. associated(bitmap%data)) return
        
        glyph_x = pen_x + bitmap%xoff
        glyph_y = pen_y + bitmap%yoff
        
        do row = 0, bitmap%height - 1
            do col = 0, bitmap%width - 1
                img_x = glyph_x + col
                img_y = glyph_y + row
                
                if (img_x >= 0 .and. img_x < width .and. img_y >= 0 .and. img_y < height) then
                    alpha_int = int(bitmap%data(row * bitmap%width + col + 1))
                    if (alpha_int < 0) alpha_int = alpha_int + 256
                    
                    if (alpha_int > 0) then
                        pixel_idx = img_y * (1 + width * 3) + 1 + img_x * 3 + 1
                        
                        alpha_f = real(alpha_int) / 255.0
                        bg_r = real(int(image_data(pixel_idx), &
                            kind=selected_int_kind(2)) + merge(256, 0, image_data(pixel_idx) < 0))
                        bg_g = real(int(image_data(pixel_idx + 1), &
                            kind=selected_int_kind(2)) + merge(256, 0, image_data(pixel_idx + 1) < 0))
                        bg_b = real(int(image_data(pixel_idx + 2), &
                            kind=selected_int_kind(2)) + merge(256, 0, image_data(pixel_idx + 2) < 0))
                        
                        ! Alpha blending
                        image_data(pixel_idx) = int(bg_r * (1.0 - alpha_f) + real(int(r) + merge(256, 0, r < 0)) * alpha_f, 1)
                        image_data(pixel_idx + 1) = int(bg_g * (1.0 - alpha_f) + real(int(g) + merge(256, 0, g < 0)) * alpha_f, 1)
                        image_data(pixel_idx + 2) = int(bg_b * (1.0 - alpha_f) + real(int(b) + merge(256, 0, b < 0)) * alpha_f, 1)
                    end if
                end if
            end do
        end do
    end subroutine render_glyph_bitmap
    
    subroutine render_simple_placeholder(image_data, width, height, x, y, r, g, b)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        integer(1), intent(in) :: r, g, b
        integer :: pixel_idx, img_x, img_y, max_idx
        
        max_idx = height * (1 + width * 3)
        
        do img_y = y, min(y + 6, height - 1)
            do img_x = x, min(x + 4, width - 1)
                if (img_x >= 0 .and. img_y >= 0) then
                    pixel_idx = img_y * (1 + width * 3) + 1 + img_x * 3 + 1
                    if (pixel_idx > 0 .and. pixel_idx <= max_idx - 2) then
                        image_data(pixel_idx) = r
                        image_data(pixel_idx + 1) = g
                        image_data(pixel_idx + 2) = b
                    end if
                end if
            end do
        end do
    end subroutine render_simple_placeholder
    
    subroutine render_rotated_text_to_image(image_data, width, height, x, y, text, r, g, b, angle)
        integer(1), intent(inout) :: image_data(*)
        integer, intent(in) :: width, height, x, y
        character(len=*), intent(in) :: text
        integer(1), intent(in) :: r, g, b
        real(wp), intent(in) :: angle
        integer :: pen_x, pen_y, i, char_code
        integer :: advance_width, left_bearing
        type(glyph_bitmap_t) :: bitmap
        real(wp) :: cos_a, sin_a
        integer :: char_len
        
        if (.not. text_system_initialized) then
            if (.not. init_text_system()) then
                return
            end if
        end if
        
        pen_x = x
        pen_y = y
        cos_a = cos(angle * PI / 180.0_wp)
        sin_a = sin(angle * PI / 180.0_wp)
        
        i = 1
        do while (i <= len_trim(text))
            char_len = utf8_char_length(text(i:i))
            if (char_len == 0) then
                char_code = iachar(text(i:i))
                i = i + 1
            else
                char_code = utf8_to_codepoint(text, i)
                i = i + char_len
            end if
            
            call global_renderer%render_glyph(char_code, bitmap)
            
            if (bitmap%width > 0 .and. bitmap%height > 0) then
                call render_glyph_bitmap(image_data, width, height, pen_x, pen_y, &
                                       bitmap, r, g, b)
                call global_renderer%free_glyph_bitmap(bitmap)
            end if
            
            ! Advance with rotation
            call global_renderer%get_codepoint_metrics(char_code, advance_width, left_bearing)
            pen_x = pen_x + int(real(advance_width) * cos_a)
            pen_y = pen_y + int(real(advance_width) * sin_a)
        end do
    end subroutine render_rotated_text_to_image
    
    subroutine get_font_metrics(ascent_pixels, descent_pixels, line_gap_pixels, success)
        real(wp), intent(out) :: ascent_pixels, descent_pixels, line_gap_pixels
        logical, intent(out) :: success
        
        success = .false.
        ascent_pixels = 0.0_wp
        descent_pixels = 0.0_wp
        line_gap_pixels = 0.0_wp
        
        if (.not. text_system_initialized) then
            if (.not. init_text_system()) then
                return
            end if
        end if
        
        call global_renderer%get_font_metrics(ascent_pixels, descent_pixels, line_gap_pixels)
        success = .true.
    end subroutine get_font_metrics
    
    function get_font_ascent_ratio() result(ratio)
        real(wp) :: ratio
        real(wp) :: ascent, descent, line_gap
        
        ratio = 0.7_wp  ! Default fallback
        
        if (.not. text_system_initialized) then
            if (.not. init_text_system()) then
                return
            end if
        end if
        
        call global_renderer%get_font_metrics(ascent, descent, line_gap)
        if (ascent > 0.0_wp .and. descent > 0.0_wp) then
            ratio = ascent / (ascent + descent)
        end if
    end function get_font_ascent_ratio
    
    subroutine set_font_backend_preference(backend)
        character(len=*), intent(in) :: backend
        
        preferred_backend = backend
        
        ! If system is already initialized, reinitialize with new backend
        if (text_system_initialized) then
            call cleanup_text_system()
        end if
    end subroutine set_font_backend_preference
    
    subroutine get_current_font_backend(backend_name)
        character(len=*), intent(out) :: backend_name
        
        backend_name = ""
        
        if (text_system_initialized .and. allocated(global_renderer)) then
            select type (renderer => global_renderer)
            type is (stb_font_renderer_t)
                backend_name = "stb"
            type is (freetype_font_renderer_t)
                backend_name = "freetype"
            class default
                backend_name = "unknown"
            end select
        else
            backend_name = preferred_backend
        end if
    end subroutine get_current_font_backend
    
    function check_backend_availability(backend_name) result(available)
        use fortplot_freetype_bindings, only: ft_library_available
        character(len=*), intent(in) :: backend_name
        logical :: available
        
        available = .false.
        
        select case (trim(backend_name))
        case ("stb")
            available = .true.  ! STB is always available
        case ("freetype")
            available = ft_library_available()
        end select
    end function check_backend_availability
    
    subroutine list_available_backends(backends, count)
        character(len=32), intent(out) :: backends(2)
        integer, intent(out) :: count
        
        count = 0
        
        ! STB is always available
        count = count + 1
        backends(count) = "stb"
        
        ! Check FreeType availability
        if (check_backend_availability("freetype")) then
            count = count + 1
            backends(count) = "freetype"
        end if
    end subroutine list_available_backends

end module fortplot_text_interface