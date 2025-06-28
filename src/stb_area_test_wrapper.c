/*
 * STB Area Calculation Test Wrapper
 * Exposes internal STB area calculation functions for testing against Fortran implementations
 */

#define STB_TRUETYPE_IMPLEMENTATION
#include "../thirdparty/stb_truetype.h"

/*
 * Test wrapper for stbtt__sized_trapezoid_area
 */
float stb_test_sized_trapezoid_area(float height, float top_width, float bottom_width) {
    return stbtt__sized_trapezoid_area(height, top_width, bottom_width);
}

/*
 * Test wrapper for stbtt__position_trapezoid_area
 */
float stb_test_position_trapezoid_area(float height, float tx0, float tx1, float bx0, float bx1) {
    return stbtt__position_trapezoid_area(height, tx0, tx1, bx0, bx1);
}

/*
 * Test wrapper for stbtt__sized_triangle_area
 */
float stb_test_sized_triangle_area(float height, float width) {
    return stbtt__sized_triangle_area(height, width);
}
