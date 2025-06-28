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

### ✅ COMPLETED: Basic Functions Added to `fortplot_stb_truetype.f90`

**Additional Core Functions:**
- [x] `stbtt_GetNumberOfFonts()` → Added `stb_get_number_of_fonts()`
- [x] `stbtt_GetFontOffsetForIndex()` → Added `stb_get_font_offset_for_index()`

**Extended Font Metrics:**
- [x] `stbtt_ScaleForMappingEmToPixels()` → Added `stb_scale_for_mapping_em_to_pixels()`
- [x] `stbtt_GetFontBoundingBox()` → Added `stb_get_font_bounding_box()`

**Glyph-level Functions:**
- [x] `stbtt_GetCodepointBox()` → Added `stb_get_codepoint_box()`

**Kerning Functions:**
- [x] `stbtt_GetCodepointKernAdvance()` → Added `stb_get_codepoint_kern_advance()`

### ✅ COMPLETED: Glyph-level and Advanced Bitmap Functions

**Extended Font Metrics:**
- [x] `stbtt_GetFontVMetricsOS2()` → Added `stb_get_font_vmetrics_os2()`

**Glyph-level Functions:**
- [x] `stbtt_GetGlyphHMetrics()` → Added `stb_get_glyph_hmetrics()`
- [x] `stbtt_GetGlyphBox()` → Added `stb_get_glyph_box()`
- [x] `stbtt_GetGlyphKernAdvance()` → Added `stb_get_glyph_kern_advance()`
- [x] `stbtt_GetKerningTableLength()` → Added `stb_get_kerning_table_length()`
- [x] `stbtt_GetKerningTable()` → Added `stb_get_kerning_table()`

**Advanced Bitmap Functions:**
- [x] `stbtt_GetGlyphBitmap()` → Added `stb_get_glyph_bitmap()`
- [x] `stbtt_GetCodepointBitmapSubpixel()` → Added `stb_get_codepoint_bitmap_subpixel()`
- [x] `stbtt_MakeGlyphBitmap()` → Added `stb_make_glyph_bitmap()`
- [x] `stbtt_GetGlyphBitmapBox()` → Added `stb_get_glyph_bitmap_box()`

### 🔲 REMAINING Functions to Add to `fortplot_stb_truetype.f90`

**Advanced Subpixel Variants:**
- [ ] `stbtt_GetGlyphBitmapSubpixel()` → Add `stb_get_glyph_bitmap_subpixel()`
- [ ] `stbtt_MakeGlyphBitmapSubpixel()` → Add `stb_make_glyph_bitmap_subpixel()`
- [ ] `stbtt_MakeCodepointBitmapSubpixel()` → Add `stb_make_codepoint_bitmap_subpixel()`
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

### ✅ COMPLETED: Basic Functions Added to `stb_truetype_wrapper.c`

**Added C wrapper functions:**
- [x] `stb_wrapper_get_number_of_fonts()` → Wraps `stbtt_GetNumberOfFonts()`
- [x] `stb_wrapper_get_font_offset_for_index()` → Wraps `stbtt_GetFontOffsetForIndex()`
- [x] `stb_wrapper_scale_for_mapping_em_to_pixels()` → Wraps `stbtt_ScaleForMappingEmToPixels()`
- [x] `stb_wrapper_get_font_bounding_box()` → Wraps `stbtt_GetFontBoundingBox()`
- [x] `stb_wrapper_get_codepoint_box()` → Wraps `stbtt_GetCodepointBox()`
- [x] `stb_wrapper_get_codepoint_kern_advance()` → Wraps `stbtt_GetCodepointKernAdvance()`

### 🔲 REMAINING Functions to Add to `stb_truetype_wrapper.c`

For each remaining Fortran function above, add corresponding C wrapper functions following the existing pattern:
- [ ] Implement remaining `stb_wrapper_*` functions for missing STB functions
- [ ] Follow existing memory management patterns
- [ ] Maintain Fortran-compatible interfaces
- [ ] Add proper error handling for each wrapper

## TODO: New Module `fortplot_stb.f90`

### ✅ COMPLETED: Pure Fortran Implementation Module Created

**Purpose:** Create a future pure Fortran port that can replace stb_truetype.h dependency

**Module Structure:**
- [x] Created `src/fortplot_stb.f90` module skeleton
- [x] Defined equivalent data structures to `stbtt_fontinfo` (`stb_fontinfo_pure_t`)
- [x] Defined module interfaces matching `fortplot_stb_truetype.f90` API
- [x] Added module documentation explaining it's for future pure Fortran port

**Implementation Strategy:**
- [x] Started with stub implementations that return error/placeholder values
- [x] Documented which functions need TrueType parsing vs. bitmap rendering
- [x] Identified external dependencies (file I/O, memory management, math functions)
- [x] Planned incremental implementation approach

### 🔲 FUTURE: Actual Pure Fortran Implementation

