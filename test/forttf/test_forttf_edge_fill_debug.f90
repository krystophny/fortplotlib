program test_forttf_edge_fill_debug
    !! Debug stb_fill_active_edges_with_offset function specifically
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    call test_edge_fill_function()
    
contains

    subroutine test_edge_fill_function()
        type(stb_active_edge_t), pointer :: active_head, edge1, edge2
        real(wp), allocatable :: scanline_buffer(:), scanline_fill_buffer(:)
        integer, parameter :: width = 20
        real(wp), parameter :: scan_y = 5.0_wp
        integer :: i
        
        write(*,*) '=== EDGE FILL DEBUG TEST ==='
        write(*,*) 'Testing stb_fill_active_edges_with_offset function'
        write(*,*)
        
        ! Allocate buffers
        allocate(scanline_buffer(width))
        allocate(scanline_fill_buffer(width + 1))
        
        ! Initialize buffers to zero
        scanline_buffer = 0.0_wp
        scanline_fill_buffer = 0.0_wp
        
        ! Create simple active edge list
        allocate(active_head)
        active_head%next => null()
        
        ! Create a test edge
        allocate(edge1)
        edge1%fx = 5.0_wp
        edge1%fdx = 0.5_wp
        edge1%sy = 4.0_wp
        edge1%ey = 6.0_wp
        edge1%direction = 1.0_wp
        edge1%next => null()
        
        active_head%next => edge1
        
        write(*,*) 'Created test edge: fx=', edge1%fx, ' fdx=', edge1%fdx
        write(*,*) 'Edge bounds: sy=', edge1%sy, ' ey=', edge1%ey
        write(*,*)
        
        ! Call the function we want to debug
        write(*,*) 'Calling stb_fill_active_edges_with_offset...'
        call stb_fill_active_edges_with_offset(edge1, scan_y, width, &
                                              scanline_buffer, scanline_fill_buffer)
        
        write(*,*) 'Function completed. Buffer values:'
        do i = 1, min(10, width)
            if (abs(scanline_buffer(i)) > 1e-10_wp .or. abs(scanline_fill_buffer(i)) > 1e-10_wp) then
                write(*,'(A,I2,A,F12.6,A,F12.6)') 'Col ', i-1, ' scanline=', scanline_buffer(i), &
                    ' fill=', scanline_fill_buffer(i)
            end if
        end do
        
        ! Clean up
        deallocate(edge1)
        deallocate(active_head)
        deallocate(scanline_buffer, scanline_fill_buffer)
        
    end subroutine test_edge_fill_function

end program test_forttf_edge_fill_debug