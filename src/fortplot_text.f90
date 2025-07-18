module fortplot_text
    use fortplot_text_interface
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    private
    public :: init_text_system, cleanup_text_system, render_text_to_image, calculate_text_width, calculate_text_height
    public :: render_rotated_text_to_image, get_font_metrics
    public :: get_font_ascent_ratio, find_font_by_name, find_any_available_font
    
    ! Re-export interface functions
    public :: set_font_backend_preference, get_current_font_backend
    public :: check_backend_availability, list_available_backends
    
contains

    ! All functions now delegate to the new interface
    
    ! Backward compatibility functions for font discovery
    function find_font_by_name(font_name, font_path) result(found)
        use fortplot_font_interface, only: create_font_renderer, font_renderer_t
        character(len=*), intent(in) :: font_name
        character(len=256), intent(out) :: font_path
        logical :: found
        class(font_renderer_t), allocatable :: renderer
        
        renderer = create_font_renderer("stb")
        if (.not. allocated(renderer)) then
            found = .false.
            return
        end if
        
        found = renderer%find_system_font(font_name, font_path)
        call renderer%cleanup()
        deallocate(renderer)
    end function find_font_by_name
    
    function find_any_available_font(font_path) result(found)
        character(len=256), intent(out) :: font_path
        logical :: found
        
        found = .false.
        
        if (find_font_by_name("Liberation Sans", font_path)) then
            found = .true.
            return
        end if
        
        if (find_font_by_name("Helvetica", font_path)) then
            found = .true.
            return
        end if
        
        if (find_font_by_name("Arial", font_path)) then
            found = .true.
            return
        end if
        
        if (find_font_by_name("DejaVu Sans", font_path)) then
            found = .true.
            return
        end if
    end function find_any_available_font

end module fortplot_text