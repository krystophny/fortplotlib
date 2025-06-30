// Custom STB wrapper to debug exact edge processing for character '$'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_TRUETYPE_IMPLEMENTATION
#define STBTT_RASTERIZER_VERSION 2

// Enable debug output in STB
#define STBTT_DEBUG_RASTERIZATION 1

#include "../thirdparty/stb_truetype.h"

// Debug wrapper to capture STB edge processing
void debug_stb_dollar_character() {
    printf("=== STB DEBUG: Character '$' Processing ===\n");
    
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
    
    printf("Rendering character '$' (codepoint=%d) at scale=%f\n", codepoint, scale);
    printf("Bitmap size: %dx%d\n\n", width, height);
    
    // Get glyph and bitmap info
    int glyph_index = stbtt_FindGlyphIndex(&font, codepoint);
    int x0, y0, x1, y1;
    stbtt_GetGlyphBitmapBox(&font, glyph_index, scale, scale, &x0, &y0, &x1, &y1);
    
    printf("Glyph %d bounding box: (%d,%d) to (%d,%d)\n", glyph_index, x0, y0, x1, y1);
    printf("Bitmap offset: (%d,%d)\n\n", x0, y0);
    
    // Allocate bitmap and generate
    unsigned char *bitmap = calloc(width * height, 1);
    
    printf("=== STB BITMAP GENERATION ===\n");
    stbtt_MakeGlyphBitmap(&font, bitmap, width, height, width, scale, scale, glyph_index);
    
    // Check Row 5, Col 8 result
    int pixel_index = 5 * width + 8;
    unsigned char pixel_value = bitmap[pixel_index];
    
    printf("STB Result: Row 5, Col 8 = %d\n", pixel_value);
    printf("Expected: 114\n");
    printf("Match: %s\n\n", (pixel_value == 114) ? "YES" : "NO");
    
    // Show context
    printf("3x3 context around Row 5, Col 8:\n");
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int r = 5 + dy;
            int c = 8 + dx;
            if (r >= 0 && r < height && c >= 0 && c < width) {
                int idx = r * width + c;
                printf("%3d ", bitmap[idx]);
            } else {
                printf("--- ");
            }
        }
        printf("\n");
    }
    
    free(bitmap);
    free(font_data);
}

// Fortran-callable wrapper
void stb_debug_dollar_c() {
    debug_stb_dollar_character();
}