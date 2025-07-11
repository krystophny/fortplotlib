module fortplot_pcolormesh
    !! Pcolormesh (pseudocolor mesh) plotting functionality
    !! 
    !! Provides 2D scalar field visualization using colored quadrilaterals
    !! on regular or irregular grids. Compatible with matplotlib pcolormesh.
    !!
    !! Following SOLID principles:
    !! - Single Responsibility: Only handles pcolormesh data structures
    !! - Open/Closed: Extensible for different shading modes
    !! - Interface Segregation: Minimal, focused interface
    
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use fortplot_colormap, only: get_colormap_color, colormap_value_to_color
    implicit none
    
    private
    public :: pcolormesh_t, validate_pcolormesh_grid, create_regular_mesh_grid
    
    type :: pcolormesh_t
        !! Pcolormesh data container
        !! Stores grid vertices and color data for quadrilateral mesh rendering
        
        ! Grid coordinates (vertices of quadrilaterals)  
        real(wp), allocatable :: x_vertices(:,:)    ! (ny+1, nx+1)
        real(wp), allocatable :: y_vertices(:,:)    ! (ny+1, nx+1)
        
        ! Color data (one value per quadrilateral)
        real(wp), allocatable :: c_values(:,:)      ! (ny, nx)
        
        ! Colormap properties
        character(len=20) :: colormap_name = 'viridis'
        real(wp) :: vmin = -huge(1.0_wp)
        real(wp) :: vmax = huge(1.0_wp)
        logical :: vmin_set = .false.
        logical :: vmax_set = .false.
        
        ! Edge properties
        logical :: show_edges = .false.
        real(wp), dimension(3) :: edge_color = [0.0_wp, 0.0_wp, 0.0_wp]
        real(wp) :: edge_width = 0.5_wp
        
        ! Transparency
        real(wp) :: alpha = 1.0_wp
        
        ! Grid dimensions for convenience
        integer :: nx = 0  ! number of columns in C
        integer :: ny = 0  ! number of rows in C
        
    contains
        procedure :: initialize_regular_grid
        procedure :: initialize_irregular_grid
        procedure :: get_data_range
        procedure :: get_quad_vertices
    end type pcolormesh_t
     
