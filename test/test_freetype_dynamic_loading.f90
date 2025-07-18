program test_freetype_dynamic_loading
    use fortplot_freetype_dynamic_loading
    use iso_c_binding
    implicit none
    
    print *, "=== FreeType Dynamic Loading Tests ==="
    
    call test_load_freetype_library()
    call test_load_freetype_functions()
    call test_error_handling()
    call test_library_cleanup()
    
    print *, "All dynamic loading tests completed."
    
contains

    subroutine test_load_freetype_library()
        type(freetype_library_handle) :: handle
        logical :: success
        
        print *, "--- Test library loading ---"
        
        call load_freetype_library(handle, success)
        
        if (success) then
            print *, "✓ FreeType library loaded successfully"
            print *, "  Library path: ", trim(handle%library_path)
            print *, "  Handle valid: ", c_associated(handle%lib_handle)
            
            call cleanup_freetype_library(handle)
        else
            print *, "✗ FreeType library loading failed"
            print *, "  Error: ", trim(handle%error_message)
        end if
        
        print *
    end subroutine test_load_freetype_library

    subroutine test_load_freetype_functions()
        type(freetype_library_handle) :: handle
        logical :: success
        
        print *, "--- Test function loading ---"
        
        call load_freetype_library(handle, success)
        
        if (success) then
            call load_freetype_functions(handle, success)
            
            if (success) then
                print *, "✓ FreeType functions loaded successfully"
                print *, "  Functions loaded: ", handle%functions_loaded
            else
                print *, "✗ FreeType functions loading failed"
                print *, "  Error: ", trim(handle%error_message)
            end if
            
            call cleanup_freetype_library(handle)
        else
            print *, "✗ Cannot test function loading - library not available"
        end if
        
        print *
    end subroutine test_load_freetype_functions

    subroutine test_error_handling()
        type(freetype_library_handle) :: handle
        logical :: success
        
        print *, "--- Test error handling ---"
        
        ! Test loading non-existent library
        call load_specific_library(handle, "nonexistent_library.so", success)
        
        if (.not. success) then
            print *, "✓ Error handling works for non-existent library"
            print *, "  Error message: ", trim(handle%error_message)
        else
            print *, "✗ Error handling failed - should not succeed"
        end if
        
        print *
    end subroutine test_error_handling

    subroutine test_library_cleanup()
        type(freetype_library_handle) :: handle
        logical :: success
        
        print *, "--- Test library cleanup ---"
        
        call load_freetype_library(handle, success)
        
        if (success) then
            print *, "✓ Library loaded for cleanup test"
            
            call cleanup_freetype_library(handle)
            
            if (.not. c_associated(handle%lib_handle)) then
                print *, "✓ Library cleanup successful"
            else
                print *, "✗ Library cleanup failed"
            end if
        else
            print *, "✗ Cannot test cleanup - library not available"
        end if
        
        print *
    end subroutine test_library_cleanup

end program test_freetype_dynamic_loading