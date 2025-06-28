# STB TrueType Fortran Interface Implementation TODO

This TODO list tracks the implementation of Fortran ISO C wrappers for all stb_truetype.h functions documented in `ttf.md`, and the creation of a new `fortplot_stb` module for potential pure Fortran implementation.

## Status: Current Implementation

### ✅ Already Implemented in `fortplot_stb_truetype.f90`

**Core Font Functions:**
- [x] `stbtt_GetFontOffsetForIndex()` → `stb_wrapper_load_font_from_file()`
- [x] `stbtt_InitFont()` → `stb_wrapper_init_font()` + `stb_init_font()`
- [x] `stbtt_ScaleForPixelHeight()` → `stb_wrapper_scale_for_pixel_height()` + `stb_scale_for_pixel_height()`

**Font Metrics Functions:**
- [x] `stbtt_GetFontVMetrics()` → `stb_wrapper_get_font_vmetrics()` + `stb_get_font_vmetrics()`
- [x] `stbtt_GetCodepointHMetrics()` → `stb_wrapper_get_codepoint_hmetrics()` + `stb_get_codepoint_hmetrics()`

**Bitmap Rendering Functions:**
- [x] `stbtt_GetCodepointBitmap()` → `stb_wrapper_get_codepoint_bitmap()` + `stb_get_codepoint_bitmap()`
- [x] `stbtt_FreeBitmap()` → `stb_wrapper_free_bitmap()` + `stb_free_bitmap()`

**Additional Functions (Available but unused):**
- [x] `stbtt_FindGlyphIndex()` → `stb_wrapper_find_glyph_index()` + `stb_find_glyph_index()`
- [x] `stbtt_GetCodepointBitmapBox()` → `stb_wrapper_get_codepoint_bitmap_box()` + `stb_get_codepoint_bitmap_box()`
- [x] `stbtt_MakeCodepointBitmap()` → `stb_wrapper_make_codepoint_bitmap()` + `stb_make_codepoint_bitmap()`

## TODO: Missing Fortran ISO C Wrappers

### 🔲 Functions to Add to `fortplot_stb_truetype.f90`

**Additional Core Functions:**
- [ ] `stbtt_GetNumberOfFonts()` → Add `stb_get_number_of_fonts()`
- [ ] `stbtt_GetFontOffsetForIndex()` → Add direct wrapper `stb_get_font_offset_for_index()`

**Extended Font Metrics:**
- [ ] `stbtt_ScaleForMappingEmToPixels()` → Add `stb_scale_for_mapping_em_to_pixels()`
- [ ] `stbtt_GetFontVMetricsOS2()` → Add `stb_get_font_vmetrics_os2()`
- [ ] `stbtt_GetFontBoundingBox()` → Add `stb_get_font_bounding_box()`

**Glyph-level Functions:**
- [ ] `stbtt_GetGlyphHMetrics()` → Add `stb_get_glyph_hmetrics()`
- [ ] `stbtt_GetGlyphBox()` → Add `stb_get_glyph_box()`
- [ ] `stbtt_GetCodepointBox()` → Add `stb_get_codepoint_box()`

**Kerning Functions:**
- [ ] `stbtt_GetCodepointKernAdvance()` → Add `stb_get_codepoint_kern_advance()`
- [ ] `stbtt_GetGlyphKernAdvance()` → Add `stb_get_glyph_kern_advance()`
- [ ] `stbtt_GetKerningTableLength()` → Add `stb_get_kerning_table_length()`
- [ ] `stbtt_GetKerningTable()` → Add `stb_get_kerning_table()`

**Advanced Bitmap Functions:**
- [ ] `stbtt_GetGlyphBitmap()` → Add `stb_get_glyph_bitmap()`
- [ ] `stbtt_GetGlyphBitmapSubpixel()` → Add `stb_get_glyph_bitmap_subpixel()`
- [ ] `stbtt_GetCodepointBitmapSubpixel()` → Add `stb_get_codepoint_bitmap_subpixel()`
- [ ] `stbtt_MakeGlyphBitmap()` → Add `stb_make_glyph_bitmap()`
- [ ] `stbtt_MakeGlyphBitmapSubpixel()` → Add `stb_make_glyph_bitmap_subpixel()`
- [ ] `stbtt_MakeCodepointBitmapSubpixel()` → Add `stb_make_codepoint_bitmap_subpixel()`
- [ ] `stbtt_GetGlyphBitmapBox()` → Add `stb_get_glyph_bitmap_box()`
- [ ] `stbtt_GetGlyphBitmapBoxSubpixel()` → Add `stb_get_glyph_bitmap_box_subpixel()`
- [ ] `stbtt_GetCodepointBitmapBoxSubpixel()` → Add `stb_get_codepoint_bitmap_box_subpixel()`

