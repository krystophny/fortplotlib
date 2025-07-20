module fortplot_figure
    !! Main plotting interface - compatibility wrapper for refactored modules
    !! 
    !! This module maintains backward compatibility while delegating to
    !! specialized modules that follow SOLID principles.
    !! 
    !! Re-exports: figure_t from fortplot_figure_core
    !! Re-exports: scale functions from fortplot_scales
    !! Re-exports: utility functions from fortplot_utils
    
    use fortplot_figure_core, only: figure_t, plot_data_t, PLOT_TYPE_LINE, PLOT_TYPE_CONTOUR, PLOT_TYPE_PCOLORMESH, PLOT_TYPE_BOXPLOT
    use fortplot_scales, only: apply_scale_transform, apply_inverse_scale_transform, &
                              transform_x_coordinate, transform_y_coordinate
    use fortplot_utils, only: get_backend_from_filename, initialize_backend
    use fortplot_axes, only: compute_scale_ticks, format_tick_label
    
    implicit none
    
    ! Re-export all public entities for backward compatibility
    public :: figure_t, plot_data_t
    public :: PLOT_TYPE_LINE, PLOT_TYPE_CONTOUR, PLOT_TYPE_PCOLORMESH, PLOT_TYPE_BOXPLOT
    public :: apply_scale_transform, apply_inverse_scale_transform
    public :: transform_x_coordinate, transform_y_coordinate
    public :: get_backend_from_filename, initialize_backend
    public :: compute_scale_ticks, format_tick_label

end module fortplot_figure