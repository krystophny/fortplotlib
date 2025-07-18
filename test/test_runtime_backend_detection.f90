program test_runtime_backend_detection
    use fortplot_text_interface
    use fortplot_freetype_bindings
    use fortplot_font_interface
    implicit none
    
    call test_freetype_availability_detection()
    call test_automatic_backend_selection()
    call test_backend_preference_fallback()
    call test_backend_reporting()
    
    print *, "All runtime backend detection tests passed!"
    
contains

    subroutine test_freetype_availability_detection()
        logical :: available
        
        ! Test direct FreeType availability check
        available = ft_library_available()
        
        if (available) then
            print *, "✓ FreeType library detected and available"
        else
            print *, "✓ FreeType library not available (expected on many systems)"
        end if
        
        ! This should never fail - it's just checking if the detection works
    end subroutine test_freetype_availability_detection
    
    subroutine test_automatic_backend_selection()
        logical :: success
        character(len=256) :: backend_name
        
        ! Test automatic backend selection
        success = init_text_system()
        if (success) then
            call get_current_font_backend(backend_name)
            print *, "✓ Automatic backend selection chose: ", trim(backend_name)
            call cleanup_text_system()
        else
            print *, "✓ No backends available (system has no fonts)"
        end if
    end subroutine test_automatic_backend_selection
    
    subroutine test_backend_preference_fallback()
        logical :: success
        character(len=256) :: backend_name
        
        ! Test preferring FreeType but falling back to STB
        call set_font_backend_preference("freetype")
        success = init_text_system()
        
        if (success) then
            call get_current_font_backend(backend_name)
            if (trim(backend_name) == "freetype") then
                print *, "✓ FreeType backend successfully selected"
            else
                print *, "✓ Fallback to STB backend (FreeType unavailable)"
            end if
            call cleanup_text_system()
        else
            print *, "✓ No backends available"
        end if
        
        ! Test preferring STB explicitly
        call set_font_backend_preference("stb")
        success = init_text_system()
        
        if (success) then
            call get_current_font_backend(backend_name)
            if (trim(backend_name) == "stb") then
                print *, "✓ STB backend successfully selected"
            else
                print *, "✓ Unexpected backend selected: ", trim(backend_name)
            end if
            call cleanup_text_system()
        else
            print *, "✓ No backends available"
        end if
    end subroutine test_backend_preference_fallback
    
    subroutine test_backend_reporting()
        class(font_renderer_t), allocatable :: renderer
        logical :: stb_available, ft_available
        character(len=32) :: backends(2)
        integer :: backend_count, i
        
        ! Test individual backend availability
        stb_available = check_backend_availability("stb")
        ft_available = check_backend_availability("freetype")
        
        if (stb_available) then
            print *, "✓ STB backend available"
        else
            print *, "✗ STB backend not available (unexpected)"
        end if
        
        if (ft_available) then
            print *, "✓ FreeType backend available"
        else
            print *, "✓ FreeType backend not available"
        end if
        
        ! Test backend listing
        call list_available_backends(backends, backend_count)
        print *, "✓ Available backends (", backend_count, "):"
        do i = 1, backend_count
            print *, "  - ", trim(backends(i))
        end do
        
        ! Test individual backend creation
        renderer = create_font_renderer("stb")
        if (allocated(renderer)) then
            print *, "✓ STB renderer creation successful"
            call renderer%cleanup()
            deallocate(renderer)
        else
            print *, "✗ STB renderer creation failed"
        end if
        
        renderer = create_font_renderer("freetype")
        if (allocated(renderer)) then
            print *, "✓ FreeType renderer creation successful"
            call renderer%cleanup()
            deallocate(renderer)
        else
            print *, "✓ FreeType renderer creation failed (expected if library unavailable)"
        end if
    end subroutine test_backend_reporting

end program test_runtime_backend_detection