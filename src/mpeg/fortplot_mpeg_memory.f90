module fortplot_mpeg_memory
    use iso_c_binding
    implicit none
    private
    
    ! Memory structure definition
    type :: mem_t
        integer :: len
        integer :: width
        integer :: height
        integer(c_int8_t), allocatable :: data(:)
    end type mem_t
    
    ! I/O buffer structure definition
    type :: iobuf_t
        integer :: hpos
        integer :: vpos
        integer :: hor
        integer :: ver
        integer :: width
        integer :: height
        integer :: flag
        type(mem_t), pointer :: mem => null()
    end type iobuf_t
    
    public :: mem_t, iobuf_t
    public :: mem_create, mem_destroy, mem_resize
    public :: mem_get_bounds, mem_set_bounds
    public :: mem_copy, mem_clear, mem_set
    public :: mem_load, mem_load_partial, mem_save, mem_save_partial
    public :: iobuf_create, iobuf_destroy, iobuf_initialize
    public :: iobuf_set_position, iobuf_get_position
    public :: char_bound, lower_bound, upper_bound
    
contains

    function mem_create(width, height) result(mem)
        integer, intent(in) :: width, height
        type(mem_t) :: mem
        
        mem%width = width
        mem%height = height
        mem%len = width * height
        
        if (mem%len > 0) then
            allocate(mem%data(mem%len))
            mem%data = 0_c_int8_t
        end if
    end function mem_create

    subroutine mem_destroy(mem)
        type(mem_t), intent(inout) :: mem
        
        if (allocated(mem%data)) then
            deallocate(mem%data)
        end if
        
        mem%width = 0
        mem%height = 0
        mem%len = 0
    end subroutine mem_destroy

    subroutine mem_resize(mem, new_width, new_height)
        type(mem_t), intent(inout) :: mem
        integer, intent(in) :: new_width, new_height
        integer :: new_len
        
        new_len = new_width * new_height
        
        if (allocated(mem%data)) then
            deallocate(mem%data)
        end if
        
        mem%width = new_width
        mem%height = new_height
        mem%len = new_len
        
        if (new_len > 0) then
            allocate(mem%data(new_len))
            mem%data = 0_c_int8_t
        end if
    end subroutine mem_resize

    function mem_get_bounds(mem, index) result(bounded_index)
        type(mem_t), intent(in) :: mem
        integer, intent(in) :: index
        integer :: bounded_index
        
        bounded_index = max(1, min(index, mem%len))
    end function mem_get_bounds

    subroutine mem_set_bounds(mem, index, value)
        type(mem_t), intent(inout) :: mem
        integer, intent(in) :: index
        integer(c_int8_t), intent(in) :: value
        integer :: bounded_index
        
        if (.not. allocated(mem%data)) return
        
        bounded_index = mem_get_bounds(mem, index)
        mem%data(bounded_index) = value
    end subroutine mem_set_bounds

    function iobuf_create(width, height, block_hor, block_ver) result(iobuf)
        integer, intent(in) :: width, height, block_hor, block_ver
        type(iobuf_t) :: iobuf
        
        iobuf%width = width
        iobuf%height = height
        iobuf%hor = block_hor
        iobuf%ver = block_ver
        iobuf%hpos = 0
        iobuf%vpos = 0
        iobuf%flag = 0
        
        allocate(iobuf%mem)
        iobuf%mem = mem_create(width, height)
    end function iobuf_create

    subroutine iobuf_destroy(iobuf)
        type(iobuf_t), intent(inout) :: iobuf
        
        if (associated(iobuf%mem)) then
            call mem_destroy(iobuf%mem)
            deallocate(iobuf%mem)
            iobuf%mem => null()
        end if
        
        iobuf%width = 0
        iobuf%height = 0
        iobuf%hor = 0
        iobuf%ver = 0
        iobuf%hpos = 0
        iobuf%vpos = 0
        iobuf%flag = 0
    end subroutine iobuf_destroy

    subroutine iobuf_initialize(iobuf, width, height, block_hor, block_ver)
        type(iobuf_t), intent(inout) :: iobuf
        integer, intent(in) :: width, height, block_hor, block_ver
        
        ! Clean up existing memory if any
        if (associated(iobuf%mem)) then
            call mem_destroy(iobuf%mem)
            deallocate(iobuf%mem)
        end if
        
        ! Initialize new buffer
        iobuf%width = width
        iobuf%height = height
        iobuf%hor = block_hor
        iobuf%ver = block_ver
        iobuf%hpos = 0
        iobuf%vpos = 0
        iobuf%flag = 0
        
        allocate(iobuf%mem)
        iobuf%mem = mem_create(width, height)
    end subroutine iobuf_initialize

    subroutine iobuf_set_position(iobuf, hpos, vpos)
        type(iobuf_t), intent(inout) :: iobuf
        integer, intent(in) :: hpos, vpos
        
        iobuf%hpos = max(0, min(hpos, iobuf%width - iobuf%hor))
        iobuf%vpos = max(0, min(vpos, iobuf%height - iobuf%ver))
    end subroutine iobuf_set_position

    subroutine iobuf_get_position(iobuf, hpos, vpos)
        type(iobuf_t), intent(in) :: iobuf
        integer, intent(out) :: hpos, vpos
        
        hpos = iobuf%hpos
        vpos = iobuf%vpos
    end subroutine iobuf_get_position

    ! Utility functions for bounds checking (MPEG equivalents)
    function char_bound(value) result(bounded_value)
        integer, intent(in) :: value
        integer :: bounded_value
        
        bounded_value = max(0, min(value, 255))
    end function char_bound

    function lower_bound(index, lower_limit) result(bounded_index)
        integer, intent(in) :: index, lower_limit
        integer :: bounded_index
        
        bounded_index = max(index, lower_limit)
    end function lower_bound

    function upper_bound(index, upper_limit) result(bounded_index)
        integer, intent(in) :: index, upper_limit
        integer :: bounded_index
        
        bounded_index = min(index, upper_limit)
    end function upper_bound

    subroutine mem_copy(source, dest)
        type(mem_t), intent(in) :: source
        type(mem_t), intent(inout) :: dest
        
        ! Ensure destination has correct size
        if (dest%width /= source%width .or. dest%height /= source%height) then
            call mem_destroy(dest)
            dest = mem_create(source%width, source%height)
        end if
        
        ! Copy data
        if (allocated(source%data) .and. allocated(dest%data)) then
            dest%data = source%data
        end if
    end subroutine mem_copy

    subroutine mem_clear(mem)
        type(mem_t), intent(inout) :: mem
        
        if (allocated(mem%data)) then
            mem%data = 0_c_int8_t
        end if
    end subroutine mem_clear

    subroutine mem_set(mem, value)
        type(mem_t), intent(inout) :: mem
        integer(c_int8_t), intent(in) :: value
        
        if (allocated(mem%data)) then
            mem%data = value
        end if
    end subroutine mem_set

    function mem_load(filename, width, height) result(mem)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: width, height
        type(mem_t) :: mem
        integer :: unit_num, iostat
        
        mem = mem_create(width, height)
        
        open(newunit=unit_num, file=filename, access='stream', form='unformatted', &
             status='old', iostat=iostat)
        if (iostat /= 0) then
            print *, "Warning: Could not open file for reading: ", filename
            return
        end if
        
        if (allocated(mem%data)) then
            read(unit_num, iostat=iostat) mem%data
            if (iostat /= 0) then
                print *, "Warning: Could not read data from file: ", filename
            end if
        end if
        
        close(unit_num)
    end function mem_load

    function mem_load_partial(filename, start_x, start_y, width, height, total_width) result(mem)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: start_x, start_y, width, height, total_width
        type(mem_t) :: mem
        integer :: unit_num, iostat, i, row_offset, file_pos
        
        mem = mem_create(width, height)
        
        open(newunit=unit_num, file=filename, access='stream', form='unformatted', &
             status='old', iostat=iostat)
        if (iostat /= 0) then
            print *, "Warning: Could not open file for reading: ", filename
            return
        end if
        
        if (allocated(mem%data)) then
            ! Read row by row to handle partial loading
            do i = 1, height
                ! Calculate file position (0-based for file, account for 1-based arrays)
                row_offset = (start_y + i - 2) * total_width + (start_x - 1)
                file_pos = row_offset + 1  ! Fortran stream I/O uses 1-based positions
                read(unit_num, pos=file_pos, iostat=iostat) &
                    mem%data((i-1)*width+1:i*width)
                if (iostat /= 0) then
                    print *, "Warning: Could not read partial data at row", i
                    exit
                end if
            end do
        end if
        
        close(unit_num)
    end function mem_load_partial

    subroutine mem_save(mem, filename)
        type(mem_t), intent(in) :: mem
        character(len=*), intent(in) :: filename
        integer :: unit_num, iostat
        
        open(newunit=unit_num, file=filename, access='stream', form='unformatted', &
             status='replace', iostat=iostat)
        if (iostat /= 0) then
            print *, "Warning: Could not open file for writing: ", filename
            return
        end if
        
        if (allocated(mem%data)) then
            write(unit_num, iostat=iostat) mem%data
            if (iostat /= 0) then
                print *, "Warning: Could not write data to file: ", filename
            end if
        end if
        
        close(unit_num)
    end subroutine mem_save

    subroutine mem_save_partial(mem, filename, start_x, start_y, total_width)
        type(mem_t), intent(in) :: mem
        character(len=*), intent(in) :: filename
        integer, intent(in) :: start_x, start_y, total_width
        integer :: unit_num, iostat, i, row_offset, file_pos
        
        open(newunit=unit_num, file=filename, access='stream', form='unformatted', &
             status='old', position='append', iostat=iostat)
        if (iostat /= 0) then
            print *, "Warning: Could not open file for partial writing: ", filename
            return
        end if
        
        if (allocated(mem%data)) then
            ! Write row by row to handle partial saving
            do i = 1, mem%height
                ! Calculate file position (0-based for file, account for 1-based arrays)
                row_offset = (start_y + i - 2) * total_width + (start_x - 1)
                file_pos = row_offset + 1  ! Fortran stream I/O uses 1-based positions
                write(unit_num, pos=file_pos, iostat=iostat) &
                    mem%data((i-1)*mem%width+1:i*mem%width)
                if (iostat /= 0) then
                    print *, "Warning: Could not write partial data at row", i
                    exit
                end if
            end do
        end if
        
        close(unit_num)
    end subroutine mem_save_partial

end module fortplot_mpeg_memory