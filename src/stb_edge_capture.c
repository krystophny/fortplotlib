// Capture STB's actual edge parameters for character '$' Row 5 Col 8
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_RASTERIZER_VERSION 2

// Inject debug into STB by modifying the source temporarily
#define STBTT_DEBUG_EDGE_PROCESSING 1

#include "../thirdparty/stb_truetype.h"

// Hook into STB edge processing
void debug_stb_edge_parameters() {
    printf("=== STB EDGE PARAMETER CAPTURE ===\n");
    
    // Load font
    FILE *font_file = fopen("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "rb");
    if (!font_file) {
        printf("ERROR: Cannot open font file\n");
        return;
    }
    
    fseek(font_file, 0, SEEK_END);
    long font_size = ftell(font_file);
    fseek(font_file, 0, SEEK_SET);
    
    unsigned char *font_data = malloc(font_size);
    fread(font_data, 1, font_size, font_file);
    fclose(font_file);
    
    stbtt_fontinfo font;
    if (!stbtt_InitFont(&font, font_data, 0)) {
        printf("ERROR: Cannot initialize font\n");
        free(font_data);
        return;
    }
    
    // Character '$' parameters
    int codepoint = 36;
    float scale = 0.02f;
    int width = 20, height = 39;
    
    printf("Capturing STB edge parameters for character '$' (codepoint=%d) at scale=%f\n", codepoint, scale);
    printf("Focus: Row 5, Col 8 where STB produces 114\n\n");
    
    // Generate bitmap to trigger edge processing
    unsigned char *bitmap = calloc(width * height, 1);
    
    int glyph_index = stbtt_FindGlyphIndex(&font, codepoint);
    stbtt_MakeGlyphBitmap(&font, bitmap, width, height, width, scale, scale, glyph_index);
    
    // Check result
    int pixel_index = 5 * width + 8;
    unsigned char pixel_value = bitmap[pixel_index];
    
    printf("STB Result Verification: Row 5, Col 8 = %d\n", pixel_value);
    printf("Expected: 114, Match: %s\n\n", (pixel_value == 114) ? "YES" : "NO");
    
    printf("STB edge parameters should be captured above during bitmap generation.\n");
    printf("Compare these parameters with ForTTF debug output.\n");
    
    free(bitmap);
    free(font_data);
}

// Fortran-callable wrapper
void stb_edge_capture_c() {
    debug_stb_edge_parameters();
}