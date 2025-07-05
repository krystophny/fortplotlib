program animation_video_export_demo
    !! Demonstrate animation video export functionality
    !! Shows how to create animations and save them as MPEG/AVI files
    use fortplot
    use fortplot_animation
    use fortplot_raster
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none

    integer, parameter :: NFRAMES = 30
    integer, parameter :: WIDTH = 320, HEIGHT = 240

    type(figure_t) :: fig
    type(animation_t) :: anim
    real(wp) :: x(100), y(100)
    integer :: i

    print *, "Animation Video Export Demo"
    print *, "=========================="

    ! Create x data for sine wave
    do i = 1, 100
        x(i) = real(i-1, wp) * 2.0_wp * 3.14159_wp / 99.0_wp  ! 0 to 2*pi
    end do

    ! Initialize figure
    call fig%initialize(WIDTH, HEIGHT)
    call fig%set_title('Animated Sine Wave - Video Export Demo')
    call fig%set_xlabel('x')
    call fig%set_ylabel('sin(x + phase)')
    call fig%set_xlim(0.0_wp, 2.0_wp * 3.14159_wp)
    call fig%set_ylim(-1.5_wp, 1.5_wp)

    ! Demo 1: Save as MPEG at 25 fps
    print *, ""
    print *, "Demo 1: Creating sine_wave_25fps.mpg..."
    anim = FuncAnimationWithFigure(create_sine_frame, frames=NFRAMES, &
                                  width=WIDTH, height=HEIGHT)
    call anim%save('sine_wave_25fps.mpg', fps=25)
    print *, "✅ MPEG video saved: sine_wave_25fps.mpg"

    ! Demo 2: Save as AVI at 30 fps  
    print *, ""
    print *, "Demo 2: Creating sine_wave_30fps.avi..."
    anim = FuncAnimationWithFigure(create_sine_frame, frames=NFRAMES, &
                                  width=WIDTH, height=HEIGHT)
    call anim%save('sine_wave_30fps.avi', fps=30)
    print *, "✅ AVI video saved: sine_wave_30fps.avi"

    ! Demo 3: Different pattern - bouncing dot
    print *, ""
    print *, "Demo 3: Creating bouncing_dot.mpg..."
    anim = FuncAnimationWithFigure(create_dot_frame, frames=20, &
                                  width=WIDTH, height=HEIGHT)
    call anim%save('bouncing_dot.mpg', fps=15)
    print *, "✅ Bouncing dot video saved: bouncing_dot.mpg"

    print *, ""
    print *, "All video exports completed successfully!"
    print *, "You can play the videos with:"
    print *, "  ffplay sine_wave_25fps.mpg"
    print *, "  ffplay sine_wave_30fps.avi" 
    print *, "  ffplay bouncing_dot.mpg"

contains

    function create_sine_frame(frame) result(raster)
        !! Create frame showing animated sine wave
        integer, intent(in) :: frame
        type(raster_image_t) :: raster
        
        real(wp) :: phase
        integer :: i
        
        ! Create raster image for this frame - dimensions will be set by animation
        raster = create_raster_image(320, 240)
        
        ! Calculate phase for this frame
        phase = real(frame-1, wp) * 2.0_wp * 3.14159_wp / real(NFRAMES, wp)
        
        ! Create simple pattern that represents a sine wave
        call create_sine_pattern(raster, 320, 240, phase)
    end function create_sine_frame

    function create_dot_frame(frame) result(raster)
        !! Create frame showing bouncing dot pattern
        integer, intent(in) :: frame
        type(raster_image_t) :: raster
        
        real(wp) :: dot_x, dot_y, t
        
        ! Create raster image for this frame
        raster = create_raster_image(320, 240)
        
        ! Calculate dot position
        t = real(frame-1, wp) / 19.0_wp  ! Normalize to 0-1
        dot_x = 0.5_wp + 0.3_wp * sin(4.0_wp * 3.14159_wp * t)  ! 0.2 to 0.8
        dot_y = 0.5_wp + 0.3_wp * cos(6.0_wp * 3.14159_wp * t)  ! 0.2 to 0.8
        
        ! Create dot pattern
        call create_dot_pattern(raster, 320, 240, dot_x, dot_y)
    end function create_dot_frame

    subroutine create_sine_pattern(raster, width, height, phase)
        !! Create visual sine wave pattern in raster
        type(raster_image_t), intent(inout) :: raster
        integer, intent(in) :: width, height
        real(wp), intent(in) :: phase
        
        integer :: i, j, idx, value
        real(wp) :: x_norm, y_pos, y_norm
        
        do j = 0, height - 1
            do i = 0, width - 1
                ! Calculate bitmap index accounting for filter bytes
                idx = j * (1 + width * 3) + 1 + 1 + i * 3
                
                ! Normalize x position (0 to 2*pi)
                x_norm = real(i, wp) / real(width-1, wp) * 2.0_wp * 3.14159_wp
                
                ! Calculate sine wave position
                y_pos = sin(x_norm + phase)
                y_norm = (y_pos + 1.0_wp) / 2.0_wp  ! Normalize to 0-1
                
                ! Create wave visualization
                if (abs(real(j, wp) / real(height-1, wp) - y_norm) < 0.05_wp) then
                    ! On the wave - bright
                    value = 255
                else
                    ! Background - darker
                    value = 64
                end if
                
                ! Set RGB values (convert to signed byte)
                if (value > 127) then
                    raster%image_data(idx) = int(value - 256, kind=1)     ! R
                    raster%image_data(idx + 1) = int(value - 256, kind=1) ! G  
                    raster%image_data(idx + 2) = int(value - 256, kind=1) ! B
                else
                    raster%image_data(idx) = int(value, kind=1)     ! R
                    raster%image_data(idx + 1) = int(value, kind=1) ! G  
                    raster%image_data(idx + 2) = int(value, kind=1) ! B
                end if
            end do
        end do
    end subroutine create_sine_pattern

    subroutine create_dot_pattern(raster, width, height, dot_x, dot_y)
        !! Create dot pattern in raster
        type(raster_image_t), intent(inout) :: raster
        integer, intent(in) :: width, height
        real(wp), intent(in) :: dot_x, dot_y
        
        integer :: i, j, idx, value
        integer :: center_x, center_y, radius
        real(wp) :: distance
        
        ! Calculate dot center and radius
        center_x = nint(dot_x * real(width-1, wp))
        center_y = nint(dot_y * real(height-1, wp))
        radius = 10
        
        do j = 0, height - 1
            do i = 0, width - 1
                ! Calculate bitmap index accounting for filter bytes
                idx = j * (1 + width * 3) + 1 + 1 + i * 3
                
                ! Calculate distance from dot center
                distance = sqrt(real((i - center_x)**2 + (j - center_y)**2, wp))
                
                ! Create dot visualization
                if (distance <= real(radius, wp)) then
                    ! Inside dot - bright red (255 as signed byte = -1)
                    raster%image_data(idx) = int(-1, kind=1)      ! R (255)
                    raster%image_data(idx + 1) = int(0, kind=1)   ! G  
                    raster%image_data(idx + 2) = int(0, kind=1)   ! B
                else
                    ! Background - dark blue
                    raster%image_data(idx) = int(0, kind=1)       ! R
                    raster%image_data(idx + 1) = int(0, kind=1)   ! G  
                    raster%image_data(idx + 2) = int(64, kind=1)  ! B
                end if
            end do
        end do
    end subroutine create_dot_pattern

end program animation_video_export_demo