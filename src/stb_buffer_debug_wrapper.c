// STB scanline buffer debug wrapper to capture exact buffer values
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_TRUETYPE_IMPLEMENTATION  
#include "../thirdparty/stb_truetype.h"

// Hook into STB's scanline processing to capture buffer values
static float *debug_scanline = NULL;
static float *debug_scanline2 = NULL;
static int debug_width = 0;
static int debug_current_y = 0;

// Function to capture STB's scanline buffer values for comparison
void stb_debug_capture_buffers(unsigned char* font_data, int glyph_index, 
                              float scale_x, float scale_y,
                              int width, int height, 
                              int xoff, int yoff) {
    stbtt_fontinfo font;
    stbtt_InitFont(&font, font_data, stbtt_GetFontOffsetForIndex(font_data, 0));
    
    // Allocate debug buffers
    debug_width = width;
    debug_scanline = (float*)malloc(width * sizeof(float));
    debug_scanline2 = (float*)malloc(width * sizeof(float));
    
    printf("=== STB BUFFER DEBUG START ===\n");
    printf("Glyph: %d, Scale: %.6f, %.6f\n", glyph_index, scale_x, scale_y);
    printf("Bitmap: %dx%d, Offset: %d,%d\n", width, height, xoff, yoff);
    
    // Create bitmap with debug hooks
    unsigned char *bitmap = (unsigned char*)calloc(width * height, 1);
    
    // Call STB's rasterization (this will trigger our hooks if we modify STB)
    stbtt_MakeGlyphBitmap(&font, bitmap, width, height, width, 
                         scale_x, scale_y, glyph_index);
    
    // For now, let's just show what we can capture without modifying STB
    printf("=== STB BUFFER DEBUG - Would need STB modification to capture internal buffers ===\n");
    
    // Show first few pixels of final bitmap for comparison
    printf("STB Final Bitmap (first row):\n");
    for (int i = 0; i < (width < 20 ? width : 20); i++) {
        printf("%3d ", bitmap[i]);
    }
    printf("\n");
    
    free(bitmap);
    free(debug_scanline);
    free(debug_scanline2);
}

// Alternative: Extract STB's rasterization parameters for exact comparison
void stb_debug_rasterization_params(unsigned char* font_data, int glyph_index,
                                   float scale_x, float scale_y) {
    stbtt_fontinfo font;
    stbtt_InitFont(&font, font_data, stbtt_GetFontOffsetForIndex(font_data, 0));
    
    // Get the exact same parameters STB uses
    int ix0, iy0, ix1, iy1;
    stbtt_GetGlyphBitmapBox(&font, glyph_index, scale_x, scale_y, &ix0, &iy0, &ix1, &iy1);
    
    printf("=== STB RASTERIZATION PARAMETERS ===\n");
    printf("Glyph %d bitmap box: (%d,%d) to (%d,%d)\n", glyph_index, ix0, iy0, ix1, iy1);
    printf("Dimensions: %dx%d\n", ix1-ix0, iy1-iy0);
    
    // Get vertex data
    stbtt_vertex *vertices;
    int num_verts = stbtt_GetGlyphShape(&font, glyph_index, &vertices);
    printf("Vertices: %d\n", num_verts);
    
    for (int i = 0; i < (num_verts < 10 ? num_verts : 10); i++) {
        printf("Vertex %d: type=%d, x=%d, y=%d, cx=%d, cy=%d\n", 
               i, vertices[i].type, vertices[i].x, vertices[i].y, 
               vertices[i].cx, vertices[i].cy);
    }
    
    stbtt_FreeShape(&font, vertices);
}