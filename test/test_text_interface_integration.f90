program test_text_interface_integration
    use fortplot_text_interface
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    call test_text_system_initialization()
    call test_text_rendering_with_interface()
    call test_text_metrics_calculation()
    call test_backend_selection()
    
    print *, "All text interface integration tests passed!"
    
contains

    subroutine test_text_system_initialization()
        logical :: success
        
        ! Test initialization
        success = init_text_system()
        if (.not. success) then
            print *, "Warning: Could not initialize text system"
            return
        end if
        
        ! Test cleanup
        call cleanup_text_system()
    end subroutine test_text_system_initialization
    
    subroutine test_text_rendering_with_interface()
        logical :: success
        integer(1), allocatable :: image_data(:)
        integer, parameter :: width = 100, height = 50
        integer :: total_size
        
        success = init_text_system()
        if (.not. success) return
        
        ! Allocate image buffer
        total_size = height * (1 + width * 3)
        allocate(image_data(total_size))
        image_data = 0
        
        ! Render text
        call render_text_to_image(image_data, width, height, 10, 10, "Test", -1_1, -1_1, -1_1)
        
        deallocate(image_data)
        call cleanup_text_system()
    end subroutine test_text_rendering_with_interface
    
    subroutine test_text_metrics_calculation()
        logical :: success
        integer :: width, height
        real(wp) :: ascent, descent, line_gap
        
        success = init_text_system()
        if (.not. success) return
        
        ! Test text width calculation
        width = calculate_text_width("Hello")
        if (width <= 0) then
            error stop "Invalid text width calculation"
        end if
        
        ! Test text height calculation
        height = calculate_text_height("Hello")
        if (height <= 0) then
            error stop "Invalid text height calculation"
        end if
        
        ! Test font metrics
        call get_font_metrics(ascent, descent, line_gap, success)
        if (success) then
            if (ascent <= 0.0_wp) then
                error stop "Invalid font ascent"
            end if
        end if
        
        call cleanup_text_system()
    end subroutine test_text_metrics_calculation
    
    subroutine test_backend_selection()
        logical :: success
        character(len=256) :: backend_name
        
        ! Test getting current backend
        call get_current_font_backend(backend_name)
        if (len_trim(backend_name) == 0) then
            error stop "No backend name returned"
        end if
        
        ! Test setting backend preference
        call set_font_backend_preference("stb")
        success = init_text_system()
        if (success) then
            call get_current_font_backend(backend_name)
            if (trim(backend_name) /= "stb") then
                print *, "Warning: Backend preference not honored"
            end if
            call cleanup_text_system()
        end if
        
        ! Test fallback
        call set_font_backend_preference("freetype")
        success = init_text_system()
        if (success) then
            call cleanup_text_system()
        end if
    end subroutine test_backend_selection

end program test_text_interface_integration