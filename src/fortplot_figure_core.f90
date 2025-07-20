module fortplot_figure_core
    !! Core figure management module (refactored for SOLID principles)
    !! 
    !! This module provides the main user interface for creating scientific plots
    !! with support for line plots, contour plots, and mixed plotting across
    !! PNG, PDF, and ASCII backends. Uses deferred rendering for efficiency.
    !! 
    !! Refactored to follow Single Responsibility Principle by delegating
    !! specialized tasks to focused modules.
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_context
    use fortplot_scales
    use fortplot_utils
    use fortplot_axes
    use fortplot_colormap
    use fortplot_pcolormesh
    use fortplot_format_parser, only: parse_format_string, contains_format_chars
    use fortplot_legend
    use fortplot_png, only: png_context, draw_axes_and_labels
    use fortplot_raster, only: draw_rotated_ylabel_raster
    use fortplot_pdf, only: pdf_context, draw_pdf_axes_and_labels
    use fortplot_ascii, only: ascii_context
    implicit none

    private
    public :: figure_t, plot_data_t
    public :: PLOT_TYPE_LINE, PLOT_TYPE_CONTOUR, PLOT_TYPE_PCOLORMESH, PLOT_TYPE_ERRORBAR

    integer, parameter :: PLOT_TYPE_LINE = 1
    integer, parameter :: PLOT_TYPE_CONTOUR = 2
    integer, parameter :: PLOT_TYPE_PCOLORMESH = 3
    integer, parameter :: PLOT_TYPE_ERRORBAR = 4

    type :: plot_data_t
        !! Data container for individual plots
        !! Separated from figure to follow Single Responsibility Principle
        integer :: plot_type = PLOT_TYPE_LINE
        ! Line plot data
        real(wp), allocatable :: x(:), y(:)
        ! Contour plot data
        real(wp), allocatable :: x_grid(:), y_grid(:), z_grid(:,:)
        real(wp), allocatable :: contour_levels(:)
        ! Color contour properties
        logical :: use_color_levels = .false.
        character(len=20) :: colormap = 'crest'
        logical :: show_colorbar = .true.
        ! Pcolormesh data
        type(pcolormesh_t) :: pcolormesh_data
        ! Error bar data
        real(wp), allocatable :: xerr(:), yerr(:)
        real(wp), allocatable :: xerr_lower(:), xerr_upper(:)
        real(wp), allocatable :: yerr_lower(:), yerr_upper(:)
        real(wp) :: capsize = 5.0_wp
        real(wp) :: elinewidth = 1.0_wp
        logical :: has_xerr = .false., has_yerr = .false.
        logical :: asymmetric_xerr = .false., asymmetric_yerr = .false.
        ! Common properties
        real(wp), dimension(3) :: color
        character(len=:), allocatable :: label
        character(len=:), allocatable :: linestyle
        character(len=:), allocatable :: marker
    end type plot_data_t

    type :: figure_t
        !! Main figure class - coordinates plotting operations
        !! Follows Open/Closed Principle by using composition over inheritance
        class(plot_context), allocatable :: backend
        integer :: plot_count = 0
        logical :: rendered = .false.
        
        ! Figure dimensions
        integer :: width = 640
        integer :: height = 480

        ! Plot area settings
        real(wp) :: margin_left = 0.15_wp
        real(wp) :: margin_right = 0.05_wp
        real(wp) :: margin_bottom = 0.15_wp
        real(wp) :: margin_top = 0.05_wp
        
        ! Scale settings
        character(len=10) :: xscale = 'linear'
        character(len=10) :: yscale = 'linear'
        real(wp) :: symlog_threshold = 1.0_wp
        
        ! Axis limits - separate original and transformed ranges
        real(wp) :: x_min, x_max, y_min, y_max  ! Original data ranges for tick generation
        real(wp) :: x_min_transformed, x_max_transformed, y_min_transformed, y_max_transformed  ! Transformed for rendering
        logical :: xlim_set = .false., ylim_set = .false.
        
        ! Figure and axis labels
        character(len=:), allocatable :: title
        character(len=:), allocatable :: xlabel
        character(len=:), allocatable :: ylabel

        ! Color palette: seaborn colorblind palette
        real(wp), dimension(3,6) :: colors = reshape([ &
            0.0_wp,   0.447_wp, 0.698_wp,  & ! #0072B2 (blue)
            0.0_wp,   0.619_wp, 0.451_wp,  & ! #009E73 (green)
            0.835_wp, 0.369_wp, 0.0_wp,    & ! #D55E00 (orange)
            0.8_wp,   0.475_wp, 0.655_wp,  & ! #CC79A7 (purple)
            0.941_wp, 0.894_wp, 0.259_wp,  & ! #F0E442 (yellow)
            0.337_wp, 0.702_wp, 0.914_wp], & ! #56B4E9 (cyan)
            [3,6])

        ! Store all plot data for deferred rendering
        type(plot_data_t), allocatable :: plots(:)
        
        ! Legend support following SOLID principles
        type(legend_t) :: legend_data
        logical :: show_legend = .false.
        integer :: max_plots = 500
        
        ! Line drawing properties
        real(wp) :: current_line_width = 1.0_wp
        
        ! Streamline data (temporary placeholder)
        type(plot_data_t), allocatable :: streamlines(:)
        logical :: has_error = .false.

    contains
        procedure :: initialize
        procedure :: add_plot
        procedure :: add_contour
        procedure :: add_contour_filled
        procedure :: add_pcolormesh
        procedure :: streamplot
        procedure :: savefig
        procedure :: set_xlabel
        procedure :: set_ylabel
        procedure :: set_title
        procedure :: set_xscale
        procedure :: set_yscale
        procedure :: set_xlim
        procedure :: set_ylim
        procedure :: set_line_width
        procedure :: errorbar
        procedure :: set_ydata
        procedure :: legend => figure_legend
        procedure :: show
        procedure :: clear_streamlines
        final :: destroy
    end type figure_t

