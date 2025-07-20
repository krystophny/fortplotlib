program histogram_demo
    !! Example demonstrating histogram plotting capabilities
    !! Shows basic histogram, custom bins, and density normalization
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot
    implicit none
    
    integer, parameter :: n_data = 1000
    real(wp) :: data(n_data), normal_data(n_data)
    type(figure_t) :: fig
    integer :: i
    real(wp) :: pi = 3.14159265359_wp
    
    ! Generate random-like data (simple distribution)
    do i = 1, n_data
        data(i) = real(i, wp) / 100.0_wp + sin(real(i, wp) * 0.01_wp) * 5.0_wp
    end do
    
    ! Generate normal-like data using Box-Muller transform approximation
    do i = 1, n_data
        normal_data(i) = cos(2.0_wp * pi * real(i, wp) / real(n_data, wp)) * &
                        sqrt(-2.0_wp * log(max(real(mod(i, 1000), wp) / 1000.0_wp, 0.001_wp)))
    end do
    
    ! Basic histogram
    call fig%initialize(800, 600)
    call fig%hist(data)
    call fig%set_title('Basic Histogram Example')
    call fig%set_xlabel('Value')
    call fig%set_ylabel('Frequency')
    call fig%savefig('plots/histogram_basic.png')
    write(*,*) 'Created histogram_basic.png'
    
    ! Custom bins histogram  
    call fig%initialize(800, 600)
    call fig%hist(data, bins=20)
    call fig%set_title('Histogram with 20 Bins')
    call fig%set_xlabel('Value')
    call fig%set_ylabel('Frequency')
    call fig%savefig('plots/histogram_custom_bins.png')
    write(*,*) 'Created histogram_custom_bins.png'
    
    ! Density histogram
    call fig%initialize(800, 600)
    call fig%hist(normal_data, bins=15, density=.true.)
    call fig%set_title('Normalized Histogram (Density)')
    call fig%set_xlabel('Value')
    call fig%set_ylabel('Probability Density')
    call fig%savefig('plots/histogram_density.png')
    write(*,*) 'Created histogram_density.png'
    
    ! Multiple histograms with labels
    call fig%initialize(800, 600)
    call fig%hist(data(1:500), bins=15, label='Dataset 1', color=[0.0_wp, 0.447_wp, 0.698_wp])
    call fig%hist(normal_data(1:500), bins=15, label='Dataset 2', color=[0.835_wp, 0.369_wp, 0.0_wp])
    call fig%legend()
    call fig%set_title('Multiple Histograms')
    call fig%set_xlabel('Value')
    call fig%set_ylabel('Frequency')
    call fig%savefig('plots/histogram_multiple.png')
    write(*,*) 'Created histogram_multiple.png'
    
    write(*,*) 'Histogram demonstration completed!'
    
end program histogram_demo