**Prefiltered Rendering:**
- [ ] `stbtt_MakeCodepointBitmapSubpixelPrefilter()` → Add `stb_make_codepoint_bitmap_subpixel_prefilter()`
- [ ] `stbtt_MakeGlyphBitmapSubpixelPrefilter()` → Add `stb_make_glyph_bitmap_subpixel_prefilter()`

**Font Baking (High-level API):**
- [ ] `stbtt_BakeFontBitmap()` → Add `stb_bake_font_bitmap()`
- [ ] `stbtt_GetBakedQuad()` → Add `stb_get_baked_quad()`
- [ ] `stbtt_GetScaledFontVMetrics()` → Add `stb_get_scaled_font_vmetrics()`

**Font Packing (Advanced):**
- [ ] `stbtt_PackBegin()` → Add `stb_pack_begin()`
- [ ] `stbtt_PackEnd()` → Add `stb_pack_end()`
- [ ] `stbtt_PackFontRange()` → Add `stb_pack_font_range()`
- [ ] `stbtt_PackFontRanges()` → Add `stb_pack_font_ranges()`
- [ ] `stbtt_PackSetOversampling()` → Add `stb_pack_set_oversampling()`
- [ ] `stbtt_PackSetSkipMissingCodepoints()` → Add `stb_pack_set_skip_missing_codepoints()`
- [ ] `stbtt_GetPackedQuad()` → Add `stb_get_packed_quad()`

## TODO: C Wrapper Extensions

### 🔲 Functions to Add to `stb_truetype_wrapper.c`

For each missing Fortran function above, add corresponding C wrapper functions following the existing pattern:
- [ ] Implement `stb_wrapper_*` functions for all missing STB functions
- [ ] Follow existing memory management patterns
- [ ] Maintain Fortran-compatible interfaces
- [ ] Add proper error handling for each wrapper

## TODO: New Module `fortplot_stb.f90`

### 🔲 Create Pure Fortran Implementation Module

**Purpose:** Create a future pure Fortran port that can replace stb_truetype.h dependency

**Module Structure:**
- [ ] Create `src/fortplot_stb.f90` module skeleton
- [ ] Define equivalent data structures to `stbtt_fontinfo`
- [ ] Define module interfaces matching `fortplot_stb_truetype.f90` API
- [ ] Add module documentation explaining it's for future pure Fortran port

**Implementation Strategy:**
- [ ] Start with stub implementations that return error/placeholder values
- [ ] Document which functions need TrueType parsing vs. bitmap rendering
- [ ] Identify external dependencies (file I/O, memory management, math functions)
- [ ] Plan incremental implementation approach

## TODO: Test Infrastructure

### 🔲 Create Test Stubs for STB vs Pure Fortran Comparison

**Purpose:** Verify compatibility between stb_truetype wrapper and future pure Fortran implementation

**Test Structure:**
- [ ] Create `test/test_stb_comparison.f90` test program
- [ ] Create test stub for each wrapper function in `fortplot_stb_truetype.f90`:
  - [ ] `test_stb_init_font_comparison()`
  - [ ] `test_stb_scale_for_pixel_height_comparison()`
  - [ ] `test_stb_get_font_vmetrics_comparison()`
  - [ ] `test_stb_get_codepoint_hmetrics_comparison()`
  - [ ] `test_stb_get_codepoint_bitmap_comparison()`
  - [ ] `test_stb_free_bitmap_comparison()`
  - [ ] `test_stb_find_glyph_index_comparison()`
  - [ ] `test_stb_get_codepoint_bitmap_box_comparison()`
  - [ ] `test_stb_make_codepoint_bitmap_comparison()`

**Test Implementation:**
- [ ] Each test should call both STB wrapper and pure Fortran implementation
- [ ] Compare outputs for identical inputs (font metrics, bitmap data, etc.)
- [ ] Report differences and compatibility issues
- [ ] Include performance comparison benchmarks
- [ ] Test with multiple font files (DejaVu, Helvetica, etc.)

**Test Data Requirements:**
- [ ] Include small test font file in repository
- [ ] Define standard test characters and sizes
- [ ] Create reference output files for regression testing

## Implementation Priority

1. **High Priority:** Complete missing basic font metric functions
2. **Medium Priority:** Add kerning and advanced bitmap functions  
3. **Low Priority:** Font baking and packing (complex, rarely used)
4. **Future:** Pure Fortran implementation in `fortplot_stb.f90`

## Notes

- All new wrapper functions should follow TDD principles from `CLAUDE.md`
- Each function should have corresponding test coverage
- Maintain backward compatibility with existing `fortplot_text.f90` usage
- Document performance characteristics of each implementation approach