contains

    subroutine initialize(self, width, height, backend)
        !! Initialize figure with specified dimensions and optional backend
        class(figure_t), intent(inout) :: self
        integer, intent(in), optional :: width, height
        character(len=*), intent(in), optional :: backend
        
        if (present(width)) self%width = width
        if (present(height)) self%height = height
        
        if (.not. allocated(self%plots)) then
            allocate(self%plots(self%max_plots))
        end if
        self%plot_count = 0
        self%rendered = .false.
        
        ! Initialize legend following SOLID principles  
        self%show_legend = .false.
        
        ! Initialize backend if specified
        if (present(backend)) then
            call initialize_backend(self%backend, backend, self%width, self%height)
        end if
    end subroutine initialize

    subroutine add_plot(self, x, y, label, linestyle, color)
        !! Add line plot data to figure with matplotlib/pyplot-fortran format string support
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x(:), y(:)
        character(len=*), intent(in), optional :: label, linestyle
        real(wp), intent(in), optional :: color(3)
        
        character(len=20) :: parsed_marker, parsed_linestyle
        
        if (self%plot_count >= self%max_plots) then
            write(*, '(A)') 'Warning: Maximum number of plots reached'
            return
        end if
        
        self%plot_count = self%plot_count + 1
        
        if (present(linestyle) .and. contains_format_chars(linestyle)) then
            ! Parse format string and use those values
            call parse_format_string(linestyle, parsed_marker, parsed_linestyle)
            call add_line_plot_data(self, x, y, label, parsed_linestyle, color, parsed_marker)
        else
            ! Use traditional linestyle with no marker
            call add_line_plot_data(self, x, y, label, linestyle, color, '')
        end if
        call update_data_ranges(self)
    end subroutine add_plot

    subroutine add_contour(self, x_grid, y_grid, z_grid, levels, label)
        !! Add contour plot data to figure
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x_grid(:), y_grid(:), z_grid(:,:)
        real(wp), intent(in), optional :: levels(:)
        character(len=*), intent(in), optional :: label
        
        if (self%plot_count >= self%max_plots) then
            write(*, '(A)') 'Warning: Maximum number of plots reached'
            return
        end if
        
        self%plot_count = self%plot_count + 1
        
        call add_contour_plot_data(self, x_grid, y_grid, z_grid, levels, label)
        call update_data_ranges(self)
    end subroutine add_contour

    subroutine add_contour_filled(self, x_grid, y_grid, z_grid, levels, colormap, show_colorbar, label)
        !! Add filled contour plot with color levels
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x_grid(:), y_grid(:), z_grid(:,:)
        real(wp), intent(in), optional :: levels(:)
        character(len=*), intent(in), optional :: colormap, label
        logical, intent(in), optional :: show_colorbar
        
        if (self%plot_count >= self%max_plots) then
            write(*, '(A)') 'Warning: Maximum number of plots reached'
            return
        end if
        
        self%plot_count = self%plot_count + 1
        
        call add_colored_contour_plot_data(self, x_grid, y_grid, z_grid, levels, colormap, show_colorbar, label)
        call update_data_ranges(self)
    end subroutine add_contour_filled

    subroutine add_pcolormesh(self, x, y, c, colormap, vmin, vmax, edgecolors, linewidths)
        !! Add pcolormesh plot to figure with matplotlib-compatible interface
        !!
        !! Arguments:
        !!   x, y: Coordinate arrays (1D for regular grid)
        !!   c: Color data array (2D)
        !!   colormap: Optional colormap name
        !!   vmin, vmax: Optional color scale limits
        !!   edgecolors: Optional edge color specification
        !!   linewidths: Optional edge line width
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x(:), y(:), c(:,:)
        character(len=*), intent(in), optional :: colormap
        real(wp), intent(in), optional :: vmin, vmax
        character(len=*), intent(in), optional :: edgecolors
        real(wp), intent(in), optional :: linewidths
        
        call add_pcolormesh_plot_data(self, x, y, c, colormap, vmin, vmax, edgecolors, linewidths)
        call update_data_ranges_pcolormesh(self)
    end subroutine add_pcolormesh

    subroutine streamplot(self, x, y, u, v, density, color, linewidth, rtol, atol, max_time)
        !! Add streamline plot to figure using matplotlib-compatible algorithm
        use fortplot_streamplot_matplotlib
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x(:), y(:), u(:,:), v(:,:)
        real(wp), intent(in), optional :: density
        real(wp), intent(in), optional :: color(3)
        real(wp), intent(in), optional :: linewidth
        real(wp), intent(in), optional :: rtol        !! Relative tolerance for DOPRI5
        real(wp), intent(in), optional :: atol        !! Absolute tolerance for DOPRI5
        real(wp), intent(in), optional :: max_time    !! Maximum integration time
        
        real(wp) :: plot_density
        real, allocatable :: trajectories(:,:,:)
        integer :: n_trajectories
        integer, allocatable :: trajectory_lengths(:)
        
        if (size(u,1) /= size(x) .or. size(u,2) /= size(y)) then
            self%has_error = .true.
            return
        end if
        
        if (size(v,1) /= size(x) .or. size(v,2) /= size(y)) then
            self%has_error = .true.
            return
        end if
        
        plot_density = 1.0_wp
        if (present(density)) plot_density = density
        
        ! Update data ranges
        if (.not. self%xlim_set) then
            self%x_min = minval(x)
            self%x_max = maxval(x)
        end if
        if (.not. self%ylim_set) then
            self%y_min = minval(y)
            self%y_max = maxval(y)
        end if
        
        ! Use matplotlib-compatible streamplot implementation
        call streamplot_matplotlib(x, y, u, v, plot_density, trajectories, n_trajectories, trajectory_lengths)
        
        
        ! Add trajectories to figure
        call add_trajectories_to_figure(self, trajectories, n_trajectories, trajectory_lengths, color, x, y)
        
    contains
        
        subroutine add_trajectories_to_figure(fig, trajectories, n_trajectories, lengths, trajectory_color, x_grid, y_grid)
            !! Add streamline trajectories to figure as regular plots
            class(figure_t), intent(inout) :: fig
            real, intent(in) :: trajectories(:,:,:)
            integer, intent(in) :: n_trajectories
            integer, intent(in) :: lengths(:)
            real(wp), intent(in), optional :: trajectory_color(3)
            real(wp), intent(in) :: x_grid(:), y_grid(:)
            
            integer :: i, j, n_points
            real(wp), allocatable :: traj_x(:), traj_y(:)
            real(wp) :: line_color(3)
            
            ! Set default color (blue)
            line_color = [0.0_wp, 0.447_wp, 0.698_wp]
            if (present(trajectory_color)) line_color = trajectory_color
            
            do i = 1, n_trajectories
                n_points = lengths(i)
                
                if (n_points > 1) then
                    allocate(traj_x(n_points), traj_y(n_points))
                    
                    ! Convert from grid coordinates to data coordinates
                    ! trajectories are in grid coordinates (0 to nx-1, 0 to ny-1)
                    ! need to convert to data coordinates like matplotlib does
                    do j = 1, n_points
                        ! Convert grid coords to data coords: grid2data transformation
                        traj_x(j) = real(trajectories(i, j, 1), wp) * (x_grid(size(x_grid)) - x_grid(1)) / &
                                   real(size(x_grid) - 1, wp) + x_grid(1)
                        traj_y(j) = real(trajectories(i, j, 2), wp) * (y_grid(size(y_grid)) - y_grid(1)) / &
                                   real(size(y_grid) - 1, wp) + y_grid(1)
                    end do
                    
                    ! Add as regular plot
                    call fig%add_plot(traj_x, traj_y, color=line_color, linestyle='-')
                    
                    deallocate(traj_x, traj_y)
                end if
            end do
        end subroutine add_trajectories_to_figure
        
    end subroutine streamplot

    subroutine savefig(self, filename, blocking)
        !! Save figure to file with backend auto-detection
        !! 
        !! Arguments:
        !!   filename: Output filename (extension determines format)
        !!   blocking: Optional - if true, wait for user input after save (default: false)
        class(figure_t), intent(inout) :: self
        character(len=*), intent(in) :: filename
        logical, intent(in), optional :: blocking
        character(len=20) :: backend_type
        logical :: do_block
        
        ! Default to non-blocking
        do_block = .false.
        if (present(blocking)) do_block = blocking
        
        backend_type = get_backend_from_filename(filename)
        
        ! Always reinitialize backend for correct format
        if (allocated(self%backend)) deallocate(self%backend)
        call initialize_backend(self%backend, backend_type, self%width, self%height)
        
        ! Reset rendered flag to force re-rendering for new backend
        self%rendered = .false.
        call render_figure(self)
        call self%backend%save(filename)
        
        write(*, '(A, A, A)') 'Saved figure: ', trim(filename)
        
        ! If blocking requested, wait for user input
        if (do_block) then
            print *, "Press Enter to continue..."
            read(*,*)
        end if
    end subroutine savefig

    subroutine show(self, blocking)
        !! Display figure in ASCII terminal
        !! 
        !! Arguments:
        !!   blocking: Optional - if true, wait for user input after display (default: false)
        class(figure_t), intent(inout) :: self
        logical, intent(in), optional :: blocking
        logical :: do_block
        
        ! Default to non-blocking
        do_block = .false.
        if (present(blocking)) do_block = blocking
        
        ! Always reinitialize backend for ASCII output
        if (allocated(self%backend)) deallocate(self%backend)
        call initialize_backend(self%backend, 'ascii', 80, 24)
        
        ! Reset rendered flag to force re-rendering for new backend
        self%rendered = .false.
        call render_figure(self)
        call self%backend%save("terminal")
        
        ! If blocking requested, wait for user input
        if (do_block) then
            print *, "Press Enter to continue..."
            read(*,*)
        end if
    end subroutine show

    ! Label setters (following Interface Segregation Principle)
    
    subroutine set_xlabel(self, label)
        class(figure_t), intent(inout) :: self
        character(len=*), intent(in) :: label
        self%xlabel = label
    end subroutine set_xlabel

    subroutine set_ylabel(self, label)
        class(figure_t), intent(inout) :: self
        character(len=*), intent(in) :: label
        self%ylabel = label
    end subroutine set_ylabel

    subroutine set_title(self, title)
        class(figure_t), intent(inout) :: self
        character(len=*), intent(in) :: title
        self%title = title
    end subroutine set_title

    subroutine set_xscale(self, scale, threshold)
        class(figure_t), intent(inout) :: self
        character(len=*), intent(in) :: scale
        real(wp), intent(in), optional :: threshold
        
        self%xscale = scale
        if (present(threshold)) self%symlog_threshold = threshold
    end subroutine set_xscale

    subroutine set_yscale(self, scale, threshold)
        class(figure_t), intent(inout) :: self
        character(len=*), intent(in) :: scale
        real(wp), intent(in), optional :: threshold
        
        self%yscale = scale
        if (present(threshold)) self%symlog_threshold = threshold
    end subroutine set_yscale

    subroutine set_xlim(self, x_min, x_max)
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x_min, x_max
        
        self%x_min = x_min
        self%x_max = x_max
        self%xlim_set = .true.
    end subroutine set_xlim

    subroutine set_ylim(self, y_min, y_max)
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: y_min, y_max
        
        self%y_min = y_min
        self%y_max = y_max
        self%ylim_set = .true.
    end subroutine set_ylim

    subroutine set_line_width(self, width)
        !! Set line width for subsequent plot operations
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: width
        
        self%current_line_width = width
    end subroutine set_line_width

    subroutine errorbar(self, x, y, xerr, yerr, xerr_lower, xerr_upper, &
                       yerr_lower, yerr_upper, capsize, elinewidth, &
                       label, linestyle, marker, color)
        !! Add error bar plot to figure
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x(:), y(:)
        real(wp), intent(in), optional :: xerr(:), yerr(:)
        real(wp), intent(in), optional :: xerr_lower(:), xerr_upper(:)
        real(wp), intent(in), optional :: yerr_lower(:), yerr_upper(:)
        real(wp), intent(in), optional :: capsize, elinewidth
        character(len=*), intent(in), optional :: label, linestyle, marker
        real(wp), intent(in), optional :: color(3)
        
        type(plot_data_t) :: plot_data
        integer :: n_points
        
        n_points = size(x)
        
        ! Validate input sizes
        if (size(y) /= n_points) then
            write(*,*) 'Error: x and y arrays must have the same size'
            return
        end if
        
        ! Initialize plot data
        plot_data%plot_type = PLOT_TYPE_ERRORBAR
        allocate(plot_data%x(n_points), plot_data%y(n_points))
        plot_data%x = x
        plot_data%y = y
        
        ! Handle symmetric error bars
        if (present(xerr)) then
            if (size(xerr) /= n_points) then
                write(*,*) 'Error: xerr array size must match x and y'
                return
            end if
            allocate(plot_data%xerr(n_points))
            plot_data%xerr = xerr
            plot_data%has_xerr = .true.
        end if
        
        if (present(yerr)) then
            if (size(yerr) /= n_points) then
                write(*,*) 'Error: yerr array size must match x and y'
                return
            end if
            allocate(plot_data%yerr(n_points))
            plot_data%yerr = yerr
            plot_data%has_yerr = .true.
        end if
        
        ! Handle asymmetric error bars
        if (present(xerr_lower) .and. present(xerr_upper)) then
            if (present(xerr)) then
                write(*,*) 'Warning: Both symmetric xerr and asymmetric xerr_lower/xerr_upper provided. Using asymmetric values.'
            end if
            if (size(xerr_lower) /= n_points .or. size(xerr_upper) /= n_points) then
                write(*,*) 'Error: xerr_lower and xerr_upper array sizes must match x and y'
                return
            end if
            allocate(plot_data%xerr_lower(n_points), plot_data%xerr_upper(n_points))
            plot_data%xerr_lower = xerr_lower
            plot_data%xerr_upper = xerr_upper
            plot_data%has_xerr = .true.
            plot_data%asymmetric_xerr = .true.
        end if
        
        if (present(yerr_lower) .and. present(yerr_upper)) then
            if (present(yerr)) then
                write(*,*) 'Warning: Both symmetric yerr and asymmetric yerr_lower/yerr_upper provided. Using asymmetric values.'
            end if
            if (size(yerr_lower) /= n_points .or. size(yerr_upper) /= n_points) then
                write(*,*) 'Error: yerr_lower and yerr_upper array sizes must match x and y'
                return
            end if
            allocate(plot_data%yerr_lower(n_points), plot_data%yerr_upper(n_points))
            plot_data%yerr_lower = yerr_lower
            plot_data%yerr_upper = yerr_upper
            plot_data%has_yerr = .true.
            plot_data%asymmetric_yerr = .true.
        end if
        
        ! Set customization options
        if (present(capsize)) plot_data%capsize = capsize
        if (present(elinewidth)) plot_data%elinewidth = elinewidth
        if (present(label)) plot_data%label = label
        if (present(linestyle)) plot_data%linestyle = linestyle
        if (present(marker)) plot_data%marker = marker
        
        ! Set color (use next color in palette if not specified)
        if (present(color)) then
            plot_data%color = color
        else
            plot_data%color = self%colors(:, mod(self%plot_count, size(self%colors, 2)) + 1)
        end if
        
        ! Check plot count limit
        if (self%plot_count >= self%max_plots) then
            write(*, '(A)') 'Warning: Maximum number of plots reached'
            return
        end if
        
        self%plot_count = self%plot_count + 1
        
        ! Add to plot list
        call add_errorbar_plot_data(self, plot_data)
        call update_data_ranges(self)
    end subroutine errorbar

    subroutine destroy(self)
        !! Clean up figure resources
        type(figure_t), intent(inout) :: self
        
        if (allocated(self%plots)) deallocate(self%plots)
        if (allocated(self%backend)) deallocate(self%backend)
    end subroutine destroy

    ! Private helper routines (implementation details)
    
    subroutine add_line_plot_data(self, x, y, label, linestyle, color, marker)
        !! Add line plot data to internal storage
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x(:), y(:)
        character(len=*), intent(in), optional :: label, linestyle, marker
        real(wp), intent(in), optional :: color(3)
        
        integer :: plot_idx, color_idx
        
        plot_idx = self%plot_count
        self%plots(plot_idx)%plot_type = PLOT_TYPE_LINE
        
        ! Store data
        if (allocated(self%plots(plot_idx)%x)) deallocate(self%plots(plot_idx)%x)
        if (allocated(self%plots(plot_idx)%y)) deallocate(self%plots(plot_idx)%y)
        allocate(self%plots(plot_idx)%x(size(x)))
        allocate(self%plots(plot_idx)%y(size(y)))
        self%plots(plot_idx)%x = x
        self%plots(plot_idx)%y = y
        
        ! Set properties
        if (present(label)) then
            self%plots(plot_idx)%label = label
        else
            self%plots(plot_idx)%label = ''
        end if
        
        if (present(linestyle)) then
            self%plots(plot_idx)%linestyle = linestyle
        else
            self%plots(plot_idx)%linestyle = 'solid'
        end if

        if (present(marker)) then
            self%plots(plot_idx)%marker = marker
        else
            self%plots(plot_idx)%marker = 'None'
        end if
        
        if (present(color)) then
            self%plots(plot_idx)%color = color
        else
            color_idx = mod(plot_idx - 1, 6) + 1
            self%plots(plot_idx)%color = self%colors(:, color_idx)
        end if
    end subroutine add_line_plot_data

    subroutine add_errorbar_plot_data(self, plot_data)
        !! Add error bar plot data to internal storage
        class(figure_t), intent(inout) :: self
        type(plot_data_t), intent(in) :: plot_data
        
        integer :: plot_idx
        
        plot_idx = self%plot_count
        
        ! Ensure plots array is allocated
        if (.not. allocated(self%plots)) then
            allocate(self%plots(self%max_plots))
        end if
        
        ! Copy the complete plot_data structure
        self%plots(plot_idx) = plot_data
    end subroutine add_errorbar_plot_data

    subroutine add_contour_plot_data(self, x_grid, y_grid, z_grid, levels, label)
        !! Add contour plot data to internal storage
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x_grid(:), y_grid(:), z_grid(:,:)
        real(wp), intent(in), optional :: levels(:)
        character(len=*), intent(in), optional :: label
        
        integer :: plot_idx
        
        plot_idx = self%plot_count
        self%plots(plot_idx)%plot_type = PLOT_TYPE_CONTOUR
        
        ! Store grid data
        if (allocated(self%plots(plot_idx)%x_grid)) deallocate(self%plots(plot_idx)%x_grid)
        if (allocated(self%plots(plot_idx)%y_grid)) deallocate(self%plots(plot_idx)%y_grid)
        if (allocated(self%plots(plot_idx)%z_grid)) deallocate(self%plots(plot_idx)%z_grid)
        allocate(self%plots(plot_idx)%x_grid(size(x_grid)))
        allocate(self%plots(plot_idx)%y_grid(size(y_grid)))
        allocate(self%plots(plot_idx)%z_grid(size(z_grid,1), size(z_grid,2)))
        
        self%plots(plot_idx)%x_grid = x_grid
        self%plots(plot_idx)%y_grid = y_grid
        self%plots(plot_idx)%z_grid = z_grid
        
        ! Set default contour properties
        self%plots(plot_idx)%use_color_levels = .false.
        
        ! Handle label
        if (present(label)) then
            self%plots(plot_idx)%label = label
        else
            self%plots(plot_idx)%label = ''
        end if
        
        ! Handle contour levels
        if (present(levels)) then
            if (allocated(self%plots(plot_idx)%contour_levels)) deallocate(self%plots(plot_idx)%contour_levels)
            allocate(self%plots(plot_idx)%contour_levels(size(levels)))
            self%plots(plot_idx)%contour_levels = levels
        else
            call generate_default_contour_levels(self%plots(plot_idx))
        end if
    end subroutine add_contour_plot_data

    subroutine add_colored_contour_plot_data(self, x_grid, y_grid, z_grid, levels, colormap, show_colorbar, label)
        !! Add colored contour plot data to internal storage
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x_grid(:), y_grid(:), z_grid(:,:)
        real(wp), intent(in), optional :: levels(:)
        character(len=*), intent(in), optional :: colormap, label
        logical, intent(in), optional :: show_colorbar
        
        integer :: plot_idx
        
        plot_idx = self%plot_count
        self%plots(plot_idx)%plot_type = PLOT_TYPE_CONTOUR
        
        ! Store grid data
        if (allocated(self%plots(plot_idx)%x_grid)) deallocate(self%plots(plot_idx)%x_grid)
        if (allocated(self%plots(plot_idx)%y_grid)) deallocate(self%plots(plot_idx)%y_grid)
        if (allocated(self%plots(plot_idx)%z_grid)) deallocate(self%plots(plot_idx)%z_grid)
        allocate(self%plots(plot_idx)%x_grid(size(x_grid)))
        allocate(self%plots(plot_idx)%y_grid(size(y_grid)))
        allocate(self%plots(plot_idx)%z_grid(size(z_grid,1), size(z_grid,2)))
        
        self%plots(plot_idx)%x_grid = x_grid
        self%plots(plot_idx)%y_grid = y_grid
        self%plots(plot_idx)%z_grid = z_grid
        
        ! Set color contour properties
        self%plots(plot_idx)%use_color_levels = .true.
        
        if (present(colormap)) then
            self%plots(plot_idx)%colormap = colormap
        else
            self%plots(plot_idx)%colormap = 'crest'
        end if
        
        if (present(show_colorbar)) then
            self%plots(plot_idx)%show_colorbar = show_colorbar
        else
            self%plots(plot_idx)%show_colorbar = .true.
        end if
        
        ! Handle label
        if (present(label)) then
            self%plots(plot_idx)%label = label
        else
            self%plots(plot_idx)%label = ''
        end if
        
        ! Handle contour levels
        if (present(levels)) then
            if (allocated(self%plots(plot_idx)%contour_levels)) deallocate(self%plots(plot_idx)%contour_levels)
            allocate(self%plots(plot_idx)%contour_levels(size(levels)))
            self%plots(plot_idx)%contour_levels = levels
        else
            call generate_default_contour_levels(self%plots(plot_idx))
        end if
    end subroutine add_colored_contour_plot_data

    subroutine add_pcolormesh_plot_data(self, x, y, c, colormap, vmin, vmax, edgecolors, linewidths)
        !! Add pcolormesh data to plot array
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x(:), y(:), c(:,:)
        character(len=*), intent(in), optional :: colormap
        real(wp), intent(in), optional :: vmin, vmax
        character(len=*), intent(in), optional :: edgecolors
        real(wp), intent(in), optional :: linewidths
        
        integer :: plot_idx
        
        if (self%plot_count >= self%max_plots) then
            error stop "Maximum number of plots exceeded"
        end if
        
        plot_idx = self%plot_count + 1
        self%plots(plot_idx)%plot_type = PLOT_TYPE_PCOLORMESH
        
        ! Initialize pcolormesh with regular grid
        call self%plots(plot_idx)%pcolormesh_data%initialize_regular_grid(x, y, c, colormap)
        
        ! Set vmin/vmax if provided
        if (present(vmin)) then
            self%plots(plot_idx)%pcolormesh_data%vmin = vmin
            self%plots(plot_idx)%pcolormesh_data%vmin_set = .true.
        end if
        if (present(vmax)) then
            self%plots(plot_idx)%pcolormesh_data%vmax = vmax
            self%plots(plot_idx)%pcolormesh_data%vmax_set = .true.
        end if
        
        ! Set edge properties
        if (present(edgecolors)) then
            if (trim(edgecolors) /= 'none' .and. trim(edgecolors) /= '') then
                self%plots(plot_idx)%pcolormesh_data%show_edges = .true.
                ! TODO: Parse color string
            end if
        end if
        if (present(linewidths)) then
            self%plots(plot_idx)%pcolormesh_data%edge_width = linewidths
        end if
        
        ! Update data range if needed
        call self%plots(plot_idx)%pcolormesh_data%get_data_range()
    end subroutine add_pcolormesh_plot_data

    subroutine update_data_ranges_pcolormesh(self)
        !! Update figure data ranges after adding pcolormesh plot
        class(figure_t), intent(inout) :: self
        
        integer :: plot_idx
        real(wp) :: x_min_plot, x_max_plot, y_min_plot, y_max_plot
        
        plot_idx = self%plot_count + 1
        
        ! Get data ranges from pcolormesh vertices
        x_min_plot = minval(self%plots(plot_idx)%pcolormesh_data%x_vertices)
        x_max_plot = maxval(self%plots(plot_idx)%pcolormesh_data%x_vertices)
        y_min_plot = minval(self%plots(plot_idx)%pcolormesh_data%y_vertices)
        y_max_plot = maxval(self%plots(plot_idx)%pcolormesh_data%y_vertices)
        
        ! Update figure ranges
        if (self%plot_count == 0) then
            self%x_min = x_min_plot
            self%x_max = x_max_plot
            self%y_min = y_min_plot
            self%y_max = y_max_plot
        else
            self%x_min = min(self%x_min, x_min_plot)
            self%x_max = max(self%x_max, x_max_plot)
            self%y_min = min(self%y_min, y_min_plot)
            self%y_max = max(self%y_max, y_max_plot)
        end if
        
        self%plot_count = plot_idx
    end subroutine update_data_ranges_pcolormesh

    subroutine update_data_ranges(self)
        !! Update figure data ranges after adding plots
        class(figure_t), intent(inout) :: self
        
        ! Implementation delegates to range calculation utilities
        ! This follows Dependency Inversion Principle
        call calculate_figure_data_ranges(self)
    end subroutine update_data_ranges

    subroutine render_figure(self)
        !! Render all plots to the backend
        class(figure_t), intent(inout) :: self
        
        if (self%rendered) return
        
        ! Setup coordinate system using scales module
        call setup_coordinate_system(self)
        
        ! Render background and axes
        call render_figure_background(self)
        call render_figure_axes(self)
        
        ! Render individual plots
        call render_all_plots(self)
        
        ! Render Y-axis label ABSOLUTELY LAST (after everything else)
        select type (backend => self%backend)
        type is (png_context)
            if (allocated(self%ylabel)) then
                call draw_rotated_ylabel_raster(backend, self%ylabel)
            end if
        type is (pdf_context)
            ! PDF handles this differently - already done in draw_pdf_axes_and_labels
        end select
        
        ! Render legend if requested (following SOLID principles)
        if (self%show_legend) then
            call legend_render(self%legend_data, self%backend)
        end if
        
        self%rendered = .true.
    end subroutine render_figure

    ! Placeholder implementations for helper routines
    ! These will delegate to specialized modules
    
    subroutine generate_default_contour_levels(plot_data)
        !! Generate default contour levels for a plot
        type(plot_data_t), intent(inout) :: plot_data
        real(wp) :: z_min, z_max, dz
        integer :: i, n_levels
        
        if (.not. allocated(plot_data%z_grid)) return
        
        z_min = minval(plot_data%z_grid)
        z_max = maxval(plot_data%z_grid)
        
        ! Generate 10 evenly spaced levels by default
        n_levels = 10
        if (allocated(plot_data%contour_levels)) deallocate(plot_data%contour_levels)
        allocate(plot_data%contour_levels(n_levels))
        
        dz = (z_max - z_min) / real(n_levels + 1, wp)
        
        do i = 1, n_levels
            plot_data%contour_levels(i) = z_min + real(i, wp) * dz
        end do
    end subroutine generate_default_contour_levels
    
    subroutine calculate_figure_data_ranges(self)
        class(figure_t), intent(inout) :: self
        integer :: i
        real(wp) :: x_min_orig, x_max_orig, y_min_orig, y_max_orig
        real(wp) :: x_min_trans, x_max_trans, y_min_trans, y_max_trans
        logical :: first_plot
        
        if (self%plot_count == 0) return
        
        first_plot = .true.
        
        do i = 1, self%plot_count
            if (self%plots(i)%plot_type == PLOT_TYPE_LINE .or. self%plots(i)%plot_type == PLOT_TYPE_ERRORBAR) then
                if (first_plot) then
                    ! Store ORIGINAL data ranges for tick generation
                    x_min_orig = minval(self%plots(i)%x)
                    x_max_orig = maxval(self%plots(i)%x)
                    y_min_orig = minval(self%plots(i)%y)
                    y_max_orig = maxval(self%plots(i)%y)
                    
                    ! Calculate transformed ranges for rendering
                    x_min_trans = apply_scale_transform(x_min_orig, self%xscale, self%symlog_threshold)
                    x_max_trans = apply_scale_transform(x_max_orig, self%xscale, self%symlog_threshold)
                    y_min_trans = apply_scale_transform(y_min_orig, self%yscale, self%symlog_threshold)
                    y_max_trans = apply_scale_transform(y_max_orig, self%yscale, self%symlog_threshold)
                    first_plot = .false.
                else
                    ! Update original ranges
                    x_min_orig = min(x_min_orig, minval(self%plots(i)%x))
                    x_max_orig = max(x_max_orig, maxval(self%plots(i)%x))
                    y_min_orig = min(y_min_orig, minval(self%plots(i)%y))
                    y_max_orig = max(y_max_orig, maxval(self%plots(i)%y))
                    
                    ! Update transformed ranges
                    x_min_trans = min(x_min_trans, apply_scale_transform(minval(self%plots(i)%x), &
                                                                         self%xscale, self%symlog_threshold))
                    x_max_trans = max(x_max_trans, apply_scale_transform(maxval(self%plots(i)%x), &
                                                                         self%xscale, self%symlog_threshold))
                    y_min_trans = min(y_min_trans, apply_scale_transform(minval(self%plots(i)%y), &
                                                                         self%yscale, self%symlog_threshold))
                    y_max_trans = max(y_max_trans, apply_scale_transform(maxval(self%plots(i)%y), &
                                                                         self%yscale, self%symlog_threshold))
                end if
            else if (self%plots(i)%plot_type == PLOT_TYPE_CONTOUR) then
                if (first_plot) then
                    ! Store ORIGINAL contour grid ranges
                    x_min_orig = minval(self%plots(i)%x_grid)
                    x_max_orig = maxval(self%plots(i)%x_grid)
                    y_min_orig = minval(self%plots(i)%y_grid)
                    y_max_orig = maxval(self%plots(i)%y_grid)
                    
                    ! Calculate transformed ranges for rendering
                    x_min_trans = apply_scale_transform(x_min_orig, self%xscale, self%symlog_threshold)
                    x_max_trans = apply_scale_transform(x_max_orig, self%xscale, self%symlog_threshold)
                    y_min_trans = apply_scale_transform(y_min_orig, self%yscale, self%symlog_threshold)
                    y_max_trans = apply_scale_transform(y_max_orig, self%yscale, self%symlog_threshold)
                    first_plot = .false.
                else
                    ! Update original ranges
                    x_min_orig = min(x_min_orig, minval(self%plots(i)%x_grid))
                    x_max_orig = max(x_max_orig, maxval(self%plots(i)%x_grid))
                    y_min_orig = min(y_min_orig, minval(self%plots(i)%y_grid))
                    y_max_orig = max(y_max_orig, maxval(self%plots(i)%y_grid))
                    
                    ! Update transformed ranges
                    x_min_trans = min(x_min_trans, apply_scale_transform(minval(self%plots(i)%x_grid), &
                                                                         self%xscale, self%symlog_threshold))
                    x_max_trans = max(x_max_trans, apply_scale_transform(maxval(self%plots(i)%x_grid), &
                                                                         self%xscale, self%symlog_threshold))
                    y_min_trans = min(y_min_trans, apply_scale_transform(minval(self%plots(i)%y_grid), &
                                                                         self%yscale, self%symlog_threshold))
                    y_max_trans = max(y_max_trans, apply_scale_transform(maxval(self%plots(i)%y_grid), &
                                                                         self%yscale, self%symlog_threshold))
                end if
            else if (self%plots(i)%plot_type == PLOT_TYPE_PCOLORMESH) then
                if (first_plot) then
                    ! Store ORIGINAL pcolormesh grid ranges  
                    x_min_orig = minval(self%plots(i)%pcolormesh_data%x_vertices)
                    x_max_orig = maxval(self%plots(i)%pcolormesh_data%x_vertices)
                    y_min_orig = minval(self%plots(i)%pcolormesh_data%y_vertices)
                    y_max_orig = maxval(self%plots(i)%pcolormesh_data%y_vertices)
                    
                    ! Calculate transformed ranges for rendering
                    x_min_trans = apply_scale_transform(x_min_orig, self%xscale, self%symlog_threshold)
                    x_max_trans = apply_scale_transform(x_max_orig, self%xscale, self%symlog_threshold)
                    y_min_trans = apply_scale_transform(y_min_orig, self%yscale, self%symlog_threshold)
                    y_max_trans = apply_scale_transform(y_max_orig, self%yscale, self%symlog_threshold)
                    first_plot = .false.
                else
                    ! Update original ranges
                    x_min_orig = min(x_min_orig, minval(self%plots(i)%pcolormesh_data%x_vertices))
                    x_max_orig = max(x_max_orig, maxval(self%plots(i)%pcolormesh_data%x_vertices))
                    y_min_orig = min(y_min_orig, minval(self%plots(i)%pcolormesh_data%y_vertices))
                    y_max_orig = max(y_max_orig, maxval(self%plots(i)%pcolormesh_data%y_vertices))
                    
                    ! Update transformed ranges for rendering
                    x_min_trans = min(x_min_trans, apply_scale_transform(minval(self%plots(i)%pcolormesh_data%x_vertices), &
                                                                         self%xscale, self%symlog_threshold))
                    x_max_trans = max(x_max_trans, apply_scale_transform(maxval(self%plots(i)%pcolormesh_data%x_vertices), &
                                                                         self%xscale, self%symlog_threshold))
                    y_min_trans = min(y_min_trans, apply_scale_transform(minval(self%plots(i)%pcolormesh_data%y_vertices), &
                                                                         self%yscale, self%symlog_threshold))
                    y_max_trans = max(y_max_trans, apply_scale_transform(maxval(self%plots(i)%pcolormesh_data%y_vertices), &
                                                                         self%yscale, self%symlog_threshold))
                end if
            end if
        end do
        
        if (.not. self%xlim_set) then
            self%x_min = x_min_orig  ! Backend gets ORIGINAL coordinates for tick generation
            self%x_max = x_max_orig
            self%x_min_transformed = x_min_trans  ! Store transformed for rendering
            self%x_max_transformed = x_max_trans
        end if
        
        if (.not. self%ylim_set) then
            self%y_min = y_min_orig  ! Backend gets ORIGINAL coordinates for tick generation  
            self%y_max = y_max_orig
            self%y_min_transformed = y_min_trans  ! Store transformed for rendering
            self%y_max_transformed = y_max_trans
        end if
    end subroutine calculate_figure_data_ranges
    
    subroutine setup_coordinate_system(self)
        class(figure_t), intent(inout) :: self
        
        if (.not. self%xlim_set .or. .not. self%ylim_set) then
            call calculate_figure_data_ranges(self)
        end if
        
        ! Set backend data coordinate ranges to TRANSFORMED coordinates for data rendering
        self%backend%x_min = self%x_min_transformed
        self%backend%x_max = self%x_max_transformed
        self%backend%y_min = self%y_min_transformed
        self%backend%y_max = self%y_max_transformed
    end subroutine setup_coordinate_system
    
    subroutine render_figure_background(self)
        class(figure_t), intent(inout) :: self
        ! Clear the background - backend-specific implementation not needed
        ! Background is handled by backend initialization
    end subroutine render_figure_background
    
    subroutine render_figure_axes(self)
        class(figure_t), intent(inout) :: self
        
        ! print *, "DEBUG: Rendering axes with ranges X:", self%x_min, "to", self%x_max, "Y:", self%y_min, "to", self%y_max
        
        ! Set axis color to black
        call self%backend%color(0.0_wp, 0.0_wp, 0.0_wp)
        
        ! Use matplotlib-style axes with margins for backends that support it
        select type (backend => self%backend)
        type is (png_context)
            call draw_axes_and_labels(backend, self%xscale, self%yscale, self%symlog_threshold, &
                                    self%x_min, self%x_max, self%y_min, self%y_max, &
                                    self%title, self%xlabel, self%ylabel)
        type is (pdf_context)
            call draw_pdf_axes_and_labels(backend, self%xscale, self%yscale, self%symlog_threshold, &
                                        self%x_min, self%x_max, self%y_min, self%y_max, &
                                        self%title, self%xlabel, self%ylabel)
        type is (ascii_context)
            ! ASCII backend: explicitly set title and draw simple axes
            if (allocated(self%title)) then
                call backend%set_title(self%title)
            end if
            call self%backend%line(self%x_min, self%y_min, self%x_max, self%y_min)
            call self%backend%line(self%x_min, self%y_min, self%x_min, self%y_max)
        class default
            ! For other backends, use simple axes
            call self%backend%line(self%x_min, self%y_min, self%x_max, self%y_min)
            call self%backend%line(self%x_min, self%y_min, self%x_min, self%y_max)
        end select
    end subroutine render_figure_axes
    
    subroutine render_all_plots(self)
        class(figure_t), intent(inout) :: self
        integer :: i
        
        ! Render regular plots
        do i = 1, self%plot_count
            ! Set color for this plot
            call self%backend%color(self%plots(i)%color(1), self%plots(i)%color(2), self%plots(i)%color(3))
            
            if (self%plots(i)%plot_type == PLOT_TYPE_LINE) then
                call render_line_plot(self, i)
            else if (self%plots(i)%plot_type == PLOT_TYPE_CONTOUR) then
                call render_contour_plot(self, i)
            else if (self%plots(i)%plot_type == PLOT_TYPE_PCOLORMESH) then
                call render_pcolormesh_plot(self, i)
            else if (self%plots(i)%plot_type == PLOT_TYPE_ERRORBAR) then
                call render_errorbar_plot(self, i)
            end if
        end do
        
    end subroutine render_all_plots

    subroutine render_streamlines(self)
        !! Render all streamlines in the streamlines array
        class(figure_t), intent(inout) :: self
        integer :: i
        
        do i = 1, size(self%streamlines)
            ! Set color for this streamline
            call self%backend%color(self%streamlines(i)%color(1), self%streamlines(i)%color(2), self%streamlines(i)%color(3))
            
            ! Render as line plot
            call render_streamline(self, i)
        end do
    end subroutine render_streamlines

    subroutine render_streamline(self, streamline_idx)
        !! Render a single streamline
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: streamline_idx
        integer :: i
        real(wp) :: x1_screen, y1_screen, x2_screen, y2_screen
        
        
        do i = 1, size(self%streamlines(streamline_idx)%x) - 1
            ! Apply scale transformations
            x1_screen = apply_scale_transform(self%streamlines(streamline_idx)%x(i), self%xscale, self%symlog_threshold)
            y1_screen = apply_scale_transform(self%streamlines(streamline_idx)%y(i), self%yscale, self%symlog_threshold)
            x2_screen = apply_scale_transform(self%streamlines(streamline_idx)%x(i+1), self%xscale, self%symlog_threshold)
            y2_screen = apply_scale_transform(self%streamlines(streamline_idx)%y(i+1), self%yscale, self%symlog_threshold)
            
            ! Draw line segment
            call self%backend%line(x1_screen, y1_screen, x2_screen, y2_screen)
        end do
    end subroutine render_streamline

    subroutine render_line_plot(self, plot_idx)
        !! Render a single line plot with linestyle support
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        integer :: i
        real(wp) :: x1_screen, y1_screen, x2_screen, y2_screen
        character(len=:), allocatable :: linestyle
        
        if (plot_idx > self%plot_count) return
        if (.not. allocated(self%plots(plot_idx)%x)) return
        if (size(self%plots(plot_idx)%x) < 1) return
        
        ! Get linestyle for this plot
        linestyle = self%plots(plot_idx)%linestyle
        
        ! Draw lines only if linestyle is not 'None' and we have at least 2 points
        if (linestyle /= 'None' .and. size(self%plots(plot_idx)%x) >= 2) then
            ! Set line width for all backends (2.0 for plot data, 1.0 for axes)
            call self%backend%set_line_width(2.0_wp)
            
            ! Draw line segments using transformed coordinates with linestyle
            call draw_line_with_style(self, plot_idx, linestyle)
        end if

        ! Always render markers regardless of linestyle (matplotlib behavior)
        call render_markers(self, plot_idx)
    end subroutine render_line_plot

    subroutine render_errorbar_plot(self, plot_idx)
        !! Render error bars with caps
        use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        integer :: i
        real(wp) :: x_screen, y_screen, x1_screen, y1_screen, x2_screen, y2_screen
        real(wp) :: cap_half_size, x_err_lower, x_err_upper, y_err_lower, y_err_upper
        
        if (.not. allocated(self%plots(plot_idx)%x) .or. .not. allocated(self%plots(plot_idx)%y)) return
        
        cap_half_size = self%plots(plot_idx)%capsize * 0.5_wp
        
        do i = 1, size(self%plots(plot_idx)%x)
            ! Skip NaN values
            if (ieee_is_nan(self%plots(plot_idx)%x(i)) .or. ieee_is_nan(self%plots(plot_idx)%y(i))) cycle
            
            ! Transform data point to screen coordinates
            x_screen = transform_x_coordinate(self%plots(plot_idx)%x(i), &
                                            self%x_min, self%x_max, self%width)
            y_screen = transform_y_coordinate(self%plots(plot_idx)%y(i), &
                                            self%y_min, self%y_max, self%height, .true.)
            
            ! Draw Y error bars if present
            if (self%plots(plot_idx)%has_yerr) then
                if (self%plots(plot_idx)%asymmetric_yerr) then
                    ! Asymmetric Y error bars
                    y_err_lower = self%plots(plot_idx)%y(i) - self%plots(plot_idx)%yerr_lower(i)
                    y_err_upper = self%plots(plot_idx)%y(i) + self%plots(plot_idx)%yerr_upper(i)
                else
                    ! Symmetric Y error bars
                    y_err_lower = self%plots(plot_idx)%y(i) - self%plots(plot_idx)%yerr(i)
                    y_err_upper = self%plots(plot_idx)%y(i) + self%plots(plot_idx)%yerr(i)
                end if
                
                ! Transform error bar endpoints
                y1_screen = transform_y_coordinate(y_err_lower, &
                                                 self%y_min, self%y_max, self%height, .true.)
                y2_screen = transform_y_coordinate(y_err_upper, &
                                                 self%y_min, self%y_max, self%height, .true.)
                
                ! Draw vertical error bar line
                call self%backend%line(x_screen, y1_screen, x_screen, y2_screen)
                
                ! Draw caps
                call self%backend%line(x_screen - cap_half_size, y1_screen, x_screen + cap_half_size, y1_screen)
                call self%backend%line(x_screen - cap_half_size, y2_screen, x_screen + cap_half_size, y2_screen)
            end if
            
            ! Draw X error bars if present
            if (self%plots(plot_idx)%has_xerr) then
                if (self%plots(plot_idx)%asymmetric_xerr) then
                    ! Asymmetric X error bars
                    x_err_lower = self%plots(plot_idx)%x(i) - self%plots(plot_idx)%xerr_lower(i)
                    x_err_upper = self%plots(plot_idx)%x(i) + self%plots(plot_idx)%xerr_upper(i)
                else
                    ! Symmetric X error bars
                    x_err_lower = self%plots(plot_idx)%x(i) - self%plots(plot_idx)%xerr(i)
                    x_err_upper = self%plots(plot_idx)%x(i) + self%plots(plot_idx)%xerr(i)
                end if
                
                ! Transform error bar endpoints
                x1_screen = transform_x_coordinate(x_err_lower, &
                                                 self%x_min, self%x_max, self%width)
                x2_screen = transform_x_coordinate(x_err_upper, &
                                                 self%x_min, self%x_max, self%width)
                
                ! Draw horizontal error bar line
                call self%backend%line(x1_screen, y_screen, x2_screen, y_screen)
                
                ! Draw caps
                call self%backend%line(x1_screen, y_screen - cap_half_size, x1_screen, y_screen + cap_half_size)
                call self%backend%line(x2_screen, y_screen - cap_half_size, x2_screen, y_screen + cap_half_size)
            end if
        end do
        
        ! Render data points if marker is specified
        if (allocated(self%plots(plot_idx)%marker) .and. len_trim(self%plots(plot_idx)%marker) > 0) then
            call render_markers(self, plot_idx)
        end if
        
        ! Render connecting lines if linestyle is specified
        if (allocated(self%plots(plot_idx)%linestyle) .and. len_trim(self%plots(plot_idx)%linestyle) > 0) then
            call render_line_plot(self, plot_idx)
        end if
    end subroutine render_errorbar_plot

    subroutine render_markers(self, plot_idx)
        !! Render markers at each data point, skipping NaN values
        use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        character(len=:), allocatable :: marker
        integer :: i
        real(wp) :: x_trans, y_trans

        if (plot_idx > self%plot_count) return
        if (.not. allocated(self%plots(plot_idx)%marker)) return

        marker = self%plots(plot_idx)%marker
        if (marker == 'None') return

        do i = 1, size(self%plots(plot_idx)%x)
            ! Skip points with NaN values
            if (ieee_is_nan(self%plots(plot_idx)%x(i)) .or. ieee_is_nan(self%plots(plot_idx)%y(i))) cycle
            
            x_trans = apply_scale_transform(self%plots(plot_idx)%x(i), self%xscale, self%symlog_threshold)
            y_trans = apply_scale_transform(self%plots(plot_idx)%y(i), self%yscale, self%symlog_threshold)
            call self%backend%draw_marker(x_trans, y_trans, marker)
        end do

    end subroutine render_markers

    subroutine render_contour_plot(self, plot_idx)
        !! Render a single contour plot using proper marching squares algorithm
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        integer :: level_idx
        real(wp) :: contour_level
        real(wp) :: z_min, z_max
        real(wp), dimension(3) :: level_color
        
        if (plot_idx > self%plot_count) return
        if (.not. allocated(self%plots(plot_idx)%z_grid)) return
        
        ! Get data range for filtering valid levels
        z_min = minval(self%plots(plot_idx)%z_grid)
        z_max = maxval(self%plots(plot_idx)%z_grid)
        
        ! For ASCII backend with colored contours, render as heatmap
        select type (backend => self%backend)
        type is (ascii_context)
            if (self%plots(plot_idx)%use_color_levels) then
                ! Render as heatmap for filled contours
                call backend%fill_heatmap(self%plots(plot_idx)%x_grid, &
                                        self%plots(plot_idx)%y_grid, &
                                        self%plots(plot_idx)%z_grid, &
                                        z_min, z_max)
                return
            end if
        end select
        
        ! Render each contour level that falls within data range
        if (allocated(self%plots(plot_idx)%contour_levels)) then
            do level_idx = 1, size(self%plots(plot_idx)%contour_levels)
                contour_level = self%plots(plot_idx)%contour_levels(level_idx)
                
                ! Only render levels within the data range
                if (contour_level > z_min .and. contour_level < z_max) then
                    ! Set color based on contour level
                    if (self%plots(plot_idx)%use_color_levels) then
                        call colormap_value_to_color(contour_level, z_min, z_max, &
                                                   self%plots(plot_idx)%colormap, level_color)
                        call self%backend%color(level_color(1), level_color(2), level_color(3))
                    end if
                    
                    call trace_contour_level(self, plot_idx, contour_level)
                end if
            end do
        else
            ! Draw a few default contour levels with colors
            call render_default_contour_levels(self, plot_idx, z_min, z_max)
        end if
    end subroutine render_contour_plot

    subroutine render_pcolormesh_plot(self, plot_idx)
        !! Render pcolormesh plot as colored quadrilaterals
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        
        integer :: i, j
        real(wp) :: x_quad(4), y_quad(4)
        real(wp) :: x_screen(4), y_screen(4)
        real(wp) :: color(3), c_value, c_min, c_max
        
        ! Get colormap range from pcolormesh data
        c_min = self%plots(plot_idx)%pcolormesh_data%vmin
        c_max = self%plots(plot_idx)%pcolormesh_data%vmax
        
        ! For ASCII backend, render as heatmap
        select type (backend => self%backend)
        type is (ascii_context)
            block
                real(wp), allocatable :: x_centers(:), y_centers(:)
                integer :: nx, ny, i, j
                
                nx = self%plots(plot_idx)%pcolormesh_data%nx
                ny = self%plots(plot_idx)%pcolormesh_data%ny
                
                allocate(x_centers(nx), y_centers(ny))
                
                ! Calculate cell centers from vertices
                do i = 1, nx
                    x_centers(i) = 0.5_wp * (self%plots(plot_idx)%pcolormesh_data%x_vertices(1, i) + &
                                           self%plots(plot_idx)%pcolormesh_data%x_vertices(1, i+1))
                end do
                
                do j = 1, ny
                    y_centers(j) = 0.5_wp * (self%plots(plot_idx)%pcolormesh_data%y_vertices(j, 1) + &
                                           self%plots(plot_idx)%pcolormesh_data%y_vertices(j+1, 1))
                end do
                
                ! Render as heatmap using cell centers
                call backend%fill_heatmap(x_centers, y_centers, &
                                        self%plots(plot_idx)%pcolormesh_data%c_values, &
                                        c_min, c_max)
            end block
            return
        end select
        
        ! Render each quadrilateral
        do i = 1, self%plots(plot_idx)%pcolormesh_data%ny
            do j = 1, self%plots(plot_idx)%pcolormesh_data%nx
                ! Get quad vertices in world coordinates
                call self%plots(plot_idx)%pcolormesh_data%get_quad_vertices(i, j, x_quad, y_quad)
                
                ! Transform to screen coordinates
                call transform_quad_to_screen(self, x_quad, y_quad, x_screen, y_screen)
                
                ! Get color for this quad
                c_value = self%plots(plot_idx)%pcolormesh_data%c_values(i, j)
                call colormap_value_to_color(c_value, c_min, c_max, &
                                            self%plots(plot_idx)%pcolormesh_data%colormap_name, color)
                
                ! Draw filled quadrilateral
                call self%backend%color(color(1), color(2), color(3))
                call draw_filled_quad(self%backend, x_screen, y_screen)
                
                ! Draw edges if requested
                if (self%plots(plot_idx)%pcolormesh_data%show_edges) then
                    call self%backend%color(self%plots(plot_idx)%pcolormesh_data%edge_color(1), &
                                          self%plots(plot_idx)%pcolormesh_data%edge_color(2), &
                                          self%plots(plot_idx)%pcolormesh_data%edge_color(3))
                    call draw_quad_edges(self%backend, x_screen, y_screen, &
                                        self%plots(plot_idx)%pcolormesh_data%edge_width)
                end if
            end do
        end do
    end subroutine render_pcolormesh_plot

    subroutine render_default_contour_levels(self, plot_idx, z_min, z_max)
        !! Render default contour levels with optional coloring
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        real(wp), intent(in) :: z_min, z_max
        real(wp), dimension(3) :: level_color
        real(wp) :: level_values(3)
        integer :: i
        
        level_values = [z_min + 0.2_wp * (z_max - z_min), &
                       z_min + 0.5_wp * (z_max - z_min), &
                       z_min + 0.8_wp * (z_max - z_min)]
        
        do i = 1, 3
            ! Set color based on contour level
            if (self%plots(plot_idx)%use_color_levels) then
                call colormap_value_to_color(level_values(i), z_min, z_max, &
                                           self%plots(plot_idx)%colormap, level_color)
                call self%backend%color(level_color(1), level_color(2), level_color(3))
            end if
            
            call trace_contour_level(self, plot_idx, level_values(i))
        end do
    end subroutine render_default_contour_levels

    subroutine trace_contour_level(self, plot_idx, level)
        !! Trace a single contour level using marching squares
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        real(wp), intent(in) :: level
        integer :: nx, ny, i, j
        
        nx = size(self%plots(plot_idx)%x_grid)
        ny = size(self%plots(plot_idx)%y_grid)
        
        do i = 1, nx-1
            do j = 1, ny-1
                call process_contour_cell(self, plot_idx, i, j, level)
            end do
        end do
    end subroutine trace_contour_level

    subroutine process_contour_cell(self, plot_idx, i, j, level)
        !! Process a single grid cell for contour extraction
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx, i, j
        real(wp), intent(in) :: level
        real(wp) :: x1, y1, x2, y2, x3, y3, x4, y4
        real(wp) :: z1, z2, z3, z4
        integer :: config
        real(wp), dimension(8) :: line_points
        integer :: num_lines

        call get_cell_coordinates(self, plot_idx, i, j, x1, y1, x2, y2, x3, y3, x4, y4)
        call get_cell_values(self, plot_idx, i, j, z1, z2, z3, z4)
        call calculate_marching_squares_config(z1, z2, z3, z4, level, config)
        call get_contour_lines(config, x1, y1, x2, y2, x3, y3, x4, y4, &
                             z1, z2, z3, z4, level, line_points, num_lines)
        call draw_contour_lines(self, line_points, num_lines)
    end subroutine process_contour_cell

    subroutine get_cell_coordinates(self, plot_idx, i, j, x1, y1, x2, y2, x3, y3, x4, y4)
        !! Get the coordinates of the four corners of a grid cell
        class(figure_t), intent(in) :: self
        integer, intent(in) :: plot_idx, i, j
        real(wp), intent(out) :: x1, y1, x2, y2, x3, y3, x4, y4

        x1 = self%plots(plot_idx)%x_grid(i)
        y1 = self%plots(plot_idx)%y_grid(j)
        x2 = self%plots(plot_idx)%x_grid(i+1)
        y2 = self%plots(plot_idx)%y_grid(j)
        x3 = self%plots(plot_idx)%x_grid(i+1)
        y3 = self%plots(plot_idx)%y_grid(j+1)
        x4 = self%plots(plot_idx)%x_grid(i)
        y4 = self%plots(plot_idx)%y_grid(j+1)
    end subroutine get_cell_coordinates

    subroutine get_cell_values(self, plot_idx, i, j, z1, z2, z3, z4)
        !! Get the data values at the four corners of a grid cell
        class(figure_t), intent(in) :: self
        integer, intent(in) :: plot_idx, i, j
        real(wp), intent(out) :: z1, z2, z3, z4

        z1 = self%plots(plot_idx)%z_grid(i, j)
        z2 = self%plots(plot_idx)%z_grid(i+1, j)
        z3 = self%plots(plot_idx)%z_grid(i+1, j+1)
        z4 = self%plots(plot_idx)%z_grid(i, j+1)
    end subroutine get_cell_values

    subroutine calculate_marching_squares_config(z1, z2, z3, z4, level, config)
        !! Calculate marching squares configuration for a cell
        real(wp), intent(in) :: z1, z2, z3, z4, level
        integer, intent(out) :: config

        config = 0
        if (z1 >= level) config = config + 1
        if (z2 >= level) config = config + 2
        if (z3 >= level) config = config + 4
        if (z4 >= level) config = config + 8
    end subroutine calculate_marching_squares_config

    subroutine get_contour_lines(config, x1, y1, x2, y2, x3, y3, x4, y4, &
                               z1, z2, z3, z4, level, line_points, num_lines)
        !! Get contour line segments for a cell based on marching squares configuration
        integer, intent(in) :: config
        real(wp), intent(in) :: x1, y1, x2, y2, x3, y3, x4, y4
        real(wp), intent(in) :: z1, z2, z3, z4, level
        real(wp), dimension(8), intent(out) :: line_points
        integer, intent(out) :: num_lines
        real(wp) :: xa, ya, xb, yb, xc, yc, xd, yd
        
        call interpolate_edge_crossings(x1, y1, x2, y2, x3, y3, x4, y4, &
                                       z1, z2, z3, z4, level, xa, ya, xb, yb, xc, yc, xd, yd)
        call apply_marching_squares_lookup(config, xa, ya, xb, yb, xc, yc, xd, yd, line_points, num_lines)
    end subroutine get_contour_lines

    subroutine interpolate_edge_crossings(x1, y1, x2, y2, x3, y3, x4, y4, &
                                         z1, z2, z3, z4, level, xa, ya, xb, yb, xc, yc, xd, yd)
        !! Interpolate where contour level crosses cell edges
        real(wp), intent(in) :: x1, y1, x2, y2, x3, y3, x4, y4
        real(wp), intent(in) :: z1, z2, z3, z4, level
        real(wp), intent(out) :: xa, ya, xb, yb, xc, yc, xd, yd

        ! Edge 1-2 (bottom)
        if (abs(z2 - z1) > 1e-10_wp) then
            xa = x1 + (level - z1) / (z2 - z1) * (x2 - x1)
            ya = y1 + (level - z1) / (z2 - z1) * (y2 - y1)
        else
            xa = (x1 + x2) * 0.5_wp
            ya = (y1 + y2) * 0.5_wp
        end if
        
        ! Edge 2-3 (right)
        if (abs(z3 - z2) > 1e-10_wp) then
            xb = x2 + (level - z2) / (z3 - z2) * (x3 - x2)
            yb = y2 + (level - z2) / (z3 - z2) * (y3 - y2)
        else
            xb = (x2 + x3) * 0.5_wp
            yb = (y2 + y3) * 0.5_wp
        end if
        
        ! Edge 3-4 (top)
        if (abs(z4 - z3) > 1e-10_wp) then
            xc = x3 + (level - z3) / (z4 - z3) * (x4 - x3)
            yc = y3 + (level - z3) / (z4 - z3) * (y4 - y3)
        else
            xc = (x3 + x4) * 0.5_wp
            yc = (y3 + y4) * 0.5_wp
        end if
        
        ! Edge 4-1 (left)
        if (abs(z1 - z4) > 1e-10_wp) then
            xd = x4 + (level - z4) / (z1 - z4) * (x1 - x4)
            yd = y4 + (level - z4) / (z1 - z4) * (y1 - y4)
        else
            xd = (x4 + x1) * 0.5_wp
            yd = (y4 + y1) * 0.5_wp
        end if
    end subroutine interpolate_edge_crossings

    subroutine apply_marching_squares_lookup(config, xa, ya, xb, yb, xc, yc, xd, yd, line_points, num_lines)
        !! Apply marching squares lookup table to get line segments
        integer, intent(in) :: config
        real(wp), intent(in) :: xa, ya, xb, yb, xc, yc, xd, yd
        real(wp), dimension(8), intent(out) :: line_points
        integer, intent(out) :: num_lines

        num_lines = 0
        line_points = 0.0_wp
        
        select case (config)
        case (1, 14)
            line_points(1:4) = [xa, ya, xd, yd]
            num_lines = 1
        case (2, 13)
            line_points(1:4) = [xa, ya, xb, yb]
            num_lines = 1
        case (3, 12)
            line_points(1:4) = [xd, yd, xb, yb]
            num_lines = 1
        case (4, 11)
            line_points(1:4) = [xb, yb, xc, yc]
            num_lines = 1
        case (5)
            line_points(1:8) = [xa, ya, xd, yd, xb, yb, xc, yc]
            num_lines = 2
        case (6, 9)
            line_points(1:4) = [xa, ya, xc, yc]
            num_lines = 1
        case (7, 8)
            line_points(1:4) = [xd, yd, xc, yc]
            num_lines = 1
        case (10)
            line_points(1:8) = [xa, ya, xb, yb, xc, yc, xd, yd]
            num_lines = 2
        case default
            num_lines = 0
        end select
    end subroutine apply_marching_squares_lookup

    subroutine draw_contour_lines(self, line_points, num_lines)
        !! Draw the contour line segments with proper coordinate transformation
        class(figure_t), intent(inout) :: self
        real(wp), dimension(8), intent(in) :: line_points
        integer, intent(in) :: num_lines
        integer :: i
        real(wp) :: x1_trans, y1_trans, x2_trans, y2_trans
        
        do i = 1, num_lines
            ! Apply scale transformations to contour line endpoints
            x1_trans = apply_scale_transform(line_points(4*i-3), self%xscale, self%symlog_threshold)
            y1_trans = apply_scale_transform(line_points(4*i-2), self%yscale, self%symlog_threshold)
            x2_trans = apply_scale_transform(line_points(4*i-1), self%xscale, self%symlog_threshold)
            y2_trans = apply_scale_transform(line_points(4*i), self%yscale, self%symlog_threshold)
            
            call self%backend%line(x1_trans, y1_trans, x2_trans, y2_trans)
        end do
    end subroutine draw_contour_lines

    subroutine draw_line_with_style(self, plot_idx, linestyle)
        !! Draw line segments with specified linestyle pattern using continuous pattern approach
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        character(len=*), intent(in) :: linestyle
        
        if (linestyle == '-' .or. linestyle == 'solid') then
            ! Solid line - draw all segments normally
            call render_solid_line(self, plot_idx)
        else
            ! Patterned line - render with continuous pattern
            call render_patterned_line(self, plot_idx, linestyle)
        end if
    end subroutine draw_line_with_style

    subroutine render_solid_line(self, plot_idx)
        !! Render solid line by drawing all segments, breaking on NaN values
        use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        integer :: i
        real(wp) :: x1_screen, y1_screen, x2_screen, y2_screen
        
        do i = 1, size(self%plots(plot_idx)%x) - 1
            ! Skip segment if either point contains NaN
            if (ieee_is_nan(self%plots(plot_idx)%x(i)) .or. ieee_is_nan(self%plots(plot_idx)%y(i)) .or. &
                ieee_is_nan(self%plots(plot_idx)%x(i+1)) .or. ieee_is_nan(self%plots(plot_idx)%y(i+1))) then
                cycle
            end if
            
            ! Apply scale transformations
            x1_screen = apply_scale_transform(self%plots(plot_idx)%x(i), self%xscale, self%symlog_threshold)
            y1_screen = apply_scale_transform(self%plots(plot_idx)%y(i), self%yscale, self%symlog_threshold)
            x2_screen = apply_scale_transform(self%plots(plot_idx)%x(i+1), self%xscale, self%symlog_threshold)
            y2_screen = apply_scale_transform(self%plots(plot_idx)%y(i+1), self%yscale, self%symlog_threshold)
            
            call self%backend%line(x1_screen, y1_screen, x2_screen, y2_screen)
        end do
    end subroutine render_solid_line

    subroutine render_patterned_line(self, plot_idx, linestyle)
        !! Render line with continuous pattern across segments (matplotlib-style)
        use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_idx
        character(len=*), intent(in) :: linestyle
        
        real(wp) :: current_distance, segment_length
        real(wp) :: dash_len, dot_len, gap_len
        real(wp) :: pattern(20), pattern_length
        integer :: pattern_size, pattern_index
        logical :: drawing
        integer :: i, valid_count
        real(wp) :: x1_screen, y1_screen, x2_screen, y2_screen, dx, dy
        
        ! Get transformed data range for proper pattern scaling
        real(wp) :: x_range, y_range, plot_scale
        real(wp), allocatable :: x_trans(:), y_trans(:)
        logical, allocatable :: valid_points(:)
        
        ! Transform all data points to get proper scaling
        allocate(x_trans(size(self%plots(plot_idx)%x)))
        allocate(y_trans(size(self%plots(plot_idx)%y)))
        allocate(valid_points(size(self%plots(plot_idx)%x)))
        
        valid_count = 0
        do i = 1, size(self%plots(plot_idx)%x)
            valid_points(i) = .not. (ieee_is_nan(self%plots(plot_idx)%x(i)) .or. ieee_is_nan(self%plots(plot_idx)%y(i)))
            if (valid_points(i)) then
                x_trans(i) = apply_scale_transform(self%plots(plot_idx)%x(i), self%xscale, self%symlog_threshold)
                y_trans(i) = apply_scale_transform(self%plots(plot_idx)%y(i), self%yscale, self%symlog_threshold)
                valid_count = valid_count + 1
            else
                x_trans(i) = 0.0_wp
                y_trans(i) = 0.0_wp
            end if
        end do
        
        ! Handle case where all points are NaN
        if (valid_count > 0) then
            x_range = maxval(x_trans, mask=valid_points) - minval(x_trans, mask=valid_points)
            y_range = maxval(y_trans, mask=valid_points) - minval(y_trans, mask=valid_points)
            plot_scale = max(x_range, y_range)
        else
            ! All points are NaN, use default scale
            plot_scale = 1.0_wp
        end if
        
        ! Define pattern lengths (matplotlib-like)
        dash_len = plot_scale * 0.03_wp    ! 3% of range
        dot_len = plot_scale * 0.005_wp    ! 0.5% of range  
        gap_len = plot_scale * 0.015_wp    ! 1.5% of range
        
        ! Define patterns like matplotlib
        select case (trim(linestyle))
        case ('--')
            ! Dashed: [dash, gap, dash, gap, ...]
            pattern_size = 2
            pattern(1) = dash_len  ! dash
            pattern(2) = gap_len   ! gap
            
        case (':')
            ! Dotted: [dot, gap, dot, gap, ...]
            pattern_size = 2
            pattern(1) = dot_len   ! dot
            pattern(2) = gap_len   ! gap
            
        case ('-.')
            ! Dash-dot: [dash, gap, dot, gap, dash, gap, dot, gap, ...]
            pattern_size = 4
            pattern(1) = dash_len  ! dash
            pattern(2) = gap_len   ! gap
            pattern(3) = dot_len   ! dot
            pattern(4) = gap_len   ! gap
            
        case default
            ! Unknown pattern, fall back to solid
            call render_solid_line(self, plot_idx)
            deallocate(x_trans, y_trans)
            return
        end select
        
        ! Calculate total pattern length
        pattern_length = sum(pattern(1:pattern_size))
        
        ! Render with continuous pattern
        current_distance = 0.0_wp
        pattern_index = 1
        drawing = .true.  ! Start drawing
        
        do i = 1, size(self%plots(plot_idx)%x) - 1
            ! Skip segment if either point is invalid (NaN)
            if (.not. valid_points(i) .or. .not. valid_points(i+1)) then
                ! Reset pattern state when encountering NaN
                current_distance = 0.0_wp
                pattern_index = 1
                drawing = .true.
                cycle
            end if
            
            x1_screen = x_trans(i)
            y1_screen = y_trans(i)
            x2_screen = x_trans(i+1)
            y2_screen = y_trans(i+1)
            
            dx = x2_screen - x1_screen
            dy = y2_screen - y1_screen
            segment_length = sqrt(dx*dx + dy*dy)
            
            if (segment_length < 1e-10_wp) cycle
            
            call render_segment_with_pattern(self, x1_screen, y1_screen, x2_screen, y2_screen, segment_length, &
                                            pattern, pattern_size, pattern_length, &
                                            current_distance, pattern_index, drawing)
        end do
        
        ! Clean up
        deallocate(x_trans, y_trans, valid_points)
    end subroutine render_patterned_line

    subroutine render_segment_with_pattern(self, x1, y1, x2, y2, segment_length, &
                                          pattern, pattern_size, pattern_length, &
                                          current_distance, pattern_index, drawing)
        !! Render single segment with continuous pattern state
        class(figure_t), intent(inout) :: self
        real(wp), intent(in) :: x1, y1, x2, y2, segment_length
        real(wp), intent(in) :: pattern(:), pattern_length
        integer, intent(in) :: pattern_size
        real(wp), intent(inout) :: current_distance
        integer, intent(inout) :: pattern_index
        logical, intent(inout) :: drawing
        
        real(wp) :: dx, dy, remaining_distance, pattern_remaining
        real(wp) :: t_start, t_end, seg_x1, seg_y1, seg_x2, seg_y2
        
        dx = x2 - x1
        dy = y2 - y1
        remaining_distance = segment_length
        t_start = 0.0_wp
        
        do while (remaining_distance > 1e-10_wp)
            ! How much of current pattern element is left?
            pattern_remaining = pattern(pattern_index) - current_distance
            
            if (pattern_remaining <= remaining_distance) then
                ! Complete this pattern element within current segment
                t_end = t_start + pattern_remaining / segment_length
                
                if (drawing) then
                    seg_x1 = x1 + t_start * dx
                    seg_y1 = y1 + t_start * dy
                    seg_x2 = x1 + t_end * dx
                    seg_y2 = y1 + t_end * dy
                    call self%backend%line(seg_x1, seg_y1, seg_x2, seg_y2)
                end if
                
                ! Move to next pattern element
                remaining_distance = remaining_distance - pattern_remaining
                t_start = t_end
                current_distance = 0.0_wp
                pattern_index = mod(pattern_index, pattern_size) + 1
                drawing = .not. drawing  ! Alternate between drawing and not drawing
            else
                ! Pattern element extends beyond this segment
                t_end = 1.0_wp
                
                if (drawing) then
                    seg_x1 = x1 + t_start * dx
                    seg_y1 = y1 + t_start * dy
                    seg_x2 = x2
                    seg_y2 = y2
                    call self%backend%line(seg_x1, seg_y1, seg_x2, seg_y2)
                end if
                
                current_distance = current_distance + remaining_distance
                remaining_distance = 0.0_wp
            end if
        end do
    end subroutine render_segment_with_pattern

    subroutine figure_legend(self, location)
        !! Add legend to figure following SOLID principles
        class(figure_t), intent(inout) :: self
        character(len=*), intent(in), optional :: location
        integer :: i
        
        ! Initialize legend if not already done
        if (.not. allocated(self%legend_data%entries)) then
            allocate(self%legend_data%entries(0))
            self%legend_data%num_entries = 0
        end if
        
        ! Set legend position if specified  
        if (present(location)) then
            call self%legend_data%set_position(location)
        end if
        
        ! Populate legend with labeled plots (DRY principle)
        do i = 1, self%plot_count
            if (allocated(self%plots(i)%label)) then
                if (len_trim(self%plots(i)%label) > 0) then
                    call self%legend_data%add_entry(self%plots(i)%label, &
                                             self%plots(i)%color, &
                                             self%plots(i)%linestyle, &
                                             self%plots(i)%marker)
                end if
            end if
        end do
        
        self%show_legend = .true.
    end subroutine figure_legend
    
    subroutine clear_streamlines(self)
        !! Clear streamline data
        class(figure_t), intent(inout) :: self
        
        if (allocated(self%streamlines)) then
            deallocate(self%streamlines)
        end if
    end subroutine clear_streamlines

    subroutine transform_quad_to_screen(self, x_quad, y_quad, x_screen, y_screen)
        !! Transform quadrilateral vertices from world to screen coordinates
        class(figure_t), intent(in) :: self
        real(wp), intent(in) :: x_quad(4), y_quad(4)
        real(wp), intent(out) :: x_screen(4), y_screen(4)
        
        integer :: i
        
        ! Apply scale transformations only (backend handles screen mapping)
        do i = 1, 4
            x_screen(i) = apply_scale_transform(x_quad(i), self%xscale, self%symlog_threshold)
            y_screen(i) = apply_scale_transform(y_quad(i), self%yscale, self%symlog_threshold)
        end do
    end subroutine transform_quad_to_screen

    subroutine draw_filled_quad(backend, x_screen, y_screen)
        !! Draw filled quadrilateral
        use fortplot_raster, only: raster_context
        use fortplot_png, only: png_context
        class(plot_context), intent(inout) :: backend
        real(wp), intent(in) :: x_screen(4), y_screen(4)
        
        ! Use backend-specific filled quad rendering
        select type (backend)
        type is (raster_context)
            call backend%fill_quad(x_screen, y_screen)
        type is (png_context)
            call backend%fill_quad(x_screen, y_screen)
        class default
            ! Fallback: draw wireframe for unsupported backends
            call backend%line(x_screen(1), y_screen(1), x_screen(2), y_screen(2))
            call backend%line(x_screen(2), y_screen(2), x_screen(3), y_screen(3))
            call backend%line(x_screen(3), y_screen(3), x_screen(4), y_screen(4))
            call backend%line(x_screen(4), y_screen(4), x_screen(1), y_screen(1))
        end select
    end subroutine draw_filled_quad

    subroutine draw_quad_edges(backend, x_screen, y_screen, line_width)
        !! Draw quadrilateral edges
        class(plot_context), intent(inout) :: backend
        real(wp), intent(in) :: x_screen(4), y_screen(4)
        real(wp), intent(in) :: line_width
        
        ! Draw quad outline
        call backend%line(x_screen(1), y_screen(1), x_screen(2), y_screen(2))
        call backend%line(x_screen(2), y_screen(2), x_screen(3), y_screen(3))
        call backend%line(x_screen(3), y_screen(3), x_screen(4), y_screen(4))
        call backend%line(x_screen(4), y_screen(4), x_screen(1), y_screen(1))
    end subroutine draw_quad_edges

    subroutine set_ydata(self, plot_index, y_new)
        class(figure_t), intent(inout) :: self
        integer, intent(in) :: plot_index
        real(wp), intent(in) :: y_new(:)
        
        if (plot_index < 1 .or. plot_index > self%plot_count) then
            print *, "Warning: Invalid plot index", plot_index, "for set_ydata"
            return
        end if
        
        if (self%plots(plot_index)%plot_type /= PLOT_TYPE_LINE) then
            print *, "Warning: set_ydata only supported for line plots"
            return
        end if
        
        if (.not. allocated(self%plots(plot_index)%y)) then
            print *, "Warning: Plot", plot_index, "has no y data to update"
            return
        end if
        
        if (size(y_new) /= size(self%plots(plot_index)%y)) then
            print *, "Warning: New y data size", size(y_new), &
                     "does not match existing size", size(self%plots(plot_index)%y)
            return
        end if
        
        self%plots(plot_index)%y = y_new
    end subroutine set_ydata

end module fortplot_figure_core