program test_freetype_pkg_config
    use fortplot_freetype_pkg_config
    use iso_c_binding
    implicit none
    
    print *, "=== FreeType pkg-config Detection Tests ==="
    
    call test_pkg_config_availability()
    call test_pkg_config_library_paths()
    call test_mock_pkg_config_not_found()
    call test_cross_platform_detection()
    
    print *, "All tests completed."
    
contains

    subroutine test_pkg_config_availability()
        logical :: available
        
        print *, "--- Test pkg-config availability ---"
        
        available = check_pkg_config_available()
        if (available) then
            print *, "✓ pkg-config is available"
        else
            print *, "✗ pkg-config is not available"
        end if
        
        print *
    end subroutine test_pkg_config_availability

    subroutine test_pkg_config_library_paths()
        character(len=1024) :: library_paths
        logical :: success
        
        print *, "--- Test pkg-config library paths ---"
        
        call get_freetype_library_paths(library_paths, success)
        if (success) then
            print *, "✓ Found FreeType library paths:"
            print *, "  ", trim(library_paths)
        else
            print *, "✗ Could not find FreeType library paths"
        end if
        
        print *
    end subroutine test_pkg_config_library_paths

    subroutine test_mock_pkg_config_not_found()
        logical :: available
        
        print *, "--- Test mock pkg-config not found ---"
        
        ! Test with mock environment where pkg-config is not available
        call set_mock_pkg_config_unavailable(.true.)
        
        available = check_pkg_config_available()
        if (.not. available) then
            print *, "✓ Mock pkg-config unavailable test passed"
        else
            print *, "✗ Mock pkg-config unavailable test failed"
        end if
        
        ! Reset mock environment
        call set_mock_pkg_config_unavailable(.false.)
        
        print *
    end subroutine test_mock_pkg_config_not_found

    subroutine test_cross_platform_detection()
        type(freetype_detection_result) :: result
        
        print *, "--- Test cross-platform detection ---"
        
        call detect_freetype_cross_platform(result)
        
        print *, "Detection method used: ", trim(result%method_used)
        print *, "FreeType available: ", result%available
        
        if (result%available) then
            print *, "Library paths: ", trim(result%library_paths)
            print *, "Version: ", trim(result%version)
        end if
        
        if (len_trim(result%error_message) > 0) then
            print *, "Error: ", trim(result%error_message)
        end if
        
        print *
    end subroutine test_cross_platform_detection

end program test_freetype_pkg_config