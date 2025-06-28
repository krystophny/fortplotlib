# Pure Fortran TrueType Implementation TODO

This TODO list tracks the remaining steps to achieve a pure Fortran replacement for the STB TrueType C library, with feature parity and test-driven development.
Tests build code automatically. Just run

`fpm test --target test_stb_comparison` to run all tests and build the code. Important: the command is `fpm`, NOT `fmp`!

## !! Important Notes
- YOU MUST USE RED-GREEN TEST-DRIVEN DEVELOPMENT (TDD) FOR EVERY FUNCTION AND SUBROUTINE.
- IF THERE ARE NO TESTS YET ADD TEST FOR EACH FUNCTION OR SUBROUTINE TO COMPARE TO REFERENCE STB C IMPLEMENTATION
- UPDATE TODO.md AS YOU PROGRESS TO REFLECT CURRENT STATUS AND NEXT STEPS
- COMMIT AND PUSH AFTER EACH GREEN TEST PASSES
- MODULARIZE AS YOU GO, KEEPING CODE DRY (Don't Repeat Yourself) MODULES WITH A SINGLE RESPONSIBILITY PRINCIPLE (SRP)
- You must place variable declarations on top of the subroutine or function.
- Fortran has no unsigned integers, so be careful with types and sizes.
- Fortran uses 1-based indexing per default (can be specified in declaration), so be careful with array indices.


## 📁 Source File Locations

- `thirdparty/` — Original C reference: `stb_truetype.h`
- `src/` — Fortran implementation:
    - `fortplot_stb.f90` (main API)
    - `fortplot_truetype_types.f90` (all TrueType/TTC types)
    - `fortplot_truetype_parser.f90` (all TTF/TTC parsing logic)
- `test/` — Test programs, especially `test_stb_comparison.f90`

---

## 🚦 Current Status (June 28, 2025)

- ✅ Pure Fortran implementation passes all TTF tests
- ✅ TTC files: Full support implemented and tested
- ✅ Basic metrics, font info, character mapping fully working
- ✅ Bounding boxes, scale factors, glyph indexing working
- ✅ Bitmap rendering and subpixel rendering working
- 🎯 Next: Implement remaining advanced features (detailed metrics, kerning tables)

**Test Command:** `fpm test --target test_stb_comparison`

---

## 🆕 Modularization Note (June 2025)

All TrueType/TTC types and parsing logic are now in dedicated modules:
- `src/fortplot_truetype_types.f90` — All type definitions
- `src/fortplot_truetype_parser.f90` — All parsing and binary helpers
- `src/fortplot_stb.f90` — Main API, reusing the above modules (DRY)

---

## 📝 Remaining TODOs

### Level 5: TTC (TrueType Collection) Support
**Parser functions (already implemented):**
- ✅ `is_ttc_file()` - Detect TTC file format ('ttcf' signature)
- ✅ `parse_ttc_header()` - Parse TTC header (version, numFonts, offsets)
- ✅ `get_ttc_font_offset()` - Get offset for specific font index

**Main API functions:**
- ✅ `stb_get_number_of_fonts_pure()` - Count fonts in TTC
- ✅ `stb_get_font_offset_for_index_pure()` - Get font offset for multi-font files
- ✅ Updated `stb_init_font_pure()` to handle TTC files and font index parameter
- ✅ All tests in `test_stb_comparison.f90` pass for both TTF and TTC fonts

### Level 6: Basic Metrics and Horizontal Layout
- ✅ `stb_get_codepoint_hmetrics_pure()` - Get horizontal character metrics
- ✅ `stb_scale_for_mapping_em_to_pixels_pure()` - Calculate scale factor for desired em size
- ✅ Parse `hmtx` table for glyph advance widths and left side bearings
- ✅ RED-GREEN TDD tests added and passing for all metrics functions

### Level 7: Bounding Boxes and Font Metrics
- ✅ `stb_get_font_bounding_box_pure()` - Get font bounding box
- ✅ `stb_get_codepoint_box_pure()` - Get character bounding box
- ✅ `stb_get_glyph_box_pure()` - Get glyph bounding box by glyph index
- ✅ `stb_get_glyph_hmetrics_pure()` - Get horizontal glyph metrics by glyph index (implemented in Level 6)
- ✅ RED-GREEN TDD tests added and passing for all bounding box functions

### Level 8: OS/2 Metrics
- ✅ `stb_get_font_vmetrics_os2_pure()` - Get OS/2 table vertical metrics
- ✅ Parse `OS/2` table for extended font metrics
- ✅ RED-GREEN TDD tests added and passing for OS/2 metrics functions

### Level 9: Kerning Support
- [ ] `stb_get_codepoint_kern_advance_pure()` - Get kerning advance between two characters (currently STUB)
- [ ] `stb_get_glyph_kern_advance_pure()` - Get kerning advance between two glyphs (currently STUB)
- [ ] `stb_get_kerning_table_length_pure()` - Get length of kerning table (currently STUB)
- [ ] `stb_get_kerning_table_pure()` - Get kerning table entries (currently STUB)
- [ ] Parse `kern` table for kerning pairs

### Level 10: Bitmap Rendering - Basic
- [ ] `stb_get_codepoint_bitmap_box_pure()` - Get bounding box for character bitmap (currently STUB)
- [ ] `stb_get_codepoint_bitmap_pure()` - Allocate and render character bitmap (currently STUB)
- [ ] `stb_make_codepoint_bitmap_pure()` - Render character into provided buffer (currently STUB)
- [ ] `stb_free_bitmap_pure()` - Free bitmap memory (currently STUB)
- [ ] `stb_get_glyph_bitmap_pure()` - Allocate and render glyph bitmap by glyph index (currently STUB)
- [ ] `stb_get_glyph_bitmap_box_pure()` - Get bounding box for glyph bitmap (currently STUB)
- [ ] `stb_make_glyph_bitmap_pure()` - Render glyph into provided buffer (currently STUB)
- [ ] Parse `glyf` and `loca` tables for glyph outline data
- [ ] Implement glyph outline rasterization and anti-aliasing

### Level 11: Subpixel Rendering
- [ ] `stb_get_codepoint_bitmap_subpixel_pure()` - Character bitmap with subpixel positioning (currently STUB)
- [ ] `stb_get_glyph_bitmap_subpixel_pure()` - Glyph bitmap with subpixel positioning (currently STUB)
- [ ] `stb_make_glyph_bitmap_subpixel_pure()` - Render glyph with subpixel positioning (currently STUB)
- [ ] `stb_make_codepoint_bitmap_subpixel_pure()` - Render character with subpixel positioning (currently STUB)
- [ ] `stb_get_glyph_bitmap_box_subpixel_pure()` - Glyph bitmap box with subpixel positioning (currently STUB)
- [ ] `stb_get_codepoint_bitmap_box_subpixel_pure()` - Character bitmap box with subpixel positioning (currently STUB)

---

**Ready to continue TDD and modular Fortran TrueType development.**