**Next Steps for Pure Fortran Port:**
- [ ] Implement TrueType file format parsing (tables: head, hhea, hmtx, cmap, glyf, loca)
- [ ] Implement glyph outline parsing and curve processing
- [ ] Implement bitmap rasterization with antialiasing
- [ ] Add proper error handling and memory management
- [ ] Performance optimization and testing

## TODO: Test Infrastructure

### ✅ COMPLETED: Test Infrastructure for STB vs Pure Fortran Comparison

**Purpose:** Verify compatibility between stb_truetype wrapper and future pure Fortran implementation

**Test Structure:**
- [x] Created `test/test_stb_comparison.f90` test program
- [x] Created test infrastructure for comparing STB and pure implementations:
  - [x] Font initialization comparison
  - [x] Scale calculation comparison
  - [x] Font metrics comparison
  - [x] Character metrics comparison
  - [x] Glyph index lookup comparison
  - [x] Bounding box calculation comparison
  - [x] Bitmap rendering comparison
  - [x] Kerning calculation comparison
  - [x] Additional functions testing

**Test Implementation:**
- [x] Each test calls both STB wrapper and pure Fortran implementation
- [x] Compares outputs for identical inputs (font metrics, etc.)
- [x] Reports differences and compatibility issues
- [x] Tests with multiple font paths (DejaVu, Helvetica, etc.)
- [x] Currently verifies that STB works and pure implementation fails as expected (stubs)

**Test Results:**
- [x] ✅ All tests pass - STB implementation works, pure implementation correctly returns stub values
- [x] ✅ New functions tested successfully (EM scaling, font/character bounding boxes, kerning)
- [x] ✅ Test can be run with `make test ARGS="test_stb_comparison"`

### 🔲 FUTURE: Enhanced Test Infrastructure

**Test Data Requirements:**
- [ ] Include small test font file in repository for consistent testing
- [ ] Define standard test characters and sizes for reproducible results
- [ ] Create reference output files for regression testing
- [ ] Add performance comparison benchmarks when pure implementation is completed

## Implementation Priority

1. ✅ **COMPLETED - High Priority:** Basic font metric functions implemented
2. **Medium Priority:** Add remaining kerning and advanced bitmap functions  
3. **Low Priority:** Font baking and packing (complex, rarely used)
4. **Future:** Pure Fortran implementation in `fortplot_stb.f90`

## Summary of Completed Work

### ✅ Implemented Functions (16 new functions)

**Phase 1 - Basic Extensions (6 functions):**
1. **`stb_get_number_of_fonts()`** - Get font count in file
2. **`stb_get_font_offset_for_index()`** - Get font offset for multi-font files
3. **`stb_scale_for_mapping_em_to_pixels()`** - Calculate EM-based scaling
4. **`stb_get_font_bounding_box()`** - Get overall font bounding box
5. **`stb_get_codepoint_box()`** - Get character bounding box
6. **`stb_get_codepoint_kern_advance()`** - Get kerning between characters

**Phase 2 - Glyph-level Functions (6 functions):**
7. **`stb_get_font_vmetrics_os2()`** - Get OS/2 table metrics
8. **`stb_get_glyph_hmetrics()`** - Get glyph horizontal metrics by index
9. **`stb_get_glyph_box()`** - Get glyph bounding box by index
10. **`stb_get_glyph_kern_advance()`** - Get kerning between glyph indices
11. **`stb_get_kerning_table_length()`** - Get length of kerning table
12. **`stb_get_kerning_table()`** - Get kerning table entries

**Phase 3 - Advanced Bitmap Functions (4 functions):**
13. **`stb_get_glyph_bitmap()`** - Render glyph bitmap by index
14. **`stb_get_glyph_bitmap_box()`** - Get glyph bitmap bounding box
15. **`stb_get_codepoint_bitmap_subpixel()`** - Render subpixel positioned bitmap
16. **`stb_make_glyph_bitmap()`** - Render glyph into user buffer

### ✅ Infrastructure Completed
- **Fortran Module**: Extended `fortplot_stb_truetype.f90` with 16 new wrapper functions
- **C Wrapper Layer**: Added 16 corresponding C functions in `stb_truetype_wrapper.c`
- **Pure Fortran Stubs**: Created `fortplot_stb.f90` with 20 stub implementations for future port
- **Test Infrastructure**: Created `test_stb_comparison.f90` to compare STB vs pure implementations
  - Tests basic functions, glyph-level functions, and bitmap functions
  - Comprehensive test coverage for all new functionality
- **Documentation**: Updated `ttf.md` and `TODO.md` to reflect progress

### ✅ Testing Results
- All new functions compile successfully
- Text rendering tests pass (no regressions)
- STB comparison test passes (STB works, pure stubs work as expected)
- Line length limit (88 chars) enforced and added to `CLAUDE.md`

## Notes

- All new wrapper functions follow TDD principles from `CLAUDE.md`
- Each function has corresponding test coverage in comparison tests
- Maintains backward compatibility with existing `fortplot_text.f90` usage
- Ready for implementation of remaining functions or pure Fortran port development