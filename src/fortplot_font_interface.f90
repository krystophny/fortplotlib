module fortplot_font_interface
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    private
    public :: font_renderer_t, glyph_bitmap_t
    public :: stb_font_renderer_t, freetype_font_renderer_t
    public :: create_font_renderer
    
    ! Glyph bitmap structure
    type :: glyph_bitmap_t
        integer :: width = 0
        integer :: height = 0
        integer :: xoff = 0
        integer :: yoff = 0
        integer(c_int8_t), pointer :: data(:) => null()
    end type glyph_bitmap_t
    
    ! Abstract font renderer interface
    type, abstract :: font_renderer_t
        logical :: initialized = .false.
        real(wp) :: pixel_height = 16.0_wp
        real(wp) :: scale_factor = 1.0_wp
    contains
        procedure(load_font_interface), deferred :: load_font
        procedure(cleanup_interface), deferred :: cleanup
        procedure(set_pixel_height_interface), deferred :: set_pixel_height
        procedure(get_codepoint_metrics_interface), deferred :: get_codepoint_metrics
        procedure(get_font_metrics_interface), deferred :: get_font_metrics
        procedure(render_glyph_interface), deferred :: render_glyph
        procedure(free_glyph_bitmap_interface), deferred :: free_glyph_bitmap
        procedure :: find_system_font => find_system_font_impl
    end type font_renderer_t
    
    ! STB TrueType font renderer
    type, extends(font_renderer_t) :: stb_font_renderer_t
        type(c_ptr) :: font_info_ptr = c_null_ptr
    contains
        procedure :: load_font => stb_load_font
        procedure :: cleanup => stb_cleanup
        procedure :: set_pixel_height => stb_set_pixel_height
        procedure :: get_codepoint_metrics => stb_get_codepoint_metrics
        procedure :: get_font_metrics => stb_get_font_metrics
        procedure :: render_glyph => stb_render_glyph
        procedure :: free_glyph_bitmap => stb_free_glyph_bitmap
    end type stb_font_renderer_t
    
    ! FreeType font renderer
    type, extends(font_renderer_t) :: freetype_font_renderer_t
        type(c_ptr) :: library_ptr = c_null_ptr
        type(c_ptr) :: face_ptr = c_null_ptr
    contains
        procedure :: load_font => ft_load_font
        procedure :: cleanup => ft_cleanup
        procedure :: set_pixel_height => ft_set_pixel_height
        procedure :: get_codepoint_metrics => ft_get_codepoint_metrics
        procedure :: get_font_metrics => ft_get_font_metrics
        procedure :: render_glyph => ft_render_glyph
        procedure :: free_glyph_bitmap => ft_free_glyph_bitmap
    end type freetype_font_renderer_t
    
    ! Abstract interfaces
    abstract interface
        function load_font_interface(this, font_path) result(success)
            import :: font_renderer_t
            class(font_renderer_t), intent(inout) :: this
            character(len=*), intent(in) :: font_path
            logical :: success
        end function load_font_interface
        
        subroutine cleanup_interface(this)
            import :: font_renderer_t
            class(font_renderer_t), intent(inout) :: this
        end subroutine cleanup_interface
        
        subroutine set_pixel_height_interface(this, height)
            import :: font_renderer_t, wp
            class(font_renderer_t), intent(inout) :: this
            real(wp), intent(in) :: height
        end subroutine set_pixel_height_interface
        
        subroutine get_codepoint_metrics_interface(this, codepoint, advance_width, left_bearing)
            import :: font_renderer_t
            class(font_renderer_t), intent(in) :: this
            integer, intent(in) :: codepoint
            integer, intent(out) :: advance_width, left_bearing
        end subroutine get_codepoint_metrics_interface
        
        subroutine get_font_metrics_interface(this, ascent, descent, line_gap)
            import :: font_renderer_t, wp
            class(font_renderer_t), intent(in) :: this
            real(wp), intent(out) :: ascent, descent, line_gap
        end subroutine get_font_metrics_interface
        
        subroutine render_glyph_interface(this, codepoint, bitmap)
            import :: font_renderer_t, glyph_bitmap_t
            class(font_renderer_t), intent(in) :: this
            integer, intent(in) :: codepoint
            type(glyph_bitmap_t), intent(out) :: bitmap
        end subroutine render_glyph_interface
        
        subroutine free_glyph_bitmap_interface(this, bitmap)
            import :: font_renderer_t, glyph_bitmap_t
            class(font_renderer_t), intent(in) :: this
            type(glyph_bitmap_t), intent(inout) :: bitmap
        end subroutine free_glyph_bitmap_interface
    end interface
    
