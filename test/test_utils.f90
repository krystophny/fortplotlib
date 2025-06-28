module test_utils
    !! Common test utilities for STB TrueType font testing
    !! Provides font discovery, initialization helpers, and common test data
    use fortplot_stb_truetype
    use fortplot_stb
    use fortplot_stb_parser, only: read_truetype_file
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    private

    ! Public interface
    public :: discover_system_fonts
    public :: print_font_list
    public :: init_both_fonts
    public :: test_chars

    ! Common test data
    character(len=1), parameter :: test_chars(10) = ['A', 'B', 'M', 'W', 'g', 'j', '!', '?', '1', '@']

contains

    subroutine discover_system_fonts(fonts, count)
        !! Discover available TrueType fonts on macOS and Linux systems
        character(len=256), allocatable, intent(out) :: fonts(:)
        integer, intent(out) :: count

        character(len=256) :: potential_fonts(20)
        logical :: font_exists
        integer :: i, found_count

        ! Common fonts on macOS and Linux
        potential_fonts(1) = "/System/Library/Fonts/Monaco.ttf"                    ! macOS monospace
        potential_fonts(2) = "/System/Library/Fonts/Helvetica.ttc"                 ! macOS sans-serif
        potential_fonts(3) = "/System/Library/Fonts/Times.ttc"                     ! macOS serif
        potential_fonts(4) = "/System/Library/Fonts/Arial.ttf"                     ! macOS common
        potential_fonts(5) = "/usr/share/fonts/TTF/DejaVuSans.ttf"                ! Linux DejaVu
        potential_fonts(6) = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"    ! Linux DejaVu alt
        potential_fonts(7) = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"           ! Linux DejaVu Bold
        potential_fonts(8) = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf" ! Linux Liberation
        potential_fonts(9) = "/usr/share/fonts/TTF/LiberationSans-Regular.ttf"    ! Linux Liberation alt
        potential_fonts(10) = "/usr/share/fonts/noto/NotoSans-Regular.ttf"        ! Linux Noto
        potential_fonts(11) = "/usr/share/fonts/google-noto/NotoSans-Regular.ttf" ! Linux Noto alt
        potential_fonts(12) = "/usr/share/fonts/ubuntu/Ubuntu-R.ttf"              ! Ubuntu font
        potential_fonts(13) = "/usr/share/fonts/truetype/ubuntu/Ubuntu-R.ttf"     ! Ubuntu alt
        potential_fonts(14) = "/usr/share/fonts/corefonts/arial.ttf"              ! Linux Arial
        potential_fonts(15) = "/usr/share/fonts/truetype/msttcorefonts/arial.ttf" ! Linux Arial alt
        potential_fonts(16) = "/opt/homebrew/share/fonts/source-code-pro/SourceCodePro-Regular.ttf" ! Homebrew
        potential_fonts(17) = "/usr/local/share/fonts/SourceCodePro-Regular.ttf"  ! Local fonts
        potential_fonts(18) = "/System/Library/Fonts/Menlo.ttc"                   ! macOS Menlo
        potential_fonts(19) = "/System/Library/Fonts/SF-Pro.ttc"                  ! macOS SF Pro
        potential_fonts(20) = "/System/Library/Fonts/Avenir.ttc"                  ! macOS Avenir

        ! Count existing fonts first
        found_count = 0
        do i = 1, size(potential_fonts)
            inquire(file=trim(potential_fonts(i)), exist=font_exists)
            if (font_exists) found_count = found_count + 1
        end do

        ! Allocate and populate found fonts
        allocate(fonts(found_count))
        count = 0
        do i = 1, size(potential_fonts)
            inquire(file=trim(potential_fonts(i)), exist=font_exists)
            if (font_exists) then
                count = count + 1
                fonts(count) = potential_fonts(i)
            end if
        end do

    end subroutine discover_system_fonts

    subroutine print_font_list(fonts, count)
        !! Print list of discovered fonts
        character(len=256), intent(in) :: fonts(:)
        integer, intent(in) :: count
        integer :: i

        do i = 1, min(count, 5)  ! Show first 5 fonts
            write(*,'(A,I0,A,A)') "   ", i, ": ", trim(fonts(i))
        end do
        if (count > 5) then
            write(*,'(A,I0,A)') "   ... and ", count - 5, " more fonts"
        end if

    end subroutine print_font_list

    function init_both_fonts(font_path, stb_font, pure_font, stb_success, pure_success) result(success)
        !! Initialize both STB and Pure Fortran fonts
        character(len=*), intent(in) :: font_path
        type(stb_fontinfo_t), intent(out) :: stb_font
        type(stb_fontinfo_pure_t), intent(out) :: pure_font
        logical, intent(out) :: stb_success, pure_success
        logical :: success

        ! Initialize STB font directly from file path
        stb_success = stb_init_font(stb_font, font_path)

        ! Initialize Pure Fortran font directly from file path
        pure_success = stb_init_font_pure(pure_font, font_path)

        success = stb_success .and. pure_success

    end function init_both_fonts

end module test_utils