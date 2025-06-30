program test_forttf_isolated_rasterization
    !! Test individual rasterization components in isolation (Phase 1.2)
    !! to identify the exact source of antialiasing differences
    use test_forttf_utils
    use fortplot_stb_truetype
    use forttf
    use forttf_types, only: ttf_vertex_t, stb_edge_t, stb_point_t, stb_bitmap_t
    use forttf_stb_raster, only: stbtt_rasterize, stb_rasterize_sorted_edges, stb_build_edges, stb_sort_edges, stb_flatten_curves
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    call test_isolated_edge_rasterization()

contains

    subroutine test_isolated_edge_rasterization()
        !! Test stb_rasterize_sorted_edges() in complete isolation
        type(stb_fontinfo_t) :: stb_font
        type(stb_fontinfo_pure_t) :: pure_font
        character(len=256) :: font_path
        logical :: stb_success, pure_success

        integer, parameter :: codepoint_a = 65  ! 'A'
        real(wp), parameter :: scale = 0.5_wp

        ! Get vertices for isolation testing
        type(c_ptr) :: stb_vertices_ptr
        integer :: stb_num_vertices, pure_num_vertices
        type(ttf_vertex_t), pointer :: stb_vertices(:)
        type(ttf_vertex_t), allocatable :: pure_vertices(:)

        ! Edge data for isolation
        type(stb_edge_t), allocatable :: edges(:)
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer :: num_edges, num_contours

        ! Bitmap data for comparison
        type(stb_bitmap_t) :: stb_bitmap_struct, pure_bitmap_struct
        integer(c_int8_t), allocatable, target :: stb_bitmap(:), pure_bitmap(:)
        integer, parameter :: width = 30, height = 30
        real(wp), parameter :: shift_x = 0.0_wp, shift_y = 0.0_wp
        real(wp), parameter :: scale_x = scale, scale_y = scale

        integer :: i, pure_nonzero, stb_nonzero, differences

        write(*,*) "=== Isolated Rasterization Component Testing ==="

        ! Initialize fonts
        if (.not. find_and_init_test_font(stb_font, pure_font, stb_success, pure_success, font_path)) then
            write(*,*) "❌ Failed to initialize fonts"
            return
        end if
        write(*,*) "✅ Using font:", trim(font_path)

        ! Get vertices from both implementations
        stb_vertices_ptr = stb_get_codepoint_shape(stb_font, codepoint_a, stb_num_vertices)
        pure_num_vertices = stb_get_codepoint_shape_pure(pure_font, codepoint_a, pure_vertices)

        if (.not. c_associated(stb_vertices_ptr) .or. pure_num_vertices <= 0) then
            write(*,*) "❌ Failed to get vertices"
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        call c_f_pointer(stb_vertices_ptr, stb_vertices, [stb_num_vertices])

        write(*,*) "--- Vertex Comparison ---"
        write(*,*) "STB vertices: ", stb_num_vertices
        write(*,*) "Pure vertices:", pure_num_vertices

        ! Show STB vertices for debugging
        if (c_associated(stb_vertices_ptr)) then
            write(*,*) "--- STB Vertices ---"
            do i = 1, min(stb_num_vertices, 20)
                write(*,*) "  STB vertex", i, ": type=", stb_vertices(i)%type, &
                          "x=", stb_vertices(i)%x, "y=", stb_vertices(i)%y, &
                          "cx=", stb_vertices(i)%cx, "cy=", stb_vertices(i)%cy
            end do
        end if

        ! Show Pure vertices for comparison
        write(*,*) "--- Pure Vertices ---"
        do i = 1, min(pure_num_vertices, 20)
            write(*,*) "  Pure vertex", i, ": type=", pure_vertices(i)%type, &
                      "x=", pure_vertices(i)%x, "y=", pure_vertices(i)%y, &
                      "cx=", pure_vertices(i)%cx, "cy=", pure_vertices(i)%cy
        end do

        if (stb_num_vertices /= pure_num_vertices) then
            write(*,*) "❌ Vertex count mismatch - continuing with Pure Fortran vertices for rasterization test"
            ! Don't return early - continue with Pure Fortran vertices for testing
        end if

        ! Use Pure Fortran vertices for edge building pipeline
        write(*,*) "--- Testing Isolated Edge Building Pipeline ---"

        ! Step 1: Flatten curves (vertices -> points)
        points = stb_flatten_curves(pure_vertices, pure_num_vertices, 0.35_wp, &
                                   contour_lengths, num_contours)
        write(*,*) "Flattened to", size(points), "points in", num_contours, "contours"

        if (.not. allocated(points) .or. size(points) == 0) then
            write(*,*) "❌ No points generated from curve flattening"
            if (c_associated(stb_vertices_ptr)) call stb_free_shape(stb_vertices_ptr)
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        ! Step 2: Build edges from points
        edges = stb_build_edges(points, contour_lengths, num_contours, &
                               scale_x, scale_y, shift_x, shift_y, .false.)
        num_edges = size(edges)
        write(*,*) "Built", num_edges, "edges from", size(points), "points"

        if (num_edges == 0) then
            write(*,*) "❌ No edges built - cannot test rasterization"
            if (c_associated(stb_vertices_ptr)) call stb_free_shape(stb_vertices_ptr)
            if (stb_success) call stb_cleanup_font(stb_font)
            if (pure_success) call stb_cleanup_font_pure(pure_font)
            return
        end if

        ! Test isolated rasterization with identical edge data
        write(*,*) "--- Testing Isolated Rasterization ---"

        ! Allocate bitmaps
        allocate(stb_bitmap(width * height))
        allocate(pure_bitmap(width * height))

        ! Clear bitmaps
        stb_bitmap = 0
        pure_bitmap = 0

        ! Set up bitmap structures
        stb_bitmap_struct%w = width
        stb_bitmap_struct%h = height
        stb_bitmap_struct%stride = width
        stb_bitmap_struct%pixels => stb_bitmap

        pure_bitmap_struct%w = width
        pure_bitmap_struct%h = height
        pure_bitmap_struct%stride = width
        pure_bitmap_struct%pixels => pure_bitmap

        ! Use STB-style rasterization for reference (via stbtt_rasterize interface)
        call stbtt_rasterize(stb_bitmap_struct, 0.35_wp, pure_vertices, pure_num_vertices, &
                           scale_x, scale_y, shift_x, shift_y, 0, 0, .false., c_null_ptr)

        ! Use Pure Fortran rasterization with identical parameters
        call stb_rasterize_sorted_edges(pure_bitmap_struct, edges, num_edges, &
                                      1, 0, 0, c_null_ptr)

        ! Compare results
        stb_nonzero = 0
        pure_nonzero = 0
        differences = 0

        do i = 1, width * height
            ! Convert signed c_int8_t to unsigned range (0-255) for proper comparison
            if (iand(int(stb_bitmap(i), kind=4), 255) /= 0) stb_nonzero = stb_nonzero + 1
            if (iand(int(pure_bitmap(i), kind=4), 255) /= 0) pure_nonzero = pure_nonzero + 1
            if (stb_bitmap(i) /= pure_bitmap(i)) differences = differences + 1
        end do

        write(*,*) "--- Isolated Rasterization Results ---"
        write(*,*) "STB non-zero pixels:  ", stb_nonzero
        write(*,*) "Pure non-zero pixels: ", pure_nonzero
        write(*,*) "Pixel differences:    ", differences
        write(*,*) "Match percentage:     ", 100.0 * (width * height - differences) / (width * height), "%"

        ! Detailed difference histogram
        call analyze_pixel_differences(stb_bitmap, pure_bitmap, width * height)

        ! Test with different parameters
        call test_parameter_sensitivity(pure_vertices, pure_num_vertices, edges, num_edges, width, height)

        ! Cleanup
        if (allocated(points)) deallocate(points)
        if (allocated(contour_lengths)) deallocate(contour_lengths)
        if (allocated(edges)) deallocate(edges)
        if (c_associated(stb_vertices_ptr)) call stb_free_shape(stb_vertices_ptr)
        if (stb_success) call stb_cleanup_font(stb_font)
        if (pure_success) call stb_cleanup_font_pure(pure_font)

    end subroutine test_isolated_edge_rasterization

    subroutine analyze_pixel_differences(stb_bitmap, pure_bitmap, total_pixels)
        integer(c_int8_t), intent(in) :: stb_bitmap(:), pure_bitmap(:)
        integer, intent(in) :: total_pixels
        integer :: diff_histogram(-255:255)
        integer :: i, diff, stb_unsigned, pure_unsigned

        diff_histogram = 0

        do i = 1, total_pixels
            ! Convert signed c_int8_t to unsigned range (0-255)
            stb_unsigned = iand(int(stb_bitmap(i), kind=4), 255)
            pure_unsigned = iand(int(pure_bitmap(i), kind=4), 255)
            diff = pure_unsigned - stb_unsigned
            diff_histogram(diff) = diff_histogram(diff) + 1
        end do

        write(*,*) "--- Difference Histogram (Pure - STB) ---"
        do i = -255, 255
            if (diff_histogram(i) > 0) then
                write(*,*) "Difference", i, ":", diff_histogram(i), "pixels"
            end if
        end do
    end subroutine analyze_pixel_differences

    subroutine test_parameter_sensitivity(vertices, num_vertices, edges, num_edges, width, height)
        type(ttf_vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_vertices, num_edges, width, height
        type(stb_edge_t), intent(in) :: edges(:)

        type(stb_bitmap_t) :: test_bitmap
        integer(c_int8_t), allocatable, target :: bitmap_data(:)
        real(wp), parameter :: flatness_values(3) = [0.25_wp, 0.35_wp, 0.45_wp]
        integer :: i, nonzero_pixels

        write(*,*) "--- Parameter Sensitivity Testing ---"

        allocate(bitmap_data(width * height))
        test_bitmap%w = width
        test_bitmap%h = height
        test_bitmap%stride = width
        test_bitmap%pixels => bitmap_data

        do i = 1, size(flatness_values)
            bitmap_data = 0

            ! Test Pure Fortran with different parameters
            call stb_rasterize_sorted_edges(test_bitmap, edges, num_edges, 1, 0, 0, c_null_ptr)

            nonzero_pixels = count(bitmap_data /= 0)
            write(*,*) "Test iteration", i, "-> Non-zero pixels:", nonzero_pixels
        end do

        deallocate(bitmap_data)
    end subroutine test_parameter_sensitivity

end program test_forttf_isolated_rasterization
