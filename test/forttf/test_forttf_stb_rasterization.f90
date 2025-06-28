program test_forttf_stb_rasterization
    implicit none

    logical :: test_passed

    call test_rasterize_sorted_edges_modifies_bitmap(test_passed)

    if (test_passed) then
        print *, "Test passed!"
    else
        print *, "Test failed!"
        error stop 1
    end if

contains

    subroutine test_rasterize_sorted_edges_modifies_bitmap(passed)
        use forttf_stb_raster, only: stb_rasterize_sorted_edges
        use forttf_types, only: stb_bitmap_t, stb_edge_t
        use iso_c_binding, only: c_null_ptr, c_int8_t
        logical, intent(out) :: passed

        type(stb_bitmap_t) :: bitmap
        type(stb_edge_t), allocatable :: edges(:)
        integer(c_int8_t), allocatable, target :: pixels(:)

        allocate(pixels(10*10))
        pixels = 0

        bitmap%w = 10
        bitmap%h = 10
        bitmap%stride = 10
        bitmap%pixels => pixels

        allocate(edges(0))

        call stb_rasterize_sorted_edges(bitmap, edges, 0, 1, 0, 0, c_null_ptr)

        passed = any(pixels /= 0)

    end subroutine test_rasterize_sorted_edges_modifies_bitmap

end program test_forttf_stb_rasterization
