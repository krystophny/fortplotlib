program test_ttc_support
    !! Quick test to check if STB supports TTC files
    use fortplot_stb_truetype
    use iso_c_binding
    implicit none

    type(stb_fontinfo_t) :: font
    logical :: success
    character(len=256) :: ttc_files(3)
    integer :: i

    write(*,*) "Testing STB TTC support..."

    ! Test common TTC files on macOS
    ttc_files(1) = "/System/Library/Fonts/Helvetica.ttc"
    ttc_files(2) = "/System/Library/Fonts/Times.ttc"
    ttc_files(3) = "/System/Library/Fonts/Menlo.ttc"

    do i = 1, 3
        write(*,'(A,A)') "Testing: ", trim(ttc_files(i))

        success = stb_init_font(font, ttc_files(i))

        if (success) then
            write(*,*) "  ✅ STB successfully loaded TTC file!"
            call stb_cleanup_font(font)
        else
            write(*,*) "  ❌ STB failed to load TTC file"
        end if
    end do

end program test_ttc_support
