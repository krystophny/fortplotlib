program test_errorbar
    !! Test suite for error bar plotting functionality
    !! Tests symmetric/asymmetric error bars, customization, and integration
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_figure
    implicit none
    
    integer :: test_count = 0
    integer :: pass_count = 0
    
    call test_errorbar_symmetric_y()
    call test_errorbar_symmetric_x()
    call test_errorbar_asymmetric_y()
    call test_errorbar_both_xy()
    call test_errorbar_customization()
    call test_errorbar_integration()
    call test_errorbar_edge_cases()
    
    call print_test_summary()
    
contains

    subroutine test_errorbar_symmetric_y()
        type(figure_t) :: fig
        real(wp) :: x(5), y(5), yerr(5)
        integer :: i
        
        call start_test("Symmetric Y error bars")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 5
            x(i) = real(i, wp)
            y(i) = real(i * 2, wp)
            yerr(i) = 0.5_wp
        end do
        
        ! Add error bar plot
        call fig%errorbar(x, y, yerr=yerr)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Error bar plot count")
        
        call end_test()
    end subroutine test_errorbar_symmetric_y

    subroutine test_errorbar_symmetric_x()
        type(figure_t) :: fig
        real(wp) :: x(4), y(4), xerr(4)
        integer :: i
        
        call start_test("Symmetric X error bars")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 4
            x(i) = real(i, wp)
            y(i) = sin(real(i, wp))
            xerr(i) = 0.2_wp
        end do
        
        ! Add X error bar plot
        call fig%errorbar(x, y, xerr=xerr)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "X error bar plot count")
        
        call end_test()
    end subroutine test_errorbar_symmetric_x

    subroutine test_errorbar_asymmetric_y()
        type(figure_t) :: fig
        real(wp) :: x(4), y(4), yerr_lower(4), yerr_upper(4)
        integer :: i
        
        call start_test("Asymmetric Y error bars")
        
        call fig%initialize(640, 480)
        
        ! Create test data with asymmetric errors
        do i = 1, 4
            x(i) = real(i, wp)
            y(i) = real(i * 3, wp)
            yerr_lower(i) = 0.3_wp * real(i, wp)
            yerr_upper(i) = 0.5_wp * real(i, wp)
        end do
        
        ! Add asymmetric error bar plot
        call fig%errorbar(x, y, yerr_lower=yerr_lower, yerr_upper=yerr_upper)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Asymmetric error bar plot count")
        
        call end_test()
    end subroutine test_errorbar_asymmetric_y

    subroutine test_errorbar_both_xy()
        type(figure_t) :: fig
        real(wp) :: x(3), y(3), xerr(3), yerr(3)
        integer :: i
        
        call start_test("Both X and Y error bars")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 3
            x(i) = real(i, wp)
            y(i) = real(i * i, wp)
            xerr(i) = 0.1_wp
            yerr(i) = real(i, wp) * 0.2_wp
        end do
        
        ! Add combined error bar plot
        call fig%errorbar(x, y, xerr=xerr, yerr=yerr)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Combined XY error bar plot count")
        
        call end_test()
    end subroutine test_errorbar_both_xy

    subroutine test_errorbar_customization()
        type(figure_t) :: fig
        real(wp) :: x(3), y(3), yerr(3)
        integer :: i
        
        call start_test("Error bar customization")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 3
            x(i) = real(i, wp)
            y(i) = cos(real(i, wp))
            yerr(i) = 0.3_wp
        end do
        
        ! Add customized error bar plot
        call fig%errorbar(x, y, yerr=yerr, capsize=8.0_wp, elinewidth=2.0_wp, &
                         color=[1.0_wp, 0.0_wp, 0.0_wp])
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Customized error bar plot count")
        
        call end_test()
    end subroutine test_errorbar_customization

    subroutine test_errorbar_integration()
        type(figure_t) :: fig
        real(wp) :: x(4), y(4), yerr(4)
        integer :: i
        
        call start_test("Error bar integration with markers")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 4
            x(i) = real(i, wp)
            y(i) = exp(real(i, wp) * 0.2_wp)
            yerr(i) = y(i) * 0.1_wp
        end do
        
        ! Add error bar plot with markers
        call fig%errorbar(x, y, yerr=yerr, marker='o', linestyle='--', &
                         label='Data with errors')
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Integrated error bar plot count")
        
        call end_test()
    end subroutine test_errorbar_integration

    subroutine test_errorbar_edge_cases()
        type(figure_t) :: fig
        real(wp) :: x(3), y(3), yerr(3)
        integer :: i
        
        call start_test("Error bar edge cases")
        
        call fig%initialize(640, 480)
        
        ! Create test data with zero and large errors
        x = [1.0_wp, 2.0_wp, 3.0_wp]
        y = [1.0_wp, 4.0_wp, 2.0_wp]
        yerr = [0.0_wp, 2.0_wp, 0.1_wp]  ! Zero, large, and small errors
        
        ! Add error bar plot with edge cases
        call fig%errorbar(x, y, yerr=yerr)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Edge case error bar plot count")
        
        call end_test()
    end subroutine test_errorbar_edge_cases

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

end program test_errorbar