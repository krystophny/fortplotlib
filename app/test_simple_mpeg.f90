program test_simple_mpeg
    use fortplot_animation
    use fortplot_raster
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    type(animation_t) :: anim
    integer :: i
    
    print *, "Test Simple MPEG Generation"
    print *, "==========================="
    
    ! Create animation with explicit dimensions
    anim = FuncAnimationWithFigure(create_test_frame, frames=5, width=160, height=120)
    
    print *, "Saving to test.mpg..."
    call anim%save('test.mpg', fps=25)
    
    print *, "Done!"
    
contains

    function create_test_frame(frame) result(raster)
        integer, intent(in) :: frame
        type(raster_image_t) :: raster
        integer :: x, y, idx
        integer :: w, h
        
        ! Use fixed dimensions
        w = 160
        h = 120
        
        print *, "Creating test frame", frame, "with dimensions", w, "x", h
        
        ! Create raster
        raster = create_raster_image(w, h)
        
        ! Fill with gradient based on frame number
        do y = 0, h - 1
            do x = 0, w - 1
                idx = y * (1 + w * 3) + 1 + 1 + x * 3
                
                ! Simple gradient pattern
                raster%image_data(idx) = int(mod(x + frame * 20, 256) - 128, kind=1)     ! R
                raster%image_data(idx + 1) = int(mod(y + frame * 10, 256) - 128, kind=1) ! G
                raster%image_data(idx + 2) = int(64, kind=1)                             ! B
            end do
        end do
        
        print *, "Frame created, raster dimensions:", raster%width, "x", raster%height
    end function create_test_frame

end program test_simple_mpeg