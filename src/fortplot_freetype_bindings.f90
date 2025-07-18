module fortplot_freetype_bindings
    use iso_c_binding
    implicit none
    
    private
    public :: ft_init_freetype, ft_done_freetype
    public :: ft_new_face, ft_done_face
    public :: ft_set_pixel_sizes, ft_set_char_size
    public :: ft_get_char_index, ft_load_glyph, ft_render_glyph
    public :: ft_get_glyph_metrics, ft_get_glyph_bitmap
    public :: ft_library_available
    public :: ft_glyph_metrics_t, ft_bitmap_t
    public :: FT_LOAD_DEFAULT, FT_LOAD_RENDER, FT_LOAD_NO_HINTING
    public :: FT_LOAD_NO_BITMAP, FT_LOAD_FORCE_AUTOHINT
    
    ! Load flags
    integer(c_int), parameter :: FT_LOAD_DEFAULT = 0
    integer(c_int), parameter :: FT_LOAD_NO_SCALE = 1
    integer(c_int), parameter :: FT_LOAD_NO_HINTING = 2
    integer(c_int), parameter :: FT_LOAD_RENDER = 4
    integer(c_int), parameter :: FT_LOAD_NO_BITMAP = 8
    integer(c_int), parameter :: FT_LOAD_VERTICAL_LAYOUT = 16
    integer(c_int), parameter :: FT_LOAD_FORCE_AUTOHINT = 32
    
    ! Glyph metrics structure
    type, bind(C) :: ft_glyph_metrics_t
        integer(c_long) :: width
        integer(c_long) :: height
        integer(c_long) :: horiBearingX
        integer(c_long) :: horiBearingY
        integer(c_long) :: horiAdvance
        integer(c_long) :: vertBearingX
        integer(c_long) :: vertBearingY
        integer(c_long) :: vertAdvance
    end type ft_glyph_metrics_t
    
    ! Bitmap structure
    type, bind(C) :: ft_bitmap_t
        integer(c_int) :: rows
        integer(c_int) :: width
        integer(c_int) :: pitch
        type(c_ptr) :: buffer
        integer(c_short) :: num_grays
        integer(c_signed_char) :: pixel_mode
        integer(c_signed_char) :: palette_mode
        type(c_ptr) :: palette
    end type ft_bitmap_t
    
contains

    function ft_library_available() result(available)
        use fortplot_freetype_pkg_config, only: detect_freetype_cross_platform, &
                                                 freetype_detection_result
        logical :: available
        type(freetype_detection_result) :: result
        
        ! Use the comprehensive detection system
        call detect_freetype_cross_platform(result)
        available = result%available
    end function ft_library_available
    
    function ft_init_freetype(library) result(error)
        type(c_ptr), intent(out) :: library
        integer(c_int) :: error
        
        ! Stub implementation
        library = c_null_ptr
        error = -1  ! Not implemented
    end function ft_init_freetype
    
    subroutine ft_done_freetype(library)
        type(c_ptr), intent(inout) :: library
        
        ! Stub implementation
        library = c_null_ptr
    end subroutine ft_done_freetype
    
    function ft_new_face(library, filename, face_index, face) result(error)
        type(c_ptr), intent(in) :: library
        character(len=*), intent(in) :: filename
        integer(c_long), intent(in) :: face_index
        type(c_ptr), intent(out) :: face
        integer(c_int) :: error
        
        ! Stub implementation
        face = c_null_ptr
        error = -1
    end function ft_new_face
    
    subroutine ft_done_face(face)
        type(c_ptr), intent(inout) :: face
        
        ! Stub implementation
        face = c_null_ptr
    end subroutine ft_done_face
    
    function ft_set_pixel_sizes(face, pixel_width, pixel_height) result(error)
        type(c_ptr), intent(in) :: face
        integer(c_int), intent(in) :: pixel_width, pixel_height
        integer(c_int) :: error
        
        ! Stub implementation
        error = -1
    end function ft_set_pixel_sizes
    
    function ft_set_char_size(face, char_width, char_height, horz_res, vert_res) result(error)
        type(c_ptr), intent(in) :: face
        integer(c_long), intent(in) :: char_width, char_height
        integer(c_int), intent(in) :: horz_res, vert_res
        integer(c_int) :: error
        
        ! Stub implementation
        error = -1
    end function ft_set_char_size
    
    function ft_get_char_index(face, charcode) result(glyph_index)
        type(c_ptr), intent(in) :: face
        integer(c_long), intent(in) :: charcode
        integer(c_int) :: glyph_index
        
        ! Stub implementation
        glyph_index = 0
    end function ft_get_char_index
    
    function ft_load_glyph(face, glyph_index, load_flags) result(error)
        type(c_ptr), intent(in) :: face
        integer(c_int), intent(in) :: glyph_index, load_flags
        integer(c_int) :: error
        
        ! Stub implementation
        error = -1
    end function ft_load_glyph
    
    function ft_render_glyph(face, render_mode) result(error)
        type(c_ptr), intent(in) :: face
        integer(c_int), intent(in) :: render_mode
        integer(c_int) :: error
        
        ! Stub implementation
        error = -1
    end function ft_render_glyph
    
    subroutine ft_get_glyph_metrics(face, metrics)
        type(c_ptr), intent(in) :: face
        type(ft_glyph_metrics_t), intent(out) :: metrics
        
        ! Stub implementation - return zeros
        metrics%width = 0
        metrics%height = 0
        metrics%horiBearingX = 0
        metrics%horiBearingY = 0
        metrics%horiAdvance = 0
        metrics%vertBearingX = 0
        metrics%vertBearingY = 0
        metrics%vertAdvance = 0
    end subroutine ft_get_glyph_metrics
    
    subroutine ft_get_glyph_bitmap(face, bitmap)
        type(c_ptr), intent(in) :: face
        type(ft_bitmap_t), intent(out) :: bitmap
        
        ! Stub implementation - return empty bitmap
        bitmap%rows = 0
        bitmap%width = 0
        bitmap%pitch = 0
        bitmap%buffer = c_null_ptr
        bitmap%num_grays = 256
        bitmap%pixel_mode = 2_c_signed_char  ! FT_PIXEL_MODE_GRAY
        bitmap%palette_mode = 0_c_signed_char
        bitmap%palette = c_null_ptr
    end subroutine ft_get_glyph_bitmap

end module fortplot_freetype_bindings