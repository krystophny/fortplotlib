program test_forttf_final_accumulation_precision
    !! Test to identify exact precision differences in final accumulation
    !! STB uses float (32-bit) while forttf uses real64 (64-bit)
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64, real32
    implicit none

    ! Test values from actual bitmap differences
    real(wp) :: test_values_wp(10)
    real(real32) :: test_values_32(10)
    integer :: i, result_wp, result_32
    real(wp) :: k_wp
    real(real32) :: k_32
    real(wp) :: boundary_tests(5)

    ! Example scanline values that might cause differences
    test_values_wp = [-0.123_wp, 0.456_wp, -0.789_wp, 0.234_wp, -0.567_wp, &
                      0.891_wp, -0.345_wp, 0.678_wp, -0.912_wp, 0.135_wp]
    test_values_32 = [-0.123, 0.456, -0.789, 0.234, -0.567, &
                      0.891, -0.345, 0.678, -0.912, 0.135]

    write(*,*) '=== FINAL ACCUMULATION PRECISION TEST ==='
    write(*,*) 'Testing STB float vs forttf real64 precision differences'
    write(*,*)
    write(*,*) 'Input Value      STB(float)  forttf(real64)  Difference'
    write(*,*) '------------------------------------------------------'

    do i = 1, 10
        ! STB formula with float precision
        k_32 = real(abs(test_values_32(i)), real32) * 255.0 + 0.5
        result_32 = int(k_32)
        if (result_32 > 255) result_32 = 255

        ! Our formula with real64 precision  
        k_wp = abs(test_values_wp(i)) * 255.0_wp + 0.5_wp
        result_wp = int(k_wp)
        if (result_wp > 255) result_wp = 255

        write(*,'(F12.6, 6X, I3, 9X, I3, 9X, I4)') &
            test_values_wp(i), result_32, result_wp, result_wp - result_32
    end do

    write(*,*)
    write(*,*) '=== CRITICAL TEST: Values near 0.5 boundary ==='
    
    ! Test values that are exactly at rounding boundaries
    boundary_tests = [0.001960_wp, 0.001961_wp, 0.001962_wp, &
                      0.001963_wp, 0.001964_wp]
    
    do i = 1, 5
        ! STB formula with float precision
        k_32 = real(abs(boundary_tests(i)), real32) * 255.0 + 0.5
        result_32 = int(k_32)
        
        ! Our formula with real64 precision
        k_wp = abs(boundary_tests(i)) * 255.0_wp + 0.5_wp  
        result_wp = int(k_wp)
        
        write(*,'(A, F12.9, A, I3, A, I3, A, I4)') &
            'Value: ', boundary_tests(i), ' STB: ', result_32, &
            ' forttf: ', result_wp, ' diff: ', result_wp - result_32
    end do

    write(*,*)
    if (any(abs(test_values_wp(1:10) * 255.0_wp + 0.5_wp - &
               test_values_32(1:10) * 255.0 - 0.5) > 1e-6)) then
        write(*,*) '*** PRECISION DIFFERENCES DETECTED ***'
        write(*,*) 'This confirms float vs real64 is causing pixel differences!'
    else
        write(*,*) 'No significant precision differences found'
    end if

end program test_forttf_final_accumulation_precision