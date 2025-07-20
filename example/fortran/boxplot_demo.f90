program boxplot_demo
    !! Box plot demonstration showing statistical visualization features
    
    use iso_fortran_env, only: real64, wp => real64
    use fortplot, only: figure_t
    implicit none
    
    type(figure_t) :: fig
    real(wp), parameter :: normal_data(20) = [1.2_wp, 1.5_wp, 1.8_wp, 2.1_wp, 2.4_wp, &
                                             2.7_wp, 3.0_wp, 3.3_wp, 3.6_wp, 3.9_wp, &
                                             4.2_wp, 4.5_wp, 4.8_wp, 5.1_wp, 5.4_wp, &
                                             5.7_wp, 6.0_wp, 6.3_wp, 6.6_wp, 6.9_wp]
    
    real(wp), parameter :: outlier_data(15) = [2.0_wp, 2.5_wp, 3.0_wp, 3.5_wp, 4.0_wp, &
                                              4.5_wp, 5.0_wp, 5.5_wp, 6.0_wp, 6.5_wp, &
                                              7.0_wp, 12.0_wp, 14.5_wp, 16.0_wp, 18.2_wp]
    
    real(wp), parameter :: group_a(10) = [1.0_wp, 2.0_wp, 3.0_wp, 4.0_wp, 5.0_wp, &
                                         6.0_wp, 7.0_wp, 8.0_wp, 9.0_wp, 10.0_wp]
    
    real(wp), parameter :: group_b(10) = [2.0_wp, 3.0_wp, 4.0_wp, 5.0_wp, 6.0_wp, &
                                         7.0_wp, 8.0_wp, 9.0_wp, 10.0_wp, 11.0_wp]
    
    real(wp), parameter :: group_c(10) = [3.0_wp, 4.0_wp, 5.0_wp, 6.0_wp, 7.0_wp, &
                                         8.0_wp, 9.0_wp, 10.0_wp, 11.0_wp, 12.0_wp]
    
    ! Single box plot
    call fig%initialize(800, 600)
    call fig%set_title('Single Box Plot Example')
    call fig%set_xlabel('Data Groups')
    call fig%set_ylabel('Values')
    call fig%boxplot(normal_data, label='Normal Distribution')
    call fig%savefig('plots/boxplot_single.png')
    print *, 'Created boxplot_single.png'
    
    ! Box plot with outliers
    call fig%initialize(800, 600)
    call fig%set_title('Box Plot with Outliers')
    call fig%set_xlabel('Data Groups')
    call fig%set_ylabel('Values')
    call fig%boxplot(outlier_data, label='Data with Outliers')
    call fig%savefig('plots/boxplot_outliers.png')
    print *, 'Created boxplot_outliers.png'
    
    ! Multiple box plots for comparison
    call fig%initialize(800, 600)
    call fig%set_title('Multiple Box Plot Comparison')
    call fig%set_xlabel('Groups')
    call fig%set_ylabel('Values')
    call fig%boxplot(group_a, position=1.0_wp, label='Group A')
    call fig%boxplot(group_b, position=2.0_wp, label='Group B')
    call fig%boxplot(group_c, position=3.0_wp, label='Group C')
    call fig%legend()
    call fig%savefig('plots/boxplot_comparison.png')
    print *, 'Created boxplot_comparison.png'
    
    ! Horizontal box plot
    call fig%initialize(800, 600)
    call fig%set_title('Horizontal Box Plot')
    call fig%set_xlabel('Values')
    call fig%set_ylabel('Data Groups')
    call fig%boxplot(normal_data, horizontal=.true., label='Horizontal')
    call fig%savefig('plots/boxplot_horizontal.png')
    print *, 'Created boxplot_horizontal.png'
    
    print *, 'Box plot demonstration completed!'
    
end program boxplot_demo