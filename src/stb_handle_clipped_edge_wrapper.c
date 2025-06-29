#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// Include STB truetype implementation
#define STB_TRUETYPE_IMPLEMENTATION
#include "../thirdparty/stb_truetype.h"

// Wrapper for testing stbtt__handle_clipped_edge in isolation
void test_stb_handle_clipped_edge(float *scanline, int x, 
                                  float sy, float ey, float direction,
                                  float x0, float y0, float x1, float y1) {
    // Create minimal active edge structure for testing
    stbtt__active_edge e;
    e.sy = sy;
    e.ey = ey;
    e.direction = direction;
    e.next = NULL;
    
    // Call the original STB function
    stbtt__handle_clipped_edge(scanline, x, &e, x0, y0, x1, y1);
}

// Fortran interface
void test_stb_handle_clipped_edge_c(float *scanline, int *x,
                                    float *sy, float *ey, float *direction,
                                    float *x0, float *y0, float *x1, float *y1) {
    test_stb_handle_clipped_edge(scanline, *x, *sy, *ey, *direction, 
                                *x0, *y0, *x1, *y1);
}