/*
 * STB Exact Validation Wrapper
 * Exposes every intermediate STB function for exact comparison
 */

#define STB_TRUETYPE_IMPLEMENTATION
#include "../thirdparty/stb_truetype.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Test wrapper for stbtt_FlattenCurves
 */
void stb_test_flatten_curves_exact(stbtt_vertex *vertices, int num_verts, float flatness,
                                  stbtt__point **points_out, int **contour_lengths_out, 
                                  int *num_contours_out, int *total_points_out) {
    stbtt__point *points = stbtt_FlattenCurves(vertices, num_verts, flatness, 
                                              contour_lengths_out, num_contours_out, NULL);
    *points_out = points;
    
    // Count total points
    *total_points_out = 0;
    for (int i = 0; i < *num_contours_out; i++) {
        *total_points_out += (*contour_lengths_out)[i];
    }
}

/*
 * Test wrapper for edge building from stbtt__rasterize 
 */
void stb_test_build_edges_exact(stbtt__point *pts, int *wcount, int windings,
                               float scale_x, float scale_y, float shift_x, float shift_y, 
                               int invert, stbtt__edge **edges_out, int *num_edges_out) {
    float y_scale_inv = invert ? -scale_y : scale_y;
    int vsubsample = 1;  // STBTT_RASTERIZER_VERSION == 2
    
    // Count edges needed (skip horizontal)
    int n = 0;
    int m = 0;
    for (int i = 0; i < windings; ++i) {
        stbtt__point *p = pts + m;
        m += wcount[i];
        int j = wcount[i] - 1;
        for (int k = 0; k < wcount[i]; j = k++) {
            if (p[j].y != p[k].y) {  // Skip horizontal edges
                n++;
            }
        }
    }
    
    *num_edges_out = n;
    if (n == 0) {
        *edges_out = NULL;
        return;
    }
    
    stbtt__edge *e = (stbtt__edge *)malloc(sizeof(*e) * n);
    *edges_out = e;
    
    // Build edges (exact STB algorithm)
    n = 0;
    m = 0;
    for (int i = 0; i < windings; ++i) {
        stbtt__point *p = pts + m;
        m += wcount[i];
        int j = wcount[i] - 1;
        for (int k = 0; k < wcount[i]; j = k++) {
            int a = k, b = j;
            // Skip horizontal edges
            if (p[j].y == p[k].y) continue;
            
            // Add edge from j to k
            e[n].invert = 0;
            if (invert ? p[j].y > p[k].y : p[j].y < p[k].y) {
                e[n].invert = 1;
                a = j; b = k;
            }
            e[n].x0 = p[a].x * scale_x + shift_x;
            e[n].y0 = (p[a].y * y_scale_inv + shift_y) * vsubsample;
            e[n].x1 = p[b].x * scale_x + shift_x;
            e[n].y1 = (p[b].y * y_scale_inv + shift_y) * vsubsample;
            ++n;
        }
    }
    
    // Sort edges
    stbtt__sort_edges(e, n);
}

/*
 * Test wrapper for complete pipeline with pixel counting
 */
void stb_test_complete_rasterize_exact(stbtt_vertex *vertices, int num_verts,
                                      float scale_x, float scale_y, float shift_x, float shift_y,
                                      int width, int height, int x_off, int y_off, int invert,
                                      unsigned char **bitmap_out, int *pixel_count_out) {
    stbtt__bitmap result;
    result.w = width;
    result.h = height;
    result.stride = width;
    result.pixels = (unsigned char *)malloc(width * height);
    memset(result.pixels, 0, width * height);
    
    // Call STB rasterization
    stbtt_Rasterize(&result, 0.35f, vertices, num_verts, 
                   scale_x, scale_y, shift_x, shift_y, 
                   x_off, y_off, invert, NULL);
    
    // Count non-zero pixels
    *pixel_count_out = 0;
    for (int i = 0; i < width * height; i++) {
        if (result.pixels[i] != 0) {
            (*pixel_count_out)++;
        }
    }
    
    *bitmap_out = result.pixels;
}

/*
 * Helper to free STB allocated memory
 */
void stb_free_points(stbtt__point *points) {
    STBTT_free(points, NULL);
}

void stb_free_contour_lengths(int *lengths) {
    STBTT_free(lengths, NULL);
}

void stb_free_edges(stbtt__edge *edges) {
    free(edges);
}

void stb_free_bitmap(unsigned char *bitmap) {
    free(bitmap);
}