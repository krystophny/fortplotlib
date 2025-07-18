module fortplot_freetype_dynamic_loading
    use iso_c_binding
    use fortplot_freetype_pkg_config, only: detect_freetype_cross_platform, &
                                             freetype_detection_result
    implicit none
    
    private
    public :: freetype_library_handle, load_freetype_library, cleanup_freetype_library
    public :: load_freetype_functions, load_specific_library
    
    ! Structure to hold library handle and metadata
    type :: freetype_library_handle
        type(c_ptr) :: lib_handle = c_null_ptr
        character(len=256) :: library_path = ""
        character(len=256) :: error_message = ""
        logical :: library_loaded = .false.
        logical :: functions_loaded = .false.
        integer :: functions_loaded_count = 0
        
        ! Function pointers for key FreeType functions
        type(c_funptr) :: ft_init_freetype = c_null_funptr
        type(c_funptr) :: ft_done_freetype = c_null_funptr
        type(c_funptr) :: ft_new_face = c_null_funptr
        type(c_funptr) :: ft_done_face = c_null_funptr
        type(c_funptr) :: ft_set_pixel_sizes = c_null_funptr
        type(c_funptr) :: ft_load_glyph = c_null_funptr
        type(c_funptr) :: ft_render_glyph = c_null_funptr
        type(c_funptr) :: ft_get_char_index = c_null_funptr
    end type freetype_library_handle
    
    ! Dynamic library loading interfaces
    interface
        function dlopen(filename, flag) bind(C, name="dlopen")
            import :: c_ptr, c_char, c_int
            character(c_char), intent(in) :: filename(*)
            integer(c_int), value :: flag
            type(c_ptr) :: dlopen
        end function dlopen
        
        function dlsym(handle, symbol) bind(C, name="dlsym")
            import :: c_ptr, c_funptr, c_char
            type(c_ptr), value :: handle
            character(c_char), intent(in) :: symbol(*)
            type(c_funptr) :: dlsym
        end function dlsym
        
        function dlclose(handle) bind(C, name="dlclose")
            import :: c_ptr, c_int
            type(c_ptr), value :: handle
            integer(c_int) :: dlclose
        end function dlclose
        
        function dlerror() bind(C, name="dlerror")
            import :: c_ptr
            type(c_ptr) :: dlerror
        end function dlerror
    end interface
    
    integer(c_int), parameter :: RTLD_LAZY = 1
    integer(c_int), parameter :: RTLD_NOW = 2
    integer(c_int), parameter :: RTLD_GLOBAL = 256
    
