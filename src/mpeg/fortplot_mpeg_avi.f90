module fortplot_mpeg_avi
    use iso_c_binding
    use fortplot_mpeg_c_io
    implicit none
    
    ! AVI container format implementation for MPEG streams
    
    ! FOURCC codes as 32-bit integers (little-endian)
    integer(c_int32_t), parameter :: FOURCC_RIFF = int(z'46464952', c_int32_t)  ! 'RIFF'
    integer(c_int32_t), parameter :: FOURCC_AVI  = int(z'20495641', c_int32_t)  ! 'AVI '
    integer(c_int32_t), parameter :: FOURCC_LIST = int(z'5453494c', c_int32_t)  ! 'LIST'
    integer(c_int32_t), parameter :: FOURCC_hdrl = int(z'6c726468', c_int32_t)  ! 'hdrl'
    integer(c_int32_t), parameter :: FOURCC_avih = int(z'68697661', c_int32_t)  ! 'avih'
    integer(c_int32_t), parameter :: FOURCC_strl = int(z'6c727473', c_int32_t)  ! 'strl'
    integer(c_int32_t), parameter :: FOURCC_strh = int(z'68727473', c_int32_t)  ! 'strh'
    integer(c_int32_t), parameter :: FOURCC_strf = int(z'66727473', c_int32_t)  ! 'strf'
    integer(c_int32_t), parameter :: FOURCC_movi = int(z'69766f6d', c_int32_t)  ! 'movi'
    integer(c_int32_t), parameter :: FOURCC_idx1 = int(z'31786469', c_int32_t)  ! 'idx1'
    integer(c_int32_t), parameter :: FOURCC_00dc = int(z'63643030', c_int32_t)  ! '00dc'
    integer(c_int32_t), parameter :: FOURCC_vids = int(z'73646976', c_int32_t)  ! 'vids'
    integer(c_int32_t), parameter :: FOURCC_mpg1 = int(z'3167706d', c_int32_t)  ! 'mpg1'
    
    ! AVI flags
    integer(c_int32_t), parameter :: AVIF_HASINDEX = int(z'00000010', c_int32_t)
    integer(c_int32_t), parameter :: AVIIF_KEYFRAME = int(z'00000010', c_int32_t)
    
    ! AVI header structures
    type :: avi_main_header_t
        integer(c_int32_t) :: microsecond_per_frame
        integer(c_int32_t) :: max_bytes_per_sec
        integer(c_int32_t) :: padding_granularity
        integer(c_int32_t) :: flags
        integer(c_int32_t) :: total_frames
        integer(c_int32_t) :: initial_frames
        integer(c_int32_t) :: streams
        integer(c_int32_t) :: suggested_buffer_size
        integer(c_int32_t) :: width
        integer(c_int32_t) :: height
        integer(c_int32_t) :: reserved(4)
    end type
    
    type :: avi_stream_header_t
        integer(c_int32_t) :: stream_type
        integer(c_int32_t) :: handler
        integer(c_int32_t) :: flags
        integer(c_int16_t) :: priority
        integer(c_int16_t) :: language
        integer(c_int32_t) :: initial_frames
        integer(c_int32_t) :: scale
        integer(c_int32_t) :: rate
        integer(c_int32_t) :: start
        integer(c_int32_t) :: length
        integer(c_int32_t) :: suggested_buffer_size
        integer(c_int32_t) :: quality
        integer(c_int32_t) :: sample_size
        integer(c_int16_t) :: left
        integer(c_int16_t) :: top
        integer(c_int16_t) :: right
        integer(c_int16_t) :: bottom
    end type
    
    type :: bitmap_info_header_t
        integer(c_int32_t) :: size
        integer(c_int32_t) :: width
        integer(c_int32_t) :: height
        integer(c_int16_t) :: planes
        integer(c_int16_t) :: bit_count
        integer(c_int32_t) :: compression
        integer(c_int32_t) :: size_image
        integer(c_int32_t) :: x_pels_per_meter
        integer(c_int32_t) :: y_pels_per_meter
        integer(c_int32_t) :: clr_used
        integer(c_int32_t) :: clr_important
    end type
    
    type :: avi_index_entry_t
        integer(c_int32_t) :: chunk_id
        integer(c_int32_t) :: flags
        integer(c_int32_t) :: offset
        integer(c_int32_t) :: size
    end type

