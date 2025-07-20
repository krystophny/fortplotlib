program errorbar_demo
    !! Example demonstrating error bar plotting capabilities
    !! Shows symmetric/asymmetric error bars, customization, and integration
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot
    implicit none
    
    type(figure_t) :: fig
    real(wp) :: x(10), y(10), yerr(10), xerr(10)
    real(wp) :: yerr_lower(5), yerr_upper(5)
    integer :: i
    
    ! Create test data with calculated errors
    do i = 1, 10
        x(i) = real(i, wp)
        y(i) = sin(real(i, wp) * 0.5_wp) * 3.0_wp
        yerr(i) = 0.3_wp + abs(y(i)) * 0.1_wp  ! Variable error based on value
        xerr(i) = 0.2_wp
    end do
    
    ! Asymmetric error data
    do i = 1, 5
        yerr_lower(i) = 0.2_wp * real(i, wp)
        yerr_upper(i) = 0.4_wp * real(i, wp)
    end do
    
    ! Basic symmetric Y error bars
    call fig%initialize(800, 600)
    call fig%errorbar(x, y, yerr=yerr, label='Data with Y errors')
    call fig%legend()
    call fig%set_title('Basic Symmetric Y Error Bars')
    call fig%set_xlabel('X values')
    call fig%set_ylabel('Y values')
    call fig%savefig('plots/errorbar_basic_y.png')
    write(*,*) 'Created errorbar_basic_y.png'
    
    ! Symmetric X error bars
    call fig%initialize(800, 600)
    call fig%errorbar(x, y, xerr=xerr, label='Data with X errors')
    call fig%legend()
    call fig%set_title('Symmetric X Error Bars')
    call fig%set_xlabel('X values')
    call fig%set_ylabel('Y values')
    call fig%savefig('plots/errorbar_basic_x.png')
    write(*,*) 'Created errorbar_basic_x.png'
    
    ! Both X and Y error bars
    call fig%initialize(800, 600)
    call fig%errorbar(x, y, xerr=xerr, yerr=yerr, label='Data with XY errors')
    call fig%legend()
    call fig%set_title('Combined X and Y Error Bars')
    call fig%set_xlabel('X values')
    call fig%set_ylabel('Y values')
    call fig%savefig('plots/errorbar_combined.png')
    write(*,*) 'Created errorbar_combined.png'
    
    ! Asymmetric Y error bars
    call fig%initialize(800, 600)
    call fig%errorbar(x(1:5), y(1:5), yerr_lower=yerr_lower, yerr_upper=yerr_upper, &
                     label='Asymmetric errors')
    call fig%legend()
    call fig%set_title('Asymmetric Y Error Bars')
    call fig%set_xlabel('X values')
    call fig%set_ylabel('Y values')
    call fig%savefig('plots/errorbar_asymmetric.png')
    write(*,*) 'Created errorbar_asymmetric.png'
    
    ! Error bars with markers and customization
    call fig%initialize(800, 600)
    call fig%errorbar(x, y, yerr=yerr, marker='o', linestyle='--', &
                     capsize=8.0_wp, elinewidth=2.0_wp, &
                     color=[1.0_wp, 0.0_wp, 0.0_wp], label='Custom styling')
    call fig%legend()
    call fig%set_title('Customized Error Bars with Markers')
    call fig%set_xlabel('X values')
    call fig%set_ylabel('Y values')
    call fig%savefig('plots/errorbar_custom.png')
    write(*,*) 'Created errorbar_custom.png'
    
    ! Scientific data example
    call fig%initialize(800, 600)
    ! Generate experimental-style data
    do i = 1, 10
        x(i) = real(i - 1, wp) * 2.0_wp
        y(i) = 2.5_wp * exp(-x(i) * 0.1_wp) + 0.5_wp
        yerr(i) = 0.1_wp + y(i) * 0.05_wp  ! 5% relative error + 0.1 absolute
    end do
    
    call fig%errorbar(x, y, yerr=yerr, marker='s', linestyle='-', &
                     color=[0.0_wp, 0.5_wp, 0.8_wp], label='Experimental data')
    call fig%legend()
    call fig%set_title('Scientific Data with Error Bars')
    call fig%set_xlabel('Time (s)')
    call fig%set_ylabel('Signal amplitude')
    call fig%savefig('plots/errorbar_scientific.png')
    write(*,*) 'Created errorbar_scientific.png'
    
    write(*,*) 'Error bar demonstration completed!'
    
end program errorbar_demo