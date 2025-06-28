/*
 * STB TrueType C wrapper for Fortran integration
 * Provides simplified C interface to stb_truetype.h for fortplot_stb_truetype.f90
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define STB_TRUETYPE_IMPLEMENTATION
#include "../thirdparty/stb_truetype.h"

/* Fortran-compatible font info structure */
typedef struct {
    const unsigned char *data_ptr;
    int fontstart;
    int numGlyphs;
    void *private_data;  /* Points to actual stbtt_fontinfo */
} stb_fontinfo_wrapper_t;

/* Internal structure to hold actual stbtt_fontinfo and font data */
typedef struct {
    stbtt_fontinfo font_info;
    unsigned char *font_data;
    int data_size;
} stb_font_context_t;

/*
 * Initialize font from memory buffer
 * Returns 1 on success, 0 on failure
 */
int stb_wrapper_init_font(stb_fontinfo_wrapper_t *wrapper, const unsigned char *font_data, int data_size) {
    if (!wrapper || !font_data || data_size <= 0) {
        return 0;
    }
    
    /* Allocate context structure */
    stb_font_context_t *context = (stb_font_context_t*)malloc(sizeof(stb_font_context_t));
    if (!context) {
        return 0;
    }
    
    /* Copy font data to ensure it stays valid */
    context->font_data = (unsigned char*)malloc(data_size);
    if (!context->font_data) {
        free(context);
        return 0;
    }
    memcpy(context->font_data, font_data, data_size);
    context->data_size = data_size;
    
    /* Initialize stbtt_fontinfo */
    int offset = stbtt_GetFontOffsetForIndex(context->font_data, 0);
    if (!stbtt_InitFont(&context->font_info, context->font_data, offset)) {
        free(context->font_data);
        free(context);
        return 0;
    }
    
    /* Fill wrapper structure */
    wrapper->data_ptr = context->font_data;
    wrapper->fontstart = offset;
    wrapper->numGlyphs = context->font_info.numGlyphs;
    wrapper->private_data = context;
    
    return 1;
}

/*
 * Clean up font resources
 */
