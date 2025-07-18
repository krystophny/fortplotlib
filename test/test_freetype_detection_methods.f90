program test_freetype_detection_methods
    use fortplot_freetype_detection
    use iso_c_binding
    implicit none
    
    print *, "=== FreeType Detection Methods Demo ==="
    print *, ""
    
    call test_simple_detection()
    call test_detailed_detection()
    call test_alternative_methods()
    
contains

    subroutine test_simple_detection()
        logical :: available
        
        print *, "--- Simple Detection ---"
        available = check_freetype_availability()
        
        if (available) then
            print *, "✓ FreeType is available"
        else
            print *, "✗ FreeType is not available"
        end if
        print *, ""
    end subroutine test_simple_detection
    
    subroutine test_detailed_detection()
        type(freetype_detection_info) :: info
        
        print *, "--- Detailed Detection ---"
        call detect_freetype_detailed(info)
        
        print *, "Library loadable: ", info%library_loadable
        print *, "Functions available: ", info%functions_available
        print *, "Initialization works: ", info%initialization_works
        
        if (len_trim(info%library_path) > 0) then
            print *, "Library path: ", trim(info%library_path)
        end if
        
        if (len_trim(info%error_message) > 0) then
            print *, "Error: ", trim(info%error_message)
        end if
        print *, ""
    end subroutine test_detailed_detection
    
    subroutine test_alternative_methods()
        print *, "--- Alternative Detection Methods ---"
        print *, ""
        
        print *, "1. File System Check:"
        call check_freetype_files()
        print *, ""
        
        print *, "2. Package Manager Check:"
        call check_package_manager()
        print *, ""
        
        print *, "3. Environment Variable Check:"
        call check_environment_variables()
        print *, ""
    end subroutine test_alternative_methods
    
    subroutine check_freetype_files()
        character(len=256) :: common_paths(6)
        logical :: exists
        integer :: i
        
        common_paths(1) = "/usr/lib/x86_64-linux-gnu/libfreetype.so.6"
        common_paths(2) = "/usr/lib/libfreetype.so"
        common_paths(3) = "/usr/local/lib/libfreetype.so"
        common_paths(4) = "/opt/homebrew/lib/libfreetype.dylib"
        common_paths(5) = "/usr/lib/libfreetype.dylib"
        common_paths(6) = "C:\\Windows\\System32\\freetype.dll"
        
        print *, "  Checking common file locations:"
        do i = 1, 6
            inquire(file=trim(common_paths(i)), exist=exists)
            if (exists) then
                print *, "    ✓ Found: ", trim(common_paths(i))
            end if
        end do
    end subroutine check_freetype_files
    
    subroutine check_package_manager()
        print *, "  Package manager detection methods:"
        print *, "    - dpkg -l | grep freetype     (Debian/Ubuntu)"
        print *, "    - rpm -q freetype-devel       (RedHat/CentOS)"
        print *, "    - brew list freetype           (macOS Homebrew)"
        print *, "    - pacman -Q freetype2          (Arch Linux)"
        print *, "    - pkg-config --exists freetype2"
    end subroutine check_package_manager
    
    subroutine check_environment_variables()
        character(len=256) :: value
        integer :: status
        
        print *, "  Environment variable checks:"
        
        call get_environment_variable("FREETYPE_DIR", value, status=status)
        if (status == 0 .and. len_trim(value) > 0) then
            print *, "    ✓ FREETYPE_DIR = ", trim(value)
        else
            print *, "    ✗ FREETYPE_DIR not set"
        end if
        
        call get_environment_variable("PKG_CONFIG_PATH", value, status=status)
        if (status == 0 .and. len_trim(value) > 0) then
            print *, "    ✓ PKG_CONFIG_PATH = ", trim(value)
        else
            print *, "    ✗ PKG_CONFIG_PATH not set"
        end if
    end subroutine check_environment_variables

end program test_freetype_detection_methods