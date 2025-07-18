program test_freetype_linux_distributions
    use fortplot_freetype_pkg_config
    use iso_c_binding
    implicit none
    
    print *, "=== FreeType Linux Distribution Tests ==="
    
    call test_debian_ubuntu_paths()
    call test_redhat_centos_paths()
    call test_arch_linux_paths()
    call test_alpine_linux_paths()
    call test_suse_paths()
    call test_gentoo_paths()
    
    print *, "All distribution tests completed."
    
contains

    subroutine test_debian_ubuntu_paths()
        print *, "--- Testing Debian/Ubuntu paths ---"
        call test_specific_paths("Debian/Ubuntu", &
            "/usr/lib/x86_64-linux-gnu:/usr/lib/i386-linux-gnu:/usr/lib")
    end subroutine test_debian_ubuntu_paths

    subroutine test_redhat_centos_paths()
        print *, "--- Testing RedHat/CentOS paths ---"
        call test_specific_paths("RedHat/CentOS", &
            "/usr/lib64:/usr/lib:/lib64:/lib")
    end subroutine test_redhat_centos_paths

    subroutine test_arch_linux_paths()
        print *, "--- Testing Arch Linux paths ---"
        call test_specific_paths("Arch Linux", &
            "/usr/lib:/usr/local/lib")
    end subroutine test_arch_linux_paths

    subroutine test_alpine_linux_paths()
        print *, "--- Testing Alpine Linux paths ---"
        call test_specific_paths("Alpine Linux", &
            "/usr/lib:/lib:/usr/local/lib")
    end subroutine test_alpine_linux_paths

    subroutine test_suse_paths()
        print *, "--- Testing SUSE paths ---"
        call test_specific_paths("SUSE", &
            "/usr/lib64:/usr/lib:/lib64:/lib")
    end subroutine test_suse_paths

    subroutine test_gentoo_paths()
        print *, "--- Testing Gentoo paths ---"
        call test_specific_paths("Gentoo", &
            "/usr/lib64:/usr/lib:/usr/local/lib64:/usr/local/lib")
    end subroutine test_gentoo_paths

    subroutine test_specific_paths(distribution, library_paths)
        character(len=*), intent(in) :: distribution
        character(len=*), intent(in) :: library_paths
        type(freetype_detection_result) :: result
        logical :: path_exists
        
        print *, "  Testing ", trim(distribution), " library paths"
        
        ! Simulate detection on this distribution
        call simulate_distribution_detection(library_paths, result)
        
        if (result%available) then
            print *, "  ✓ FreeType would be detected on ", trim(distribution)
            print *, "    Method: ", trim(result%method_used)
            print *, "    Paths: ", trim(result%library_paths)
        else
            print *, "  ✗ FreeType would not be detected on ", trim(distribution)
            print *, "    Error: ", trim(result%error_message)
        end if
        
        ! Test path parsing
        call test_path_parsing(library_paths)
        
        print *
    end subroutine test_specific_paths

    subroutine simulate_distribution_detection(library_paths, result)
        character(len=*), intent(in) :: library_paths
        type(freetype_detection_result), intent(out) :: result
        
        ! Initialize result
        result%available = .false.
        result%method_used = "system-paths"
        result%library_paths = ""
        result%version = ""
        result%error_message = ""
        
        ! Check if any of the paths might contain FreeType
        if (index(library_paths, "/usr/lib") > 0) then
            result%available = .true.
            result%library_paths = "/usr/lib"
            result%method_used = "system-paths"
        else if (index(library_paths, "/usr/lib64") > 0) then
            result%available = .true.
            result%library_paths = "/usr/lib64"
            result%method_used = "system-paths"
        else if (index(library_paths, "/lib") > 0) then
            result%available = .true.
            result%library_paths = "/lib"
            result%method_used = "system-paths"
        else
            result%error_message = "No standard library paths found"
        end if
    end subroutine simulate_distribution_detection

    subroutine test_path_parsing(library_paths)
        character(len=*), intent(in) :: library_paths
        character(len=256) :: individual_paths(10)
        integer :: path_count
        integer :: i
        
        call parse_colon_separated_paths(library_paths, individual_paths, path_count)
        
        print *, "    Parsed paths (", path_count, "):"
        do i = 1, path_count
            print *, "      ", trim(individual_paths(i))
        end do
    end subroutine test_path_parsing

    subroutine parse_colon_separated_paths(input_paths, output_paths, count)
        character(len=*), intent(in) :: input_paths
        character(len=*), intent(out) :: output_paths(:)
        integer, intent(out) :: count
        integer :: start_pos, end_pos, i
        
        count = 0
        start_pos = 1
        
        do i = 1, size(output_paths)
            end_pos = index(input_paths(start_pos:), ":")
            if (end_pos == 0) then
                ! Last path
                end_pos = len_trim(input_paths) + 1
            else
                end_pos = start_pos + end_pos - 2
            end if
            
            if (end_pos >= start_pos) then
                count = count + 1
                if (end_pos > len_trim(input_paths)) then
                    output_paths(count) = input_paths(start_pos:len_trim(input_paths))
                else
                    output_paths(count) = input_paths(start_pos:end_pos)
                end if
                start_pos = end_pos + 2
                
                if (start_pos > len_trim(input_paths)) exit
            else
                exit
            end if
        end do
    end subroutine parse_colon_separated_paths

end program test_freetype_linux_distributions