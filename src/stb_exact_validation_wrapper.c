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
 * Fortran ttf_vertex_t structure (must match forttf_types.f90)
 */
typedef struct {
    int x, y;           // Primary coordinates  
    int cx, cy;         // Control point 1
    int cx1, cy1;       // Control point 2  
    int type;           // Vertex type
} fortran_vertex_t;

/*
 * Convert Fortran vertices to STB format
 */
static stbtt_vertex* convert_fortran_to_stb_vertices(fortran_vertex_t *fortran_verts, int num_verts) {
    stbtt_vertex *stb_verts = malloc(num_verts * sizeof(stbtt_vertex));
    if (!stb_verts) return NULL;
    
    for (int i = 0; i < num_verts; i++) {
        stb_verts[i].x = (short)fortran_verts[i].x;
        stb_verts[i].y = (short)fortran_verts[i].y;
        stb_verts[i].cx = (short)fortran_verts[i].cx;
        stb_verts[i].cy = (short)fortran_verts[i].cy;
        stb_verts[i].cx1 = (short)fortran_verts[i].cx1;
        stb_verts[i].cy1 = (short)fortran_verts[i].cy1;
        stb_verts[i].type = (unsigned char)fortran_verts[i].type;
        stb_verts[i].padding = 0;
    }
    
    return stb_verts;
}

/*
 * Test wrapper for stbtt_FlattenCurves
 */
void stb_test_flatten_curves_exact(fortran_vertex_t *fortran_vertices, int num_verts, float flatness,
                                  stbtt__point **points_out, int **contour_lengths_out, 
                                  int *num_contours_out, int *total_points_out) {
    // Convert Fortran vertices to STB format
    stbtt_vertex *stb_vertices = convert_fortran_to_stb_vertices(fortran_vertices, num_verts);
    if (!stb_vertices) {
        *points_out = NULL;
        *contour_lengths_out = NULL;
        *num_contours_out = 0;
        *total_points_out = 0;
        return;
    }
    
    stbtt__point *points = stbtt_FlattenCurves(stb_vertices, num_verts, flatness, 
                                              contour_lengths_out, num_contours_out, NULL);
    *points_out = points;
    
    // Count total points
    *total_points_out = 0;
    for (int i = 0; i < *num_contours_out; i++) {
        *total_points_out += (*contour_lengths_out)[i];
    }
    
    free(stb_vertices);
}

/*
 * Debug wrapper for stbtt_FlattenCurves - same as test version but different name
 */
void stb_debug_flatten_curves(fortran_vertex_t *fortran_vertices, int num_verts, float flatness,
                             stbtt__point **points_out, int **contour_lengths_out, 
                             int *num_contours_out, int *total_points_out) {
    // Convert Fortran vertices to STB format
    stbtt_vertex *stb_vertices = convert_fortran_to_stb_vertices(fortran_vertices, num_verts);
    if (!stb_vertices) {
        *points_out = NULL;
        *contour_lengths_out = NULL;
        *num_contours_out = 0;
        *total_points_out = 0;
        return;
    }
    
    stbtt__point *points = stbtt_FlattenCurves(stb_vertices, num_verts, flatness, 
                                              contour_lengths_out, num_contours_out, NULL);
    *points_out = points;
    
    // Count total points
    *total_points_out = 0;
    for (int i = 0; i < *num_contours_out; i++) {
        *total_points_out += (*contour_lengths_out)[i];
    }
    
    free(stb_vertices);
}

/*
 * Forward declarations
 */
void stb_test_build_edges_exact(stbtt__point *pts, int *wcount, int windings,
                               float scale_x, float scale_y, float shift_x, float shift_y, 
                               int invert, stbtt__edge **edges_out, int *num_edges_out);

/*
 * Fortran double-precision point structure (must match forttf_types.f90)
 */
typedef struct {
    double x, y;
} fortran_point_t;

/*
 * Fortran double-precision edge structure (must match forttf_types.f90)
 */
typedef struct {
    double x0, y0, x1, y1;
    int invert;
} fortran_edge_t;

/*
 * Convert Fortran double-precision points to STB single-precision points
 */
static stbtt__point* convert_fortran_points_to_stb(fortran_point_t *fortran_points, int num_points) {
    stbtt__point *stb_points = malloc(num_points * sizeof(stbtt__point));
    if (!stb_points) return NULL;
    
    for (int i = 0; i < num_points; i++) {
        stb_points[i].x = (float)fortran_points[i].x;
        stb_points[i].y = (float)fortran_points[i].y;
    }
    
    return stb_points;
}

/*
 * Convert STB single-precision edges to Fortran double-precision edges
 */
static fortran_edge_t* convert_stb_edges_to_fortran(stbtt__edge *stb_edges, int num_edges) {
    fortran_edge_t *fortran_edges = malloc(num_edges * sizeof(fortran_edge_t));
    if (!fortran_edges) return NULL;
    
    for (int i = 0; i < num_edges; i++) {
        fortran_edges[i].x0 = (double)stb_edges[i].x0;
        fortran_edges[i].y0 = (double)stb_edges[i].y0;
        fortran_edges[i].x1 = (double)stb_edges[i].x1;
        fortran_edges[i].y1 = (double)stb_edges[i].y1;
        fortran_edges[i].invert = stb_edges[i].invert;
    }
    
    return fortran_edges;
}

