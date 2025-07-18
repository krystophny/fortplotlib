program freetype_detection_demo
    use iso_c_binding
    implicit none
    
    ! Demo showing different FreeType detection methods
    call demo_dynamic_loading()
    call demo_compile_time_detection()
    call demo_runtime_function_call()
    
contains

    subroutine demo_dynamic_loading()
        type(c_ptr) :: library_handle
        logical :: available
        
        print *, "=== Dynamic Library Loading Method ==="
        
        ! This is the most robust method
        ! Try to load FreeType library at runtime
        available = try_load_freetype_library(library_handle)
        
        if (available) then
            print *, "✓ FreeType library successfully loaded"
            call close_library(library_handle)
        else
            print *, "✗ FreeType library not found or failed to load"
        end if
        print *, ""
    end subroutine demo_dynamic_loading
    
    subroutine demo_compile_time_detection()
        print *, "=== Compile-Time Detection Method ==="
        print *, "This would use preprocessor directives like:"
        print *, "#ifdef HAVE_FREETYPE"
        print *, "  available = .true."
        print *, "#else"
        print *, "  available = .false."
        print *, "#endif"
        print *, ""
    end subroutine demo_compile_time_detection
    
    subroutine demo_runtime_function_call()
        print *, "=== Runtime Function Call Method ==="
        print *, "Try to call FreeType init function and check for errors"
        print *, "If it succeeds, FreeType is available"
        print *, "If it fails, FreeType is not available"
        print *, ""
    end subroutine demo_runtime_function_call
    
    function try_load_freetype_library(library_handle) result(success)
        type(c_ptr), intent(out) :: library_handle
        logical :: success
        
        ! Interface to dlopen (Linux/macOS) or LoadLibrary (Windows)
        interface
            function dlopen(filename, flag) bind(C, name="dlopen")
                import :: c_ptr, c_char, c_int
                character(c_char), intent(in) :: filename(*)
                integer(c_int), value :: flag
                type(c_ptr) :: dlopen
            end function dlopen
            
            function dlclose(handle) bind(C, name="dlclose")
                import :: c_ptr, c_int
                type(c_ptr), value :: handle
                integer(c_int) :: dlclose
            end function dlclose
        end interface
        
        integer(c_int), parameter :: RTLD_LAZY = 1
        character(len=256) :: lib_names(4)
        integer :: i
        
        ! Try different library names
        lib_names(1) = "libfreetype.so.6"//c_null_char
        lib_names(2) = "libfreetype.so"//c_null_char
        lib_names(3) = "libfreetype.dylib"//c_null_char
        lib_names(4) = "freetype.dll"//c_null_char
        
        library_handle = c_null_ptr
        success = .false.
        
        do i = 1, 4
            library_handle = dlopen(lib_names(i), RTLD_LAZY)
            if (c_associated(library_handle)) then
                success = .true.
                exit
            end if
        end do
    end function try_load_freetype_library
    
    subroutine close_library(library_handle)
        type(c_ptr), intent(inout) :: library_handle
        
        interface
            function dlclose(handle) bind(C, name="dlclose")
                import :: c_ptr, c_int
                type(c_ptr), value :: handle
                integer(c_int) :: dlclose
            end function dlclose
        end interface
        
        integer(c_int) :: result
        
        if (c_associated(library_handle)) then
            result = dlclose(library_handle)
            library_handle = c_null_ptr
        end if
    end subroutine close_library

end program freetype_detection_demo