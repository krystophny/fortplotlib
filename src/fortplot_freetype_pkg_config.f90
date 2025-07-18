module fortplot_freetype_pkg_config
    use iso_c_binding
    implicit none
    
    private
    public :: check_pkg_config_available, get_freetype_library_paths
    public :: detect_freetype_cross_platform, freetype_detection_result
    public :: set_mock_pkg_config_unavailable
    
    ! Structure to hold cross-platform detection results
    type :: freetype_detection_result
        logical :: available = .false.
        character(len=256) :: method_used = ""
        character(len=1024) :: library_paths = ""
        character(len=64) :: version = ""
        character(len=256) :: error_message = ""
    end type freetype_detection_result
    
    ! Mock testing support
    logical :: mock_pkg_config_unavailable = .false.
    
contains

    function check_pkg_config_available() result(available)
        logical :: available
        integer :: exit_status
        
        if (mock_pkg_config_unavailable) then
            available = .false.
            return
        end if
        
        ! Check if pkg-config is available by running 'pkg-config --version'
        call execute_command_line("pkg-config --version > /dev/null 2>&1", &
                                  exitstat=exit_status)
        
        available = (exit_status == 0)
    end function check_pkg_config_available

    subroutine get_freetype_library_paths(library_paths, success)
        character(len=*), intent(out) :: library_paths
        logical, intent(out) :: success
        integer :: exit_status
        integer :: unit_num
        character(len=256) :: temp_file
        
        library_paths = ""
        success = .false.
        
        if (mock_pkg_config_unavailable) then
            return
        end if
        
        ! Create temporary file for command output
        call get_temp_filename(temp_file)
        
        ! Execute pkg-config command to get library paths
        call execute_command_line("pkg-config --libs-only-L freetype2 > " // &
                                  trim(temp_file) // " 2>&1", &
                                  exitstat=exit_status)
        
        if (exit_status /= 0) then
            ! Try alternative names
            call execute_command_line("pkg-config --libs-only-L freetype > " // &
                                      trim(temp_file) // " 2>&1", &
                                      exitstat=exit_status)
        end if
        
        if (exit_status == 0) then
            ! Read the output from temporary file
            open(newunit=unit_num, file=temp_file, status='old', &
                 action='read', iostat=exit_status)
            
            if (exit_status == 0) then
                read(unit_num, '(A)', iostat=exit_status) library_paths
                close(unit_num)
                
                if (exit_status == 0) then
                    success = .true.
                    ! Clean up the -L prefix from paths
                    call clean_library_paths(library_paths)
                end if
            end if
        end if
        
        ! Clean up temporary file
        call execute_command_line("rm -f " // trim(temp_file))
    end subroutine get_freetype_library_paths

    subroutine clean_library_paths(library_paths)
        character(len=*), intent(inout) :: library_paths
        character(len=1024) :: cleaned_paths
        integer :: i, j, path_start
        logical :: in_path
        
        cleaned_paths = ""
        j = 1
        i = 1
        in_path = .false.
        path_start = 1
        
        do while (i <= len_trim(library_paths))
            if (library_paths(i:i+1) == "-L") then
                ! Found -L prefix, skip it
                i = i + 2
                path_start = i
                in_path = .true.
            else if (library_paths(i:i) == " " .and. in_path) then
                ! End of current path
                if (j > 1) then
                    cleaned_paths(j:j) = ":"
                    j = j + 1
                end if
                
                ! Copy the path (without -L prefix)
                cleaned_paths(j:j+i-path_start-1) = library_paths(path_start:i-1)
                j = j + (i - path_start)
                in_path = .false.
                
                ! Skip spaces
                do while (i <= len_trim(library_paths) .and. library_paths(i:i) == " ")
                    i = i + 1
                end do
                i = i - 1  ! Adjust for loop increment
            end if
            i = i + 1
        end do
        
        ! Handle last path if we ended in the middle of one
        if (in_path) then
            if (j > 1) then
                cleaned_paths(j:j) = ":"
                j = j + 1
            end if
            cleaned_paths(j:j+len_trim(library_paths)-path_start) = &
                library_paths(path_start:len_trim(library_paths))
        end if
        
        library_paths = cleaned_paths
    end subroutine clean_library_paths

    subroutine detect_freetype_cross_platform(result)
        type(freetype_detection_result), intent(out) :: result
        character(len=1024) :: library_paths
        logical :: success
        
        ! Initialize result
        result%available = .false.
        result%method_used = ""
        result%library_paths = ""
        result%version = ""
        result%error_message = ""
        
        ! Method 1: Try pkg-config first (most reliable on Linux)
        if (check_pkg_config_available()) then
            result%method_used = "pkg-config"
            
            call get_freetype_library_paths(library_paths, success)
            if (success) then
                result%available = .true.
                result%library_paths = library_paths
                call get_freetype_version(result%version)
                return
            else
                result%error_message = "pkg-config found but freetype2 not available"
            end if
        end if
        
        ! Method 2: Check common system paths
        result%method_used = "system-paths"
        call detect_freetype_system_paths(result)
        if (result%available) return
        
        ! Method 3: Check macOS specific paths (Homebrew, etc.)
        result%method_used = "macos-paths"
        call detect_freetype_macos_paths(result)
        if (result%available) return
        
        ! Method 4: Check Windows paths
        result%method_used = "windows-paths"
        call detect_freetype_windows_paths(result)
        if (result%available) return
        
        ! If we get here, FreeType was not found
        result%method_used = "none"
        result%error_message = "FreeType not found using any detection method"
    end subroutine detect_freetype_cross_platform

    subroutine get_freetype_version(version)
        character(len=*), intent(out) :: version
        integer :: exit_status
        integer :: unit_num
        character(len=256) :: temp_file
        
        version = ""
        
        if (mock_pkg_config_unavailable) then
            return
        end if
        
        call get_temp_filename(temp_file)
        
        call execute_command_line("pkg-config --modversion freetype2 > " // &
                                  trim(temp_file) // " 2>&1", &
                                  exitstat=exit_status)
        
        if (exit_status /= 0) then
            call execute_command_line("pkg-config --modversion freetype > " // &
                                      trim(temp_file) // " 2>&1", &
                                      exitstat=exit_status)
        end if
        
        if (exit_status == 0) then
            open(newunit=unit_num, file=temp_file, status='old', &
                 action='read', iostat=exit_status)
            
            if (exit_status == 0) then
                read(unit_num, '(A)', iostat=exit_status) version
                close(unit_num)
            end if
        end if
        
        call execute_command_line("rm -f " // trim(temp_file))
    end subroutine get_freetype_version

    subroutine detect_freetype_system_paths(result)
        type(freetype_detection_result), intent(inout) :: result
        character(len=256) :: common_paths(8)
        character(len=512) :: full_path
        logical :: exists
        integer :: i
        
        ! Common Linux system paths
        common_paths(1) = "/usr/lib/x86_64-linux-gnu"
        common_paths(2) = "/usr/lib64"
        common_paths(3) = "/usr/lib"
        common_paths(4) = "/usr/local/lib"
        common_paths(5) = "/lib/x86_64-linux-gnu"
        common_paths(6) = "/lib64"
        common_paths(7) = "/lib"
        common_paths(8) = "/opt/lib"
        
        do i = 1, 8
            ! Check for libfreetype.so.6
            full_path = trim(common_paths(i)) // "/libfreetype.so.6"
            inquire(file=trim(full_path), exist=exists)
            
            if (exists) then
                result%available = .true.
                result%library_paths = trim(common_paths(i))
                return
            end if
            
            ! Check for libfreetype.so
            full_path = trim(common_paths(i)) // "/libfreetype.so"
            inquire(file=trim(full_path), exist=exists)
            
            if (exists) then
                result%available = .true.
                result%library_paths = trim(common_paths(i))
                return
            end if
        end do
        
        result%error_message = "FreeType not found in common system paths"
    end subroutine detect_freetype_system_paths

    subroutine detect_freetype_macos_paths(result)
        type(freetype_detection_result), intent(inout) :: result
        character(len=256) :: macos_paths(4)
        character(len=512) :: full_path
        logical :: exists
        integer :: i
        
        ! macOS specific paths
        macos_paths(1) = "/opt/homebrew/lib"      ! Apple Silicon Homebrew
        macos_paths(2) = "/usr/local/lib"         ! Intel Homebrew
        macos_paths(3) = "/usr/lib"               ! System libraries
        macos_paths(4) = "/opt/local/lib"         ! MacPorts
        
        do i = 1, 4
            ! Check for libfreetype.dylib
            full_path = trim(macos_paths(i)) // "/libfreetype.dylib"
            inquire(file=trim(full_path), exist=exists)
            
            if (exists) then
                result%available = .true.
                result%library_paths = trim(macos_paths(i))
                return
            end if
            
            ! Check for libfreetype.6.dylib
            full_path = trim(macos_paths(i)) // "/libfreetype.6.dylib"
            inquire(file=trim(full_path), exist=exists)
            
            if (exists) then
                result%available = .true.
                result%library_paths = trim(macos_paths(i))
                return
            end if
        end do
        
        result%error_message = "FreeType not found in macOS paths"
    end subroutine detect_freetype_macos_paths

    subroutine detect_freetype_windows_paths(result)
        type(freetype_detection_result), intent(inout) :: result
        character(len=256) :: windows_paths(3)
        character(len=512) :: full_path
        logical :: exists
        integer :: i
        
        ! Windows specific paths
        windows_paths(1) = "C:\Windows\System32"
        windows_paths(2) = "C:\Windows\SysWOW64"
        windows_paths(3) = "C:\Program Files\FreeType\lib"
        
        do i = 1, 3
            ! Check for freetype.dll
            full_path = trim(windows_paths(i)) // "\freetype.dll"
            inquire(file=trim(full_path), exist=exists)
            
            if (exists) then
                result%available = .true.
                result%library_paths = trim(windows_paths(i))
                return
            end if
        end do
        
        result%error_message = "FreeType not found in Windows paths"
    end subroutine detect_freetype_windows_paths

    subroutine set_mock_pkg_config_unavailable(unavailable)
        logical, intent(in) :: unavailable
        mock_pkg_config_unavailable = unavailable
    end subroutine set_mock_pkg_config_unavailable

    subroutine get_temp_filename(filename)
        character(len=*), intent(out) :: filename
        character(len=256) :: temp_dir
        integer :: pid
        
        ! Try to get a proper temporary directory
        call get_environment_variable("TMPDIR", temp_dir)
        if (len_trim(temp_dir) == 0) then
            call get_environment_variable("TMP", temp_dir)
        end if
        if (len_trim(temp_dir) == 0) then
            call get_environment_variable("TEMP", temp_dir)
        end if
        if (len_trim(temp_dir) == 0) then
            temp_dir = "/tmp"
        end if
        
        ! Create a unique filename using process ID
        pid = getpid()
        write(filename, '(A,A,I0,A)') trim(temp_dir), "/fortplot_", pid, ".tmp"
    end subroutine get_temp_filename

    function getpid() result(pid)
        integer :: pid
        integer :: values(8)
        
        ! Use date_and_time to get a pseudo-unique ID
        call date_and_time(values=values)
        pid = values(7) * 1000 + values(8)  ! milliseconds + subseconds
    end function getpid

end module fortplot_freetype_pkg_config