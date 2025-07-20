program test_histogram
    !! Test suite for histogram plotting functionality
    !! Tests histogram binning, data processing, and rendering
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_figure
    implicit none
    
    integer :: test_count = 0
    integer :: pass_count = 0
    
    call test_histogram_basic()
    call test_histogram_custom_bins()
    call test_histogram_density()
    call test_histogram_empty_data()
    
    call print_test_summary()
    
contains

    subroutine test_histogram_basic()
        type(figure_t) :: fig
        real(wp) :: data(10)
        integer :: i
        
        call start_test("Basic histogram")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 10
            data(i) = real(i, wp)
        end do
        
        ! Add histogram with default 10 bins
        call fig%hist(data)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Histogram plot count")
        
        call end_test()
    end subroutine test_histogram_basic

    subroutine test_histogram_custom_bins()
        type(figure_t) :: fig
        real(wp) :: data(10)
        integer :: i
        
        call start_test("Histogram with custom bins")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 10
            data(i) = real(i, wp)
        end do
        
        ! Add histogram with 5 bins
        call fig%hist(data, bins=5)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Custom bins histogram count")
        
        call end_test()
    end subroutine test_histogram_custom_bins

    subroutine test_histogram_density()
        type(figure_t) :: fig
        real(wp) :: data(100)
        integer :: i
        
        call start_test("Histogram with density normalization")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 100
            data(i) = real(i, wp) / 10.0_wp
        end do
        
        ! Add histogram with density normalization
        call fig%hist(data, density=.true.)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Density histogram count")
        
        call end_test()
    end subroutine test_histogram_density

    subroutine test_histogram_empty_data()
        type(figure_t) :: fig
        real(wp) :: data(0)
        
        call start_test("Histogram with empty data")
        
        call fig%initialize(640, 480)
        
        ! Add histogram with empty data - should handle gracefully
        call fig%hist(data)
        call assert_equal(real(fig%plot_count, wp), 0.0_wp, "Empty data histogram count")
        
        call end_test()
    end subroutine test_histogram_empty_data

    subroutine start_test(test_name)
        character(len=*), intent(in) :: test_name
        write(*, '(A, A)') 'Running test: ', test_name
    end subroutine start_test

    subroutine end_test()
        write(*, '(A)') 'Test completed'
        write(*, *)
    end subroutine end_test

    subroutine assert_equal(actual, expected, description)
        real(wp), intent(in) :: actual, expected
        character(len=*), intent(in) :: description
        real(wp), parameter :: tolerance = 1.0e-10_wp
        
        test_count = test_count + 1
        if (abs(actual - expected) < tolerance) then
            write(*, '(A, A)') '  PASS: ', description
            pass_count = pass_count + 1
        else
            write(*, '(A, A, F12.6, A, F12.6)') '  FAIL: ', description, actual, ' != ', expected
        end if
    end subroutine assert_equal

    subroutine print_test_summary()
        write(*, '(A)') '============================================'
        write(*, '(A, I0, A, I0, A)') 'Test Summary: ', pass_count, ' of ', test_count, ' tests passed'
        if (pass_count == test_count) then
            write(*, '(A)') 'All tests PASSED!'
        else
            write(*, '(A)') 'Some tests FAILED!'
        end if
    end subroutine print_test_summary

end program test_histogram