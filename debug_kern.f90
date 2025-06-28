program debug_kern
    use iso_c_binding
    use fortplot_stb
    use fortplot_truetype_types
    implicit none

    interface
        ! C wrapper functions
        function stb_init_wrapper(file_path, wrapper) bind(C, name="stb_wrapper_init")
            import :: c_ptr, c_char
            character(c_char), intent(in) :: file_path(*)
            type(c_ptr), intent(out) :: wrapper
            integer(c_int) :: stb_init_wrapper
        end function

        function stb_get_kerning_table_length(wrapper) bind(C, name="stb_wrapper_get_kerning_table_length")
            import :: c_ptr, c_int
            type(c_ptr), value, intent(in) :: wrapper
            integer(c_int) :: stb_get_kerning_table_length
        end function

        subroutine stb_cleanup_wrapper(wrapper) bind(C, name="stb_wrapper_cleanup")
            import :: c_ptr
            type(c_ptr), value, intent(in) :: wrapper
        end subroutine
    end interface

    type(c_ptr) :: stb_wrapper
    type(stb_fontinfo_pure_t) :: pure_font
    character(len=256) :: font_path
    integer :: result, kern_table_length_stb, kern_table_length_pure
    integer :: i

    font_path = "/System/Library/Fonts/Times.ttc" // c_null_char

    ! Initialize STB wrapper
    result = stb_init_wrapper(font_path, stb_wrapper)
    if (result == 0) then
        write(*,*) "ERROR: Failed to initialize STB wrapper"
        stop 1
    end if

    ! Get STB kerning table length
    kern_table_length_stb = stb_get_kerning_table_length(stb_wrapper)
    write(*,'(A,I0)') "STB kerning table length: ", kern_table_length_stb

    ! Initialize pure Fortran implementation
    if (.not. stb_init_font_pure(pure_font, "/System/Library/Fonts/Times.ttc")) then
        write(*,*) "ERROR: Failed to initialize pure font"
        call stb_cleanup_wrapper(stb_wrapper)
        stop 1
    end if

    ! Check if kern table exists
    do i = 1, size(pure_font%tables)
        if (pure_font%tables(i)%tag == "kern") then
            write(*,'(A,I0,A,I0)') "Found kern table at offset ", &
                pure_font%tables(i)%offset, " length ", pure_font%tables(i)%length
            exit
        end if
    end do

    ! Get pure kerning table length
    kern_table_length_pure = stb_get_kerning_table_length_pure(pure_font)
    write(*,'(A,I0)') "Pure kerning table length: ", kern_table_length_pure

    call stb_cleanup_font_pure(pure_font)
    call stb_cleanup_wrapper(stb_wrapper)

end program debug_kern