contains

    subroutine mpeg_to_avi(mpeg_file, avi_file, width, height, frame_rate, num_frames)
        character(len=*), intent(in) :: mpeg_file
        character(len=*), intent(in) :: avi_file
        integer, intent(in) :: width, height, frame_rate, num_frames
        
        type(c_ptr) :: avi_ptr, mpeg_ptr
        type(avi_main_header_t) :: main_header
        type(avi_stream_header_t) :: stream_header
        type(bitmap_info_header_t) :: bitmap_header
        type(avi_index_entry_t), allocatable :: index_entries(:)
        
        integer(c_int32_t) :: file_size, list_size, chunk_size
        integer(c_int32_t) :: movi_start_offset, current_offset
        integer :: frame_num, mpeg_frame_size
        integer(c_int8_t), allocatable :: frame_buffer(:)
        integer :: buffer_size, bytes_read
        integer(c_int) :: status
        
        print *, "Converting MPEG to AVI format..."
        print *, "  Input:", trim(mpeg_file)
        print *, "  Output:", trim(avi_file)
        print *, "  Dimensions:", width, "x", height
        print *, "  Frame rate:", frame_rate, "fps"
        print *, "  Frames:", num_frames
        
        ! Allocate index entries
        allocate(index_entries(num_frames))
        
        ! Open files
        avi_ptr = c_fopen(trim(avi_file)//c_null_char, "wb"//c_null_char)
        if (.not. c_associated(avi_ptr)) then
            error stop "Failed to open AVI output file"
        end if
        
        mpeg_ptr = c_fopen(trim(mpeg_file)//c_null_char, "rb"//c_null_char)
        if (.not. c_associated(mpeg_ptr)) then
            status = c_fclose(avi_ptr)
            error stop "Failed to open MPEG input file"
        end if
        
        ! Calculate file size and offsets
        call calculate_avi_structure_sizes(width, height, frame_rate, num_frames, &
                                         file_size, movi_start_offset)
        
        ! Write RIFF header
        call write_riff_header(avi_ptr, file_size)
        
        ! Write header list
        call write_header_list(avi_ptr, width, height, frame_rate, num_frames)
        
        ! Write movie list header
        call write_movi_list_header(avi_ptr)
        
        ! Record movi start for index calculations
        current_offset = 4  ! Start after 'movi' FOURCC
        
        ! Process MPEG frames and write as AVI chunks
        buffer_size = width * height * 2  ! Reasonable buffer size
        allocate(frame_buffer(buffer_size))
        
        do frame_num = 1, num_frames
            ! Read MPEG frame data (simplified - assumes fixed frame size)
            mpeg_frame_size = read_mpeg_frame(mpeg_ptr, frame_buffer, buffer_size, bytes_read)
            
            if (bytes_read <= 0) then
                print *, "Warning: Could not read frame", frame_num
                bytes_read = 0
            end if
            
            ! Write video chunk
            call write_video_chunk(avi_ptr, frame_buffer, bytes_read)
            
            ! Record index entry
            index_entries(frame_num)%chunk_id = FOURCC_00dc
            index_entries(frame_num)%flags = AVIIF_KEYFRAME  ! Mark all as keyframes for simplicity
            index_entries(frame_num)%offset = current_offset
            index_entries(frame_num)%size = bytes_read
            
            current_offset = current_offset + 8 + bytes_read  ! 8 = chunk header size
            if (mod(bytes_read, 2) /= 0) current_offset = current_offset + 1  ! Padding
        end do
        
        ! Write index
        call write_index(avi_ptr, index_entries, num_frames)
        
        ! Cleanup
        deallocate(frame_buffer)
        deallocate(index_entries)
        status = c_fclose(avi_ptr)
        status = c_fclose(mpeg_ptr)
        
        print *, "AVI conversion completed successfully"
    end subroutine

    subroutine calculate_avi_structure_sizes(width, height, frame_rate, num_frames, &
                                           file_size, movi_start)
        integer, intent(in) :: width, height, frame_rate, num_frames
        integer(c_int32_t), intent(out) :: file_size, movi_start
        
        integer(c_int32_t) :: header_size, index_size, estimated_data_size
        
        ! Calculate sizes
        header_size = 12 + 4 + 56 + 8 + 64 + 8 + 40  ! RIFF + LIST hdrl + avih + LIST strl + strh + strf
        estimated_data_size = num_frames * (8 + width * height)  ! Rough estimate
        index_size = 8 + num_frames * 16  ! idx1 header + entries
        movi_start = header_size + 12  ! After 'LIST movi' header
        
        file_size = header_size + 12 + estimated_data_size + index_size - 8  ! -8 for RIFF header
    end subroutine

    subroutine write_riff_header(file_ptr, file_size)
        type(c_ptr), intent(in) :: file_ptr
        integer(c_int32_t), intent(in) :: file_size
        
        integer(c_size_t) :: status
        integer(c_int32_t), target :: riff_fourcc, avi_fourcc, temp_file_size
        
        riff_fourcc = FOURCC_RIFF
        avi_fourcc = FOURCC_AVI
        temp_file_size = file_size
        
        status = c_fwrite(c_loc(riff_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(temp_file_size), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(avi_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
    end subroutine

    subroutine write_header_list(file_ptr, width, height, frame_rate, num_frames)
        type(c_ptr), intent(in) :: file_ptr
        integer, intent(in) :: width, height, frame_rate, num_frames
        
        type(avi_main_header_t), target :: main_header
        type(avi_stream_header_t), target :: stream_header
        type(bitmap_info_header_t), target :: bitmap_header
        integer(c_int32_t), target :: list_size, chunk_size
        integer(c_int32_t), target :: list_fourcc, hdrl_fourcc, avih_fourcc, strl_fourcc, strh_fourcc, strf_fourcc
        integer(c_size_t) :: status
        
        ! Set FOURCC values
        list_fourcc = FOURCC_LIST
        hdrl_fourcc = FOURCC_hdrl
        avih_fourcc = FOURCC_avih
        strl_fourcc = FOURCC_strl
        strh_fourcc = FOURCC_strh
        strf_fourcc = FOURCC_strf
        
        ! Calculate list size
        list_size = 4 + 8 + 56 + 8 + 8 + 64 + 8 + 40  ! hdrl + avih + LIST strl + strh + strf
        
        ! Write LIST hdrl header
        status = c_fwrite(c_loc(list_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(list_size), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(hdrl_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        
        ! Write main AVI header
        call setup_main_header(main_header, width, height, frame_rate, num_frames)
        chunk_size = 56
        status = c_fwrite(c_loc(avih_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(chunk_size), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(main_header), 56_c_size_t, 1_c_size_t, file_ptr)
        
        ! Write stream list
        list_size = 4 + 8 + 64 + 8 + 40  ! strl + strh + strf
        status = c_fwrite(c_loc(list_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(list_size), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(strl_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        
        ! Write stream header
        call setup_stream_header(stream_header, width, height, frame_rate, num_frames)
        chunk_size = 64
        status = c_fwrite(c_loc(strh_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(chunk_size), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(stream_header), 64_c_size_t, 1_c_size_t, file_ptr)
        
        ! Write stream format
        call setup_bitmap_header(bitmap_header, width, height)
        chunk_size = 40
        status = c_fwrite(c_loc(strf_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(chunk_size), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(bitmap_header), 40_c_size_t, 1_c_size_t, file_ptr)
    end subroutine

    subroutine setup_main_header(header, width, height, frame_rate, num_frames)
        type(avi_main_header_t), intent(out) :: header
        integer, intent(in) :: width, height, frame_rate, num_frames
        
        header%microsecond_per_frame = 1000000 / frame_rate
        header%max_bytes_per_sec = width * height * frame_rate
        header%padding_granularity = 0
        header%flags = AVIF_HASINDEX
        header%total_frames = num_frames
        header%initial_frames = 0
        header%streams = 1
        header%suggested_buffer_size = width * height
        header%width = width
        header%height = height
        header%reserved = 0
    end subroutine

    subroutine setup_stream_header(header, width, height, frame_rate, num_frames)
        type(avi_stream_header_t), intent(out) :: header
        integer, intent(in) :: width, height, frame_rate, num_frames
        
        header%stream_type = FOURCC_vids
        header%handler = FOURCC_mpg1
        header%flags = 0
        header%priority = 0
        header%language = 0
        header%initial_frames = 0
        header%scale = 1
        header%rate = frame_rate
        header%start = 0
        header%length = num_frames
        header%suggested_buffer_size = width * height
        header%quality = -1
        header%sample_size = 0
        header%left = 0
        header%top = 0
        header%right = width
        header%bottom = height
    end subroutine

    subroutine setup_bitmap_header(header, width, height)
        type(bitmap_info_header_t), intent(out) :: header
        integer, intent(in) :: width, height
        
        header%size = 40
        header%width = width
        header%height = height
        header%planes = 1
        header%bit_count = 24
        header%compression = FOURCC_mpg1
        header%size_image = width * height * 3
        header%x_pels_per_meter = 0
        header%y_pels_per_meter = 0
        header%clr_used = 0
        header%clr_important = 0
    end subroutine

    subroutine write_movi_list_header(file_ptr)
        type(c_ptr), intent(in) :: file_ptr
        integer(c_int32_t), target :: placeholder_size, list_fourcc, movi_fourcc
        integer(c_size_t) :: status
        
        list_fourcc = FOURCC_LIST
        movi_fourcc = FOURCC_movi
        
        ! Write LIST movi header (size will be updated later)
        placeholder_size = 4  ! Placeholder
        status = c_fwrite(c_loc(list_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(placeholder_size), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(movi_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
    end subroutine

    function read_mpeg_frame(file_ptr, buffer, buffer_size, bytes_read) result(frame_size)
        type(c_ptr), intent(in) :: file_ptr
        integer(c_int8_t), intent(out), target :: buffer(:)
        integer, intent(in) :: buffer_size
        integer, intent(out) :: bytes_read
        integer :: frame_size
        integer(c_size_t) :: read_count
        
        ! Simple frame reading - read up to buffer size
        ! In real implementation, this would parse MPEG frame boundaries
        read_count = c_fread(c_loc(buffer), 1_c_size_t, int(min(buffer_size, 1024), c_size_t), file_ptr)
        bytes_read = int(read_count)
        frame_size = bytes_read
    end function

    subroutine write_video_chunk(file_ptr, data, data_size)
        type(c_ptr), intent(in) :: file_ptr
        integer(c_int8_t), intent(in), target :: data(:)
        integer, intent(in) :: data_size
        
        integer(c_int32_t), target :: chunk_size, video_fourcc
        integer(c_size_t) :: status
        integer(c_int8_t), target :: padding_byte = 0
        
        chunk_size = data_size
        video_fourcc = FOURCC_00dc
        
        ! Write chunk header
        status = c_fwrite(c_loc(video_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(chunk_size), 4_c_size_t, 1_c_size_t, file_ptr)
        
        ! Write data
        if (data_size > 0) then
            status = c_fwrite(c_loc(data), 1_c_size_t, int(data_size, c_size_t), file_ptr)
            
            ! Add padding byte if needed (AVI chunks must be word-aligned)
            if (mod(data_size, 2) /= 0) then
                status = c_fwrite(c_loc(padding_byte), 1_c_size_t, 1_c_size_t, file_ptr)
            end if
        end if
    end subroutine

    subroutine write_index(file_ptr, entries, num_entries)
        type(c_ptr), intent(in) :: file_ptr
        type(avi_index_entry_t), intent(in) :: entries(:)
        integer, intent(in) :: num_entries
        
        integer(c_int32_t), target :: chunk_size, idx1_fourcc
        integer(c_size_t) :: status
        integer :: i
        
        chunk_size = num_entries * 16
        idx1_fourcc = FOURCC_idx1
        
        ! Write index header
        status = c_fwrite(c_loc(idx1_fourcc), 4_c_size_t, 1_c_size_t, file_ptr)
        status = c_fwrite(c_loc(chunk_size), 4_c_size_t, 1_c_size_t, file_ptr)
        
        ! Write index entries
        do i = 1, num_entries
            ! Copy to temporary variables for c_loc compatibility
            block
                integer(c_int32_t), target :: temp_chunk_id, temp_flags, temp_offset, temp_size
                temp_chunk_id = entries(i)%chunk_id
                temp_flags = entries(i)%flags
                temp_offset = entries(i)%offset
                temp_size = entries(i)%size
                
                status = c_fwrite(c_loc(temp_chunk_id), 4_c_size_t, 1_c_size_t, file_ptr)
                status = c_fwrite(c_loc(temp_flags), 4_c_size_t, 1_c_size_t, file_ptr)
                status = c_fwrite(c_loc(temp_offset), 4_c_size_t, 1_c_size_t, file_ptr)
                status = c_fwrite(c_loc(temp_size), 4_c_size_t, 1_c_size_t, file_ptr)
            end block
        end do
    end subroutine

end module fortplot_mpeg_avi