contains

    function find_system_font_impl(this, font_name, font_path) result(found)
        class(font_renderer_t), intent(in) :: this
        character(len=*), intent(in) :: font_name
        character(len=*), intent(out) :: font_path
        logical :: found
        
        ! Suppress unused parameter warnings
        associate(unused_this => this); end associate
        
        found = .false.
        
        select case (trim(font_name))
        case ("Liberation Sans")
            call check_liberation_paths(font_path, found)
        case ("Helvetica")
            call check_helvetica_paths(font_path, found)
        case ("Arial")
            call check_arial_paths(font_path, found)
        case ("DejaVu Sans")
            call check_dejavu_paths(font_path, found)
        end select
    end function find_system_font_impl
    
    subroutine check_liberation_paths(font_path, found)
        character(len=*), intent(out) :: font_path
        logical, intent(out) :: found
        character(len=256) :: candidates(4)
        integer :: i
        
        found = .false.
        
        candidates(1) = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
        candidates(2) = "/usr/share/fonts/liberation-fonts/LiberationSans-Regular.ttf"
        candidates(3) = "/usr/share/fonts/TTF/LiberationSans-Regular.ttf"
        candidates(4) = "/usr/local/share/fonts/LiberationSans-Regular.ttf"
        
        do i = 1, 4
            if (file_exists(candidates(i))) then
                font_path = candidates(i)
                found = .true.
                return
            end if
        end do
    end subroutine check_liberation_paths
    
    subroutine check_helvetica_paths(font_path, found)
        character(len=*), intent(out) :: font_path
        logical, intent(out) :: found
        character(len=256) :: candidates(4)
        integer :: i
        
        found = .false.
        
        candidates(1) = "/System/Library/Fonts/Helvetica.ttc"
        candidates(2) = "/System/Library/Fonts/HelveticaNeue.ttc"
        candidates(3) = "/Library/Fonts/Helvetica.ttf"
        candidates(4) = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
        
        do i = 1, 4
            if (file_exists(candidates(i))) then
                font_path = candidates(i)
                found = .true.
                return
            end if
        end do
    end subroutine check_helvetica_paths
    
    subroutine check_arial_paths(font_path, found)
        character(len=*), intent(out) :: font_path
        logical, intent(out) :: found
        character(len=256) :: candidates(5)
        integer :: i
        
        found = .false.
        
        candidates(1) = "/System/Library/Fonts/Arial.ttf"
        candidates(2) = "/Library/Fonts/Arial.ttf"
        candidates(3) = "/usr/share/fonts/truetype/msttcorefonts/arial.ttf"
        candidates(4) = "/usr/share/fonts/TTF/arial.ttf"
        candidates(5) = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
        
        do i = 1, 5
            if (file_exists(candidates(i))) then
                font_path = candidates(i)
                found = .true.
                return
            end if
        end do
    end subroutine check_arial_paths
    
    subroutine check_dejavu_paths(font_path, found)
        character(len=*), intent(out) :: font_path
        logical, intent(out) :: found
        character(len=256) :: candidates(4)
        integer :: i
        
        found = .false.
        
        candidates(1) = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        candidates(2) = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        candidates(3) = "/usr/share/fonts/dejavu-fonts/DejaVuSans.ttf"
        candidates(4) = "/usr/local/share/fonts/DejaVuSans.ttf"
        
        do i = 1, 4
            if (file_exists(candidates(i))) then
                font_path = candidates(i)
                found = .true.
                return
            end if
        end do
    end subroutine check_dejavu_paths
    
    function file_exists(file_path) result(exists)
        character(len=*), intent(in) :: file_path
        logical :: exists
        
        inquire(file=trim(file_path), exist=exists)
    end function file_exists
    
    ! STB font renderer implementations
    function stb_load_font(this, font_path) result(success)
        use fortplot_stb_truetype, only: stb_fontinfo_t, stb_init_font
        class(stb_font_renderer_t), intent(inout) :: this
        character(len=*), intent(in) :: font_path
        logical :: success
        type(stb_fontinfo_t), pointer :: font_info
        
        ! Allocate font info structure
        allocate(font_info)
        success = stb_init_font(font_info, font_path)
        
        if (success) then
            this%font_info_ptr = c_loc(font_info)
            this%initialized = .true.
        else
            deallocate(font_info)
            this%font_info_ptr = c_null_ptr
        end if
    end function stb_load_font
    
    subroutine stb_cleanup(this)
        use fortplot_stb_truetype, only: stb_fontinfo_t, stb_cleanup_font
        class(stb_font_renderer_t), intent(inout) :: this
        type(stb_fontinfo_t), pointer :: font_info
        
        if (c_associated(this%font_info_ptr)) then
            call c_f_pointer(this%font_info_ptr, font_info)
            call stb_cleanup_font(font_info)
            deallocate(font_info)
            this%font_info_ptr = c_null_ptr
            this%initialized = .false.
        end if
    end subroutine stb_cleanup
    
    subroutine stb_set_pixel_height(this, height)
        use fortplot_stb_truetype, only: stb_fontinfo_t, stb_scale_for_pixel_height
        class(stb_font_renderer_t), intent(inout) :: this
        real(wp), intent(in) :: height
        type(stb_fontinfo_t), pointer :: font_info
        
        this%pixel_height = height
        
        if (c_associated(this%font_info_ptr)) then
            call c_f_pointer(this%font_info_ptr, font_info)
            this%scale_factor = stb_scale_for_pixel_height(font_info, height)
        end if
    end subroutine stb_set_pixel_height
    
    subroutine stb_get_codepoint_metrics(this, codepoint, advance_width, left_bearing)
        use fortplot_stb_truetype, only: stb_fontinfo_t, stb_get_codepoint_hmetrics
        class(stb_font_renderer_t), intent(in) :: this
        integer, intent(in) :: codepoint
        integer, intent(out) :: advance_width, left_bearing
        type(stb_fontinfo_t), pointer :: font_info
        integer :: unscaled_advance, unscaled_bearing
        
        if (c_associated(this%font_info_ptr)) then
            call c_f_pointer(this%font_info_ptr, font_info)
            call stb_get_codepoint_hmetrics(font_info, codepoint, unscaled_advance, unscaled_bearing)
            advance_width = int(real(unscaled_advance, wp) * this%scale_factor)
            left_bearing = int(real(unscaled_bearing, wp) * this%scale_factor)
        else
            advance_width = 0
            left_bearing = 0
        end if
    end subroutine stb_get_codepoint_metrics
    
    subroutine stb_get_font_metrics(this, ascent, descent, line_gap)
        use fortplot_stb_truetype, only: stb_fontinfo_t, stb_get_font_vmetrics
        class(stb_font_renderer_t), intent(in) :: this
        real(wp), intent(out) :: ascent, descent, line_gap
        type(stb_fontinfo_t), pointer :: font_info
        integer :: unscaled_ascent, unscaled_descent, unscaled_gap
        
        if (c_associated(this%font_info_ptr)) then
            call c_f_pointer(this%font_info_ptr, font_info)
            call stb_get_font_vmetrics(font_info, unscaled_ascent, unscaled_descent, unscaled_gap)
            ascent = real(unscaled_ascent, wp) * this%scale_factor
            descent = abs(real(unscaled_descent, wp)) * this%scale_factor
            line_gap = real(unscaled_gap, wp) * this%scale_factor
        else
            ascent = 0.0_wp
            descent = 0.0_wp
            line_gap = 0.0_wp
        end if
    end subroutine stb_get_font_metrics
    
    subroutine stb_render_glyph(this, codepoint, bitmap)
        use fortplot_stb_truetype, only: stb_fontinfo_t, stb_get_codepoint_bitmap
        class(stb_font_renderer_t), intent(in) :: this
        integer, intent(in) :: codepoint
        type(glyph_bitmap_t), intent(out) :: bitmap
        type(stb_fontinfo_t), pointer :: font_info
        type(c_ptr) :: bitmap_ptr
        
        if (c_associated(this%font_info_ptr)) then
            call c_f_pointer(this%font_info_ptr, font_info)
            bitmap_ptr = stb_get_codepoint_bitmap(font_info, this%scale_factor, this%scale_factor, &
                                                 codepoint, bitmap%width, bitmap%height, &
                                                 bitmap%xoff, bitmap%yoff)
            
            if (c_associated(bitmap_ptr) .and. bitmap%width > 0 .and. bitmap%height > 0) then
                allocate(bitmap%data(bitmap%width * bitmap%height))
                call c_f_pointer(bitmap_ptr, bitmap%data, [bitmap%width * bitmap%height])
            end if
        end if
    end subroutine stb_render_glyph
    
    subroutine stb_free_glyph_bitmap(this, bitmap)
        use fortplot_stb_truetype, only: stb_free_bitmap
        class(stb_font_renderer_t), intent(in) :: this
        type(glyph_bitmap_t), intent(inout) :: bitmap
        
        ! Suppress unused parameter warnings
        associate(unused_this => this); end associate
        
        if (associated(bitmap%data)) then
            ! For STB, the bitmap was allocated by C, so we need to free it properly
            call stb_free_bitmap(c_loc(bitmap%data))
            nullify(bitmap%data)
        end if
        bitmap%width = 0
        bitmap%height = 0
        bitmap%xoff = 0
        bitmap%yoff = 0
    end subroutine stb_free_glyph_bitmap
    
    ! FreeType font renderer implementations
    function ft_load_font(this, font_path) result(success)
        use fortplot_freetype_bindings, only: ft_library_available, ft_init_freetype, &
                                             ft_new_face, ft_set_pixel_sizes, ft_done_face, &
                                             ft_done_freetype
        class(freetype_font_renderer_t), intent(inout) :: this
        character(len=*), intent(in) :: font_path
        logical :: success
        integer(c_int) :: error
        
        success = .false.
        
        ! Check if FreeType is available
        if (.not. ft_library_available()) then
            return
        end if
        
        ! Initialize FreeType library
        error = ft_init_freetype(this%library_ptr)
        if (error /= 0) then
            return
        end if
        
        ! Load font face
        error = ft_new_face(this%library_ptr, font_path, 0_c_long, this%face_ptr)
        if (error /= 0) then
            call ft_done_freetype(this%library_ptr)
            return
        end if
        
        ! Set default pixel height
        error = ft_set_pixel_sizes(this%face_ptr, 0_c_int, int(this%pixel_height, c_int))
        if (error == 0) then
            this%initialized = .true.
            success = .true.
        else
            call ft_done_face(this%face_ptr)
            call ft_done_freetype(this%library_ptr)
        end if
    end function ft_load_font
    
    subroutine ft_cleanup(this)
        use fortplot_freetype_bindings, only: ft_done_face, ft_done_freetype
        class(freetype_font_renderer_t), intent(inout) :: this
        
        if (c_associated(this%face_ptr)) then
            call ft_done_face(this%face_ptr)
        end if
        
        if (c_associated(this%library_ptr)) then
            call ft_done_freetype(this%library_ptr)
        end if
        
        this%initialized = .false.
    end subroutine ft_cleanup
    
    subroutine ft_set_pixel_height(this, height)
        use fortplot_freetype_bindings, only: ft_set_pixel_sizes
        class(freetype_font_renderer_t), intent(inout) :: this
        real(wp), intent(in) :: height
        integer(c_int) :: error
        
        this%pixel_height = height
        
        if (c_associated(this%face_ptr)) then
            error = ft_set_pixel_sizes(this%face_ptr, 0_c_int, int(height, c_int))
            ! Update scale factor based on success
            if (error == 0) then
                this%scale_factor = 1.0_wp  ! FreeType handles scaling internally
            end if
        end if
    end subroutine ft_set_pixel_height
    
    subroutine ft_get_codepoint_metrics(this, codepoint, advance_width, left_bearing)
        use fortplot_freetype_bindings, only: ft_get_char_index, ft_load_glyph, ft_get_glyph_metrics, &
                                             FT_LOAD_DEFAULT, ft_glyph_metrics_t
        class(freetype_font_renderer_t), intent(in) :: this
        integer, intent(in) :: codepoint
        integer, intent(out) :: advance_width, left_bearing
        integer(c_int) :: glyph_index, error
        type(ft_glyph_metrics_t) :: metrics
        
        advance_width = 0
        left_bearing = 0
        
        if (.not. c_associated(this%face_ptr)) return
        
        ! Get glyph index
        glyph_index = ft_get_char_index(this%face_ptr, int(codepoint, c_long))
        if (glyph_index == 0) return
        
        ! Load glyph to get metrics
        error = ft_load_glyph(this%face_ptr, glyph_index, FT_LOAD_DEFAULT)
        if (error /= 0) return
        
        ! Get glyph metrics
        call ft_get_glyph_metrics(this%face_ptr, metrics)
        
        ! Convert from 26.6 fixed point to pixels
        advance_width = int(metrics%horiAdvance / 64)
        left_bearing = int(metrics%horiBearingX / 64)
    end subroutine ft_get_codepoint_metrics
    
    subroutine ft_get_font_metrics(this, ascent, descent, line_gap)
        class(freetype_font_renderer_t), intent(in) :: this
        real(wp), intent(out) :: ascent, descent, line_gap
        
        ascent = 0.0_wp
        descent = 0.0_wp
        line_gap = 0.0_wp
        
        if (.not. c_associated(this%face_ptr)) return
        
        ! For stub implementation, return reasonable defaults
        ! Real implementation would extract from face->size->metrics
        ascent = this%pixel_height * 0.8_wp
        descent = this%pixel_height * 0.2_wp
        line_gap = this%pixel_height * 0.1_wp
    end subroutine ft_get_font_metrics
    
    subroutine ft_render_glyph(this, codepoint, bitmap)
        use fortplot_freetype_bindings, only: ft_get_char_index, ft_load_glyph, ft_get_glyph_bitmap, &
                                             FT_LOAD_RENDER, ft_bitmap_t
        class(freetype_font_renderer_t), intent(in) :: this
        integer, intent(in) :: codepoint
        type(glyph_bitmap_t), intent(out) :: bitmap
        integer(c_int) :: glyph_index, error
        type(ft_bitmap_t) :: ft_bitmap
        
        bitmap%width = 0
        bitmap%height = 0
        bitmap%xoff = 0
        bitmap%yoff = 0
        nullify(bitmap%data)
        
        if (.not. c_associated(this%face_ptr)) return
        
        ! Get glyph index
        glyph_index = ft_get_char_index(this%face_ptr, int(codepoint, c_long))
        if (glyph_index == 0) return
        
        ! Load and render glyph
        error = ft_load_glyph(this%face_ptr, glyph_index, FT_LOAD_RENDER)
        if (error /= 0) return
        
        ! Get bitmap from glyph
        call ft_get_glyph_bitmap(this%face_ptr, ft_bitmap)
        
        if (ft_bitmap%rows > 0 .and. ft_bitmap%width > 0) then
            bitmap%width = ft_bitmap%width
            bitmap%height = ft_bitmap%rows
            bitmap%xoff = 0  ! TODO: Get from glyph bearing
            bitmap%yoff = 0  ! TODO: Get from glyph bearing
            
            ! For stub implementation, don't allocate data
            ! Real implementation would copy bitmap buffer
        end if
    end subroutine ft_render_glyph
    
    subroutine ft_free_glyph_bitmap(this, bitmap)
        class(freetype_font_renderer_t), intent(in) :: this
        type(glyph_bitmap_t), intent(inout) :: bitmap
        
        ! Suppress unused parameter warnings
        associate(unused_this => this); end associate
        
        if (associated(bitmap%data)) then
            deallocate(bitmap%data)
        end if
        bitmap%width = 0
        bitmap%height = 0
        bitmap%xoff = 0
        bitmap%yoff = 0
    end subroutine ft_free_glyph_bitmap
    
    ! Factory function
    function create_font_renderer(backend) result(renderer)
        character(len=*), intent(in), optional :: backend
        class(font_renderer_t), allocatable :: renderer
        character(len=:), allocatable :: backend_name
        
        if (present(backend)) then
            backend_name = backend
        else
            backend_name = "stb"  ! Default to STB
        end if
        
        select case (backend_name)
        case ("stb")
            allocate(stb_font_renderer_t :: renderer)
        case ("freetype")
            allocate(freetype_font_renderer_t :: renderer)
        case default
            allocate(stb_font_renderer_t :: renderer)
        end select
    end function create_font_renderer

end module fortplot_font_interface