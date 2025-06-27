program test_truetype_glyph_parsing
    !! Test TrueType glyph parsing functionality
    use fortplot_stb_truetype
    use fortplot_truetype_native
    use fortplot_truetype_types, only: glyph_point_t
    use fortplot_truetype_parser, only: parse_glyph_header, parse_simple_glyph_endpoints, parse_simple_glyph_points
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    logical :: all_tests_passed
    character(len=256) :: font_path

    all_tests_passed = .true.
    font_path = "/System/Library/Fonts/Monaco.ttf"

    print *, "=== TrueType Glyph Parsing Tests ==="
    print *, ""

    ! Test 1: Glyph outline access
    if (.not. test_glyph_outline_access(font_path)) all_tests_passed = .false.

    ! Test 2: Glyph header parsing
    if (.not. test_glyph_header_parsing(font_path)) all_tests_passed = .false.

    ! Test 3: Simple glyph contour parsing
    if (.not. test_simple_glyph_contours(font_path)) all_tests_passed = .false.

    ! Test 4: Simple glyph point parsing
    if (.not. test_simple_glyph_points(font_path)) all_tests_passed = .false.

    print *, ""
    if (all_tests_passed) then
        print *, "✅ All glyph parsing tests PASSED"
        stop 0
    else
        print *, "❌ Some glyph parsing tests FAILED"
        stop 1
    end if

