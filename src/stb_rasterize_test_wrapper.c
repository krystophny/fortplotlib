/*
 * STB Rasterize Sorted Edges Test Wrapper
 * Exposes STB rasterize_sorted_edges function for testing against Fortran implementation
 */

#define STB_TRUETYPE_IMPLEMENTATION
#include "../thirdparty/stb_truetype.h"
#include <stdlib.h>
#include <string.h>

/*
 * Test wrapper for stbtt__rasterize_sorted_edges
 * Simplified interface for testing basic functionality
 */
void stb_test_rasterize_sorted_edges(unsigned char* pixels, int width, int height, int stride,
                                   float* edge_x0, float* edge_y0, float* edge_x1, float* edge_y1, int* edge_invert,
                                   int num_edges, int vsubsample, int off_x, int off_y) {
    
    // Create STB bitmap structure
    stbtt__bitmap result;
    result.w = width;
    result.h = height;
    result.stride = stride;
    result.pixels = pixels;
    
    // Clear the bitmap
    memset(pixels, 0, width * height);
    
    if (num_edges == 0) {
        return; // Nothing to rasterize
    }
    
    // Convert input arrays to STB edge structures
    stbtt__edge* edges = (stbtt__edge*)malloc((num_edges + 1) * sizeof(stbtt__edge));
    if (!edges) return;
    
    for (int i = 0; i < num_edges; i++) {
        edges[i].x0 = edge_x0[i];
        edges[i].y0 = edge_y0[i];
        edges[i].x1 = edge_x1[i];
        edges[i].y1 = edge_y1[i];
        edges[i].invert = edge_invert[i];
    }
    
    // Add sentinel edge (STB requirement)
    edges[num_edges].y0 = (float)(off_y + height) + 1.0f;
    
    // Call STB rasterization function
    stbtt__rasterize_sorted_edges(&result, edges, num_edges, vsubsample, off_x, off_y, NULL);
    
    free(edges);
}

/*
 * Simple test wrapper for a single vertical edge
 */
void stb_test_rasterize_single_vertical_edge(unsigned char* pixels, int width, int height,
                                           float x, float y0, float y1, int direction) {
    float edge_x0[1] = {x};
    float edge_y0[1] = {y0};
    float edge_x1[1] = {x};
    float edge_y1[1] = {y1};
    int edge_invert[1] = {direction};
    
    stb_test_rasterize_sorted_edges(pixels, width, height, width, 
                                  edge_x0, edge_y0, edge_x1, edge_y1, edge_invert,
                                  1, 1, 0, 0);
}

/*
 * Test wrapper for triangle (3 edges)
 */
void stb_test_rasterize_triangle(unsigned char* pixels, int width, int height,
                                float x1, float y1, float x2, float y2, float x3, float y3) {
    float edge_x0[3] = {x1, x2, x3};
    float edge_y0[3] = {y1, y2, y3};
    float edge_x1[3] = {x2, x3, x1};
    float edge_y1[3] = {y2, y3, y1};
    int edge_invert[3] = {0, 0, 0}; // All same direction
    
    stb_test_rasterize_sorted_edges(pixels, width, height, width,
                                  edge_x0, edge_y0, edge_x1, edge_y1, edge_invert,
                                  3, 1, 0, 0);
}
