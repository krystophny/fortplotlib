program debug_mpeg_animation
    use fortplot_animation
    use fortplot_raster
    implicit none
    
    type(animation_t) :: anim
    
    print *, "Testing animation dimensions..."
    
    ! Create animation with explicit dimensions
    anim = FuncAnimationWithFigure(simple_frame, frames=2, width=320, height=240)
    
    print *, "Initial dimensions:", anim%video_width, "x", anim%video_height
    
    ! Enable collection and run
    anim%collect_video_frames = .true.
    call anim%run()
    
    print *, "After run dimensions:", anim%video_width, "x", anim%video_height
    
    ! Try to save as MPEG
    print *, "Attempting to save as MPEG..."
    call anim%save('test_debug.mpg', fps=25)
    
contains

    function simple_frame(frame) result(raster)
        integer, intent(in) :: frame
        type(raster_image_t) :: raster
        
        print *, "Creating frame", frame
        raster = create_raster_image(320, 240)
        print *, "Frame dimensions:", raster%width, "x", raster%height
    end function simple_frame

end program debug_mpeg_animation