contains

    function test_glyph_outline_access(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success
        integer :: glyph_index

        passed = .false.

        print *, "Test 1: Glyph Outline Access"
        print *, "----------------------------"

        stb_success = stb_init_font(stb_font, font_path)
        native_success = native_init_font(native_font, font_path)

        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for glyph outline test"
            return
        end if

        ! Get glyph index for 'A'
        glyph_index = native_find_glyph_index(native_font, iachar('A'))
        print *, "Glyph index for 'A':", glyph_index

        ! Check infrastructure for glyph access
        if (allocated(native_font%glyph_offsets) .and. native_font%glyf_offset > 0) then
            print *, "✅ Native has glyph outline access infrastructure"
            print *, "   Glyf table offset:", native_font%glyf_offset
            
            if (glyph_index > 0 .and. glyph_index <= size(native_font%glyph_offsets) - 1) then
                print *, "   Glyph offset range:", native_font%glyph_offsets(glyph_index), &
                         "to", native_font%glyph_offsets(glyph_index + 1)
                print *, "   Glyph data length:", &
                         native_font%glyph_offsets(glyph_index + 1) - native_font%glyph_offsets(glyph_index)
                passed = .true.
            else
                print *, "❌ Invalid glyph index or bounds"
            end if
        else
            print *, "⚠️  Native missing glyf table or glyph offsets"
        end if

        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)

    end function test_glyph_outline_access

    function test_glyph_header_parsing(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(stb_fontinfo_t) :: stb_font
        type(native_fontinfo_t) :: native_font
        logical :: stb_success, native_success
        integer :: glyph_index
        integer :: native_contours, native_x0, native_y0, native_x1, native_y1
        integer :: stb_x0, stb_y0, stb_x1, stb_y1

        passed = .false.

        print *, ""
        print *, "Test 2: Glyph Header Parsing"
        print *, "-----------------------------"

        stb_success = stb_init_font(stb_font, font_path)
        native_success = native_init_font(native_font, font_path)

        if (.not. stb_success .or. .not. native_success) then
            print *, "❌ Cannot initialize fonts for glyph header test"
            return
        end if

        ! Get glyph index for 'A'
        glyph_index = native_find_glyph_index(native_font, iachar('A'))

        ! Parse glyph header with native implementation
        call parse_glyph_header(native_font, glyph_index, native_contours, &
                                native_x0, native_y0, native_x1, native_y1)

        ! Get STB bounding box for comparison
        call stb_get_glyph_box(stb_font, glyph_index, stb_x0, stb_y0, stb_x1, stb_y1)

        print *, "STB 'A' bounding box:   (", stb_x0, ",", stb_y0, ") to (", stb_x1, ",", stb_y1, ")"
        print *, "Native 'A' bounding box:(", native_x0, ",", native_y0, ") to (", native_x1, ",", native_y1, ")"
        print *, "Native number of contours:", native_contours

        ! Check if results are reasonable - STRICT TEST against STB
        if (native_contours <= 0) then
            print *, "❌ CRITICAL: Native glyph header parsing failed"
            print *, "   Expected positive contours, got:", native_contours
        else if (native_x0 >= native_x1 .or. native_y0 >= native_y1) then
            print *, "❌ CRITICAL: Invalid bounding box from native implementation"
            print *, "   Box: (", native_x0, ",", native_y0, ") to (", native_x1, ",", native_y1, ")"
        else if (abs(native_x0 - stb_x0) > 10 .or. abs(native_y0 - stb_y0) > 10 .or. &
                 abs(native_x1 - stb_x1) > 10 .or. abs(native_y1 - stb_y1) > 10) then
            print *, "❌ CRITICAL: Native bounding box differs significantly from STB"
            print *, "   Max difference allowed: 10 units"
            print *, "   X0 diff:", abs(native_x0 - stb_x0), "Y0 diff:", abs(native_y0 - stb_y0)
            print *, "   X1 diff:", abs(native_x1 - stb_x1), "Y1 diff:", abs(native_y1 - stb_y1)
        else
            print *, "✅ Native glyph header parsing matches STB within tolerance"
            print *, "   Contours > 0 indicates simple glyph"
            print *, "   Bounding box matches STB within 10 units"
            passed = .true.
        end if

        call stb_cleanup_font(stb_font)
        call native_cleanup_font(native_font)

    end function test_glyph_header_parsing

    function test_simple_glyph_contours(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(native_fontinfo_t) :: native_font
        logical :: native_success
        integer :: glyph_index
        integer :: native_contours, native_x0, native_y0, native_x1, native_y1
        integer :: glyph_start, glyph_end, glyph_size
        integer, allocatable :: endpoints(:)
        logical :: endpoints_success

        passed = .false.

        print *, ""
        print *, "Test 3: Simple Glyph Contour Parsing"
        print *, "-------------------------------------"

        native_success = native_init_font(native_font, font_path)

        if (.not. native_success) then
            print *, "❌ Cannot initialize font for simple glyph test"
            return
        end if

        ! Get glyph index for 'A'
        glyph_index = native_find_glyph_index(native_font, iachar('A'))

        ! Parse glyph header to verify it's a simple glyph
        call parse_glyph_header(native_font, glyph_index, native_contours, &
                                native_x0, native_y0, native_x1, native_y1)

        print *, "Glyph 'A' has", native_contours, "contours"

        if (native_contours > 0) then
            print *, "✅ Simple glyph detected (numberOfContours > 0)"

            ! Verify we can access the glyph data
            if (allocated(native_font%glyph_offsets)) then
                glyph_start = native_font%glyph_offsets(glyph_index)
                glyph_end = native_font%glyph_offsets(glyph_index + 1)
                glyph_size = glyph_end - glyph_start

                print *, "   Glyph data starts at offset:", glyph_start
                print *, "   Glyph data size:", glyph_size, "bytes"

                if (glyph_size > 10) then  ! Should have at least header + some data
                    print *, "✅ Sufficient glyph data available for parsing"

                    ! Test actual contour endpoint parsing
                    call parse_simple_glyph_endpoints(native_font, glyph_index, endpoints, endpoints_success)

                    if (endpoints_success .and. allocated(endpoints)) then
                        print *, "✅ Successfully parsed contour endpoints"
                        print *, "   Endpoints:", endpoints
                        print *, "   Total points in glyph:", endpoints(size(endpoints)) + 1
                        passed = .true.
                    else
                        print *, "❌ Failed to parse contour endpoints"
                    end if
                else
                    print *, "❌ Insufficient glyph data"
                end if
            else
                print *, "❌ No glyph offset data available"
            end if
        else if (native_contours == 0) then
            print *, "⚠️  Empty glyph (numberOfContours = 0)"
            passed = .true.  ! Empty glyphs are valid
        else
            print *, "⚠️  Composite glyph (numberOfContours < 0)"
            print *, "   Will need separate composite glyph handling"
            passed = .true.  ! Composite glyphs exist but need different handling
        end if

        call native_cleanup_font(native_font)

    end function test_simple_glyph_contours

    function test_simple_glyph_points(font_path) result(passed)
        character(len=*), intent(in) :: font_path
        logical :: passed
        type(native_fontinfo_t) :: native_font
        logical :: native_success
        integer :: glyph_index
        integer :: num_points
        type(glyph_point_t), allocatable :: points(:)
        logical :: points_success

        passed = .false.

        print *, ""
        print *, "Test 4: Simple Glyph Point Parsing"
        print *, "-----------------------------------"

        native_success = native_init_font(native_font, font_path)

        if (.not. native_success) then
            print *, "❌ Cannot initialize font for simple glyph points test"
            return
        end if

        ! Get glyph index for 'A'
        glyph_index = native_find_glyph_index(native_font, iachar('A'))

        ! Parse the points
        call parse_simple_glyph_points(font_info=native_font, glyph_index=glyph_index, &
                                       points=points, num_points=num_points, success=points_success)

        if (points_success .and. allocated(points)) then
            print *, "✅ Successfully parsed glyph points for 'A'"
            print *, "   Number of points:", num_points
            if (num_points > 0) then
                print *, "   First point: (", points(1)%x, ",", points(1)%y, ") flags:", points(1)%flags
                if (num_points > 1) then
                    print *, "   Second point:(", points(2)%x, ",", points(2)%y, ") flags:", points(2)%flags
                end if
                print *, "   Last point:  (", points(num_points)%x, ",", points(num_points)%y, ") flags:", points(num_points)%flags
            end if
            passed = .true.
        else
            print *, "❌ Failed to parse glyph points"
        end if

        call native_cleanup_font(native_font)

    end function test_simple_glyph_points

end program test_truetype_glyph_parsing
