program test_glyph_outline
    !! Test glyph outline parsing functionality
    !! This implements the first failing test for TDD of glyph outline parsing
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_letter_a_outline_parsing()

contains

    subroutine test_letter_a_outline_parsing()
        !! Test that letter 'A' glyph outline can be parsed into vertices
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success
        
        integer, parameter :: codepoint_a = 65  ! 'A'
        
        ! STB variables
        type(c_ptr) :: stb_vertices_ptr
        integer :: stb_num_vertices
        
        ! Pure Fortran variables (to be implemented)
        integer :: pure_num_vertices
        
        write(*,*) "=== Testing Letter 'A' Outline Parsing ==="
        
        ! Try multiple common font paths for cross-distribution compatibility
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize test fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)
        
        ! Test that we can get a glyph index for 'A'
        call test_glyph_index_lookup(pure_font, codepoint_a)
        
        ! Test Pure Fortran glyph outline parsing
        call test_outline_parsing(pure_font, codepoint_a)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)
        
    end subroutine test_letter_a_outline_parsing

    subroutine test_glyph_index_lookup(pure_font, codepoint)
        !! Test that we can look up glyph index for a codepoint
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        integer :: glyph_index
        
        glyph_index = stb_find_glyph_index_pure(pure_font, codepoint)
        if (glyph_index == 0) then
            write(*,*) "❌ Failed to find glyph index for codepoint", codepoint
            error stop 1
        end if
        
        write(*,*) "✅ Found glyph index", glyph_index, "for codepoint", codepoint
        
    end subroutine test_glyph_index_lookup

    subroutine test_outline_parsing(pure_font, codepoint)
        !! Test that we can parse glyph outline vertices
        type(stb_fontinfo_pure_t), intent(in) :: pure_font
        integer, intent(in) :: codepoint
        type(ttf_vertex_t), allocatable :: vertices(:)
        integer :: num_vertices
        
        num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint, vertices)
        if (num_vertices <= 0) then
            write(*,*) "❌ Failed to parse outline for codepoint", codepoint
            error stop 1
        end if
        
        write(*,*) "✅ Parsed", num_vertices, "vertices for codepoint", codepoint
        write(*,*) "   First vertex: type=", vertices(1)%type, "x=", vertices(1)%x, "y=", vertices(1)%y
        
        ! Cleanup
        call stb_free_shape_pure(vertices)
        
    end subroutine test_outline_parsing

end program test_glyph_outline