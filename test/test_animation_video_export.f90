program test_animation_video_export
    use fortplot
    use fortplot_animation
    use fortplot_raster
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    
    ! Test animation video export functionality
    call test_video_export_api()
    call test_mpeg_export()
    call test_avi_export()
    call test_different_fps_rates()
    call test_video_dimensions()
    
    print *, "PASS: All animation video export tests completed"
    
contains

    subroutine test_video_export_api()
        ! Test the video export API design
        type(animation_t) :: anim
        
        print *, "Testing video export API..."
        
        ! Test FuncAnimationWithFigure constructor
        anim = FuncAnimationWithFigure(test_figure_callback, frames=5, interval=100, &
                                      width=32, height=32)
        
        if (anim%frames /= 5) then
            error stop "Animation frames not set correctly"
        end if
        
        if (anim%video_width /= 32 .or. anim%video_height /= 32) then
            error stop "Video dimensions not set correctly"
        end if
        
        if (.not. associated(anim%figure_func)) then
            error stop "Figure callback not associated"
        end if
        
        print *, "  ✅ Video export API design validated"
    end subroutine test_video_export_api

    subroutine test_mpeg_export()
        ! Test MPEG video export
        type(animation_t) :: anim
        character(len=*), parameter :: output_file = "test_output.mpg"
        
        print *, "Testing MPEG video export..."
        
        ! Create animation with small dimensions for fast testing
        anim = FuncAnimationWithFigure(test_figure_callback, frames=3, interval=100, &
                                      width=32, height=32)
        
        ! Save as MPEG
        call anim%save(output_file, fps=25)
        
        ! Verify file was created
        call verify_file_exists(output_file)
        
        ! Cleanup
        call cleanup_test_file(output_file)
        
        print *, "  ✅ MPEG export validated"
    end subroutine test_mpeg_export

    subroutine test_avi_export()
        ! Test AVI video export  
        type(animation_t) :: anim
        character(len=*), parameter :: output_file = "test_output.avi"
        
        print *, "Testing AVI video export..."
        
        ! Create animation with small dimensions
        anim = FuncAnimationWithFigure(test_figure_callback, frames=3, interval=100, &
                                      width=32, height=32)
        
        ! Save as AVI
        call anim%save(output_file, fps=30)
        
        ! Verify file was created
        call verify_file_exists(output_file)
        
        ! Cleanup
        call cleanup_test_file(output_file)
        
        print *, "  ✅ AVI export validated"
    end subroutine test_avi_export

    subroutine test_different_fps_rates()
        ! Test various frame rates
        type(animation_t) :: anim
        integer :: fps_values(3) = [15, 25, 30]
        character(len=64) :: filename
        integer :: i
        
        print *, "Testing different frame rates..."
        
        do i = 1, size(fps_values)
            write(filename, '("test_fps_", I0, ".mpg")') fps_values(i)
            
            anim = FuncAnimationWithFigure(test_figure_callback, frames=2, &
                                          width=32, height=32)
            
            call anim%save(filename, fps=fps_values(i))
            call verify_file_exists(filename)
            call cleanup_test_file(filename)
        end do
        
        print *, "  ✅ Multiple frame rates validated"
    end subroutine test_different_fps_rates

    subroutine test_video_dimensions()
        ! Test different video dimensions
        type(animation_t) :: anim
        integer :: dimensions(3,2) = reshape([32, 32, 64, 64, 128, 128], [3, 2])
        character(len=64) :: filename
        integer :: i
        
        print *, "Testing different video dimensions..."
        
        do i = 1, size(dimensions, 1)
            write(filename, '("test_", I0, "x", I0, ".mpg")') dimensions(i,1), dimensions(i,2)
            
            anim = FuncAnimationWithFigure(test_figure_callback, frames=2, &
                                          width=dimensions(i,1), height=dimensions(i,2))
            
            call anim%save(filename, fps=25)
            call verify_file_exists(filename)
            call cleanup_test_file(filename)
        end do
        
        print *, "  ✅ Multiple video dimensions validated"
    end subroutine test_video_dimensions

    ! Test callback function that returns raster data
    function test_figure_callback(frame) result(raster)
        integer, intent(in) :: frame
        type(raster_image_t) :: raster
        
        integer :: i, j, idx, value
        integer :: width, height
        
        ! Use small dimensions for testing
        width = 32
        height = 32
        
        ! Create test raster image
        raster = create_raster_image(width, height)
        
        ! Fill with test pattern that changes per frame
        do j = 0, height - 1
            do i = 0, width - 1
                ! Calculate bitmap index accounting for filter bytes
                idx = j * (1 + width * 3) + 1 + 1 + i * 3
                
                ! Create pattern that changes with frame number
                value = mod((i + j + frame * 10), 256)
                
                ! RGB values (simple grayscale pattern) - convert to signed byte
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
    end function test_figure_callback

    ! Helper subroutines

    subroutine verify_file_exists(filename)
        character(len=*), intent(in) :: filename
        logical :: file_exists
        
        inquire(file=filename, exist=file_exists)
        if (.not. file_exists) then
            print *, "ERROR: File not created: ", trim(filename)
            error stop "Video file was not created"
        end if
    end subroutine verify_file_exists

    subroutine cleanup_test_file(filename)
        character(len=*), intent(in) :: filename
        integer :: unit
        logical :: file_exists
        
        inquire(file=filename, exist=file_exists)
        if (file_exists) then
            open(newunit=unit, file=filename, status='old')
            close(unit, status='delete')
        end if
    end subroutine cleanup_test_file

end program test_animation_video_export