/*
 * STB Fill Active Edges Test Wrapper
 * Exposes STB fill_active_edges function for testing against Fortran implementation
 */

#define STB_TRUETYPE_IMPLEMENTATION
#include "../thirdparty/stb_truetype.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * STB Active Edge structure (for creating test data)
 */
typedef struct stbtt__active_edge stb_active_edge_c;

/*
 * Helper function to create an STB active edge
 */
stb_active_edge_c* stb_create_active_edge(float fx, float fdx, float fdy, 
                                         float direction, float sy, float ey) {
    stb_active_edge_c* edge = (stb_active_edge_c*)malloc(sizeof(stb_active_edge_c));
    if (!edge) return NULL;
    
    edge->fx = fx;
    edge->fdx = fdx;
    edge->fdy = fdy;
    edge->direction = direction;
    edge->sy = sy;
    edge->ey = ey;
    edge->next = NULL;
    
    return edge;
}

/*
 * Helper function to create a linked list of active edges
 */
stb_active_edge_c* stb_create_active_edge_list(int count, float *fx_vals, float *fdx_vals, 
                                              float *fdy_vals, float *direction_vals,
                                              float *sy_vals, float *ey_vals) {
    if (count <= 0) return NULL;
    
    stb_active_edge_c* head = stb_create_active_edge(fx_vals[0], fdx_vals[0], fdy_vals[0],
                                                    direction_vals[0], sy_vals[0], ey_vals[0]);
    stb_active_edge_c* current = head;
    
    for (int i = 1; i < count; i++) {
        current->next = stb_create_active_edge(fx_vals[i], fdx_vals[i], fdy_vals[i],
                                              direction_vals[i], sy_vals[i], ey_vals[i]);
        current = current->next;
    }
    
    return head;
}

/*
 * Helper function to free active edge list
 */
void stb_free_active_edge_list(stb_active_edge_c* head) {
    while (head) {
        stb_active_edge_c* next = head->next;
        free(head);
        head = next;
    }
}

/*
 * Test wrapper for stbtt__fill_active_edges_new with simple interface
 */
void stb_test_fill_active_edges_simple(float *scanline, float *scanline_fill, int len, 
                                      float fx, float fdx, float fdy, float direction,
                                      float sy, float ey, float y_top) {
    stb_active_edge_c* edge = stb_create_active_edge(fx, fdx, fdy, direction, sy, ey);
    if (!edge) return;
    
    stbtt__fill_active_edges_new(scanline, scanline_fill, len, edge, y_top);
    
    stb_free_active_edge_list(edge);
}

/*
 * Test wrapper for stbtt__fill_active_edges_new with multiple edges
 */
void stb_test_fill_active_edges_multi(float *scanline, float *scanline_fill, int len, 
                                     int edge_count, float *fx_vals, float *fdx_vals, 
                                     float *fdy_vals, float *direction_vals,
                                     float *sy_vals, float *ey_vals, float y_top) {
    stb_active_edge_c* edges = stb_create_active_edge_list(edge_count, fx_vals, fdx_vals,
                                                          fdy_vals, direction_vals,
                                                          sy_vals, ey_vals);
    if (!edges) return;
    
    stbtt__fill_active_edges_new(scanline, scanline_fill, len, edges, y_top);
    
    stb_free_active_edge_list(edges);
}
