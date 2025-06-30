program test_forttf_buffer_capture
    !! Capture scanline buffer values for rows with known differences
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    integer, parameter :: test_char = 65  ! 'A'
    real(wp), parameter :: scale = 0.02_wp
    integer, parameter :: width = 20, height = 39
    
    ! Test specific row known to have differences
    call test_row_5_buffer_values()
    
contains

    subroutine test_row_5_buffer_values()
        type(stb_bitmap_t) :: bitmap
        type(stb_point_t), allocatable :: points(:)
        integer, allocatable :: contour_lengths(:)
        integer(c_int8_t), allocatable, target :: pixels(:)
        integer :: num_contours
        
        write(*,*) '=== BUFFER CAPTURE TEST ==='
        write(*,*) 'Capturing scanline buffer values for row 5'
        write(*,*)
        
        ! Initialize bitmap
        allocate(pixels(width * height))
        pixels = 0
        bitmap%w = width
        bitmap%h = height
        bitmap%stride = width
        bitmap%pixels => pixels
        
        ! Get glyph contours (use simple triangle first)
        allocate(points(3))
        points(1) = stb_point_t(x=2.0_wp, y=2.0_wp)
        points(2) = stb_point_t(x=8.0_wp, y=2.0_wp)
        points(3) = stb_point_t(x=5.0_wp, y=8.0_wp)
        
        allocate(contour_lengths(1))
        contour_lengths(1) = 3
        num_contours = 1
        
        ! Rasterize with debug output enabled for rows 5-10
        call stb_rasterize(bitmap, points, contour_lengths, num_contours, &
                          scale, scale, 0.0_wp, 0.0_wp, 0, 0, .false., c_null_ptr)
        
        write(*,*) '=== BUFFER CAPTURE COMPLETE ==='
        
        ! Clean up
        deallocate(pixels)
        if (allocated(points)) deallocate(points)
        if (allocated(contour_lengths)) deallocate(contour_lengths)
        
    end subroutine test_row_5_buffer_values

end program test_forttf_buffer_capture