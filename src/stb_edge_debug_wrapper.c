// C wrapper to call actual STB functions for debugging edge processing
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_RASTERIZER_VERSION 2
#include "../thirdparty/stb_truetype.h"

// Test the exact problematic edge with actual STB functions
void test_stb_edge_processing(float fx, float fdx, float fdy, float direction,
                             float sy, float ey, float y_top, float y_bottom)
{
    printf("=== STB C DIRECT TEST ===\n");
    printf("Testing exact problematic edge with actual STB functions\n\n");
    
    // Create STB active edge structure
    stbtt__active_edge edge;
    edge.fx = fx;
    edge.fdx = fdx;
    edge.fdy = fdy;
    edge.direction = direction;
    edge.sy = sy;
    edge.ey = ey;
    edge.next = NULL;
    
    printf("Edge parameters:\n");
    printf("  fx=%.6f, fdx=%.6f, fdy=%.6f\n", fx, fdx, fdy);
    printf("  direction=%.6f, sy=%.6f, ey=%.6f\n", direction, sy, ey);
    printf("  y_top=%.6f, y_bottom=%.6f\n\n", y_top, y_bottom);
    
    // Create scanline buffers (like STB does)
    int width = 20;
    float scanline[20];
    float scanline_fill[21];  // scanline2 = scanline + width
    
    // Initialize buffers to zero
    memset(scanline, 0, sizeof(scanline));
    memset(scanline_fill, 0, sizeof(scanline_fill));
    
    printf("Calling stbtt__fill_active_edges_new...\n");
    
    // Call the actual STB function
    stbtt__fill_active_edges_new(scanline, scanline_fill, width, &edge, y_top);
    
    printf("STB Results:\n");
    for (int i = 0; i < width; i++) {
        if (fabs(scanline[i]) > 1e-10 || fabs(scanline_fill[i]) > 1e-10) {
            printf("Col %2d: scanline=%12.6f fill=%12.6f\n", i, scanline[i], scanline_fill[i]);
        }
    }
    
    // Focus on column 8 and simulate final accumulation
    printf("\nCRITICAL ANALYSIS: Column 8\n");
    
    float sum = 0.0f;
    for (int i = 0; i <= 8; i++) {
        sum += scanline_fill[i];
    }
    
    float k = scanline[8] + sum;
    int final_pixel = (int)(fabs(k) * 255.0f + 0.5f);
    if (final_pixel > 255) final_pixel = 255;
    
    printf("STB scanline[8] = %12.6f\n", scanline[8]);
    printf("STB fill_sum    = %12.6f\n", sum);
    printf("STB k_val       = %12.6f\n", k);
    printf("STB final       = %d\n", final_pixel);
    printf("Expected final  = 114\n\n");
    
    printf("COMPARISON:\n");
    printf("ForTTF k = -1.175017 (produces final=299)\n");
    printf("STB    k = %8.6f (produces final=%d)\n", k, final_pixel);
    printf("Difference = %8.6f\n", fabs(k - (-1.175017f)));
}

// Fortran-callable wrapper
void stb_edge_debug_c(float *fx, float *fdx, float *fdy, float *direction,
                      float *sy, float *ey, float *y_top, float *y_bottom)
{
    test_stb_edge_processing(*fx, *fdx, *fdy, *direction, *sy, *ey, *y_top, *y_bottom);
}