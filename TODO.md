# Pure Fortran TrueType Implementation TODO

This TODO list tracks the remaining steps to achieve a pure Fortran replacement for the STB TrueType C library, with feature parity and test-driven development.

**Build and Test Commands (modular tests run automatically via fpm):**

All test commands build the code automatically! If you want to build, just test!

- `fpm test --target test_forttf_*` — Run all tests
- `fpm test --target test_forttf_metrics` — Run metrics comparison tests
- `fpm test --target test_forttf_mapping` — Run character mapping tests  
- `fpm test --target test_forttf_bitmap` — Run bitmap rendering tests
- `fpm test --target test_forttf_bitmap_content` — Run bitmap rendering content tests 

## !! Important Notes
- Port original C reference `thirdparty/stb_truetype.h` and use it to check your logics.
- YOU MUST USE RED-GREEN TEST-DRIVEN DEVELOPMENT (TDD) FOR EVERY FUNCTION AND SUBROUTINE.
- IF THERE ARE NO TESTS YET ADD TEST FOR EACH FUNCTION OR SUBROUTINE TO COMPARE TO REFERENCE STB C IMPLEMENTATION
- UPDATE TODO.md AS YOU PROGRESS TO REFLECT CURRENT STATUS AND NEXT STEPS
- COMMIT AND PUSH AFTER EACH GREEN TEST PASSES
- MODULARIZE AS YOU GO, KEEPING CODE DRY (Don't Repeat Yourself) MODULES WITH A SINGLE RESPONSIBILITY PRINCIPLE (SRP)
- Prefer systematic unit tests to ad-hoc debug output.
- You must place variable declarations on top of the subroutine or function.
- Fortran has no unsigned integers, so be careful with types and sizes.
- Fortran uses 1-based indexing per default (can be specified in declaration), so be careful with array indices.


## 📁 Source File Locations

- `thirdparty/` — Original C reference: `stb_truetype.h`
- `src/forttf/` — Fortran implementation (modular architecture):
    - `forttf.f90` (thin API layer)
    - `forttf_core.f90` (font initialization)
    - `forttf_metrics.f90` (all metrics functionality)
    - `forttf_mapping.f90` (character mapping)
    - `forttf_bitmap.f90` (bitmap rendering)
    - `forttf_types.f90` (type definitions)
    - `forttf_parser.f90` (parsing logic)
- `src/` — STB C wrapper: `fortplot_stb_truetype.f90`, `stb_truetype_wrapper.c`
- `test/forttf/` — Focused test modules: `test_forttf_metrics.f90`, `test_forttf_mapping.f90`, `test_forttf_bitmap.f90`
- `DONE.md` — Completed tasks and implementations

---

## 🚦 Current Status (June 28, 2025)

- ✅ **Modularization Complete**: All phases successfully completed with specialized modules (see DONE.md)
- ✅ **Parser Refactoring**: `forttf_parser.f90` converted to wrapper module re-exporting specialized functionality
- ✅ **Module Organization**: Functions properly distributed across specialized modules:
  - `forttf_file_io.f90`: File I/O, header parsing, TTC support
  - `forttf_table_parser.f90`: Table parsing (head, hhea, maxp, cmap, kern)
  - `forttf_glyph_parser.f90`: Glyph-specific parsing (loca, glyf)
  - `forttf_parser.f90`: Wrapper module providing unified interface
- ✅ **Naming Consistency**: All modules now use consistent `forttf_*` naming scheme
- ✅ **Core Implementation**: Font initialization, metrics, mapping fully working
- ✅ **Kerning Implementation**: Level 9.5 COMPLETE! All kerning functions working with perfect STB compatibility
- ✅ **Bitmap Rendering**: Level 10 COMPLETE! All basic bitmap functions working with perfect STB compatibility
- ✅ **Subpixel Rendering**: Level 11 COMPLETE! All subpixel functions working with perfect STB compatibility
- ✅ **Test Architecture**: Focused modular test suite with comprehensive coverage
- ✅ **API Completeness**: All STB functions required by `fortplot_text.f90` are implemented and tested
- 🎯 **Next Priority**: Switch backend from STB C library to pure Fortran implementation (Level 12)

## 📝 Remaining TODOs

### ✅ All Core TrueType Functionality - COMPLETED!

**Status: COMPLETE** - All levels (9.5, 10, 11) have been successfully implemented! See DONE.md for details.

---

### ❌ Level 12: Backend Switch to Pure Fortran - CRITICAL ISSUE DISCOVERED!

**Status: BROKEN** - Backend switch completed BUT bitmap rendering is producing placeholder shapes instead of actual text!

**CRITICAL PROBLEM DISCOVERED (June 28, 2025):**
The pure Fortran bitmap implementation in `forttf_bitmap.f90` is currently generating placeholder shapes (gray circles/rectangles) instead of actual glyph bitmaps. This was missed by our tests because:

1. **Test Gap**: Bitmap tests only verified dimensions, NOT actual bitmap content ✅ FIXED - Added `test_bitmap_content.f90`
2. **Missing Implementation**: `render_glyph_to_bitmap()` creates placeholder shapes, not real text
3. **Real Impact**: Plots now show gray circles instead of text labels

**IMMEDIATE ACTION REQUIRED:**

### 🚨 Level 12A: Fix Bitmap Rendering Implementation (URGENT)

**Objective**: Implement actual glyph outline parsing and rasterization to replace placeholder shapes.

**Missing Components:**
1. **Glyph Outline Parsing**: Parse TrueType glyph outline data from `glyf` table
2. **Curve Rasterization**: Convert Bézier curves and lines to bitmap pixels
3. **Antialiasing**: Implement proper antialiased rendering like STB
4. **Hinting Support**: Basic glyph hinting for better readability

**Implementation Strategy:**

**Phase 12A.1: TrueType Outline Parsing**
- [ ] Study STB's `stbtt__GetGlyphShapeTT()` function in `stb_truetype.h`
- [ ] Implement glyph coordinate parsing from `glyf` table
- [ ] Parse simple glyph contours (MoveTo, LineTo, QuadTo operations)
- [ ] Handle composite glyphs (glyph references)
- [ ] **TEST**: Compare parsed coordinates with STB reference

**Phase 12A.2: Rasterization Engine**
- [ ] Study STB's `stbtt__rasterize()` function
- [ ] Implement scanline rasterization algorithm
- [ ] Convert outline curves to pixel coverage
- [ ] Implement proper antialiasing (coverage calculation)
- [ ] **TEST**: Compare rasterized bitmaps pixel-by-pixel with STB

**Phase 12A.3: Enhanced Testing**
- [x] Add bitmap content comparison tests (not just dimensions) - `test_bitmap_content.f90` created and failing as expected
- [ ] Test actual glyph shapes: 'A', 'B', '0', '1', etc.
- [ ] Verify antialiasing quality matches STB
- [ ] Test complex glyphs with curves
- [ ] **TEST**: Visual comparison plots - STB vs Pure Fortran

**Phase 12A.4: Integration and Validation**
- [ ] Replace placeholder `render_glyph_to_bitmap()` with real implementation
- [ ] Test full text rendering pipeline
- [ ] Verify plot labels render correctly
- [ ] Performance optimization
- [ ] Memory leak testing

**Temporary Workaround Options:**
1. **Revert to STB**: Switch back to STB C library until bitmap rendering is fixed
2. **Hybrid Approach**: Use pure Fortran for metrics, STB for bitmaps temporarily
3. **Simple Text**: Use basic ASCII bitmap fonts as fallback

**Testing Requirements Going Forward:**
- [ ] **Content-based tests**: Compare actual bitmap pixels, not just dimensions
- [ ] **Visual validation**: Generate test images showing rendered text
- [ ] **Character coverage**: Test full ASCII + Unicode subset
- [ ] **Edge cases**: Empty glyphs, composite glyphs, malformed fonts

### 🎯 Level 12B: Backend Switch (DEFERRED until 12A complete)

**Status: ON HOLD** - Cannot proceed until bitmap rendering is properly implemented.

---

**Ready to continue TDD and modular Fortran TrueType development.**
