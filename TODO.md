# Pure Fortran TrueType Implementation TODO

This TODO list tracks the remaining steps to achieve a pure Fortran replacement for the STB TrueType C library, with feature parity and test-driven development.

**Test Commands (modular tests run automatically via fpm):**
- `fpm test --target test_forttf_metrics` — Run metrics comparison tests
- `fpm test --target test_forttf_mapping` — Run character mapping tests  
- `fpm test --target test_forttf_bitmap` — Run bitmap rendering tests
- `fpm test` — Run all tests (builds code automatically)

**Note:** The old `test_stb_comparison` is no longer needed. Individual focused test modules now handle comprehensive testing.

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

- ✅ **Modularization Complete**: Phase 1, 2, and 3 successfully completed (see DONE.md)
- ✅ **Naming Consistency**: All modules now use consistent `forttf_*` naming scheme
- ✅ **Core Implementation**: Font initialization, metrics, mapping fully working
- ✅ **Test Architecture**: Focused modular test suite with comprehensive coverage
- 🎯 **Next Priority**: Implement kerning table parsing (Level 9.5)
- 🔄 **Following**: Complete bitmap rendering implementation (Level 10)

**Available Test Commands:**
- `fpm test --target test_forttf_metrics` — Metrics validation
- `fpm test --target test_forttf_mapping` — Character mapping validation  
- `fpm test --target test_forttf_bitmap` — Bitmap functionality validation

You can run all tests for forttf by 

`fpm test --target test_forttf_*`
---

## 📝 Remaining TODOs

### Level 9.5: Kerning Implementation (🎯 Immediate Next Priority)
Current status: Kerning functions exist and have proper interfaces but return 0 (need actual kern table parsing)

- [ ] Implement `kern` table parsing in `forttf_parser.f90`
  - [ ] Add `ttf_kern_table_t` type to `forttf_types.f90`
  - [ ] Implement `parse_kern_table()` function
  - [ ] Add kerning table validation and format support
- [ ] Update `stb_get_codepoint_kern_advance_pure()` to use parsed kerning data
- [ ] Update `stb_get_glyph_kern_advance_pure()` to use parsed kerning data  
- [ ] Update `stb_get_kerning_table_pure()` to return actual kerning pairs
- [ ] Implement proper kerning table search and lookup algorithms
- [ ] Update tests to validate kerning functionality works correctly

### Level 10: Bitmap Rendering - Basic (🎯 Next Priority After Kerning)
Current status: Bounding box functions implemented, actual rendering functions are stubs

- [ ] Parse `glyf` and `loca` tables for glyph outline data
  - [ ] Add glyph table types to `forttf_types.f90`
  - [ ] Implement `parse_glyf_table()` and `parse_loca_table()` functions
- [ ] Implement glyph outline rasterization and anti-aliasing
- [ ] Complete bitmap rendering functions:
  - [ ] `stb_get_codepoint_bitmap_pure()` - Allocate and render character bitmap
  - [ ] `stb_make_codepoint_bitmap_pure()` - Render character into provided buffer  
  - [ ] `stb_free_bitmap_pure()` - Free bitmap memory
  - [ ] `stb_get_glyph_bitmap_pure()` - Allocate and render glyph bitmap by index
  - [ ] `stb_make_glyph_bitmap_pure()` - Render glyph into provided buffer
- [ ] Update tests to validate bitmap rendering works correctly

### Level 11: Subpixel Rendering (🎯 Future Priority)
Current status: All subpixel functions are stubs

- [ ] Implement subpixel positioning infrastructure
- [ ] Complete subpixel rendering functions:
  - [ ] `stb_get_codepoint_bitmap_subpixel_pure()` - Character bitmap with subpixel positioning
  - [ ] `stb_get_glyph_bitmap_subpixel_pure()` - Glyph bitmap with subpixel positioning
  - [ ] `stb_make_glyph_bitmap_subpixel_pure()` - Render glyph with subpixel positioning
  - [ ] `stb_make_codepoint_bitmap_subpixel_pure()` - Render character with subpixel positioning
  - [ ] `stb_get_glyph_bitmap_box_subpixel_pure()` - Glyph bitmap box with subpixel positioning
  - [ ] `stb_get_codepoint_bitmap_box_subpixel_pure()` - Character bitmap box with subpixel positioning
- [ ] Update tests to validate subpixel rendering works correctly

---

**Ready to continue TDD and modular Fortran TrueType development.**
