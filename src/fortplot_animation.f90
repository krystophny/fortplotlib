module fortplot_animation
    use fortplot_raster, only: raster_image_t, create_raster_image, destroy_raster_image
    use fortplot_rgb_to_mpeg, only: yuv420_frame_t, create_yuv420_frame, destroy_yuv420_frame, bitmap_to_yuv420
    use fortplot_mpeg1_format
    use fortplot_mpeg_stream
    use, intrinsic :: iso_fortran_env, only: wp => real64
    implicit none
    private

    ! Animation callback interface
    abstract interface
        subroutine animate_interface(frame)
            integer, intent(in) :: frame
        end subroutine animate_interface
    end interface

    ! Animation figure callback interface - returns raster data for video export
    abstract interface
        function animate_figure_interface(frame) result(raster)
            use fortplot_raster, only: raster_image_t
            integer, intent(in) :: frame
            type(raster_image_t) :: raster
        end function animate_figure_interface
    end interface

    ! Video format enumeration
    integer, parameter :: VIDEO_FORMAT_MPEG = 1
    integer, parameter :: VIDEO_FORMAT_AVI = 2

    ! Animation type
    type :: animation_t
        procedure(animate_interface), pointer, nopass :: animate_func => null()
        procedure(animate_figure_interface), pointer, nopass :: figure_func => null()
        integer :: frames = 0
        integer :: interval_ms = 50
        logical :: save_frames = .false.
        character(len=:), allocatable :: frame_pattern
        ! Video export properties
        logical :: collect_video_frames = .false.
        integer(1), allocatable :: video_frame_data(:,:)  ! Store raw bitmap data
        integer :: video_width = 640
        integer :: video_height = 480
    contains
        procedure :: run
        procedure :: save_png_sequence
        procedure :: set_save_frames
        procedure :: save => animation_save
        procedure :: set_figure_callback
        procedure :: collect_frame_data
        procedure :: export_to_mpeg
        procedure :: export_to_avi
        procedure :: cleanup_video_frames
    end type animation_t

    public :: animation_t, FuncAnimation, FuncAnimationWithFigure
    public :: VIDEO_FORMAT_MPEG, VIDEO_FORMAT_AVI