contains

    subroutine load_freetype_library(handle, success)
        type(freetype_library_handle), intent(out) :: handle
        logical, intent(out) :: success
        type(freetype_detection_result) :: detection_result
        character(len=512) :: full_path
        
        ! Initialize handle
        call initialize_handle(handle)
        success = .false.
        
        ! Use cross-platform detection to find FreeType
        call detect_freetype_cross_platform(detection_result)
        
        if (.not. detection_result%available) then
            handle%error_message = "FreeType not detected on system"
            return
        end if
        
        ! Try to load using detected library paths
        call try_load_from_paths(handle, detection_result%library_paths, success)
        
        if (.not. success) then
            ! Fallback to standard library names
            call try_load_standard_names(handle, success)
        end if
        
        if (success) then
            handle%library_loaded = .true.
            call load_freetype_functions(handle, success)
        end if
    end subroutine load_freetype_library

    subroutine load_specific_library(handle, library_name, success)
        type(freetype_library_handle), intent(out) :: handle
        character(len=*), intent(in) :: library_name
        logical, intent(out) :: success
        
        call initialize_handle(handle)
        success = .false.
        
        handle%lib_handle = dlopen(trim(library_name)//c_null_char, RTLD_LAZY)
        
        if (c_associated(handle%lib_handle)) then
            success = .true.
            handle%library_loaded = .true.
            handle%library_path = trim(library_name)
        else
            call get_dl_error_message(handle%error_message)
        end if
    end subroutine load_specific_library

    subroutine try_load_from_paths(handle, library_paths, success)
        type(freetype_library_handle), intent(inout) :: handle
        character(len=*), intent(in) :: library_paths
        logical, intent(out) :: success
        character(len=512) :: full_path
        character(len=256) :: library_names(4)
        integer :: i, path_start, path_end
        
        success = .false.
        
        ! Common library names to try
        library_names(1) = "libfreetype.so.6"
        library_names(2) = "libfreetype.so"
        library_names(3) = "libfreetype.6.dylib"
        library_names(4) = "libfreetype.dylib"
        
        ! Parse library paths (colon-separated)
        path_start = 1
        do while (path_start <= len_trim(library_paths))
            path_end = index(library_paths(path_start:), ":")
            if (path_end == 0) then
                path_end = len_trim(library_paths) + 1
            else
                path_end = path_start + path_end - 2
            end if
            
            if (path_end >= path_start) then
                ! Try each library name in this path
                do i = 1, 4
                    if (path_end >= path_start) then
                        full_path = library_paths(path_start:path_end) // "/" // &
                                   trim(library_names(i))
                    else
                        full_path = trim(library_names(i))
                    end if
                    
                    handle%lib_handle = dlopen(trim(full_path)//c_null_char, RTLD_LAZY)
                    
                    if (c_associated(handle%lib_handle)) then
                        success = .true.
                        handle%library_path = trim(full_path)
                        return
                    end if
                end do
            end if
            
            path_start = path_end + 2  ! Skip past colon
        end do
        
        if (.not. success) then
            call get_dl_error_message(handle%error_message)
        end if
    end subroutine try_load_from_paths

    subroutine try_load_standard_names(handle, success)
        type(freetype_library_handle), intent(inout) :: handle
        logical, intent(out) :: success
        character(len=256) :: library_names(6)
        integer :: i
        
        success = .false.
        
        ! Try standard library names without full paths
        library_names(1) = "libfreetype.so.6"
        library_names(2) = "libfreetype.so"
        library_names(3) = "libfreetype.6.dylib"
        library_names(4) = "libfreetype.dylib"
        library_names(5) = "freetype.dll"
        library_names(6) = "freetype6.dll"
        
        do i = 1, 6
            handle%lib_handle = dlopen(trim(library_names(i))//c_null_char, RTLD_LAZY)
            
            if (c_associated(handle%lib_handle)) then
                success = .true.
                handle%library_path = trim(library_names(i))
                return
            end if
        end do
        
        if (.not. success) then
            call get_dl_error_message(handle%error_message)
        end if
    end subroutine try_load_standard_names

    subroutine load_freetype_functions(handle, success)
        type(freetype_library_handle), intent(inout) :: handle
        logical, intent(out) :: success
        character(len=64) :: function_names(8)
        integer :: i
        
        success = .false.
        handle%functions_loaded_count = 0
        
        if (.not. c_associated(handle%lib_handle)) then
            handle%error_message = "Library not loaded"
            return
        end if
        
        ! Define required function names
        function_names(1) = "FT_Init_FreeType"
        function_names(2) = "FT_Done_FreeType"
        function_names(3) = "FT_New_Face"
        function_names(4) = "FT_Done_Face"
        function_names(5) = "FT_Set_Pixel_Sizes"
        function_names(6) = "FT_Load_Glyph"
        function_names(7) = "FT_Render_Glyph"
        function_names(8) = "FT_Get_Char_Index"
        
        ! Load all required functions
        handle%ft_init_freetype = dlsym(handle%lib_handle, &
                                        trim(function_names(1))//c_null_char)
        if (c_associated(handle%ft_init_freetype)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        handle%ft_done_freetype = dlsym(handle%lib_handle, &
                                        trim(function_names(2))//c_null_char)
        if (c_associated(handle%ft_done_freetype)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        handle%ft_new_face = dlsym(handle%lib_handle, &
                                   trim(function_names(3))//c_null_char)
        if (c_associated(handle%ft_new_face)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        handle%ft_done_face = dlsym(handle%lib_handle, &
                                    trim(function_names(4))//c_null_char)
        if (c_associated(handle%ft_done_face)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        handle%ft_set_pixel_sizes = dlsym(handle%lib_handle, &
                                          trim(function_names(5))//c_null_char)
        if (c_associated(handle%ft_set_pixel_sizes)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        handle%ft_load_glyph = dlsym(handle%lib_handle, &
                                     trim(function_names(6))//c_null_char)
        if (c_associated(handle%ft_load_glyph)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        handle%ft_render_glyph = dlsym(handle%lib_handle, &
                                       trim(function_names(7))//c_null_char)
        if (c_associated(handle%ft_render_glyph)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        handle%ft_get_char_index = dlsym(handle%lib_handle, &
                                         trim(function_names(8))//c_null_char)
        if (c_associated(handle%ft_get_char_index)) then
            handle%functions_loaded_count = handle%functions_loaded_count + 1
        end if
        
        ! Check if all functions were loaded
        if (handle%functions_loaded_count == 8) then
            success = .true.
            handle%functions_loaded = .true.
        else
            write(handle%error_message, '(A,I0,A)') &
                "Only ", handle%functions_loaded_count, " out of 8 functions loaded"
        end if
    end subroutine load_freetype_functions

    subroutine cleanup_freetype_library(handle)
        type(freetype_library_handle), intent(inout) :: handle
        integer(c_int) :: result
        
        if (c_associated(handle%lib_handle)) then
            result = dlclose(handle%lib_handle)
        end if
        
        call initialize_handle(handle)
    end subroutine cleanup_freetype_library

    subroutine initialize_handle(handle)
        type(freetype_library_handle), intent(out) :: handle
        
        handle%lib_handle = c_null_ptr
        handle%library_path = ""
        handle%error_message = ""
        handle%library_loaded = .false.
        handle%functions_loaded = .false.
        handle%functions_loaded_count = 0
        
        handle%ft_init_freetype = c_null_funptr
        handle%ft_done_freetype = c_null_funptr
        handle%ft_new_face = c_null_funptr
        handle%ft_done_face = c_null_funptr
        handle%ft_set_pixel_sizes = c_null_funptr
        handle%ft_load_glyph = c_null_funptr
        handle%ft_render_glyph = c_null_funptr
        handle%ft_get_char_index = c_null_funptr
    end subroutine initialize_handle

    subroutine get_dl_error_message(error_message)
        character(len=*), intent(out) :: error_message
        type(c_ptr) :: error_ptr
        character(len=256), pointer :: error_str
        
        error_message = ""
        error_ptr = dlerror()
        
        if (c_associated(error_ptr)) then
            call c_f_pointer(error_ptr, error_str)
            error_message = error_str
        else
            error_message = "Unknown dynamic loading error"
        end if
    end subroutine get_dl_error_message

end module fortplot_freetype_dynamic_loading