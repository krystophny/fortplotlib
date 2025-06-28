/*
 * STB Complete Pipeline Test Wrapper
 * Tests the complete stbtt_Rasterize function against Fortran implementation
 */

#define STB_TRUETYPE_IMPLEMENTATION
#include "../thirdparty/stb_truetype.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Test wrapper for complete stbtt_Rasterize pipeline
 */
void stb_test_complete_pipeline(unsigned char *pixels, int width, int height, int stride,
                               stbtt_vertex *vertices, int num_vertices,
                               float scale_x, float scale_y, float shift_x, float shift_y,
                               int x_off, int y_off, int invert) {
    stbtt__bitmap result;
    
    // Set up bitmap structure
    result.w = width;
    result.h = height;
    result.stride = stride;
    result.pixels = pixels;
    
    // Clear bitmap to background
    memset(pixels, 0, width * height);
    
    // Call STB rasterization
    stbtt_Rasterize(&result, 0.35f, vertices, num_vertices, 
                   scale_x, scale_y, shift_x, shift_y, 
                   x_off, y_off, invert, NULL);
}