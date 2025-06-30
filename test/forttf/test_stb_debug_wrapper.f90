program test_stb_debug_wrapper
    !! Call STB debug wrapper to see exact STB processing
    use iso_c_binding
    implicit none

    interface
        subroutine stb_debug_dollar_c() bind(c)
        end subroutine stb_debug_dollar_c
    end interface

    call stb_debug_dollar_c()

end program test_stb_debug_wrapper