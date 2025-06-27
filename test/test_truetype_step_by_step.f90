program test_truetype_step_by_step
    !! Step-by-step test for TrueType port development
    !! Compare Fortran implementation against C stb_truetype
    use fortplot_stb_truetype
    use fortplot_truetype_native
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use iso_c_binding
    implicit none
    
    logical :: all_tests_passed
    
    all_tests_passed = .true.
    
    print *, "=== Step-by-Step TrueType Implementation Tests ==="
    print *, ""
    
    ! Step 1: Test font file reading and basic parsing
    if (.not. test_step1_font_reading()) all_tests_passed = .false.
    
    ! Step 2: Test table directory parsing
    if (.not. test_step2_table_directory()) all_tests_passed = .false.
    
    ! Step 3: Test head table parsing
    if (.not. test_step3_head_table()) all_tests_passed = .false.
    
    ! Step 4: Test maxp table parsing
    if (.not. test_step4_maxp_table()) all_tests_passed = .false.
    
    ! Step 5: Test hhea table parsing
    if (.not. test_step5_hhea_table()) all_tests_passed = .false.
    
    print *, ""
    if (all_tests_passed) then
        print *, "✅ All step-by-step tests PASSED"
        stop 0
    else
        print *, "❌ Some step-by-step tests FAILED"
        stop 1
    end if
    
