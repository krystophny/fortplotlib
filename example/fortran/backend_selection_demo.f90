program backend_selection_demo
    use fortplot_text_interface
    use fortplot_freetype_bindings
    implicit none
    
    logical :: success
    character(len=256) :: backend_name
    integer :: text_width, text_height
    
    print *, "=== Font Backend Selection Demo ==="
    print *, ""
    
    ! Check FreeType availability
    if (ft_library_available()) then
        print *, "✓ FreeType library is available"
        print *, "  You can use either 'stb' or 'freetype' backends"
    else
        print *, "✗ FreeType library is not available"
        print *, "  Only 'stb' backend will be used"
    end if
    print *, ""
    
    ! Demo 1: Default backend selection
    print *, "--- Demo 1: Default Backend Selection ---"
    success = init_text_system()
    if (success) then
        call get_current_font_backend(backend_name)
        print *, "Default backend selected: ", trim(backend_name)
        
        text_width = calculate_text_width("Hello, World!")
        text_height = calculate_text_height("Hello, World!")
        print *, "Text metrics - Width:", text_width, "Height:", text_height
        
        call cleanup_text_system()
    else
        print *, "Failed to initialize text system"
    end if
    print *, ""
    
    ! Demo 2: Explicit FreeType preference
    print *, "--- Demo 2: Preferring FreeType ---"
    call set_font_backend_preference("freetype")
    success = init_text_system()
    if (success) then
        call get_current_font_backend(backend_name)
        if (trim(backend_name) == "freetype") then
            print *, "✓ FreeType backend successfully selected"
        else
            print *, "✓ Fallback to ", trim(backend_name), " (FreeType unavailable)"
        end if
        
        text_width = calculate_text_width("Hello, FreeType!")
        text_height = calculate_text_height("Hello, FreeType!")
        print *, "Text metrics - Width:", text_width, "Height:", text_height
        
        call cleanup_text_system()
    else
        print *, "Failed to initialize text system"
    end if
    print *, ""
    
    ! Demo 3: Explicit STB preference
    print *, "--- Demo 3: Preferring STB ---"
    call set_font_backend_preference("stb")
    success = init_text_system()
    if (success) then
        call get_current_font_backend(backend_name)
        print *, "✓ STB backend selected: ", trim(backend_name)
        
        text_width = calculate_text_width("Hello, STB!")
        text_height = calculate_text_height("Hello, STB!")
        print *, "Text metrics - Width:", text_width, "Height:", text_height
        
        call cleanup_text_system()
    else
        print *, "Failed to initialize text system"
    end if
    print *, ""
    
    print *, "=== Demo Complete ==="
    print *, ""
    print *, "Key Points:"
    print *, "- Runtime detection automatically chooses available backend"
    print *, "- You can set preferences with set_font_backend_preference()"
    print *, "- System gracefully falls back when preferred backend unavailable"
    print *, "- No code changes needed - same API works with both backends"

end program backend_selection_demo