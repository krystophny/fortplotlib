program show_viewer_demo
    !! Demonstration of show_viewer() functionality
    !! 
    !! This program creates a simple plot and displays it using the system's
    !! default PDF viewer, similar to matplotlib.pyplot.show()
    !!
    !! Usage:
    !!   make example ARGS="show_viewer_demo"
    !!
    !! The plot will open in your default PDF viewer. Press Enter in the terminal
    !! to continue and clean up the temporary file.

    use fortplot
    use iso_fortran_env, only: wp => real64
    implicit none

    integer, parameter :: n = 100
    real(wp), dimension(n) :: x, y1, y2
    integer :: i

    ! Generate sample data
    do i = 1, n
        x(i) = real(i-1, wp) * 2.0_wp * 3.14159_wp / real(n-1, wp)
        y1(i) = sin(x(i))
        y2(i) = cos(x(i))
    end do

    ! Create figure and add plots
    call figure(800, 600)
    call title('Show Viewer Demo - Sine and Cosine Functions')
    call xlabel('x (radians)')
    call ylabel('y')

    call plot(x, y1, label='sin(x)', linestyle='b-')
    call plot(x, y2, label='cos(x)', linestyle='r--')
    call legend()

    ! Display in system viewer
    print *, '=== Show Viewer Demo ==='
    print *, 'Opening plot in system default PDF viewer...'
    print *, 'This demonstrates the new show_viewer() functionality.'
    print *, ''
    
    call show_viewer()
    
    print *, 'Demo completed successfully!'

end program show_viewer_demo