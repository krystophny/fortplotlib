program validate_memory_fortran
    use fortplot_mpeg_memory
    use iso_c_binding
    implicit none
    
    ! Test Fortran memory implementation
    call test_mem_operations()
    call test_iobuf_operations()
    call test_bounds_functions()
    call test_memory_allocation()
    
    print *, "PASS: Fortran memory implementation validation"
    
contains

    subroutine test_mem_operations()
        type(mem_t) :: test_mem
        integer, parameter :: test_width = 16
        integer, parameter :: test_height = 16
        integer :: bounded_index
        
        ! Create memory structure
        test_mem = mem_create(test_width, test_height)
        
        if (test_mem%width /= test_width) then
            error stop "MEM width creation failed"
        end if
        
        if (test_mem%height /= test_height) then
            error stop "MEM height creation failed"
        end if
        
        if (test_mem%len /= test_width * test_height) then
            error stop "MEM length calculation failed"
        end if
        
        if (.not. allocated(test_mem%data)) then
            error stop "MEM data allocation failed"
        end if
        
        ! Test bounds checking
        bounded_index = mem_get_bounds(test_mem, -5)
        if (bounded_index /= 1) then
            error stop "Lower bounds check failed"
        end if
        
        bounded_index = mem_get_bounds(test_mem, test_mem%len + 10)
        if (bounded_index /= test_mem%len) then
            error stop "Upper bounds check failed"
        end if
        
        ! Test data access
        call mem_set_bounds(test_mem, 1, 42_c_int8_t)
        if (test_mem%data(1) /= 42_c_int8_t) then
            error stop "MEM data access failed"
        end if
        
        ! Resize memory
        call mem_resize(test_mem, 32, 32)
        if (test_mem%width /= 32 .or. test_mem%height /= 32) then
            error stop "MEM resize failed"
        end if
        
        ! Clean up
        call mem_destroy(test_mem)
        if (allocated(test_mem%data)) then
            error stop "MEM cleanup failed"
        end if
        
        print *, "PASS: MEM operations"
    end subroutine

    subroutine test_iobuf_operations()
        type(iobuf_t) :: test_iobuf
        integer :: hpos, vpos
        
        ! Create I/O buffer
        test_iobuf = iobuf_create(352, 240, 16, 16)
        
        if (test_iobuf%width /= 352) then
            error stop "IOBUF width creation failed"
        end if
        
        if (test_iobuf%height /= 240) then
            error stop "IOBUF height creation failed"
        end if
        
        if (test_iobuf%hor /= 16 .or. test_iobuf%ver /= 16) then
            error stop "IOBUF block size creation failed"
        end if
        
        if (.not. associated(test_iobuf%mem)) then
            error stop "IOBUF memory association failed"
        end if
        
        ! Test position operations
        call iobuf_set_position(test_iobuf, 100, 50)
        call iobuf_get_position(test_iobuf, hpos, vpos)
        
        if (hpos /= 100 .or. vpos /= 50) then
            error stop "IOBUF position operations failed"
        end if
        
        ! Test bounds on position
        call iobuf_set_position(test_iobuf, -10, -10)
        call iobuf_get_position(test_iobuf, hpos, vpos)
        
        if (hpos /= 0 .or. vpos /= 0) then
            error stop "IOBUF position lower bounds failed"
        end if
        
        ! Test reinitialization
        call iobuf_initialize(test_iobuf, 176, 120, 8, 8)
        
        if (test_iobuf%width /= 176 .or. test_iobuf%height /= 120) then
            error stop "IOBUF reinitialization failed"
        end if
        
        ! Clean up
        call iobuf_destroy(test_iobuf)
        if (associated(test_iobuf%mem)) then
            error stop "IOBUF cleanup failed"
        end if
        
        print *, "PASS: IOBUF operations"
    end subroutine

    subroutine test_bounds_functions()
        integer :: result
        
        ! Test character bounds (0-255)
        result = char_bound(300)
        if (result /= 255) then
            error stop "Character upper bound failed"
        end if
        
        result = char_bound(-50)
        if (result /= 0) then
            error stop "Character lower bound failed"
        end if
        
        result = char_bound(128)
        if (result /= 128) then
            error stop "Character valid range failed"
        end if
        
        ! Test lower bound function
        result = lower_bound(5, 10)
        if (result /= 10) then
            error stop "Lower bound function failed"
        end if
        
        result = lower_bound(15, 10)
        if (result /= 15) then
            error stop "Lower bound passthrough failed"
        end if
        
        ! Test upper bound function
        result = upper_bound(15, 10)
        if (result /= 10) then
            error stop "Upper bound function failed"
        end if
        
        result = upper_bound(5, 10)
        if (result /= 5) then
            error stop "Upper bound passthrough failed"
        end if
        
        print *, "PASS: bounds functions"
    end subroutine

    subroutine test_memory_allocation()
        type(mem_t) :: mem1, mem2, mem3
        type(iobuf_t) :: iobuf1, iobuf2
        
        ! Test multiple allocations
        mem1 = mem_create(100, 100)
        mem2 = mem_create(200, 150)
        mem3 = mem_create(50, 50)
        
        if (.not. allocated(mem1%data) .or. .not. allocated(mem2%data) .or. .not. allocated(mem3%data)) then
            error stop "Multiple memory allocations failed"
        end if
        
        ! Test multiple I/O buffers
        iobuf1 = iobuf_create(352, 240, 16, 16)
        iobuf2 = iobuf_create(176, 120, 8, 8)
        
        if (.not. associated(iobuf1%mem) .or. .not. associated(iobuf2%mem)) then
            error stop "Multiple IOBUF allocations failed"
        end if
        
        ! Clean up
        call mem_destroy(mem1)
        call mem_destroy(mem2)
        call mem_destroy(mem3)
        call iobuf_destroy(iobuf1)
        call iobuf_destroy(iobuf2)
        
        print *, "PASS: memory allocation stress test"
    end subroutine

end program validate_memory_fortran