contains

    subroutine initialize_regular_grid(self, x_coords, y_coords, c_data, colormap)
        !! Initialize pcolormesh with regular grid from 1D coordinate arrays
        !! 
        !! Arguments:
        !!   x_coords: 1D array of x-coordinates (length nx+1)
        !!   y_coords: 1D array of y-coordinates (length ny+1)  
        !!   c_data: 2D color data array (ny, nx)
        !!   colormap: Optional colormap name
        class(pcolormesh_t), intent(inout) :: self
        real(wp), intent(in) :: x_coords(:)
        real(wp), intent(in) :: y_coords(:)
        real(wp), intent(in) :: c_data(:,:)
        character(len=*), intent(in), optional :: colormap
        
        integer :: i, j
        
        ! Validate dimensions
        self%nx = size(c_data, 2)
        self%ny = size(c_data, 1)
        
        if (size(x_coords) /= self%nx + 1) then
            error stop "pcolormesh: x_coords size must be nx+1"
        end if
        if (size(y_coords) /= self%ny + 1) then
            error stop "pcolormesh: y_coords size must be ny+1"
        end if
        
        ! Allocate arrays (deallocate first if already allocated)
        if (allocated(self%x_vertices)) deallocate(self%x_vertices)
        if (allocated(self%y_vertices)) deallocate(self%y_vertices)
        if (allocated(self%c_values)) deallocate(self%c_values)
        
        allocate(self%x_vertices(self%ny+1, self%nx+1))
        allocate(self%y_vertices(self%ny+1, self%nx+1))
        allocate(self%c_values(self%ny, self%nx))
        
        ! Create 2D meshgrid from 1D arrays
        do i = 1, self%ny + 1
            do j = 1, self%nx + 1
                self%x_vertices(i, j) = x_coords(j)
                self%y_vertices(i, j) = y_coords(i)
            end do
        end do
        
        ! Copy color data
        self%c_values = c_data
        
        ! Set colormap
        if (present(colormap)) then
            self%colormap_name = trim(colormap)
        end if
        
        ! Compute data range for auto-scaling
        call self%get_data_range()
    end subroutine initialize_regular_grid
    
    subroutine initialize_irregular_grid(self, x_verts, y_verts, c_data, colormap)
        !! Initialize pcolormesh with irregular grid from 2D vertex arrays
        !!
        !! Arguments:
        !!   x_verts, y_verts: 2D vertex coordinate arrays (ny+1, nx+1)
        !!   c_data: 2D color data array (ny, nx)
        !!   colormap: Optional colormap name
        class(pcolormesh_t), intent(inout) :: self
        real(wp), intent(in) :: x_verts(:,:)
        real(wp), intent(in) :: y_verts(:,:)
        real(wp), intent(in) :: c_data(:,:)
        character(len=*), intent(in), optional :: colormap
        
        ! Validate dimensions
        self%ny = size(c_data, 1)
        self%nx = size(c_data, 2)
        
        if (size(x_verts, 1) /= self%ny + 1 .or. size(x_verts, 2) /= self%nx + 1) then
            error stop "pcolormesh: x_verts dimensions must be (ny+1, nx+1)"
        end if
        if (size(y_verts, 1) /= self%ny + 1 .or. size(y_verts, 2) /= self%nx + 1) then
            error stop "pcolormesh: y_verts dimensions must be (ny+1, nx+1)"
        end if
        
        ! Allocate and copy data (deallocate first if already allocated)
        if (allocated(self%x_vertices)) deallocate(self%x_vertices)
        if (allocated(self%y_vertices)) deallocate(self%y_vertices)
        if (allocated(self%c_values)) deallocate(self%c_values)
        
        allocate(self%x_vertices(self%ny+1, self%nx+1))
        allocate(self%y_vertices(self%ny+1, self%nx+1))
        allocate(self%c_values(self%ny, self%nx))
        
        self%x_vertices = x_verts
        self%y_vertices = y_verts
        self%c_values = c_data
        
        ! Set colormap
        if (present(colormap)) then
            self%colormap_name = trim(colormap)
        end if
        
        ! Compute data range
        call self%get_data_range()
    end subroutine initialize_irregular_grid
    
    subroutine get_data_range(self)
        !! Compute data range for colormap normalization
        class(pcolormesh_t), intent(inout) :: self
        
        if (.not. self%vmin_set) then
            self%vmin = minval(self%c_values)
        end if
        if (.not. self%vmax_set) then
            self%vmax = maxval(self%c_values)
        end if
    end subroutine get_data_range
    
    subroutine get_quad_vertices(self, i, j, x_quad, y_quad)
        !! Get vertices of quadrilateral (i,j)
        !! 
        !! Arguments:
        !!   i, j: Quadrilateral indices (1-based)
        !!   x_quad, y_quad: Output vertex coordinates (4 elements each)
        class(pcolormesh_t), intent(in) :: self
        integer, intent(in) :: i, j
        real(wp), intent(out) :: x_quad(4), y_quad(4)
        
        ! Quadrilateral vertices in counter-clockwise order
        ! Bottom-left, bottom-right, top-right, top-left
        x_quad(1) = self%x_vertices(i, j)       ! bottom-left
        y_quad(1) = self%y_vertices(i, j)
        
        x_quad(2) = self%x_vertices(i, j+1)     ! bottom-right  
        y_quad(2) = self%y_vertices(i, j+1)
        
        x_quad(3) = self%x_vertices(i+1, j+1)   ! top-right
        y_quad(3) = self%y_vertices(i+1, j+1)
        
        x_quad(4) = self%x_vertices(i+1, j)     ! top-left
        y_quad(4) = self%y_vertices(i+1, j)
    end subroutine get_quad_vertices
    
    subroutine validate_pcolormesh_grid(x_coords, y_coords, c_data)
        !! Validate grid dimensions for pcolormesh
        !!
        !! For regular grids: x(nx+1), y(ny+1), C(ny,nx)
        !! For flat shading: vertices define quad corners
        real(wp), intent(in) :: x_coords(:)
        real(wp), intent(in) :: y_coords(:)
        real(wp), intent(in) :: c_data(:,:)
        
        integer :: nx, ny
        
        ny = size(c_data, 1)
        nx = size(c_data, 2)
        
        if (size(x_coords) /= nx + 1) then
            error stop "pcolormesh: x coordinate array size must be nx+1"
        end if
        
        if (size(y_coords) /= ny + 1) then
            error stop "pcolormesh: y coordinate array size must be ny+1"
        end if
    end subroutine validate_pcolormesh_grid
    
    subroutine create_regular_mesh_grid(x_1d, y_1d, x_2d, y_2d)
        !! Create 2D meshgrid from 1D coordinate arrays
        !! Used internally for regular grid setup
        real(wp), intent(in) :: x_1d(:), y_1d(:)
        real(wp), intent(out) :: x_2d(:,:), y_2d(:,:)
        
        integer :: i, j, nx, ny
        
        ny = size(y_1d)
        nx = size(x_1d)
        
        do i = 1, ny
            do j = 1, nx
                x_2d(i, j) = x_1d(j)
                y_2d(i, j) = y_1d(i)
            end do
        end do
    end subroutine create_regular_mesh_grid

end module fortplot_pcolormesh