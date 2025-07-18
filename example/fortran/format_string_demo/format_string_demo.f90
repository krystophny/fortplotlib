program format_string_demo
    !! Demonstrate matplotlib-style format strings
    use fortplot
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    integer, parameter :: n = 50
    real(wp) :: x(n), y1(n), y2(n), y3(n), y4(n)
    integer :: i
    type(figure_t) :: fig
    
    ! Generate sample data
    do i = 1, n
        x(i) = real(i-1, wp) * 0.2_wp
        y1(i) = sin(x(i))
        y2(i) = cos(x(i))
        y3(i) = sin(x(i) * 0.5_wp) * 0.8_wp
        y4(i) = cos(x(i) * 0.5_wp) * 0.6_wp
    end do
    
    call fig%initialize(800, 600)
    call fig%set_title('Matplotlib-style Format Strings Demo')
    call fig%set_xlabel('X values')
    call fig%set_ylabel('Y values')
    
    ! Different format strings using linestyle parameter (pyplot-fortran style)
    call fig%add_plot(x, y1, label='sin(x) - solid line', linestyle='-')
    call fig%add_plot(x, y2, label='cos(x) - dashed line', linestyle='--')
    call fig%add_plot(x, y3, label='sin(x/2) - circles only', linestyle='o')
    call fig%add_plot(x, y4, label='cos(x/2) - x markers with line', linestyle='x-')
    
    call fig%legend()
    call fig%savefig('build/example/format_string_demo/format_string_demo.png')
    call fig%savefig('build/example/format_string_demo/format_string_demo.pdf')
    call fig%savefig('build/example/format_string_demo/format_string_demo.txt')
    
    write(*, '(A)') 'Format string demo saved to format_string_demo.png/pdf/txt'
    
end program