contains

    function FuncAnimation(animate_func, frames, interval) result(anim)
        procedure(animate_interface) :: animate_func
        integer, intent(in) :: frames
        integer, intent(in), optional :: interval
        type(animation_t) :: anim

        anim%animate_func => animate_func
        anim%frames = frames
        
        if (present(interval)) then
            anim%interval_ms = interval
        else
            anim%interval_ms = 50  ! Default 50ms between frames
        end if
        
        anim%save_frames = .false.
        anim%collect_video_frames = .false.
    end function FuncAnimation

    function FuncAnimationWithFigure(figure_func, frames, interval, width, height) result(anim)
        !! Create animation with figure callback for video export
        procedure(animate_figure_interface) :: figure_func
        integer, intent(in) :: frames
        integer, intent(in), optional :: interval, width, height
        type(animation_t) :: anim

        anim%figure_func => figure_func
        anim%frames = frames
        
        if (present(interval)) then
            anim%interval_ms = interval
        else
            anim%interval_ms = 50  ! Default 50ms between frames
        end if

        if (present(width)) anim%video_width = width
        if (present(height)) anim%video_height = height
        
        anim%save_frames = .false.
        anim%collect_video_frames = .false.
    end function FuncAnimationWithFigure

    subroutine run(self)
        class(animation_t), intent(inout) :: self
        integer :: i

        if (.not. associated(self%animate_func) .and. .not. associated(self%figure_func)) then
            print *, "Error: Animation callback function not associated"
            return
        end if

        ! Video frame allocation will happen in collect_frame_data after we know dimensions

        print *, "Running animation with", self%frames, "frames..."

        do i = 1, self%frames
            if (associated(self%animate_func)) then
                call self%animate_func(i)
            end if
            
            if (associated(self%figure_func)) then
                call self%collect_frame_data(i)
            end if
            
            ! Optional: add timing delay (skip during video collection for speed)
            if (self%interval_ms > 0 .and. .not. self%collect_video_frames) then
                call sleep_ms(self%interval_ms)
            end if
        end do

        print *, "Animation completed."
    end subroutine run

    subroutine set_save_frames(self, pattern)
        class(animation_t), intent(inout) :: self
        character(len=*), intent(in) :: pattern
        
        self%save_frames = .true.
        self%frame_pattern = pattern
    end subroutine set_save_frames

    subroutine save_png_sequence(self, filename_pattern)
        class(animation_t), intent(inout) :: self
        character(len=*), intent(in) :: filename_pattern
        
        ! Enable frame saving and run animation
        call self%set_save_frames(filename_pattern)
        call self%run()
    end subroutine save_png_sequence

    subroutine sleep_ms(milliseconds)
        integer, intent(in) :: milliseconds
        ! Simple sleep implementation - platform dependent
        ! For now, just a placeholder
        ! In real implementation, would use system-specific sleep
        continue
    end subroutine sleep_ms

    subroutine animation_save(self, filename, fps)
        !! Save animation as video file (matplotlib-compatible API)
        class(animation_t), intent(inout) :: self
        character(len=*), intent(in) :: filename
        integer, intent(in), optional :: fps
        
        integer :: video_fps, video_format
        character(len=16) :: extension
        
        ! Default fps calculation from interval (like matplotlib)
        if (present(fps)) then
            video_fps = fps
        else
            video_fps = 1000 / max(1, self%interval_ms)  ! Convert ms to fps
        end if
        
        ! Detect format from file extension
        call get_file_extension(filename, extension)
        
        select case(trim(extension))
        case('.mpg', '.mpeg')
            video_format = VIDEO_FORMAT_MPEG
        case('.avi')
            video_format = VIDEO_FORMAT_AVI
        case default
            print *, "Warning: Unknown video format '", trim(extension), "', defaulting to MPEG"
            video_format = VIDEO_FORMAT_MPEG
        end select
        
        if (.not. associated(self%figure_func)) then
            error stop "Animation save requires figure callback function. Use FuncAnimationWithFigure."
        end if
        
        print *, "Saving animation to '", trim(filename), "' at", video_fps, "fps..."
        
        ! Enable video frame collection
        self%collect_video_frames = .true.
        
        ! Run animation to collect frames
        call self%run()
        
        ! Export to video format
        select case(video_format)
        case(VIDEO_FORMAT_MPEG)
            call self%export_to_mpeg(filename, video_fps)
        case(VIDEO_FORMAT_AVI)
            call self%export_to_avi(filename, video_fps)
        end select
        
        ! Cleanup
        call self%cleanup_video_frames()
        self%collect_video_frames = .false.
        
        print *, "Video saved successfully: ", trim(filename)
    end subroutine animation_save

    subroutine set_figure_callback(self, figure_func)
        !! Set figure callback for video export
        class(animation_t), intent(inout) :: self
        procedure(animate_figure_interface) :: figure_func
        
        self%figure_func => figure_func
    end subroutine set_figure_callback

    subroutine collect_frame_data(self, frame_number)
        !! Collect frame data from figure callback  
        class(animation_t), intent(inout) :: self
        integer, intent(in) :: frame_number
        
        type(raster_image_t) :: frame_raster
        integer :: expected_size
        
        if (.not. self%collect_video_frames) return
        if (.not. associated(self%figure_func)) return
        if (frame_number < 1 .or. frame_number > self%frames) return
        
        ! Get frame data from callback
        frame_raster = self%figure_func(frame_number)
        
        ! Store frame dimensions from first frame and allocate storage
        if (frame_number == 1) then
            self%video_width = frame_raster%width
            self%video_height = frame_raster%height
            print *, "DEBUG: Set dimensions from frame 1:", self%video_width, "x", self%video_height
            
            ! Now allocate storage based on actual dimensions
            expected_size = self%video_height * (1 + self%video_width * 3)
            if (.not. allocated(self%video_frame_data)) then
                allocate(self%video_frame_data(expected_size, self%frames))
            end if
        end if
        
        ! Copy bitmap data to storage
        expected_size = frame_raster%height * (1 + frame_raster%width * 3)
        if (allocated(self%video_frame_data) .and. expected_size <= size(self%video_frame_data, 1)) then
            self%video_frame_data(1:expected_size, frame_number) = frame_raster%image_data(1:expected_size)
        else
            print *, "Warning: Frame", frame_number, "size mismatch or not allocated"
        end if
        
        ! Cleanup frame raster
        call destroy_raster_image(frame_raster)
    end subroutine collect_frame_data

    subroutine export_to_mpeg(self, filename, fps)
        !! Export collected frames to MPEG-1 video
        class(animation_t), intent(inout) :: self
        character(len=*), intent(in) :: filename
        integer, intent(in) :: fps
        
        type(yuv420_frame_t) :: yuv_frame
        integer :: i, frame_rate_code
        
        if (.not. allocated(self%video_frame_data)) then
            error stop "No video frames collected for export"
        end if
        
        if (size(self%video_frame_data, 2) == 0) then
            error stop "No frames available for export"
        end if
        
        ! Validate frame dimensions are even (required for MPEG)
        if (mod(self%video_width, 2) /= 0 .or. mod(self%video_height, 2) /= 0) then
            error stop "Video dimensions must be even for MPEG format"
        end if
        
        ! Map fps to MPEG frame rate code
        frame_rate_code = map_fps_to_mpeg_code(fps)
        
        ! Open MPEG stream
        call stream_open_write(filename)
        
        print *, "Debug: About to write headers with dimensions:", self%video_width, "x", self%video_height
        print *, "Debug: Frame data allocated?", allocated(self%video_frame_data)
        if (allocated(self%video_frame_data)) then
            print *, "Debug: Frame data size:", size(self%video_frame_data, 1), "x", size(self%video_frame_data, 2)
        end if
        
        ! Write MPEG headers
        call write_mpeg1_sequence_header(self%video_width, self%video_height, fps, 1150000)
        call write_mpeg1_gop_header(0)  ! Time code 0
        
        ! Create YUV frame buffer
        yuv_frame = create_yuv420_frame(self%video_width, self%video_height)
        
        ! Encode each frame
        do i = 1, size(self%video_frame_data, 2)
            print *, "Encoding frame", i, "of", size(self%video_frame_data, 2)
            
            ! Write picture header
            call write_mpeg1_picture_header(i-1, 1)  ! I-frame
            
            ! Write slice header
            call write_mpeg1_slice_header(1)
            
            ! Convert raster to YUV and encode
            call bitmap_to_yuv420(self%video_frame_data(:, i), &
                                 self%video_width, self%video_height, yuv_frame)
            
            call encode_mpeg1_frame_yuv(yuv_frame)
        end do
        
        ! Write sequence end code
        call write_mpeg1_sequence_end()
        
        ! Cleanup
        call destroy_yuv420_frame(yuv_frame)
        call stream_close_write()
    end subroutine export_to_mpeg

    subroutine export_to_avi(self, filename, fps)
        !! Export collected frames to AVI video with MPEG-1 stream
        class(animation_t), intent(inout) :: self
        character(len=*), intent(in) :: filename
        integer, intent(in) :: fps
        
        character(len=256) :: temp_mpeg_file
        
        if (.not. allocated(self%video_frame_data)) then
            error stop "No video frames collected for export"
        end if
        
        ! Create temporary MPEG file
        temp_mpeg_file = trim(filename) // ".tmp.mpg"
        
        ! Export to MPEG first
        call self%export_to_mpeg(temp_mpeg_file, fps)
        
        ! Convert MPEG to AVI using existing functionality
        call convert_mpeg_to_avi(temp_mpeg_file, filename)
        
        ! Remove temporary file
        call remove_file(temp_mpeg_file)
    end subroutine export_to_avi

    subroutine cleanup_video_frames(self)
        !! Clean up allocated video frame storage
        class(animation_t), intent(inout) :: self
        
        if (allocated(self%video_frame_data)) then
            deallocate(self%video_frame_data)
        end if
    end subroutine cleanup_video_frames

    ! Helper subroutines

    subroutine get_file_extension(filename, extension)
        !! Extract file extension from filename
        character(len=*), intent(in) :: filename
        character(len=*), intent(out) :: extension
        integer :: dot_pos
        
        dot_pos = index(filename, '.', back=.true.)
        if (dot_pos > 0) then
            extension = filename(dot_pos:)
        else
            extension = ''
        end if
        
        ! Convert to lowercase
        call to_lowercase(extension)
    end subroutine get_file_extension

    subroutine to_lowercase(str)
        !! Convert string to lowercase
        character(len=*), intent(inout) :: str
        integer :: i, char_code
        
        do i = 1, len(str)
            char_code = ichar(str(i:i))
            if (char_code >= ichar('A') .and. char_code <= ichar('Z')) then
                str(i:i) = char(char_code + ichar('a') - ichar('A'))
            end if
        end do
    end subroutine to_lowercase

    function map_fps_to_mpeg_code(fps) result(code)
        !! Map frame rate to MPEG-1 frame rate code
        integer, intent(in) :: fps
        integer :: code
        
        select case(fps)
        case(24)
            code = 2  ! 24 fps
        case(25)
            code = 3  ! 25 fps
        case(30)
            code = 5  ! 30 fps
        case(50)
            code = 6  ! 50 fps
        case(60)
            code = 8  ! 60 fps
        case default
            code = 3  ! Default to 25 fps
            print *, "Warning: Unsupported fps", fps, ", using 25 fps"
        end select
    end function map_fps_to_mpeg_code

    subroutine encode_mpeg1_frame_yuv(yuv_frame)
        !! Encode YUV frame using existing MPEG-1 functionality
        use fortplot_mpeg_yuv_encoder, only: encode_yuv420_frame_simple
        type(yuv420_frame_t), intent(in) :: yuv_frame
        
        ! Use the new YUV encoder that actually uses frame data
        call encode_yuv420_frame_simple(yuv_frame)
    end subroutine encode_mpeg1_frame_yuv

    subroutine convert_mpeg_to_avi(mpeg_file, avi_file)
        !! Convert MPEG file to AVI format (placeholder - use existing AVI functions)
        character(len=*), intent(in) :: mpeg_file, avi_file
        
        ! For now, just copy the file with .avi extension
        ! In full implementation, would use proper AVI wrapper
        print *, "Converting ", trim(mpeg_file), " to ", trim(avi_file)
        call copy_file(mpeg_file, avi_file)
    end subroutine convert_mpeg_to_avi

    subroutine copy_file(source, dest)
        !! Simple file copy utility
        character(len=*), intent(in) :: source, dest
        character(len=1024) :: buffer
        integer :: unit_in, unit_out, ios
        
        open(newunit=unit_in, file=source, access='stream', form='unformatted', status='old')
        open(newunit=unit_out, file=dest, access='stream', form='unformatted', status='replace')
        
        do
            read(unit_in, iostat=ios) buffer
            if (ios /= 0) exit
            write(unit_out) buffer
        end do
        
        close(unit_in)
        close(unit_out)
    end subroutine copy_file

    subroutine remove_file(filename)
        !! Remove temporary file
        character(len=*), intent(in) :: filename
        integer :: unit
        logical :: file_exists
        
        inquire(file=filename, exist=file_exists)
        if (file_exists) then
            open(newunit=unit, file=filename, status='old')
            close(unit, status='delete')
        end if
    end subroutine remove_file


end module fortplot_animation