/*
 * Test wrapper for edge building from Fortran double-precision points
 * Returns Fortran-compatible edge data
 */
void stb_test_build_edges_from_fortran_points(fortran_point_t *fortran_pts, int *wcount, int windings,
                                             float scale_x, float scale_y, float shift_x, float shift_y, 
                                             int invert, fortran_edge_t **edges_out, int *num_edges_out) {
    // Count total points
    int total_points = 0;
    for (int i = 0; i < windings; i++) {
        total_points += wcount[i];
    }
    
    // Convert Fortran points to STB format
    stbtt__point *stb_pts = convert_fortran_points_to_stb(fortran_pts, total_points);
    if (!stb_pts) {
        *edges_out = NULL;
        *num_edges_out = 0;
        return;
    }
    
    // Call the existing STB edge building function
    stbtt__edge *stb_edges;
    stb_test_build_edges_exact(stb_pts, wcount, windings, scale_x, scale_y, shift_x, shift_y, 
                              invert, &stb_edges, num_edges_out);
    
    // Convert STB edges to Fortran format
    if (*num_edges_out > 0 && stb_edges) {
        *edges_out = convert_stb_edges_to_fortran(stb_edges, *num_edges_out);
        free(stb_edges);  // Free original STB edges
    } else {
        *edges_out = NULL;
    }
    
    // Clean up converted points
    free(stb_pts);
}

/*
 * C-compatible wrapper for Fortran interface (returns void* instead of fortran_edge_t**)
 */
void stb_test_build_edges_from_fortran_points_c(fortran_point_t *fortran_pts, int *wcount, int windings,
                                               float scale_x, float scale_y, float shift_x, float shift_y, 
                                               int invert, void **edges_out, int *num_edges_out) {
    fortran_edge_t *fortran_edges;
    stb_test_build_edges_from_fortran_points(fortran_pts, wcount, windings, 
                                            scale_x, scale_y, shift_x, shift_y, 
                                            invert, &fortran_edges, num_edges_out);
    *edges_out = (void*)fortran_edges;
}

/*
 * Test wrapper for edge building from stbtt__rasterize 
 */
void stb_test_build_edges_exact(stbtt__point *pts, int *wcount, int windings,
                               float scale_x, float scale_y, float shift_x, float shift_y, 
                               int invert, stbtt__edge **edges_out, int *num_edges_out) {
    float y_scale_inv = invert ? -scale_y : scale_y;
    int vsubsample = 1;  // STBTT_RASTERIZER_VERSION == 2
    
    printf("STB C: Input parameters: scale=(%.6f,%.6f) shift=(%.6f,%.6f) invert=%d\n", 
           scale_x, scale_y, shift_x, shift_y, invert);
    
    // Count edges needed (skip horizontal)
    int n = 0;
    int m = 0;
    printf("STB C: Counting edges...\n");
    for (int i = 0; i < windings; ++i) {
        stbtt__point *p = pts + m;
        m += wcount[i];
        int j = wcount[i] - 1;
        printf("  Contour %d: length=%d\n", i+1, wcount[i]);
        for (int k = 0; k < wcount[i]; j = k++) {
            printf("    Candidate k=%d j=%d: (%.2f,%.2f) -> (%.2f,%.2f)\n", 
                   k, j, p[j].x, p[j].y, p[k].x, p[k].y);
            if (p[j].y != p[k].y) {  // Skip horizontal edges
                n++;
                printf("      ADDED: Edge %d\n", n);
            } else {
                printf("      SKIPPED: Horizontal edge (dy = %.6f)\n", p[k].y - p[j].y);
            }
        }
    }
    printf("  Total edges after filtering: %d\n", n);
    
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
void stb_test_complete_rasterize_exact(fortran_vertex_t *fortran_vertices, int num_verts,
                                      float scale_x, float scale_y, float shift_x, float shift_y,
                                      int width, int height, int x_off, int y_off, int invert,
                                      unsigned char **bitmap_out, int *pixel_count_out) {
    // Convert Fortran vertices to STB format
    stbtt_vertex *stb_vertices = convert_fortran_to_stb_vertices(fortran_vertices, num_verts);
    if (!stb_vertices) {
        *bitmap_out = NULL;
        *pixel_count_out = 0;
        return;
    }
    
    stbtt__bitmap result;
    result.w = width;
    result.h = height;
    result.stride = width;
    result.pixels = (unsigned char *)malloc(width * height);
    memset(result.pixels, 0, width * height);
    
    // Call STB rasterization
    stbtt_Rasterize(&result, 0.35f, stb_vertices, num_verts, 
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
    free(stb_vertices);
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

void stb_free_fortran_edges(fortran_edge_t *edges) {
    free(edges);
}

void stb_free_bitmap(unsigned char *bitmap) {
    free(bitmap);
}