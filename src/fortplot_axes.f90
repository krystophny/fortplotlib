module fortplot_axes
    !! Axes and tick generation module
    !! 
    !! This module handles axis drawing, tick computation, and label formatting
    !! for all scale types. Follows Single Responsibility Principle by focusing
    !! solely on axis-related functionality.
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_context
    use fortplot_scales
    implicit none
    
    private
    public :: compute_scale_ticks, format_tick_label
    
    integer, parameter :: MAX_TICKS = 20
    
contains

    subroutine compute_scale_ticks(scale_type, data_min, data_max, threshold, tick_positions, num_ticks)
        !! Compute tick positions for different scale types
        !! 
        !! @param scale_type: Type of scale ('linear', 'log', 'symlog')
        !! @param data_min: Minimum data value
        !! @param data_max: Maximum data value
        !! @param threshold: Threshold for symlog (ignored for others)
        !! @param tick_positions: Output array of tick positions
        !! @param num_ticks: Number of ticks generated
        
        character(len=*), intent(in) :: scale_type
        real(wp), intent(in) :: data_min, data_max, threshold
        real(wp), intent(out) :: tick_positions(MAX_TICKS)
        integer, intent(out) :: num_ticks
        
        select case (trim(scale_type))
        case ('linear')
            call compute_linear_ticks(data_min, data_max, tick_positions, num_ticks)
        case ('log')
            call compute_log_ticks(data_min, data_max, tick_positions, num_ticks)
        case ('symlog')
            call compute_symlog_ticks(data_min, data_max, threshold, tick_positions, num_ticks)
        case default
            call compute_linear_ticks(data_min, data_max, tick_positions, num_ticks)
        end select
    end subroutine compute_scale_ticks

    subroutine compute_linear_ticks(data_min, data_max, tick_positions, num_ticks)
        !! Compute tick positions for linear scale
        real(wp), intent(in) :: data_min, data_max
        real(wp), intent(out) :: tick_positions(MAX_TICKS)
        integer, intent(out) :: num_ticks
        
        real(wp) :: range, step, nice_step, tick_value
        integer :: max_ticks_desired
        
        max_ticks_desired = 8
        range = data_max - data_min
        
        if (range <= 0.0_wp) then
            num_ticks = 0
            return
        end if
        
        step = range / real(max_ticks_desired, wp)
        nice_step = calculate_nice_step(step)
        
        ! Find first tick >= data_min
        tick_value = ceiling(data_min / nice_step) * nice_step
        num_ticks = 0
        
        do while (tick_value <= data_max .and. num_ticks < MAX_TICKS)
            num_ticks = num_ticks + 1
            tick_positions(num_ticks) = tick_value
            tick_value = tick_value + nice_step
        end do
    end subroutine compute_linear_ticks

    subroutine compute_log_ticks(data_min, data_max, tick_positions, num_ticks)
        !! Compute tick positions for logarithmic scale
        real(wp), intent(in) :: data_min, data_max
        real(wp), intent(out) :: tick_positions(MAX_TICKS)
        integer, intent(out) :: num_ticks
        
        real(wp) :: log_min, log_max, current_power
        integer :: start_power, end_power, power
        
        if (data_min <= 0.0_wp .or. data_max <= 0.0_wp) then
            num_ticks = 0
            return
        end if
        
        log_min = log10(data_min)
        log_max = log10(data_max)
        
        start_power = floor(log_min)
        end_power = ceiling(log_max)
        
        num_ticks = 0
        do power = start_power, end_power
            if (num_ticks >= MAX_TICKS) exit
            current_power = 10.0_wp**power
            if (current_power >= data_min .and. current_power <= data_max) then
                num_ticks = num_ticks + 1
                tick_positions(num_ticks) = current_power
            end if
        end do
    end subroutine compute_log_ticks

    subroutine compute_symlog_ticks(data_min, data_max, threshold, tick_positions, num_ticks)
        !! Compute tick positions for symmetric logarithmic scale
        real(wp), intent(in) :: data_min, data_max, threshold
        real(wp), intent(out) :: tick_positions(MAX_TICKS)
        integer, intent(out) :: num_ticks
        
        num_ticks = 0
        
        ! Add negative log region ticks
        if (data_min < -threshold) then
            call add_negative_symlog_ticks(data_min, -threshold, tick_positions, num_ticks)
        end if
        
        ! Add linear region ticks
        if (data_min <= threshold .and. data_max >= -threshold) then
            call add_linear_symlog_ticks(max(data_min, -threshold), min(data_max, threshold), &
                                       tick_positions, num_ticks)
        end if
        
        ! Add positive log region ticks
        if (data_max > threshold) then
            call add_positive_symlog_ticks(threshold, data_max, tick_positions, num_ticks)
        end if
    end subroutine compute_symlog_ticks

    function format_tick_label(value, scale_type) result(label)
        !! Format a tick value as a string label
        !! 
        !! @param value: Tick value to format
        !! @param scale_type: Scale type for context
        !! @return label: Formatted label string
        
        real(wp), intent(in) :: value
        character(len=*), intent(in) :: scale_type
        character(len=20) :: label
        
        if (abs(value) < 1.0e-10_wp) then
            label = '0'
        else if (trim(scale_type) == 'log' .and. is_power_of_ten(value)) then
            label = format_power_of_ten(value)
        else
            write(label, '(G0)') value
        end if
    end function format_tick_label



    ! Helper subroutines (implementation details)
    
    function calculate_nice_step(raw_step) result(nice_step)
        real(wp), intent(in) :: raw_step
        real(wp) :: nice_step, magnitude, normalized
        
        magnitude = 10.0_wp**floor(log10(raw_step))
        normalized = raw_step / magnitude
        
        if (normalized <= 1.0_wp) then
            nice_step = magnitude
        else if (normalized <= 2.0_wp) then
            nice_step = 2.0_wp * magnitude
        else if (normalized <= 5.0_wp) then
            nice_step = 5.0_wp * magnitude
        else
            nice_step = 10.0_wp * magnitude
        end if
    end function calculate_nice_step
    
    subroutine add_negative_symlog_ticks(data_min, upper_bound, tick_positions, num_ticks)
        real(wp), intent(in) :: data_min, upper_bound
        real(wp), intent(inout) :: tick_positions(MAX_TICKS)
        integer, intent(inout) :: num_ticks
        
        ! Suppress unused parameter warnings for stub implementation
        associate(unused_real => data_min + upper_bound, &
                  unused_arr => tick_positions, unused_int => num_ticks); end associate
        
        ! Implementation for negative symlog region (placeholder)
    end subroutine add_negative_symlog_ticks
    
    subroutine add_linear_symlog_ticks(lower_bound, upper_bound, tick_positions, num_ticks)
        real(wp), intent(in) :: lower_bound, upper_bound
        real(wp), intent(inout) :: tick_positions(MAX_TICKS)
        integer, intent(inout) :: num_ticks
        
        ! Suppress unused parameter warnings for stub implementation
        associate(unused_real => lower_bound + upper_bound, &
                  unused_arr => tick_positions, unused_int => num_ticks); end associate
        
        ! Implementation for linear symlog region (placeholder)
    end subroutine add_linear_symlog_ticks
    
    subroutine add_positive_symlog_ticks(lower_bound, data_max, tick_positions, num_ticks)
        real(wp), intent(in) :: lower_bound, data_max
        real(wp), intent(inout) :: tick_positions(MAX_TICKS)
        integer, intent(inout) :: num_ticks
        
        ! Suppress unused parameter warnings for stub implementation
        associate(unused_real => lower_bound + data_max, &
                  unused_arr => tick_positions, unused_int => num_ticks); end associate
        
        ! Implementation for positive symlog region (placeholder)
    end subroutine add_positive_symlog_ticks
    
    function is_power_of_ten(value) result(is_power)
        real(wp), intent(in) :: value
        logical :: is_power
        real(wp) :: log_val
        log_val = log10(abs(value))
        is_power = abs(log_val - nint(log_val)) < 1.0e-10_wp
    end function is_power_of_ten
    
    function format_power_of_ten(value) result(formatted)
        real(wp), intent(in) :: value
        character(len=20) :: formatted
        integer :: exponent
        exponent = nint(log10(abs(value)))
        if (value < 0.0_wp) then
            write(formatted, '(A, I0)') '-10^', exponent
        else
            write(formatted, '(A, I0)') '10^', exponent
        end if
    end function format_power_of_ten
    

end module fortplot_axes