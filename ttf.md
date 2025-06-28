# TrueType Font Function Call Tree Documentation

This document maps the complete function call tree from the Fortran `fortplot_text` module through the C interface wrapper to the stb_truetype.h library functions.

## Architecture Overview

The text rendering system consists of three layers:

1. **Fortran Layer**: `fortplot_text.f90` - High-level text rendering API
2. **C Wrapper Layer**: `stb_truetype_wrapper.c` - C interface bridging Fortran and stb_truetype
3. **STB TrueType Layer**: `stb_truetype.h` - Low-level font processing and bitmap generation

## Function Call Tree

### Font Initialization

#### Fortran → C Wrapper → STB TrueType

```
fortplot_text.f90:42: stb_init_font()
  ↓
fortplot_stb_truetype.f90:142: stb_wrapper_load_font_from_file()
  ↓
stb_truetype_wrapper.c:212: stb_wrapper_load_font_from_file()
  ↓
stb_truetype_wrapper.c:53: stbtt_GetFontOffsetForIndex()    [stb_truetype.h:704]
  ↓
stb_truetype_wrapper.c:54: stbtt_InitFont()                [stb_truetype.h:733]
```

### Font Cleanup

```
fortplot_text.f90:59: stb_cleanup_font()
  ↓
fortplot_stb_truetype.f90:153: stb_wrapper_cleanup_font()
  ↓
stb_truetype_wrapper.c:72: stb_wrapper_cleanup_font()
```

### Font Scaling

```
fortplot_text.f90:43: stb_scale_for_pixel_height()
  ↓
fortplot_stb_truetype.f90:174: stb_wrapper_scale_for_pixel_height()
  ↓
stb_truetype_wrapper.c:93: stb_wrapper_scale_for_pixel_height()
  ↓
stb_truetype_wrapper.c:99: stbtt_ScaleForPixelHeight()     [stb_truetype.h:758]
```

### Text Width Calculation

```
fortplot_text.f90:83: stb_get_codepoint_hmetrics()
  ↓
fortplot_stb_truetype.f90:212: stb_wrapper_get_codepoint_hmetrics()
  ↓
stb_truetype_wrapper.c:120: stb_wrapper_get_codepoint_hmetrics()
  ↓
stb_truetype_wrapper.c:129: stbtt_GetCodepointHMetrics()   [stb_truetype.h:788]
```

### Text Height Calculation

```
fortplot_text.f90:104: stb_get_font_vmetrics()
  ↓
fortplot_stb_truetype.f90:191: stb_wrapper_get_font_vmetrics()
  ↓
stb_truetype_wrapper.c:105: stb_wrapper_get_font_vmetrics()
  ↓
stb_truetype_wrapper.c:114: stbtt_GetFontVMetrics()        [stb_truetype.h:771]
```

### Text Rendering (Main Path)

```
fortplot_text.f90:137: stb_get_codepoint_bitmap()
  ↓
fortplot_stb_truetype.f90:271: stb_wrapper_get_codepoint_bitmap()
  ↓
stb_truetype_wrapper.c:166: stb_wrapper_get_codepoint_bitmap()
  ↓
stb_truetype_wrapper.c:180: stbtt_GetCodepointBitmap()     [stb_truetype.h:874]

fortplot_text.f90:143: stb_free_bitmap()
  ↓
fortplot_stb_truetype.f90:303: stb_wrapper_free_bitmap()
  ↓
stb_truetype_wrapper.c:202: stb_wrapper_free_bitmap()
  ↓
stb_truetype_wrapper.c:204: stbtt_FreeBitmap()             [stb_truetype.h:869]

fortplot_text.f90:147: stb_get_codepoint_hmetrics()
  [Same path as Text Width Calculation above]
```

### Rotated Text Rendering

```
fortplot_text.f90:352: stb_get_codepoint_bitmap()
  [Same path as Text Rendering above]

fortplot_text.f90:358: stb_free_bitmap()
  [Same path as Text Rendering above]

fortplot_text.f90:362: stb_get_codepoint_hmetrics()
  [Same path as Text Width Calculation above]
```

## STB TrueType Functions Used

The following stb_truetype.h functions are directly used by the wrapper:

### Core Font Functions
- `stbtt_GetFontOffsetForIndex()` - Get font offset for multi-font files
- `stbtt_InitFont()` - Initialize font structure from data
- `stbtt_ScaleForPixelHeight()` - Calculate scaling factor for pixel height

### Font Metrics Functions
- `stbtt_GetFontVMetrics()` - Get vertical font metrics (ascent, descent, line gap)
- `stbtt_GetCodepointHMetrics()` - Get horizontal character metrics (advance, bearing)

### Bitmap Rendering Functions
- `stbtt_GetCodepointBitmap()` - Allocate and render character bitmap
- `stbtt_FreeBitmap()` - Free bitmap allocated by stbtt_GetCodepointBitmap()

### Additional Available Functions (not currently used)
- `stbtt_FindGlyphIndex()` - Available via wrapper but not used in fortplot_text
- `stbtt_GetCodepointBitmapBox()` - Available via wrapper but not used in fortplot_text
- `stbtt_MakeCodepointBitmap()` - Available via wrapper but not used in fortplot_text

## Key Data Structures

### Fortran Level
- `type(stb_fontinfo_t)` - Fortran wrapper for font information

### C Wrapper Level
- `stb_fontinfo_wrapper_t` - Fortran-compatible font structure
- `stb_font_context_t` - Internal structure holding actual stbtt_fontinfo and font data

### STB TrueType Level
- `stbtt_fontinfo` - Core font information structure in stb_truetype.h

## Error Handling Path

When font initialization fails:
```
fortplot_text.f90:72-77: Font initialization check
  ↓
fortplot_text.f90:125: render_simple_placeholder() [fallback rendering]
```

## Notes

- All text rendering goes through character-by-character bitmap generation
- The C wrapper manages memory allocation/deallocation for font data
- STB TrueType provides antialiased bitmap rendering with clean output
- Rotated text currently uses simple character-by-character positioning rather than true bitmap rotation