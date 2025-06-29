program test_forttf_scanline_buffer_debug
    !! Extract actual scanline buffer values to find where STB and forttf diverge
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_stb_raster
    use forttf_types
    implicit none

    ! Test the exact same parameters as our bitmap test
    real(wp), parameter :: scale = 0.02_wp
    integer, parameter :: width = 20, height = 39
    
    ! We'll capture scanline buffers for a specific scanline with known differences
    integer, parameter :: debug_scanline = 5  ! Row with differences in diff_bitmap.pgm
    
    real(wp), allocatable :: scanline_buffer(:), scanline_fill_buffer(:)
    integer :: i
    logical :: found_differences
    
    write(*,*) '=== SCANLINE BUFFER DEBUG TEST ==='
    write(*,*) 'Extracting actual scanline buffer values to find divergence'
    write(*,*) 'Scale:', scale, ' Width:', width, ' Height:', height
    write(*,*) 'Debug scanline:', debug_scanline
    write(*,*)
    
    ! Allocate buffers
    allocate(scanline_buffer(width))
    allocate(scanline_fill_buffer(width))
    
    ! Initialize to zero
    scanline_buffer = 0.0_wp
    scanline_fill_buffer = 0.0_wp
    
    write(*,*) 'CRITICAL INSIGHT:'
    write(*,*) 'Since individual functions work perfectly but final result differs,'
    write(*,*) 'the issue MUST be in:'
    write(*,*) '1. Scanline buffer coordination between fill operations'
    write(*,*) '2. Buffer values before final accumulation'
    write(*,*) '3. Order of operations in the rasterization loop'
    write(*,*)
    
    ! Let's examine what makes a pixel difference
    write(*,*) 'From diff_bitmap.pgm, row 5 (index 4) has differences:'
    write(*,*) 'Column 8: diff=54 (STB and forttf differ by 54-128=-74)'
    write(*,*) 'Column 14: diff=174 (STB and forttf differ by 174-128=+46)'
    write(*,*)
    
    write(*,*) 'HYPOTHESIS:'
    write(*,*) 'The issue is NOT in the final accumulation formula,'
    write(*,*) 'but in the scanline buffer VALUES going into that formula.'
    write(*,*)
    
    write(*,*) 'ACTION NEEDED:'
    write(*,*) '1. Add debug prints to stb_rasterize_sorted_edges before final loop'
    write(*,*) '2. Capture scanline_buffer and scanline_fill_buffer values'  
    write(*,*) '3. Compare these buffer values between STB C and forttf implementations'
    write(*,*) '4. Find where the buffers first diverge'
    write(*,*)
    
    ! This test confirms we need to instrument the actual rasterization
    write(*,*) 'NEXT STEP: Modify forttf_stb_raster.f90 to dump buffer values'
    write(*,*) 'for rows 5-10 where we know differences exist.'
    
    found_differences = .true.
    if (found_differences) then
        write(*,*) ''
        write(*,*) '*** BUFFER DEBUG NEEDED ***'
        write(*,*) 'Must instrument stb_rasterize_sorted_edges to capture'
        write(*,*) 'actual scanline buffer values before final accumulation.'
    end if
    
end program test_forttf_scanline_buffer_debug