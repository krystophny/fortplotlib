program test_rasterization_quality
    !! TDD test to fix native rasterization issues compared to STB
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, int8
    use fortplot_truetype_native
    use fortplot_bmp, only: save_grayscale_bmp
    implicit none

    ! C interface to STB wrapper
    interface
        function stb_wrapper_load_font_from_file(wrapper, filename) bind(c, name='stb_wrapper_load_font_from_file') result(success)
            import :: c_ptr, c_char, c_int
            type(c_ptr), value :: wrapper
            character(kind=c_char), intent(in) :: filename(*)
            integer(c_int) :: success
        end function

        function stb_wrapper_scale_for_pixel_height(wrapper, height) bind(c, name='stb_wrapper_scale_for_pixel_height') result(scale)
            import :: c_ptr, c_float
            type(c_ptr), value :: wrapper
            real(c_float), value :: height
            real(c_float) :: scale
        end function

        function stb_wrapper_get_codepoint_bitmap(wrapper, scale_x, scale_y, codepoint, width, height, xoff, yoff) &
                bind(c, name='stb_wrapper_get_codepoint_bitmap') result(bitmap_ptr)
            import :: c_ptr, c_float, c_int
            type(c_ptr), value :: wrapper
            real(c_float), value :: scale_x, scale_y
            integer(c_int), value :: codepoint
            integer(c_int), intent(out) :: width, height, xoff, yoff
            type(c_ptr) :: bitmap_ptr
        end function

        subroutine stb_wrapper_free_bitmap(bitmap_ptr) bind(c, name='stb_wrapper_free_bitmap')
            import :: c_ptr
            type(c_ptr), value :: bitmap_ptr
        end subroutine

        subroutine stb_wrapper_cleanup_font(wrapper) bind(c, name='stb_wrapper_cleanup_font')
            import :: c_ptr
            type(c_ptr), value :: wrapper
        end subroutine
    end interface

    ! STB wrapper context structure
    type, bind(c) :: stb_fontinfo_wrapper_t
        type(c_ptr) :: data_ptr
        integer(c_int) :: fontstart
        integer(c_int) :: numGlyphs
        type(c_ptr) :: private_data
    end type

    ! Test parameters
    character(len=*), parameter :: FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"
    integer, parameter :: TEST_CODEPOINT = 65  ! 'A'
    real(wp), parameter :: FONT_SIZE = 24.0_wp

    ! Font objects
    type(stb_fontinfo_wrapper_t), target :: stb_wrapper
    type(native_fontinfo_t) :: native_font

    ! Results
    integer :: stb_width, stb_height, stb_xoff, stb_yoff
    integer :: native_width, native_height, native_xoff, native_yoff
    type(c_ptr) :: stb_bitmap_ptr
    integer(int8), pointer :: stb_bitmap(:), native_bitmap(:)
    real(c_float) :: scale

    logical :: success
    integer :: i, center_x, center_y, center_idx
    integer :: stb_center_val, native_center_val
    integer :: stb_nonzero_count, native_nonzero_count
    integer :: stb_top_ink, stb_bottom_ink, native_top_ink, native_bottom_ink
    logical :: stb_top_heavy, native_top_heavy

    print *, "=== TDD: Rasterization Quality Test ==="

    ! Initialize fonts
    success = (stb_wrapper_load_font_from_file(c_loc(stb_wrapper), FONT_PATH//c_null_char) == 1)
    if (.not. success) then
        print *, "ERROR: Failed to load STB font"
        stop 1
    end if

    success = native_init_font(native_font, FONT_PATH)
    if (.not. success) then
        print *, "ERROR: Failed to load native font"
        stop 1
    end if

    ! Get scale
    scale = stb_wrapper_scale_for_pixel_height(c_loc(stb_wrapper), real(FONT_SIZE, c_float))

    ! Render with STB
    stb_bitmap_ptr = stb_wrapper_get_codepoint_bitmap(c_loc(stb_wrapper), scale, scale, &
                                                      TEST_CODEPOINT, stb_width, stb_height, stb_xoff, stb_yoff)
    call c_f_pointer(stb_bitmap_ptr, stb_bitmap, [stb_width * stb_height])

    ! Render with native
    native_bitmap => native_get_codepoint_bitmap(native_font, real(scale, wp), real(scale, wp), &
                                                  TEST_CODEPOINT, native_width, native_height, native_xoff, native_yoff)

    print *, ""
    print *, "TEST 1: Bitmap dimensions must match"
    print *, "STB:    ", stb_width, "x", stb_height
    print *, "Native: ", native_width, "x", native_height
    if (stb_width /= native_width .or. stb_height /= native_height) then
        print *, "❌ FAIL: Dimensions don't match"
        call cleanup_and_exit(1)
    end if
    print *, "✅ PASS: Dimensions match"

    print *, ""
    print *, "TEST 2: Both should have reasonable ink coverage"
    ! Count total ink pixels first
    stb_nonzero_count = 0
    native_nonzero_count = 0
    do i = 1, stb_width * stb_height
        if (stb_bitmap(i) /= 0) stb_nonzero_count = stb_nonzero_count + 1
        if (native_bitmap(i) /= 0) native_nonzero_count = native_nonzero_count + 1
    end do
    
    print *, "STB ink pixels:    ", stb_nonzero_count, "/", stb_width * stb_height
    print *, "Native ink pixels: ", native_nonzero_count, "/", stb_width * stb_height
    
    ! STB should have reasonable coverage for 'A' 
    if (stb_nonzero_count < 20) then
        print *, "❌ FAIL: STB has too little ink - test setup issue"
        call cleanup_and_exit(1) 
    end if
    
    ! Native should have at least some ink
    if (native_nonzero_count < 5) then
        print *, "❌ FAIL: Native has almost no ink - rasterization completely broken"
        call save_comparison_bitmaps()
        call cleanup_and_exit(1)
    end if
    print *, "✅ PASS: Both have some ink coverage"

    print *, ""
    print *, "TEST 3: Similar number of ink pixels (coverage test)"
    ! (Already counted above)
    
    ! Native should have at least 60% of STB's ink pixels
    if (real(native_nonzero_count) < 0.6 * real(stb_nonzero_count)) then
        print *, "❌ FAIL: Native has too few ink pixels (<60% of STB)"
        print *, "Expected at least:", int(0.6 * real(stb_nonzero_count))
        call save_comparison_bitmaps()
        call cleanup_and_exit(1)
    end if
    print *, "✅ PASS: Native has sufficient ink pixels"

    print *, ""
    print *, "TEST 4: Y-axis orientation test (top vs bottom pixels)"
    ! Check if native is upside down by comparing top/bottom rows
    
    ! Count ink in top and bottom rows
    stb_top_ink = 0
    stb_bottom_ink = 0  
    native_top_ink = 0
    native_bottom_ink = 0
    
    do i = 1, stb_width
        ! Top row
        if (stb_bitmap(i) /= 0) stb_top_ink = stb_top_ink + 1
        if (native_bitmap(i) /= 0) native_top_ink = native_top_ink + 1
        ! Bottom row  
        if (stb_bitmap((stb_height-1)*stb_width + i) /= 0) stb_bottom_ink = stb_bottom_ink + 1
        if (native_bitmap((stb_height-1)*stb_width + i) /= 0) native_bottom_ink = native_bottom_ink + 1
    end do
    
    print *, "Top row ink - STB:", stb_top_ink, " Native:", native_top_ink  
    print *, "Bottom row ink - STB:", stb_bottom_ink, " Native:", native_bottom_ink
    
    ! For 'A', top should have more ink than bottom (peak vs base)
    ! If native is inverted, this relationship will be flipped
    stb_top_heavy = stb_top_ink > stb_bottom_ink
    native_top_heavy = native_top_ink > native_bottom_ink
    
    if (stb_top_heavy .neqv. native_top_heavy) then
        print *, "❌ FAIL: Y-axis orientation differs (native appears upside down)"
        call save_comparison_bitmaps()
        call cleanup_and_exit(1)
    end if
    print *, "✅ PASS: Y-axis orientation matches"

    call save_comparison_bitmaps()
    print *, ""
    print *, "🎉 ALL RASTERIZATION TESTS PASS!"
    
    call cleanup_and_exit(0)

contains

    subroutine save_comparison_bitmaps()
        call save_grayscale_bmp("test_raster_stb_A.bmp", stb_bitmap, stb_width, stb_height)
        call save_grayscale_bmp("test_raster_native_A.bmp", native_bitmap, native_width, native_height)
        print *, "Saved comparison: test_raster_stb_A.bmp vs test_raster_native_A.bmp"
    end subroutine

    subroutine cleanup_and_exit(exit_code)
        integer, intent(in) :: exit_code
        if (c_associated(stb_bitmap_ptr)) call stb_wrapper_free_bitmap(stb_bitmap_ptr)
        if (associated(native_bitmap)) call native_free_bitmap(native_bitmap)
        call stb_wrapper_cleanup_font(c_loc(stb_wrapper))
        call native_cleanup_font(native_font)
        stop exit_code
    end subroutine

end program test_rasterization_quality