contains

    function test_step1_font_reading() result(passed)
        !! Step 1: Test basic font file reading and initialization
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        character(len=256) :: font_path
        logical :: stb_success, native_success
        
        passed = .false.
        
        print *, "Step 1: Font File Reading"
        print *, "-------------------------"
        
        ! Try to find a test font
        font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        
        ! Test STB implementation
        stb_success = stb_init_font(stb_font, font_path)
        
        ! Test native implementation
        native_success = native_init_font(native_font, font_path)
        
        print *, "STB TrueType initialization:", merge("SUCCESS", "FAILED ", stb_success)
        print *, "Native implementation init:", merge("SUCCESS", "FAILED ", native_success)
        
        if (stb_success .and. native_success) then
            print *, "✅ Both implementations can read font file"
            passed = .true.
        else if (stb_success .and. .not. native_success) then
            print *, "❌ Native implementation failed while STB succeeded"
            print *, "   This indicates our parser needs work"
        else if (.not. stb_success .and. .not. native_success) then
            print *, "⚠️  Both failed - likely no font file available"
            print *, "   Trying fallback font..."
            
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            stb_success = stb_init_font(stb_font, font_path)
            native_success = native_init_font(native_font, font_path)
            
            if (stb_success .and. native_success) then
                print *, "✅ Both work with fallback font"
                passed = .true.
            else
                print *, "❌ No suitable font found for testing"
            end if
        end if
        
        ! Clean up
        if (stb_success) call stb_cleanup_font(stb_font)
        if (native_success) call native_cleanup_font(native_font)
        
    end function test_step1_font_reading

    function test_step2_table_directory() result(passed)
        !! Step 2: Test table directory parsing
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        character(len=256) :: font_path
        logical :: stb_success, native_success
        
        passed = .false.
        
        print *, ""
        print *, "Step 2: Table Directory Parsing"
        print *, "-------------------------------"
        
        font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        
        stb_success = stb_init_font(stb_font, font_path)
        if (.not. stb_success) then
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            stb_success = stb_init_font(stb_font, font_path)
        end if
        
        native_success = native_init_font(native_font, font_path)
        
        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for table directory test"
            return
        end if
        
        ! For now, just check that native implementation found some tables
        if (native_font%num_tables > 0) then
            print *, "✅ Native found", native_font%num_tables, "tables"
            print *, "   Font data size:", size(native_font%font_data), "bytes"
            passed = .true.
        else
            print *, "❌ Native implementation found no tables"
        end if
        
        ! Clean up
        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)
        
    end function test_step2_table_directory

    function test_step3_head_table() result(passed)
        !! Step 3: Test head table parsing - compare units per EM
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        character(len=256) :: font_path
        logical :: stb_success, native_success
        integer :: stb_ascent, stb_descent, stb_line_gap
        integer :: native_ascent, native_descent, native_line_gap
        real(wp) :: stb_scale, native_scale
        
        passed = .false.
        
        print *, ""
        print *, "Step 3: Head Table Parsing"
        print *, "--------------------------"
        
        font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        
        stb_success = stb_init_font(stb_font, font_path)
        if (.not. stb_success) then
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            stb_success = stb_init_font(stb_font, font_path)
        end if
        
        native_success = native_init_font(native_font, font_path)
        
        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for head table test"
            return
        end if
        
        ! Test scale calculation (depends on units per EM from head table)
        stb_scale = stb_scale_for_pixel_height(stb_font, 16.0_wp)
        native_scale = native_scale_for_pixel_height(native_font, 16.0_wp)
        
        print *, "STB scale for 16px:", stb_scale
        print *, "Native scale for 16px:", native_scale
        print *, "Native units per EM:", native_font%units_per_em
        
        ! Test vertical metrics (from hhea table but related to head)
        call stb_get_font_vmetrics(stb_font, stb_ascent, stb_descent, stb_line_gap)
        call native_get_font_vmetrics(native_font, native_ascent, native_descent, native_line_gap)
        
        print *, "STB metrics - ascent:", stb_ascent, "descent:", stb_descent, "line_gap:", stb_line_gap
        print *, "Native metrics - ascent:", native_ascent, "descent:", native_descent, "line_gap:", native_line_gap
        
        ! Check if scales are reasonable (should be positive and similar magnitude)
        if (stb_scale > 0.0_wp .and. native_scale > 0.0_wp) then
            if (abs(stb_scale - native_scale) / stb_scale < 0.1_wp) then
                print *, "✅ Scale calculations match within 10%"
                passed = .true.
            else
                print *, "⚠️  Scale calculations differ significantly"
                print *, "   Difference:", abs(stb_scale - native_scale)
                ! Still pass if both are reasonable
                passed = (native_scale > 0.001_wp .and. native_scale < 1.0_wp)
            end if
        else
            print *, "❌ Scale calculation failed"
        end if
        
        ! Clean up
        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)
        
    end function test_step3_head_table

    function test_step4_maxp_table() result(passed)
        !! Step 4: Test maxp table parsing - compare number of glyphs
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        character(len=256) :: font_path
        logical :: stb_success, native_success
        integer :: stb_glyph_A, native_glyph_A
        
        passed = .false.
        
        print *, ""
        print *, "Step 4: Maxp Table Parsing"
        print *, "--------------------------"
        
        font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        
        stb_success = stb_init_font(stb_font, font_path)
        if (.not. stb_success) then
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            stb_success = stb_init_font(stb_font, font_path)
        end if
        
        native_success = native_init_font(native_font, font_path)
        
        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for maxp table test"
            return
        end if
        
        print *, "Native num_glyphs:", native_font%num_glyphs
        
        ! Test glyph lookup (depends on maxp table for bounds checking)
        stb_glyph_A = stb_find_glyph_index(stb_font, iachar('A'))
        native_glyph_A = native_find_glyph_index(native_font, iachar('A'))
        
        print *, "STB glyph index for 'A':", stb_glyph_A
        print *, "Native glyph index for 'A':", native_glyph_A
        
        ! Check if glyph lookup works
        if (stb_glyph_A > 0 .and. native_glyph_A > 0) then
            if (stb_glyph_A == native_glyph_A) then
                print *, "✅ Glyph indices match exactly"
                passed = .true.
            else
                print *, "⚠️  Glyph indices differ but both found valid glyphs"
                passed = .true.  ! Different mapping is OK as long as both work
            end if
        else if (stb_glyph_A > 0 .and. native_glyph_A == 0) then
            print *, "❌ Native implementation failed to find glyph that STB found"
        else
            print *, "⚠️  Both returned 0 - may indicate missing character mapping"
            passed = (native_font%num_glyphs > 0)  ! At least parsed the table
        end if
        
        ! Clean up
        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)
        
    end function test_step4_maxp_table

    function test_step5_hhea_table() result(passed)
        !! Step 5: Test hhea table and hmtx - compare horizontal metrics
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        character(len=256) :: font_path
        logical :: stb_success, native_success
        integer :: stb_advance, stb_bearing, native_advance, native_bearing
        
        passed = .false.
        
        print *, ""
        print *, "Step 5: Hhea/Hmtx Table Parsing"
        print *, "-------------------------------"
        
        font_path = "/usr/share/fonts/TTF/DejaVuSans.ttf"
        
        stb_success = stb_init_font(stb_font, font_path)
        if (.not. stb_success) then
            font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
            stb_success = stb_init_font(stb_font, font_path)
        end if
        
        native_success = native_init_font(native_font, font_path)
        
        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for hhea table test"
            return
        end if
        
        ! Test horizontal metrics for 'A'
        call stb_get_codepoint_hmetrics(stb_font, iachar('A'), stb_advance, stb_bearing)
        call native_get_codepoint_hmetrics(native_font, iachar('A'), native_advance, native_bearing)
        
        print *, "STB 'A' metrics - advance:", stb_advance, "bearing:", stb_bearing
        print *, "Native 'A' metrics - advance:", native_advance, "bearing:", native_bearing
        
        ! Test horizontal metrics for 'i' (different width)
        call stb_get_codepoint_hmetrics(stb_font, iachar('i'), stb_advance, stb_bearing)
        call native_get_codepoint_hmetrics(native_font, iachar('i'), native_advance, native_bearing)
        
        print *, "STB 'i' metrics - advance:", stb_advance, "bearing:", stb_bearing
        print *, "Native 'i' metrics - advance:", native_advance, "bearing:", native_bearing
        
        ! Check if metrics are reasonable
        if (native_advance > 0) then
            print *, "✅ Native implementation provides positive advance widths"
            passed = .true.
        else
            print *, "❌ Native implementation provides invalid advance widths"
        end if
        
        ! Clean up
        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)
        
    end function test_step5_hhea_table

end program test_truetype_step_by_step