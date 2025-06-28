module forttf_stb_raster
    !! STB TrueType-compatible rasterization pipeline
    !! Implements exact algorithms from stb_truetype.h for pixel-perfect matching
    use iso_c_binding
    use, intrinsic :: iso_fortran_env, only: wp => real64
    use forttf_types
    implicit none

    private

    ! Public interface for STB-compatible rasterization
    public :: stb_flatten_curves
    public :: stb_tesselate_curve
    public :: stb_tesselate_cubic
    public :: stb_add_point

contains

    function stb_flatten_curves(vertices, num_verts, objspace_flatness, &
                               contour_lengths, num_contours) result(points)
        !! Main curve flattening function (matches stbtt_FlattenCurves)
        type(ttf_vertex_t), intent(in) :: vertices(:)
        integer, intent(in) :: num_verts
        real(wp), intent(in) :: objspace_flatness
        integer, allocatable, intent(out) :: contour_lengths(:)
        integer, intent(out) :: num_contours
        type(stb_point_t), allocatable :: points(:)
        
        type(stb_point_t), allocatable :: temp_points(:)
        integer :: max_points, num_points
        integer :: i, contour_start, n
        real(wp) :: objspace_flatness_squared
        logical :: in_contour
        
        ! Pre-calculate squared flatness for efficiency (matches STB)
        objspace_flatness_squared = objspace_flatness * objspace_flatness
        
        ! Estimate maximum points needed (conservative)
        max_points = num_verts * 32  ! Each curve could expand significantly
        allocate(temp_points(max_points))
        
        ! Track contours
        allocate(contour_lengths(num_verts))  ! Max possible contours
        num_contours = 0
        num_points = 0
        in_contour = .false.
        contour_start = 0
        
        i = 1
        do while (i <= num_verts)
            select case (vertices(i)%type)
            case (TTF_VERTEX_MOVE)
                ! End previous contour if any
                if (in_contour) then
                    num_contours = num_contours + 1
                    contour_lengths(num_contours) = num_points - contour_start
                end if
                
                ! Start new contour
                in_contour = .true.
                contour_start = num_points
                call stb_add_point(temp_points, num_points, max_points, &
                                  real(vertices(i)%x, wp), real(vertices(i)%y, wp))
                i = i + 1
                
            case (TTF_VERTEX_LINE)
                if (in_contour) then
                    call stb_add_point(temp_points, num_points, max_points, &
                                      real(vertices(i)%x, wp), real(vertices(i)%y, wp))
                end if
                i = i + 1
                
            case (TTF_VERTEX_CURVE)
                if (in_contour .and. i <= num_verts) then
                    ! Quadratic Bézier curve (P0, P1, P2)
                    ! P0 = previous point, P1 = control point, P2 = end point
                    call stb_tesselate_curve(temp_points, num_points, max_points, &
                                           temp_points(num_points)%x, temp_points(num_points)%y, &
                                           real(vertices(i)%cx, wp), real(vertices(i)%cy, wp), &
                                           real(vertices(i)%x, wp), real(vertices(i)%y, wp), &
                                           objspace_flatness_squared, 0)
                end if
                i = i + 1
                
            case (TTF_VERTEX_CUBIC)
                if (in_contour .and. i <= num_verts) then
                    ! Cubic Bézier curve (P0, P1, P2, P3)
                    ! P0 = previous point, P1 = first control, P2 = second control, P3 = end
                    call stb_tesselate_cubic(temp_points, num_points, max_points, &
                                           temp_points(num_points)%x, temp_points(num_points)%y, &
                                           real(vertices(i)%cx, wp), real(vertices(i)%cy, wp), &
                                           real(vertices(i)%cx1, wp), real(vertices(i)%cy1, wp), &
                                           real(vertices(i)%x, wp), real(vertices(i)%y, wp), &
                                           objspace_flatness_squared, 0)
                end if
                i = i + 1
                
            case default
                i = i + 1
            end select
        end do
        
        ! End final contour
        if (in_contour) then
            num_contours = num_contours + 1
            contour_lengths(num_contours) = num_points - contour_start
        end if
        
        ! Copy to final result array (exact size)
        allocate(points(num_points))
        points(1:num_points) = temp_points(1:num_points)
        
        ! Resize contour_lengths to actual size
        if (num_contours > 0) then
            contour_lengths = contour_lengths(1:num_contours)
        else
            deallocate(contour_lengths)
            allocate(contour_lengths(0))
        end if
        
    end function stb_flatten_curves
    
    subroutine stb_add_point(points, num_points, max_points, x, y)
        !! Add point to points array (matches stbtt__add_point)
        type(stb_point_t), intent(inout) :: points(:)
        integer, intent(inout) :: num_points
        integer, intent(in) :: max_points
        real(wp), intent(in) :: x, y
        
        if (num_points < max_points) then
            num_points = num_points + 1
            points(num_points) = stb_point_t(x=x, y=y)
        end if
        
    end subroutine stb_add_point
    
    recursive subroutine stb_tesselate_curve(points, num_points, max_points, &
                                            x0, y0, x1, y1, x2, y2, &
                                            objspace_flatness_squared, n)
        !! Tessellate quadratic Bézier curve (matches stbtt__tesselate_curve)
        type(stb_point_t), intent(inout) :: points(:)
        integer, intent(inout) :: num_points
        integer, intent(in) :: max_points
        real(wp), intent(in) :: x0, y0, x1, y1, x2, y2
        real(wp), intent(in) :: objspace_flatness_squared
        integer, intent(in) :: n
        
        real(wp) :: mx, my, dx, dy
        
        ! Prevent infinite recursion (matches STB's max depth)
        if (n > TTF_MAX_RECURSION_DEPTH) then
            call stb_add_point(points, num_points, max_points, x2, y2)
            return
        end if
        
        ! Calculate midpoint of control polygon vs actual curve midpoint
        ! STB algorithm: compare (x0+2*x1+x2)/4 vs (x0+x2)/2
        mx = (x0 + 2.0_wp * x1 + x2) * 0.25_wp  ! Curve midpoint
        my = (y0 + 2.0_wp * y1 + y2) * 0.25_wp
        
        dx = (x0 + x2) * 0.5_wp - mx  ! Difference from linear midpoint  
        dy = (y0 + y2) * 0.5_wp - my
        
        ! STB flatness test: is deviation within tolerance?
        if (dx * dx + dy * dy > objspace_flatness_squared) then
            ! Curve is not flat enough - subdivide
            ! Left half: (x0,y0) to ((x0+x1)/2, (y0+y1)/2) to (mx,my)
            call stb_tesselate_curve(points, num_points, max_points, &
                                   x0, y0, &
                                   (x0 + x1) * 0.5_wp, (y0 + y1) * 0.5_wp, &
                                   mx, my, &
                                   objspace_flatness_squared, n + 1)
            
            ! Right half: (mx,my) to ((x1+x2)/2, (y1+y2)/2) to (x2,y2)
            call stb_tesselate_curve(points, num_points, max_points, &
                                   mx, my, &
                                   (x1 + x2) * 0.5_wp, (y1 + y2) * 0.5_wp, &
                                   x2, y2, &
                                   objspace_flatness_squared, n + 1)
        else
            ! Curve is flat enough - add endpoint
            call stb_add_point(points, num_points, max_points, x2, y2)
        end if
        
    end subroutine stb_tesselate_curve
    
    recursive subroutine stb_tesselate_cubic(points, num_points, max_points, &
                                           x0, y0, x1, y1, x2, y2, x3, y3, &
                                           objspace_flatness_squared, n)
        !! Tessellate cubic Bézier curve (matches stbtt__tesselate_cubic)
        type(stb_point_t), intent(inout) :: points(:)
        integer, intent(inout) :: num_points
        integer, intent(in) :: max_points
        real(wp), intent(in) :: x0, y0, x1, y1, x2, y2, x3, y3
        real(wp), intent(in) :: objspace_flatness_squared
        integer, intent(in) :: n
        
        real(wp) :: dx0, dy0, dx1, dy1, dx2, dy2, dx3, dy3
        real(wp) :: longlen, shortlen
        real(wp) :: x01, y01, x12, y12, x23, y23
        real(wp) :: x012, y012, x123, y123, x0123, y0123
        
        ! Prevent infinite recursion
        if (n > TTF_MAX_RECURSION_DEPTH) then
            call stb_add_point(points, num_points, max_points, x3, y3)
            return
        end if
        
        ! STB algorithm: compare arc length vs chord length
        ! Calculate the sum of all segment lengths
        dx0 = x1 - x0
        dy0 = y1 - y0
        dx1 = x2 - x1  
        dy1 = y2 - y1
        dx2 = x3 - x2
        dy2 = y3 - y2
        dx3 = x3 - x0  ! Direct chord
        dy3 = y3 - y0
        
        longlen = sqrt(dx0*dx0 + dy0*dy0) + sqrt(dx1*dx1 + dy1*dy1) + sqrt(dx2*dx2 + dy2*dy2)
        shortlen = sqrt(dx3*dx3 + dy3*dy3)
        
        ! STB flatness test for cubic curves
        if (longlen - shortlen > sqrt(objspace_flatness_squared)) then
            ! Curve is not flat enough - subdivide using de Casteljau's algorithm
            ! First level interpolation
            x01 = (x0 + x1) * 0.5_wp
            y01 = (y0 + y1) * 0.5_wp
            x12 = (x1 + x2) * 0.5_wp
            y12 = (y1 + y2) * 0.5_wp
            x23 = (x2 + x3) * 0.5_wp
            y23 = (y2 + y3) * 0.5_wp
            
            ! Second level interpolation
            x012 = (x01 + x12) * 0.5_wp
            y012 = (y01 + y12) * 0.5_wp
            x123 = (x12 + x23) * 0.5_wp
            y123 = (y12 + y23) * 0.5_wp
            
            ! Final midpoint
            x0123 = (x012 + x123) * 0.5_wp
            y0123 = (y012 + y123) * 0.5_wp
            
            ! Left half: (x0,y0,x01,y01,x012,y012,x0123,y0123)
            call stb_tesselate_cubic(points, num_points, max_points, &
                                   x0, y0, x01, y01, x012, y012, x0123, y0123, &
                                   objspace_flatness_squared, n + 1)
            
            ! Right half: (x0123,y0123,x123,y123,x23,y23,x3,y3)  
            call stb_tesselate_cubic(points, num_points, max_points, &
                                   x0123, y0123, x123, y123, x23, y23, x3, y3, &
                                   objspace_flatness_squared, n + 1)
        else
            ! Curve is flat enough - add endpoint
            call stb_add_point(points, num_points, max_points, x3, y3)
        end if
        
    end subroutine stb_tesselate_cubic

end module forttf_stb_raster