void stb_wrapper_cleanup_font(stb_fontinfo_wrapper_t *wrapper) {
    if (!wrapper || !wrapper->private_data) {
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    
    if (context->font_data) {
        free(context->font_data);
    }
    free(context);
    
    wrapper->data_ptr = NULL;
    wrapper->fontstart = 0;
    wrapper->numGlyphs = 0;
    wrapper->private_data = NULL;
}

/*
 * Calculate scale factor for desired pixel height
 */
float stb_wrapper_scale_for_pixel_height(const stb_fontinfo_wrapper_t *wrapper, float height) {
    if (!wrapper || !wrapper->private_data) {
        return 0.0f;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_ScaleForPixelHeight(&context->font_info, height);
}

/*
 * Get vertical font metrics
 */
void stb_wrapper_get_font_vmetrics(const stb_fontinfo_wrapper_t *wrapper, int *ascent, int *descent, int *line_gap) {
    if (!wrapper || !wrapper->private_data || !ascent || !descent || !line_gap) {
        if (ascent) *ascent = 0;
        if (descent) *descent = 0;
        if (line_gap) *line_gap = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetFontVMetrics(&context->font_info, ascent, descent, line_gap);
}

/*
 * Get horizontal character metrics
 */
void stb_wrapper_get_codepoint_hmetrics(const stb_fontinfo_wrapper_t *wrapper, int codepoint, 
                                       int *advance_width, int *left_side_bearing) {
    if (!wrapper || !wrapper->private_data || !advance_width || !left_side_bearing) {
        if (advance_width) *advance_width = 0;
        if (left_side_bearing) *left_side_bearing = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetCodepointHMetrics(&context->font_info, codepoint, advance_width, left_side_bearing);
}

/*
 * Find glyph index for Unicode codepoint
 */
int stb_wrapper_find_glyph_index(const stb_fontinfo_wrapper_t *wrapper, int codepoint) {
    if (!wrapper || !wrapper->private_data) {
        return 0;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_FindGlyphIndex(&context->font_info, codepoint);
}

/*
 * Get bounding box for character bitmap
 */
void stb_wrapper_get_codepoint_bitmap_box(const stb_fontinfo_wrapper_t *wrapper, int codepoint, 
                                         float scale_x, float scale_y, 
                                         int *ix0, int *iy0, int *ix1, int *iy1) {
    if (!wrapper || !wrapper->private_data || !ix0 || !iy0 || !ix1 || !iy1) {
        if (ix0) *ix0 = 0;
        if (iy0) *iy0 = 0;
        if (ix1) *ix1 = 0;
        if (iy1) *iy1 = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetCodepointBitmapBox(&context->font_info, codepoint, scale_x, scale_y, ix0, iy0, ix1, iy1);
}

/*
 * Allocate and render character bitmap with clean antialiasing
 * Returns pointer to 8-bit grayscale bitmap, must be freed with stb_wrapper_free_bitmap
 */
unsigned char* stb_wrapper_get_codepoint_bitmap(const stb_fontinfo_wrapper_t *wrapper, 
                                               float scale_x, float scale_y, int codepoint,
                                               int *width, int *height, int *xoff, int *yoff) {
    if (!wrapper || !wrapper->private_data || !width || !height || !xoff || !yoff) {
        if (width) *width = 0;
        if (height) *height = 0;
        if (xoff) *xoff = 0;
        if (yoff) *yoff = 0;
        return NULL;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    
    /* Use clean, simple antialiasing without oversampling */
    return stbtt_GetCodepointBitmap(&context->font_info, scale_x, scale_y, codepoint, width, height, xoff, yoff);
}

/*
 * Render character into provided buffer with clean antialiasing
 */
void stb_wrapper_make_codepoint_bitmap(const stb_fontinfo_wrapper_t *wrapper, unsigned char *output,
                                      int out_w, int out_h, int out_stride,
                                      float scale_x, float scale_y, int codepoint) {
    if (!wrapper || !wrapper->private_data || !output) {
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    
    /* Use clean, simple antialiasing without oversampling */
    stbtt_MakeCodepointBitmap(&context->font_info, output, out_w, out_h, out_stride, scale_x, scale_y, codepoint);
}

/*
 * Free bitmap allocated by stb_wrapper_get_codepoint_bitmap
 */
void stb_wrapper_free_bitmap(unsigned char *bitmap) {
    if (bitmap) {
        stbtt_FreeBitmap(bitmap, NULL);
    }
}

/*
 * Load font from file - utility function for Fortran integration
 * Returns 1 on success, 0 on failure
 */
int stb_wrapper_load_font_from_file(stb_fontinfo_wrapper_t *wrapper, const char *filename) {
    if (!wrapper || !filename) {
        return 0;
    }
    
    FILE *file = fopen(filename, "rb");
    if (!file) {
        return 0;
    }
    
    /* Get file size */
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    if (file_size <= 0) {
        fclose(file);
        return 0;
    }
    
    /* Read file into memory */
    unsigned char *font_data = (unsigned char*)malloc(file_size);
    if (!font_data) {
        fclose(file);
        return 0;
    }
    
    size_t bytes_read = fread(font_data, 1, file_size, file);
    fclose(file);
    
    if ((long)bytes_read != file_size) {
        free(font_data);
        return 0;
    }
    
    /* Initialize font */
    int result = stb_wrapper_init_font(wrapper, font_data, (int)file_size);
    
    /* font_data is copied inside stb_wrapper_init_font, so we can free it */
    free(font_data);
    
    return result;
}

/*
 * Get number of fonts in font file/data
 */
int stb_wrapper_get_number_of_fonts(const unsigned char *data, int data_size) {
    if (!data || data_size <= 0) {
        return 0;
    }
    
    return stbtt_GetNumberOfFonts(data);
}

/*
 * Get font offset for multi-font files
 */
int stb_wrapper_get_font_offset_for_index(const unsigned char *data, int index) {
    if (!data) {
        return -1;
    }
    
    return stbtt_GetFontOffsetForIndex(data, index);
}

/*
 * Calculate scale factor for desired em size
 */
float stb_wrapper_scale_for_mapping_em_to_pixels(const stb_fontinfo_wrapper_t *wrapper, float pixels) {
    if (!wrapper || !wrapper->private_data) {
        return 0.0f;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_ScaleForMappingEmToPixels(&context->font_info, pixels);
}

/*
 * Get font bounding box in unscaled coordinates
 */
void stb_wrapper_get_font_bounding_box(const stb_fontinfo_wrapper_t *wrapper, int *x0, int *y0, int *x1, int *y1) {
    if (!wrapper || !wrapper->private_data || !x0 || !y0 || !x1 || !y1) {
        if (x0) *x0 = 0;
        if (y0) *y0 = 0;
        if (x1) *x1 = 0;
        if (y1) *y1 = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetFontBoundingBox(&context->font_info, x0, y0, x1, y1);
}

/*
 * Get character bounding box in unscaled coordinates
 */
void stb_wrapper_get_codepoint_box(const stb_fontinfo_wrapper_t *wrapper, int codepoint, int *x0, int *y0, int *x1, int *y1) {
    if (!wrapper || !wrapper->private_data || !x0 || !y0 || !x1 || !y1) {
        if (x0) *x0 = 0;
        if (y0) *y0 = 0;
        if (x1) *x1 = 0;
        if (y1) *y1 = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetCodepointBox(&context->font_info, codepoint, x0, y0, x1, y1);
}

/*
 * Get kerning advance between two characters
 */
int stb_wrapper_get_codepoint_kern_advance(const stb_fontinfo_wrapper_t *wrapper, int ch1, int ch2) {
    if (!wrapper || !wrapper->private_data) {
        return 0;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_GetCodepointKernAdvance(&context->font_info, ch1, ch2);
}

/*
 * Get OS/2 table vertical metrics
 */
void stb_wrapper_get_font_vmetrics_os2(const stb_fontinfo_wrapper_t *wrapper, 
                                       int *typoAscent, int *typoDescent, int *typoLineGap) {
    if (!wrapper || !wrapper->private_data || !typoAscent || !typoDescent || !typoLineGap) {
        if (typoAscent) *typoAscent = 0;
        if (typoDescent) *typoDescent = 0;
        if (typoLineGap) *typoLineGap = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetFontVMetricsOS2(&context->font_info, typoAscent, typoDescent, typoLineGap);
}

/*
 * Get horizontal glyph metrics by glyph index
 */
void stb_wrapper_get_glyph_hmetrics(const stb_fontinfo_wrapper_t *wrapper, int glyph_index,
                                   int *advanceWidth, int *leftSideBearing) {
    if (!wrapper || !wrapper->private_data || !advanceWidth || !leftSideBearing) {
        if (advanceWidth) *advanceWidth = 0;
        if (leftSideBearing) *leftSideBearing = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetGlyphHMetrics(&context->font_info, glyph_index, advanceWidth, leftSideBearing);
}

/*
 * Get glyph bounding box by glyph index
 */
void stb_wrapper_get_glyph_box(const stb_fontinfo_wrapper_t *wrapper, int glyph_index,
                              int *x0, int *y0, int *x1, int *y1) {
    if (!wrapper || !wrapper->private_data || !x0 || !y0 || !x1 || !y1) {
        if (x0) *x0 = 0;
        if (y0) *y0 = 0;
        if (x1) *x1 = 0;
        if (y1) *y1 = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetGlyphBox(&context->font_info, glyph_index, x0, y0, x1, y1);
}

/*
 * Get kerning advance between two glyphs by glyph indices
 */
int stb_wrapper_get_glyph_kern_advance(const stb_fontinfo_wrapper_t *wrapper, int glyph1, int glyph2) {
    if (!wrapper || !wrapper->private_data) {
        return 0;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_GetGlyphKernAdvance(&context->font_info, glyph1, glyph2);
}

/*
 * Get length of kerning table
 */
int stb_wrapper_get_kerning_table_length(const stb_fontinfo_wrapper_t *wrapper) {
    if (!wrapper || !wrapper->private_data) {
        return 0;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_GetKerningTableLength(&context->font_info);
}

/*
 * Get kerning table entries
 */
int stb_wrapper_get_kerning_table(const stb_fontinfo_wrapper_t *wrapper, 
                                 void *table, int table_length) {
    if (!wrapper || !wrapper->private_data || !table || table_length <= 0) {
        return 0;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_GetKerningTable(&context->font_info, (stbtt_kerningentry*)table, table_length);
}

/*
 * Allocate and render glyph bitmap by glyph index
 */
unsigned char* stb_wrapper_get_glyph_bitmap(const stb_fontinfo_wrapper_t *wrapper, 
                                           float scale_x, float scale_y, int glyph,
                                           int *width, int *height, int *xoff, int *yoff) {
    if (!wrapper || !wrapper->private_data || !width || !height || !xoff || !yoff) {
        if (width) *width = 0;
        if (height) *height = 0;
        if (xoff) *xoff = 0;
        if (yoff) *yoff = 0;
        return NULL;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_GetGlyphBitmap(&context->font_info, scale_x, scale_y, glyph, width, height, xoff, yoff);
}

/*
 * Get bounding box for glyph bitmap
 */
void stb_wrapper_get_glyph_bitmap_box(const stb_fontinfo_wrapper_t *wrapper, int glyph, 
                                     float scale_x, float scale_y, 
                                     int *ix0, int *iy0, int *ix1, int *iy1) {
    if (!wrapper || !wrapper->private_data || !ix0 || !iy0 || !ix1 || !iy1) {
        if (ix0) *ix0 = 0;
        if (iy0) *iy0 = 0;
        if (ix1) *ix1 = 0;
        if (iy1) *iy1 = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetGlyphBitmapBox(&context->font_info, glyph, scale_x, scale_y, ix0, iy0, ix1, iy1);
}

/*
 * Allocate and render character bitmap with subpixel positioning
 */
unsigned char* stb_wrapper_get_codepoint_bitmap_subpixel(const stb_fontinfo_wrapper_t *wrapper, 
                                                        float scale_x, float scale_y, 
                                                        float shift_x, float shift_y, int codepoint,
                                                        int *width, int *height, int *xoff, int *yoff) {
    if (!wrapper || !wrapper->private_data || !width || !height || !xoff || !yoff) {
        if (width) *width = 0;
        if (height) *height = 0;
        if (xoff) *xoff = 0;
        if (yoff) *yoff = 0;
        return NULL;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_GetCodepointBitmapSubpixel(&context->font_info, scale_x, scale_y, shift_x, shift_y, 
                                           codepoint, width, height, xoff, yoff);
}

/*
 * Render glyph into provided buffer
 */
void stb_wrapper_make_glyph_bitmap(const stb_fontinfo_wrapper_t *wrapper, unsigned char *output,
                                  int out_w, int out_h, int out_stride,
                                  float scale_x, float scale_y, int glyph) {
    if (!wrapper || !wrapper->private_data || !output) {
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_MakeGlyphBitmap(&context->font_info, output, out_w, out_h, out_stride, scale_x, scale_y, glyph);
}

/*
 * Allocate and render glyph bitmap with subpixel positioning
 */
unsigned char* stb_wrapper_get_glyph_bitmap_subpixel(const stb_fontinfo_wrapper_t *wrapper, 
                                                    float scale_x, float scale_y, 
                                                    float shift_x, float shift_y, int glyph,
                                                    int *width, int *height, int *xoff, int *yoff) {
    if (!wrapper || !wrapper->private_data || !width || !height || !xoff || !yoff) {
        if (width) *width = 0;
        if (height) *height = 0;
        if (xoff) *xoff = 0;
        if (yoff) *yoff = 0;
        return NULL;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    return stbtt_GetGlyphBitmapSubpixel(&context->font_info, scale_x, scale_y, shift_x, shift_y, 
                                       glyph, width, height, xoff, yoff);
}

/*
 * Render glyph into provided buffer with subpixel positioning
 */
void stb_wrapper_make_glyph_bitmap_subpixel(const stb_fontinfo_wrapper_t *wrapper, 
                                           unsigned char *output,
                                           int out_w, int out_h, int out_stride,
                                           float scale_x, float scale_y, 
                                           float shift_x, float shift_y, int glyph) {
    if (!wrapper || !wrapper->private_data || !output) {
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_MakeGlyphBitmapSubpixel(&context->font_info, output, out_w, out_h, out_stride, 
                                 scale_x, scale_y, shift_x, shift_y, glyph);
}

/*
 * Render character into provided buffer with subpixel positioning
 */
void stb_wrapper_make_codepoint_bitmap_subpixel(const stb_fontinfo_wrapper_t *wrapper, 
                                               unsigned char *output,
                                               int out_w, int out_h, int out_stride,
                                               float scale_x, float scale_y, 
                                               float shift_x, float shift_y, int codepoint) {
    if (!wrapper || !wrapper->private_data || !output) {
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_MakeCodepointBitmapSubpixel(&context->font_info, output, out_w, out_h, out_stride, 
                                     scale_x, scale_y, shift_x, shift_y, codepoint);
}

/*
 * Get bounding box for glyph bitmap with subpixel positioning
 */
void stb_wrapper_get_glyph_bitmap_box_subpixel(const stb_fontinfo_wrapper_t *wrapper, int glyph, 
                                              float scale_x, float scale_y, 
                                              float shift_x, float shift_y,
                                              int *ix0, int *iy0, int *ix1, int *iy1) {
    if (!wrapper || !wrapper->private_data || !ix0 || !iy0 || !ix1 || !iy1) {
        if (ix0) *ix0 = 0;
        if (iy0) *iy0 = 0;
        if (ix1) *ix1 = 0;
        if (iy1) *iy1 = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetGlyphBitmapBoxSubpixel(&context->font_info, glyph, scale_x, scale_y, 
                                   shift_x, shift_y, ix0, iy0, ix1, iy1);
}

/*
 * Get bounding box for character bitmap with subpixel positioning
 */
void stb_wrapper_get_codepoint_bitmap_box_subpixel(const stb_fontinfo_wrapper_t *wrapper, int codepoint, 
                                                  float scale_x, float scale_y, 
                                                  float shift_x, float shift_y,
                                                  int *ix0, int *iy0, int *ix1, int *iy1) {
    if (!wrapper || !wrapper->private_data || !ix0 || !iy0 || !ix1 || !iy1) {
        if (ix0) *ix0 = 0;
        if (iy0) *iy0 = 0;
        if (ix1) *ix1 = 0;
        if (iy1) *iy1 = 0;
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_GetCodepointBitmapBoxSubpixel(&context->font_info, codepoint, scale_x, scale_y, 
                                       shift_x, shift_y, ix0, iy0, ix1, iy1);
}

/*
 * Render character into provided buffer with subpixel positioning and prefiltering
 */
void stb_wrapper_make_codepoint_bitmap_subpixel_prefilter(const stb_fontinfo_wrapper_t *wrapper, 
                                                         unsigned char *output,
                                                         int out_w, int out_h, int out_stride,
                                                         float scale_x, float scale_y, 
                                                         float shift_x, float shift_y,
                                                         int oversample_x, int oversample_y,
                                                         float sub_x, float sub_y, int codepoint) {
    if (!wrapper || !wrapper->private_data || !output) {
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_MakeCodepointBitmapSubpixelPrefilter(&context->font_info, output, out_w, out_h, out_stride, 
                                              scale_x, scale_y, shift_x, shift_y,
                                              oversample_x, oversample_y, &sub_x, &sub_y, codepoint);
}

/*
 * Render glyph into provided buffer with subpixel positioning and prefiltering
 */
void stb_wrapper_make_glyph_bitmap_subpixel_prefilter(const stb_fontinfo_wrapper_t *wrapper, 
                                                     unsigned char *output,
                                                     int out_w, int out_h, int out_stride,
                                                     float scale_x, float scale_y, 
                                                     float shift_x, float shift_y,
                                                     int oversample_x, int oversample_y,
                                                     float sub_x, float sub_y, int glyph) {
    if (!wrapper || !wrapper->private_data || !output) {
        return;
    }
    
    stb_font_context_t *context = (stb_font_context_t*)wrapper->private_data;
    stbtt_MakeGlyphBitmapSubpixelPrefilter(&context->font_info, output, out_w, out_h, out_stride, 
                                          scale_x, scale_y, shift_x, shift_y,
                                          oversample_x, oversample_y, &sub_x, &sub_y, glyph);
}