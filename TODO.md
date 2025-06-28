# Pure Fortran TrueType Implementation TODO

This TODO list tracks the remaining steps to achieve a pure Fortran replacement for the STB TrueType C library, with feature parity and test-driven development.

**Build and Test Commands (modular tests run automatically via fpm):**

All test commands build the code automatically! If you want to build, just test!

- `fpm test --target test_forttf_*` — Run all tests
- `fpm test --target test_forttf_metrics` — Run metrics comparison tests
- `fpm test --target test_forttf_mapping` — Run character mapping tests  
- `fpm test --target test_forttf_bitmap` — Run bitmap rendering tests

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

### 🎯 Level 12: Backend Switch to Pure Fortran (Immediate Next Priority)

**Status: READY** - All required STB functions are implemented and tested. Time to switch!

**Objective**: Replace the STB C library backend in `fortplot_text.f90` with the pure Fortran implementation.

**Implementation Strategy:**

**Phase 12.1: Preparation**
- [ ] Create backup of current `fortplot_text.f90` as `fortplot_text_stb.f90.backup`
- [ ] Audit all STB function calls in `fortplot_text.f90` (7 functions confirmed)
- [ ] Verify pure Fortran equivalents exist and work (✅ Already confirmed)

**Phase 12.2: Backend Switch**
- [ ] Update `use fortplot_stb_truetype` → `use forttf` in `fortplot_text.f90`
- [ ] Replace function calls:
  - [ ] `stb_init_font()` → `stb_init_font_pure()`
  - [ ] `stb_scale_for_pixel_height()` → `stb_scale_for_pixel_height_pure()`
  - [ ] `stb_cleanup_font()` → `stb_cleanup_font_pure()`
  - [ ] `stb_get_codepoint_hmetrics()` → `stb_get_codepoint_hmetrics_pure()`
  - [ ] `stb_get_font_vmetrics()` → `stb_get_font_vmetrics_pure()`
  - [ ] `stb_get_codepoint_bitmap()` → `stb_get_codepoint_bitmap_pure()`
  - [ ] `stb_free_bitmap()` → `stb_free_bitmap_pure()`
- [ ] Update type declarations: `stb_fontinfo_t` → `stb_fontinfo_pure_t`

**Phase 12.3: Testing and Validation**
- [ ] Run comprehensive text rendering tests
- [ ] Compare output with STB version (pixel-perfect matching expected)
- [ ] Verify memory management (no leaks)
- [ ] Test all font loading scenarios
- [ ] Performance testing and optimization

**Phase 12.4: Cleanup**
- [ ] Remove STB C library dependency from build system
- [ ] Remove C wrapper files: `stb_truetype_wrapper.c`, `fortplot_stb_truetype.f90`
- [ ] Update documentation to reflect pure Fortran implementation
- [ ] Clean up build configuration

**Expected Benefits:**
- ✅ 100% pure Fortran implementation (no C dependencies)
- ✅ Better portability and compiler compatibility
- ✅ Easier debugging and maintenance
- ✅ Same performance and accuracy as STB

---

**Ready to continue TDD and modular Fortran TrueType development.**
