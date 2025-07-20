program subplot_test
    use iso_fortran_env, only: real64, wp => real64
    use fortplot, only: figure_t
    implicit none
    
    type(figure_t) :: fig
    real(wp) :: x(5), y(5)
    integer :: i
    
    ! Generate simple data
    do i = 1, 5
        x(i) = real(i, wp)
        y(i) = real(i**2, wp)
    end do
    
    ! Create figure with background
    call fig%initialize(800, 600)
    
    ! Test regular plot first (should work)
    call fig%add_plot(x, y, label='Regular plot')
    call fig%savefig('plots/subplot_test_regular.png')
    print *, 'Created regular plot'
    
    ! Now test subplot
    call fig%initialize(800, 600)
    call fig%subplots(1, 1)  ! Single subplot
    call fig%subplot_plot(1, 1, x, y, label='Subplot plot')
    call fig%savefig('plots/subplot_test_single.png')
    print *, 'Created single subplot'
    
end program subplot_test