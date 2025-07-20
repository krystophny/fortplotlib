program test_boxplot
    !! Basic test for box plot functionality
    use iso_fortran_env, only: real64, wp => real64
    use fortplot, only: figure_t
    implicit none
    
    type(figure_t) :: fig
    real(wp), parameter :: test_data(10) = [1.0_wp, 2.0_wp, 3.0_wp, 4.0_wp, 5.0_wp, &
                                           6.0_wp, 7.0_wp, 8.0_wp, 9.0_wp, 10.0_wp]
    
    print *, 'Running box plot test...'
    
    call fig%initialize(800, 600)
    call fig%boxplot(test_data, label='Test Data')
    
    if (fig%plot_count == 1) then
        print *, 'PASS: Box plot created successfully'
    else
        print *, 'FAIL: Expected 1 plot, got', fig%plot_count
        stop 1
    end if
    
    if (allocated(fig%plots(1)%box_data)) then
        print *, 'PASS: Box data allocated correctly'
    else
        print *, 'FAIL: Box data not allocated'
        stop 1
    end if
    
    print *, 'All box plot tests PASSED!'
    
end program test_boxplot