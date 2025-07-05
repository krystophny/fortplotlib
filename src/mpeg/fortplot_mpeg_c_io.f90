module fortplot_mpeg_c_io
    use iso_c_binding
    implicit none
    private
    
    ! C stdio.h interface for exact compatibility with MPEG C implementation
    
    ! C file pointer type
    type, bind(c) :: c_file
        type(c_ptr) :: ptr
    end type c_file
    
    ! C stdio constants
    integer(c_int), parameter :: SEEK_SET = 0
    integer(c_int), parameter :: SEEK_CUR = 1  
    integer(c_int), parameter :: SEEK_END = 2
    integer(c_int), parameter :: EOF = -1
    
    ! C stdio function interfaces
    interface
        ! FILE *fopen(const char *filename, const char *mode)
        function c_fopen(filename, mode) bind(c, name="fopen") result(file_ptr)
            import :: c_char, c_ptr
            character(kind=c_char), intent(in) :: filename(*)
            character(kind=c_char), intent(in) :: mode(*)
            type(c_ptr) :: file_ptr
        end function c_fopen
        
        ! int fclose(FILE *stream)
        function c_fclose(stream) bind(c, name="fclose") result(status)
            import :: c_ptr, c_int
            type(c_ptr), value :: stream
            integer(c_int) :: status
        end function c_fclose
        
        ! int fseek(FILE *stream, long offset, int whence)
        function c_fseek(stream, offset, whence) bind(c, name="fseek") result(status)
            import :: c_ptr, c_long, c_int
            type(c_ptr), value :: stream
            integer(c_long), value :: offset
            integer(c_int), value :: whence
            integer(c_int) :: status
        end function c_fseek
        
        ! long ftell(FILE *stream)
        function c_ftell(stream) bind(c, name="ftell") result(position)
            import :: c_ptr, c_long
            type(c_ptr), value :: stream
            integer(c_long) :: position
        end function c_ftell
        
        ! int fgetc(FILE *stream)
        function c_fgetc(stream) bind(c, name="fgetc") result(char_code)
            import :: c_ptr, c_int
            type(c_ptr), value :: stream
            integer(c_int) :: char_code
        end function c_fgetc
        
        ! int fputc(int c, FILE *stream)
        function c_fputc(char_code, stream) bind(c, name="fputc") result(status)
            import :: c_int, c_ptr
            integer(c_int), value :: char_code
            type(c_ptr), value :: stream
            integer(c_int) :: status
        end function c_fputc
        
        ! size_t fwrite(const void *ptr, size_t size, size_t nmemb, FILE *stream)
        function c_fwrite(ptr, size, nmemb, stream) bind(c, name="fwrite") result(count)
            import :: c_ptr, c_size_t
            type(c_ptr), value :: ptr
            integer(c_size_t), value :: size
            integer(c_size_t), value :: nmemb
            type(c_ptr), value :: stream
            integer(c_size_t) :: count
        end function c_fwrite
        
        ! size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream)
        function c_fread(ptr, size, nmemb, stream) bind(c, name="fread") result(count)
            import :: c_ptr, c_size_t
            type(c_ptr), value :: ptr
            integer(c_size_t), value :: size
            integer(c_size_t), value :: nmemb
            type(c_ptr), value :: stream
            integer(c_size_t) :: count
        end function c_fread
    end interface
    
    public :: c_file, SEEK_SET, SEEK_CUR, SEEK_END, EOF
    public :: c_fopen, c_fclose, c_fseek, c_ftell, c_fgetc, c_fputc
    public :: c_fwrite, c_fread
    public :: c_string_from_fortran, c_string_terminate
    
contains
    
    function c_string_from_fortran(fortran_string) result(c_string)
        !! Convert Fortran string to null-terminated C string
        character(len=*), intent(in) :: fortran_string
        character(len=len(fortran_string)+1) :: c_string
        
        c_string = trim(fortran_string) // c_null_char
    end function c_string_from_fortran
    
    subroutine c_string_terminate(c_string, length)
        !! Ensure C string is null-terminated
        character(kind=c_char), intent(inout) :: c_string(*)
        integer, intent(in) :: length
        
        c_string(length + 1) = c_null_char
    end subroutine c_string_terminate
    
end module fortplot_mpeg_c_io