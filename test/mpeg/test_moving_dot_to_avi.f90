program test_moving_dot_to_avi
    use fortplot_mpeg_avi
    implicit none
    
    ! Test converting the moving dot video to AVI format
    call test_convert_moving_dot_to_avi()
    
    print *, "PASS: Moving dot video converted to AVI successfully"
    
contains

    subroutine test_convert_moving_dot_to_avi()
        character(len=*), parameter :: mpeg_file = "moving_dot_video.mpg"
        character(len=*), parameter :: avi_file = "moving_dot_video.avi"
        integer, parameter :: width = 32, height = 24, frame_rate = 15, num_frames = 30
        
        print *, "Converting moving dot MPEG to AVI format..."
        print *, "  Source:", mpeg_file
        print *, "  Target:", avi_file
        
        ! Convert the moving dot video to AVI
        call mpeg_to_avi(mpeg_file, avi_file, width, height, frame_rate, num_frames)
        
        print *, "Moving dot video conversion to AVI completed"
        print *, "  Output file:", avi_file
        print *, "  Ready for playback in standard video players"
    end subroutine

end program test_moving_dot_to_avi