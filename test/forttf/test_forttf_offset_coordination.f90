program test_offset_coordination
    !! Test to verify the coordinate offset hypothesis
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_stb_raster, only: stbtt_rasterize
    use forttf_types, only: stb_bitmap_t
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call debug_offset_coordination()

contains

    subroutine debug_offset_coordination()
        !! Test different offset coordination strategies
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.5_wp

        ! STB reference bitmap
        type(c_ptr) :: stb_bitmap_ptr
        integer :: stb_width, stb_height, stb_xoff, stb_yoff
        integer(c_int8_t), pointer :: stb_bitmap(:)

        ! Pure Fortran test variants
        type(c_ptr) :: pure_bitmap_ptr
        integer :: pure_width, pure_height, pure_xoff, pure_yoff
        integer(c_int8_t), pointer :: pure_bitmap(:)

        type(ttf_vertex_t), allocatable :: vertices(:)
        integer :: num_vertices, glyph_index
        type(stb_bitmap_t) :: bitmap_struct
        integer(c_int8_t), allocatable, target :: test_bitmap(:)
        integer :: total_pixels, i, stb_count, pure_count, zero_offset_count

        write(*,*) "=== Testing Coordinate Offset Coordination ==="

        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts - skipping test"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)

        ! Get STB reference
        stb_bitmap_ptr = stb_get_codepoint_bitmap(stb_font, scale, scale, codepoint_a, &
                                                 stb_width, stb_height, stb_xoff, stb_yoff)
        if (.not. c_associated(stb_bitmap_ptr)) then
            write(*,*) "❌ STB failed to render"
            return
        end if

        write(*,*) "STB bitmap:", stb_width, "x", stb_height, " offset:", stb_xoff, stb_yoff

        call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])
        stb_count = 0
        do i = 1, stb_width * stb_height
            if (iand(int(stb_bitmap(i), kind=4), 255) /= 0) stb_count = stb_count + 1
        end do
        write(*,*) "STB non-zero pixels:", stb_count

        ! Test 1: Original Pure Fortran (with offset)
        write(*,*) "--- Test 1: Original Pure Fortran (with offset) ---"
        pure_bitmap_ptr = stb_get_codepoint_bitmap_pure(pure_font, scale, scale, codepoint_a, &
                                                       pure_width, pure_height, pure_xoff, pure_yoff)
        if (c_associated(pure_bitmap_ptr)) then
            call c_f_pointer(pure_bitmap_ptr, pure_bitmap, [pure_width * pure_height])
            pure_count = 0
            do i = 1, pure_width * pure_height
                if (iand(int(pure_bitmap(i), kind=4), 255) /= 0) pure_count = pure_count + 1
            end do
            write(*,*) "Pure Fortran non-zero pixels:", pure_count
            call stb_free_bitmap_pure(pure_bitmap_ptr)
        end if

        ! Test 2: Manual rasterization with zero offset
        write(*,*) "--- Test 2: Manual rasterization with ZERO offset ---"
        glyph_index = stb_find_glyph_index_pure(pure_font, codepoint_a)
        num_vertices = stb_get_glyph_shape_pure(pure_font, glyph_index, vertices)

        if (num_vertices > 0) then
            allocate(test_bitmap(stb_width * stb_height))
            test_bitmap = 0

            bitmap_struct%w = stb_width
            bitmap_struct%h = stb_height
            bitmap_struct%stride = stb_width
            bitmap_struct%pixels => test_bitmap

            ! Call stbtt_rasterize with ZERO offset (let it handle coordinates internally)
            call stbtt_rasterize(bitmap_struct, 0.35_wp, vertices, num_vertices, &
                                scale, scale, 0.0_wp, 0.0_wp, 0, 0, .false., c_null_ptr)

            zero_offset_count = 0
            do i = 1, stb_width * stb_height
                if (iand(int(test_bitmap(i), kind=4), 255) /= 0) zero_offset_count = zero_offset_count + 1
            end do
            write(*,*) "Zero offset non-zero pixels:", zero_offset_count

            call stb_free_shape_pure(vertices)
            deallocate(test_bitmap)
        end if

        ! Cleanup
        call stb_free_bitmap(stb_bitmap_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)

        write(*,*) "=== Summary ==="
        write(*,*) "STB reference:      ", stb_count, " pixels"
        write(*,*) "Pure (with offset): ", pure_count, " pixels"
        write(*,*) "Pure (zero offset): ", zero_offset_count, " pixels"

    end subroutine debug_offset_coordination

end program test_offset_coordination
