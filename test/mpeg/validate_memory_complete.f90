program validate_memory_complete
    use fortplot_mpeg_memory
    use iso_c_binding
    implicit none
    
    ! Test all memory functionality including new file I/O functions
    call test_memory_copy_operations()
    call test_memory_set_clear_operations()
    call test_memory_file_io_operations()
    call test_memory_partial_file_operations()
    
    print *, "PASS: All memory operation validation tests"
    
contains

    subroutine test_memory_copy_operations()
        type(mem_t) :: source, dest
        integer :: i
        
        ! Create source memory with test pattern
        source = mem_create(4, 3)
        do i = 1, source%len
            source%data(i) = int(i * 2, c_int8_t)
        end do
        
        ! Test copy to uninitialized destination
        dest = mem_create(1, 1)  ! Wrong size initially
        call mem_copy(source, dest)
        
        ! Verify copy worked
        if (dest%width /= source%width .or. dest%height /= source%height) then
            error stop "Memory copy failed to resize destination"
        end if
        
        do i = 1, source%len
            if (dest%data(i) /= source%data(i)) then
                error stop "Memory copy failed to copy data correctly"
            end if
        end do
        
        call mem_destroy(source)
        call mem_destroy(dest)
        print *, "PASS: Memory copy operations"
    end subroutine

    subroutine test_memory_set_clear_operations()
        type(mem_t) :: mem
        integer :: i
        
        ! Test set operation
        mem = mem_create(3, 2)
        call mem_set(mem, 42_c_int8_t)
        
        do i = 1, mem%len
            if (mem%data(i) /= 42_c_int8_t) then
                error stop "Memory set operation failed"
            end if
        end do
        
        ! Test clear operation
        call mem_clear(mem)
        
        do i = 1, mem%len
            if (mem%data(i) /= 0_c_int8_t) then
                error stop "Memory clear operation failed"
            end if
        end do
        
        call mem_destroy(mem)
        print *, "PASS: Memory set/clear operations"
    end subroutine

    subroutine test_memory_file_io_operations()
        type(mem_t) :: original, loaded
        integer :: i
        character(len=*), parameter :: test_file = "test_memory_io.dat"
        
        ! Create original memory with test pattern
        original = mem_create(5, 4)
        do i = 1, original%len
            original%data(i) = int(mod(i * 3, 256), c_int8_t)
        end do
        
        ! Save to file
        call mem_save(original, test_file)
        
        ! Load from file
        loaded = mem_load(test_file, 5, 4)
        
        ! Verify loaded data matches original
        if (loaded%width /= original%width .or. loaded%height /= original%height) then
            error stop "Memory load failed to preserve dimensions"
        end if
        
        do i = 1, original%len
            if (loaded%data(i) /= original%data(i)) then
                print *, "Mismatch at position", i
                print *, "Original:", original%data(i)
                print *, "Loaded:  ", loaded%data(i)
                error stop "Memory load/save roundtrip failed"
            end if
        end do
        
        call mem_destroy(original)
        call mem_destroy(loaded)
        print *, "PASS: Memory file I/O operations"
    end subroutine

    subroutine test_memory_partial_file_operations()
        type(mem_t) :: full_image, partial_region, loaded_partial
        integer :: i, j
        integer :: expected_val, actual_val, linear_index
        character(len=*), parameter :: full_file = "test_full_image.dat"
        character(len=*), parameter :: partial_file = "test_partial_image.dat"
        integer, parameter :: full_width = 8, full_height = 6
        integer, parameter :: partial_width = 3, partial_height = 2
        integer, parameter :: start_x = 2, start_y = 1
        
        ! Create full image with identifiable pattern
        full_image = mem_create(full_width, full_height)
        do i = 1, full_height
            do j = 1, full_width
                full_image%data((i-1)*full_width + j) = &
                    int(i * 10 + j, c_int8_t)
            end do
        end do
        
        ! Save full image
        call mem_save(full_image, full_file)
        
        ! Create partial region to save
        partial_region = mem_create(partial_width, partial_height)
        do i = 1, partial_height
            do j = 1, partial_width
                partial_region%data((i-1)*partial_width + j) = &
                    int(100 + i * 10 + j, c_int8_t)
            end do
        end do
        
        ! Save partial region to separate file first (to test basic partial save)
        call mem_save(partial_region, partial_file)
        
        ! Load partial region from full image
        loaded_partial = mem_load_partial(full_file, start_x, start_y, &
                                        partial_width, partial_height, full_width)
        
        ! Verify loaded partial dimensions
        if (loaded_partial%width /= partial_width .or. &
            loaded_partial%height /= partial_height) then
            error stop "Partial load failed to preserve dimensions"
        end if
        
        ! Verify loaded partial data matches expected values from full image
        do i = 1, partial_height
            do j = 1, partial_width
                expected_val = (start_y + i - 1) * 10 + (start_x + j - 1)
                linear_index = (i-1)*partial_width + j
                actual_val = int(loaded_partial%data(linear_index))
                
                if (actual_val /= expected_val) then
                    print *, "Partial load mismatch at (", i, ",", j, ")"
                    print *, "Expected:", expected_val
                    print *, "Actual:  ", actual_val
                    error stop "Partial load data mismatch"
                end if
            end do
        end do
        
        call mem_destroy(full_image)
        call mem_destroy(partial_region)
        call mem_destroy(loaded_partial)
        print *, "PASS: Memory partial file operations"
    end subroutine

end program validate_memory_complete