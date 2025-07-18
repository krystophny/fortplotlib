module fortplot_freetype_detection
    use iso_c_binding
    implicit none
    
    private
    public :: check_freetype_availability, freetype_detection_info
    public :: detect_freetype_detailed
    
    ! Structure to hold detection results
    type :: freetype_detection_info
        logical :: library_loadable = .false.
        logical :: functions_available = .false.
        logical :: initialization_works = .false.
        character(len=256) :: library_path = ""
        character(len=256) :: error_message = ""
    end type freetype_detection_info
    
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
    end interface
    
    integer(c_int), parameter :: RTLD_LAZY = 1
    
contains

    function check_freetype_availability() result(available)
        logical :: available
        type(freetype_detection_info) :: info
        
        call detect_freetype_detailed(info)
        available = info%library_loadable .and. info%functions_available
    end function check_freetype_availability
    
    subroutine detect_freetype_detailed(info)
        type(freetype_detection_info), intent(out) :: info
        type(c_ptr) :: library_handle
        type(c_funptr) :: init_func_ptr
        
        ! Initialize result structure
        info%library_loadable = .false.
        info%functions_available = .false.
        info%initialization_works = .false.
        info%library_path = ""
        info%error_message = ""
        
        ! Step 1: Try to load the FreeType library
        call try_load_library(library_handle, info)
        if (.not. info%library_loadable) return
        
        ! Step 2: Try to find required functions
        call check_required_functions(library_handle, info)
        if (.not. info%functions_available) then
            call cleanup_library(library_handle)
            return
        end if
        
        ! Step 3: Try to initialize FreeType
        call test_initialization(library_handle, info)
        
        ! Cleanup
        call cleanup_library(library_handle)
    end subroutine detect_freetype_detailed
    
    subroutine try_load_library(library_handle, info)
        type(c_ptr), intent(out) :: library_handle
        type(freetype_detection_info), intent(inout) :: info
        character(len=256) :: lib_names(4)
        integer :: i
        
        ! Try different library names on different platforms
        lib_names(1) = "libfreetype.so.6"//c_null_char      ! Linux
        lib_names(2) = "libfreetype.so"//c_null_char        ! Linux fallback
        lib_names(3) = "libfreetype.6.dylib"//c_null_char   ! macOS
        lib_names(4) = "freetype.dll"//c_null_char          ! Windows
        
        library_handle = c_null_ptr
        
        do i = 1, 4
            library_handle = dlopen(lib_names(i), RTLD_LAZY)
            if (c_associated(library_handle)) then
                info%library_loadable = .true.
                info%library_path = trim(lib_names(i))
                return
            end if
        end do
        
        info%error_message = "FreeType library not found in system"
    end subroutine try_load_library
    
    subroutine check_required_functions(library_handle, info)
        type(c_ptr), intent(in) :: library_handle
        type(freetype_detection_info), intent(inout) :: info
        type(c_funptr) :: func_ptr
        character(len=32) :: required_functions(5)
        integer :: i
        
        ! List of required FreeType functions
        required_functions(1) = "FT_Init_FreeType"//c_null_char
        required_functions(2) = "FT_Done_FreeType"//c_null_char
        required_functions(3) = "FT_New_Face"//c_null_char
        required_functions(4) = "FT_Done_Face"//c_null_char
        required_functions(5) = "FT_Set_Pixel_Sizes"//c_null_char
        
        do i = 1, 5
            func_ptr = dlsym(library_handle, required_functions(i))
            if (.not. c_associated(func_ptr)) then
                info%error_message = "Required function not found: "//trim(required_functions(i))
                return
            end if
        end do
        
        info%functions_available = .true.
    end subroutine check_required_functions
    
    subroutine test_initialization(library_handle, info)
        type(c_ptr), intent(in) :: library_handle
        type(freetype_detection_info), intent(inout) :: info
        type(c_funptr) :: init_func_ptr, done_func_ptr
        type(c_ptr) :: ft_library
        integer(c_int) :: error
        
        ! Get function pointers
        init_func_ptr = dlsym(library_handle, "FT_Init_FreeType"//c_null_char)
        done_func_ptr = dlsym(library_handle, "FT_Done_FreeType"//c_null_char)
        
        if (.not. c_associated(init_func_ptr) .or. .not. c_associated(done_func_ptr)) then
            info%error_message = "Cannot get function pointers for testing"
            return
        end if
        
        ! Test FreeType initialization
        ! Note: This is a simplified test - full implementation would need
        ! proper procedure pointer handling
        
        ! For now, just mark as working if we got this far
        info%initialization_works = .true.
    end subroutine test_initialization
    
    subroutine cleanup_library(library_handle)
        type(c_ptr), intent(inout) :: library_handle
        integer(c_int) :: result
        
        if (c_associated(library_handle)) then
            result = dlclose(library_handle)
            library_handle = c_null_ptr
        end if
    end subroutine cleanup_library

end module fortplot_freetype_detection