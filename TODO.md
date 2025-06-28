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
- 🎯 **Next Priority**: Complete Phase 2 & 3 modularization before continuing with Level 10
- 🎯 After modularization: Implement remaining advanced features (detailed metrics, kerning tables)

**Test Command:** `fpm test --target test_stb_comparison`

---

## 🆕 Modularization Strategy (June 2025)

### Phase 1: Core Modules (✅ Complete)
All TrueType/TTC types and parsing logic are now in dedicated modules:
- `src/fortplot_truetype_types.f90` — All type definitions
- `src/fortplot_truetype_parser.f90` — All parsing and binary helpers
- `src/fortplot_stb.f90` — Main API, reusing the above modules (DRY)

### Phase 2: STB API Modularization (🎯 Next Priority)
Break down the large `src/fortplot_stb.f90` into focused modules following SRP:
- `src/fortplot_stb_core.f90` — Core font initialization and cleanup
- `src/fortplot_stb_metrics.f90` — All metrics functions (horizontal, vertical, OS/2, kerning)
- `src/fortplot_stb_mapping.f90` — Character-to-glyph mapping and lookup functions
- `src/fortplot_stb_bitmap.f90` — Bitmap rendering and rasterization functions
- `src/fortplot_stb.f90` — Main public API, importing and re-exporting all modules

### Phase 3: Test Modularization (🎯 Next Priority)
Break down the large `test/test_stb_comparison.f90` into focused test modules:
- `test/test_utils.f90` — Common test utilities (font discovery, initialization helpers)
- `test/test_stb_core.f90` — Core font initialization and TTC tests
- `test/test_stb_metrics.f90` — All metrics comparison tests
- `test/test_stb_mapping.f90` — Character mapping and glyph lookup tests
- `test/test_stb_bitmap.f90` — Bitmap rendering comparison tests
- `test/test_stb_comparison.f90` — Main test program orchestrating all test modules

### Benefits of Modularization:
- **Single Responsibility Principle (SRP)**: Each module has one clear purpose
- **DRY**: Shared functionality in dedicated modules
- **Maintainability**: Easier to find and modify specific functionality
- **Testing**: Focused test modules for each functional area
- **Build Performance**: Faster incremental compilation

---

## 📝 Remaining TODOs

### 🔧 IMMEDIATE: Complete Modularization (Phase 2 & 3)
We refactor `src/fortplot_stb.f90` and `test/test_stb_comparison.f90` into focused modules. Don't duplicate code from `src/fortplot_truetype_parser.f90` or `src/fortplot_truetype_types.f90`, but import them as needed.

**Phase 2: STB API Modularization (✅ Complete)**
In every step refactor `src/fortplot_stb.f90` to remove funcionality moved to specialized modules and become a thin API layer importing/re-exporting modules.

- [x] Move functionality to `src/fortplot_stb_core.f90` (font init/cleanup, TTC support)
- [x] Run Tests. Ensure all core functionality works as before.
- [x] Move functionality to `src/fortplot_stb_metrics.f90` (horizontal, vertical, OS/2, kerning metrics)
- [x] Run Tests. Ensure all metrics functions work as before.
- [x] Move functionality to `src/fortplot_stb_mapping.f90` (character-to-glyph mapping and lookup)
- [x] Run Tests. Ensure all mapping functions work as before.
- [x] Move functionality to `src/fortplot_stb_bitmap.f90` (bitmap rendering functions - stubs for now)
- [x] Run Tests. Ensure all bitmap functions work as before.

**Phase 3: Test Modularization**
In every step refactor `test/test_stb_comparison.f90` to remove functionality moved into focused test modules.

- [ ] Move relevant tests to `test/test_utils.f90` (font discovery, initialization helpers)
- [ ] Move relevant tests to `test/test_stb_metrics.f90` (metrics comparison tests)
- [ ] Move relevant tests to `test/test_stb_mapping.f90` (character mapping tests)
- [ ] Move relevant tests to `test/test_stb_bitmap.f90` (bitmap rendering tests)
- [ ] Ensure all tests pass and provide same coverage as before

---

## 📝 Future Development TODOs (After Modularization)

### Level 5: TTC (TrueType Collection) Support (✅ Complete)
**Parser functions (already implemented):**
- ✅ `is_ttc_file()` - Detect TTC file format ('ttcf' signature)
- ✅ `parse_ttc_header()` - Parse TTC header (version, numFonts, offsets)
- ✅ `get_ttc_font_offset()` - Get offset for specific font index

**Main API functions:**
- ✅ `stb_get_number_of_fonts_pure()` - Count fonts in TTC
- ✅ `stb_get_font_offset_for_index_pure()` - Get font offset for multi-font files
- ✅ Updated `stb_init_font_pure()` to handle TTC files and font index parameter
- ✅ All tests in `test_stb_comparison.f90` pass for both TTF and TTC fonts

### Level 6: Basic Metrics and Horizontal Layout (✅ Complete)
- ✅ `stb_get_codepoint_hmetrics_pure()` - Get horizontal character metrics
- ✅ `stb_scale_for_mapping_em_to_pixels_pure()` - Calculate scale factor for desired em size
- ✅ Parse `hmtx` table for glyph advance widths and left side bearings
- ✅ RED-GREEN TDD tests added and passing for all metrics functions

### Level 7: Bounding Boxes and Font Metrics (✅ Complete)
- ✅ `stb_get_font_bounding_box_pure()` - Get font bounding box
- ✅ `stb_get_codepoint_box_pure()` - Get character bounding box
- ✅ `stb_get_glyph_box_pure()` - Get glyph bounding box by glyph index
- ✅ `stb_get_glyph_hmetrics_pure()` - Get horizontal glyph metrics by glyph index (implemented in Level 6)
- ✅ RED-GREEN TDD tests added and passing for all bounding box functions

### Level 8: OS/2 Metrics (✅ Complete)
- ✅ `stb_get_font_vmetrics_os2_pure()` - Get OS/2 table vertical metrics
- ✅ Parse `OS/2` table for extended font metrics
- ✅ RED-GREEN TDD tests added and passing for OS/2 metrics functions

### Level 9: Kerning Support (✅ Complete)
- ✅ `stb_get_codepoint_kern_advance_pure()` - Get kerning advance between two characters
- ✅ `stb_get_glyph_kern_advance_pure()` - Get kerning advance between two glyphs
- ✅ `stb_get_kerning_table_length_pure()` - Get length of kerning table
- ✅ `stb_get_kerning_table_pure()` - Get kerning table entries
- ✅ Parse `kern` table for kerning pairs (currently returns 0 for fonts without kern tables)
- ✅ RED-GREEN TDD tests added and passing for all kerning functions

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
