program test_stb_truetype
    !! Unit test for STB TrueType integration
    !! Tests that the new stb_truetype module works correctly
    use fortplot_stb_truetype
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use iso_c_binding
    implicit none
    
    logical :: all_tests_passed
    type(stb_fontinfo_t) :: font_info
    
    all_tests_passed = .true.
    
    print *, "=== STB TrueType Integration Tests ==="
    print *, ""
    
    ! Test font initialization
    if (.not. test_font_initialization()) all_tests_passed = .false.
    
    ! Test basic metrics
    if (.not. test_font_metrics()) all_tests_passed = .false.
    
    ! Test character rendering
    if (.not. test_character_rendering()) all_tests_passed = .false.
    
    if (all_tests_passed) then
        print *, "All STB TrueType tests PASSED"
        stop 0
    else
        print *, "Some STB TrueType tests FAILED"
        stop 1
    end if
    
contains

    function test_font_initialization() result(passed)
        !! Test that font can be initialized from file
        logical :: passed
        type(stb_fontinfo_t) :: test_font
        character(len=256) :: font_paths(3)
        integer :: i
        
        passed = .false.
        
        print *, "Test 1: Font Initialization"
        print *, "---------------------------"
        
        ! Try multiple common font paths
        font_paths(1) = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        font_paths(2) = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"  
        font_paths(3) = "/System/Library/Fonts/Helvetica.ttc"
        
        do i = 1, 3
            if (stb_init_font(test_font, trim(font_paths(i)))) then
                print *, "✅ Successfully loaded font:", trim(font_paths(i))
                print *, "   Font initialized successfully"
                print *, "   Using native Fortran implementation"
                
                call stb_cleanup_font(test_font)
                passed = .true.
                exit
            else
                print *, "❌ Failed to load font:", trim(font_paths(i))
            end if
        end do
        
        if (.not. passed) then
            print *, "ERROR: Could not load any test fonts"
        end if
        
    end function test_font_initialization
    
    function test_font_metrics() result(passed)
        !! Test font metrics functions
        logical :: passed
        type(stb_fontinfo_t) :: test_font
        integer :: ascent, descent, line_gap
        integer :: advance_width, left_side_bearing
        real(wp) :: scale
        character(len=256) :: font_path
        
        passed = .false.
        
        print *, ""
        print *, "Test 2: Font Metrics"
        print *, "--------------------"
        
        ! Try to load a font
        font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        if (.not. stb_init_font(test_font, font_path)) then
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            if (.not. stb_init_font(test_font, font_path)) then
                print *, "❌ Cannot load font for metrics test"
                return
            end if
        end if
        
        ! Test scale calculation
        scale = stb_scale_for_pixel_height(test_font, 12.0_wp)
        if (scale > 0.0_wp) then
            print *, "✅ Scale for 12px height:", scale
        else
            print *, "❌ Invalid scale factor:", scale
            call stb_cleanup_font(test_font)
            return
        end if
        
        ! Test vertical metrics
        call stb_get_font_vmetrics(test_font, ascent, descent, line_gap)
        print *, "✅ Vertical metrics: ascent=", ascent, " descent=", descent, " line_gap=", line_gap
        
        if (ascent <= 0 .or. descent >= 0) then
            print *, "❌ Suspicious vertical metrics values"
            call stb_cleanup_font(test_font)
            return
        end if
        
        ! Test character metrics for 'A'
        call stb_get_codepoint_hmetrics(test_font, iachar('A'), advance_width, left_side_bearing)
        print *, "✅ 'A' metrics: advance=", advance_width, " bearing=", left_side_bearing
        
        if (advance_width <= 0) then
            print *, "❌ Invalid advance width for 'A'"
            call stb_cleanup_font(test_font)
            return
        end if
        
        passed = .true.
        call stb_cleanup_font(test_font)
        
    end function test_font_metrics
    
    function test_character_rendering() result(passed)
        !! Test character bitmap rendering
        logical :: passed
        type(stb_fontinfo_t) :: test_font
        type(c_ptr) :: bitmap_ptr
        integer :: width, height, xoff, yoff
        integer :: ix0, iy0, ix1, iy1
        integer :: glyph_index
        real(wp) :: scale
        character(len=256) :: font_path
        
        passed = .false.
        
        print *, ""
        print *, "Test 3: Character Rendering"
        print *, "---------------------------"
        
        ! Try to load a font
        font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        if (.not. stb_init_font(test_font, font_path)) then
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            if (.not. stb_init_font(test_font, font_path)) then
                print *, "❌ Cannot load font for rendering test"
                return
            end if
        end if
        
        ! Test glyph lookup
        glyph_index = stb_find_glyph_index(test_font, iachar('A'))
        if (glyph_index == 0) then
            print *, "❌ Could not find glyph for 'A'"
            call stb_cleanup_font(test_font)
            return
        end if
        print *, "✅ Found glyph index for 'A':", glyph_index
        
        ! Calculate scale for 16px font
        scale = stb_scale_for_pixel_height(test_font, 16.0_wp)
        
        ! Test bounding box calculation
        call stb_get_codepoint_bitmap_box(test_font, iachar('A'), scale, scale, ix0, iy0, ix1, iy1)
        print *, "✅ 'A' bitmap box: (", ix0, ",", iy0, ") to (", ix1, ",", iy1, ")"
        
        if (ix1 <= ix0 .or. iy1 <= iy0) then
            print *, "❌ Invalid bitmap bounding box"
            call stb_cleanup_font(test_font)
            return
        end if
        
        ! Test bitmap rendering
        bitmap_ptr = stb_get_codepoint_bitmap(test_font, scale, scale, iachar('A'), width, height, xoff, yoff)
        
        if (.not. c_associated(bitmap_ptr)) then
            print *, "❌ Failed to render 'A' bitmap"
            call stb_cleanup_font(test_font)
            return
        end if
        
        print *, "✅ Rendered 'A' bitmap: ", width, "x", height, " offset=(", xoff, ",", yoff, ")"
        
        if (width <= 0 .or. height <= 0) then
            print *, "❌ Invalid bitmap dimensions"
            call stb_free_bitmap(bitmap_ptr)
            call stb_cleanup_font(test_font)
            return
        end if
        
        ! Test bitmap content (basic sanity check)
        if (.not. test_bitmap_content(bitmap_ptr, width, height)) then
            print *, "❌ Bitmap content validation failed"
            call stb_free_bitmap(bitmap_ptr)
            call stb_cleanup_font(test_font)
            return
        end if
        
        print *, "✅ Bitmap content validation passed"
        
        ! Clean up
        call stb_free_bitmap(bitmap_ptr)
        call stb_cleanup_font(test_font)
        passed = .true.
        
    end function test_character_rendering
    
    function test_bitmap_content(bitmap_ptr, width, height) result(valid)
        !! Basic validation of bitmap content
        type(c_ptr), intent(in) :: bitmap_ptr
        integer, intent(in) :: width, height
        logical :: valid
        integer(c_int8_t), pointer :: bitmap_data(:)
        integer :: i, non_zero_pixels, total_pixels
        
        valid = .false.
        
        ! Convert C pointer to Fortran pointer
        call c_f_pointer(bitmap_ptr, bitmap_data, [width * height])
        
        total_pixels = width * height
        non_zero_pixels = 0
        
        ! Count non-zero pixels (handle signed/unsigned conversion)
        do i = 1, total_pixels
            if (bitmap_data(i) /= 0) then  ! Check for any non-zero value, signed or unsigned
                non_zero_pixels = non_zero_pixels + 1
            end if
        end do
        
        print *, "   Bitmap analysis:", non_zero_pixels, "/", total_pixels, " pixels have ink"
        
        ! Sanity checks
        if (non_zero_pixels == 0) then
            print *, "   ERROR: No ink pixels found"
            return
        end if
        
        if (non_zero_pixels == total_pixels) then
            print *, "   ERROR: All pixels are ink (likely rendering error)"
            return
        end if
        
        ! Check for reasonable ink ratio (should be between 1% and 80% for normal characters)
        if (non_zero_pixels < total_pixels / 100 .or. non_zero_pixels > total_pixels * 4 / 5) then
            print *, "   WARNING: Unusual ink ratio"
        end if
        
        valid = .true.
        
    end function test_bitmap_content

end program test_stb_truetype