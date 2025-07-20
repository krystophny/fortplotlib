program test_bar_chart
    !! Test suite for bar chart plotting functionality
    !! Tests vertical/horizontal bars, grouping, and categorical data
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_figure
    implicit none
    
    integer :: test_count = 0
    integer :: pass_count = 0
    
    call test_bar_basic()
    call test_barh_basic()
    call test_bar_custom_width()
    call test_bar_grouped()
    call test_bar_empty_data()
    
    call print_test_summary()
    
contains

    subroutine test_bar_basic()
        type(figure_t) :: fig
        real(wp) :: x_pos(5), heights(5)
        integer :: i
        
        call start_test("Basic vertical bar chart")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 5
            x_pos(i) = real(i, wp)
            heights(i) = real(i * 2, wp)
        end do
        
        ! Add vertical bar chart
        call fig%bar(x_pos, heights)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Bar chart plot count")
        
        call end_test()
    end subroutine test_bar_basic

    subroutine test_barh_basic()
        type(figure_t) :: fig
        real(wp) :: y_pos(4), widths(4)
        integer :: i
        
        call start_test("Basic horizontal bar chart")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 4
            y_pos(i) = real(i, wp)
            widths(i) = real(i * 3, wp)
        end do
        
        ! Add horizontal bar chart
        call fig%barh(y_pos, widths)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Horizontal bar chart plot count")
        
        call end_test()
    end subroutine test_barh_basic

    subroutine test_bar_custom_width()
        type(figure_t) :: fig
        real(wp) :: x_pos(3), heights(3)
        integer :: i
        
        call start_test("Bar chart with custom width")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 3
            x_pos(i) = real(i, wp)
            heights(i) = real(i + 5, wp)
        end do
        
        ! Add bar chart with custom width
        call fig%bar(x_pos, heights, width=0.5_wp)
        call assert_equal(real(fig%plot_count, wp), 1.0_wp, "Custom width bar chart count")
        
        call end_test()
    end subroutine test_bar_custom_width

    subroutine test_bar_grouped()
        type(figure_t) :: fig
        real(wp) :: x_pos(3), heights1(3), heights2(3)
        integer :: i
        
        call start_test("Grouped bar charts")
        
        call fig%initialize(640, 480)
        
        ! Create test data
        do i = 1, 3
            x_pos(i) = real(i, wp)
            heights1(i) = real(i * 2, wp)
            heights2(i) = real(i * 3, wp)
        end do
        
        ! Add grouped bar charts
        call fig%bar(x_pos, heights1, width=0.35_wp, label='Series 1')
        call fig%bar(x_pos + 0.35_wp, heights2, width=0.35_wp, label='Series 2')
        call assert_equal(real(fig%plot_count, wp), 2.0_wp, "Grouped bar chart count")
        
        call end_test()
    end subroutine test_bar_grouped

    subroutine test_bar_empty_data()
        type(figure_t) :: fig
        real(wp) :: x_pos(0), heights(0)
        
        call start_test("Bar chart with empty data")
        
        call fig%initialize(640, 480)
        
        ! Add bar chart with empty data - should handle gracefully
        call fig%bar(x_pos, heights)
        call assert_equal(real(fig%plot_count, wp), 0.0_wp, "Empty data bar chart count")
        
        call end_test()
    end subroutine test_bar_empty_data

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

end program test_bar_chart