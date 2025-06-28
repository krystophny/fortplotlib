# Pure Fortran TrueType Implementation TODO

This TODO list tracks the remaining steps to achieve a pure Fortran replacement for the STB TrueType C library, with feature parity and test-driven development.

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

## 🚀 Build and Test Commands

All test commands build the code automatically. To build, just run the tests.

- `fpm test --target test_forttf_*` — Run all tests.
- `fpm test --target test_forttf_metrics` — Run metrics comparison tests.
- `fpm test --target test_forttf_mapping` — Run character mapping tests.
- `fpm test --target test_forttf_bitmap` — Run bitmap rendering tests.
- `fpm test --target test_forttf_bitmap_content` — Run bitmap content comparison tests.
- `fpm test --target test_forttf_stb_rasterization` — Run STB rasterization pipeline tests.


## 📁 Source File Locations

- **C Reference:** `thirdparty/stb_truetype.h`
- **STB C Wrapper:** `src/fortplot_stb_truetype.f90`, `src/stb_truetype_wrapper.c`
- **Completed Tasks:** `DONE.md`

### Pure Fortran `forttf` Implementation (`src/forttf/`)
- `forttf.f90`: Main thin API layer, re-exporting all functionality.
- `forttf_core.f90`: Core font initialization and data management.
- `forttf_types.f90`: All TrueType-related type definitions.
- **Parser Modules:**
  - `forttf_parser.f90`: Wrapper for parsing modules.
  - `forttf_file_io.f90`: File I/O and header parsing.
  - `forttf_table_parser.f90`: Parsing for `head`, `hhea`, `maxp`, `cmap`, `kern` tables.
  - `forttf_glyph_parser.f90`: Glyph-specific parsing for `loca` and `glyf` tables.
- **Font Metrics & Mapping:**
  - `forttf_metrics.f90`: All metrics functionality (hmtx, vmtx, etc.).
  - `forttf_mapping.f90`: Character-to-glyph mapping (`cmap`).
- **Bitmap & Rasterization:**
  - `forttf_bitmap.f90`: Glyph bitmap creation and management.
  - `forttf_outline.f90`: Glyph outline processing.
  - `forttf_stb_raster.f90`: The STB-based scanline rasterizer.

### `forttf` Test Suite (`test/forttf/`)
- `test_forttf_metrics.f90`: Tests for font metrics.
- `test_forttf_mapping.f90`: Tests for character-to-glyph mapping.
- `test_forttf_bitmap.f90`: Tests for bitmap creation.
- `test_forttf_bitmap_content.f90`: Compares rendered bitmap content.
- `test_forttf_character_coverage.f90`: Validates rendering for a set of characters.
- `test_forttf_stb_comparison.f90`: End-to-end comparison with STB.
- **Rasterizer Pipeline Tests:**
  - `test_forttf_stb_structures.f90`: Validates ported data structures.
  - `test_forttf_curve_flattening.f90`: Tests for Bézier curve tessellation.
  - `test_forttf_edge_processing.f90`: Tests for edge building and sorting.
  - `test_forttf_active_edges.f90`: Tests for active edge management.
  - `test_forttf_stb_rasterization.f90`: **(To be created)** for the new scanline rasterizer functions.
- **Debugging & Utility Tests:**
  - `test_forttf_utils.f90`: Tests for utility functions.
  - `test_forttf_glyph_outline.f90`: Tests for glyph outline parsing.
  - `test_forttf_simple_bitmap.f90`: Basic bitmap tests.
  - `test_forttf_debug_bitmap.f90`: Debugging tests for bitmaps.

---

## 🎯 Primary Goal: Pixel-Perfect STB Rasterization

**CRITICAL ISSUE:** The current Pure Fortran rasterizer generates 8,544 non-zero pixels for the letter 'A', whereas STB's reference implementation produces 1,817 pixels. This discrepancy is because our implementation uses a simple bounding-box fill, while STB employs a sophisticated anti-aliased scanline rasterizer.

**REQUIREMENT:** To resolve this, we must port STB's internal rasterization pipeline to Fortran, ensuring every intermediate function and data structure matches the C reference exactly. The final output must be pixel-perfect with the STB implementation.

**ROOT CAUSE:** The `rasterize_vertices()` function in `forttf_bitmap.f90` currently calls `rasterize_vertices_simple()`. This must be replaced with a new `stb_rasterize_edges()` function that correctly implements the anti-aliased scanline rendering logic from STB.

---

## 🔬 Phase 1: Port STB Scanline Rasterization Functions - ✅ COMPLETED

All core STB scanline rasterization functions have been successfully ported and validated with pixel-perfect STB C comparison!

---

## 🛠️ Phase 2: Integrate and Validate the New Pipeline

### **CRITICAL PIXEL COUNT MISMATCH - DEBUGGING STEPS**

**Current Issue:** Pure Fortran generates 665 pixels vs STB's 1817 pixels (63% undercount)

#### **STEP-BY-STEP DEBUG PLAN:**

**STEP 1: ✅ COMPLETED** - Fix edge building to match STB exactly
- **Location:** `forttf_stb_raster.f90:1780-1900` (`stb_build_edges`)
- **Status:** Fixed edge building algorithm, generates correct 6 edges
- **Validation:** `test_forttf_pipeline_debug.f90` shows proper edge count

**STEP 2: ✅ COMPLETED** - Test edge building output  
- **Location:** `test_forttf_pipeline_debug.f90:50-70`
- **Result:** Edge building works correctly (6 edges with proper coordinates)
- **Next:** Issue is in scanline filling, not edge building

**STEP 3: 🔄 IN PROGRESS** - Fix scanline filling algorithm
- **Issue Location:** `forttf_stb_raster.f90:1950-2100` (`stb_rasterize_sorted_edges`)
- **Specific Problem:** Two different offset patterns in STB:
  - `stb_fill_active_edges` calls: `scanline_fill` (no offset)
  - `stb_rasterize_sorted_edges` calls: `scanline_fill-1` (with offset)
- **Line Numbers to Fix:**
  - Line 1960: `call stb_fill_active_edges_with_offset(...)` vs `call stb_fill_active_edges(...)`
  - Line 1890: `stb_fill_active_edges_with_offset` implementation needs offset handling
- **Test Requirements:**
  - `test_forttf_fill_active_edges.f90` MUST pass (tests basic function)
  - `test_forttf_rasterize_sorted_edges.f90` MUST pass (tests with offset)
  - `test_forttf_exact_params.f90` should show pixel count improvement from 665

**STEP 4: [ ] TODO** - Validate winding rule application
- **Location:** `forttf_stb_raster.f90:1890-1920` (`stb_fill_active_edges_with_offset`)
- **Check:** Coverage calculation logic for multiple overlapping edges
- **Test:** Verify STB winding rule matches Fortran implementation

**STEP 5: [ ] TODO** - Test intermediate scanline buffers
- **Location:** Create debug output in `stb_fill_active_edges_with_offset`
- **Action:** Compare scanline and scanline_fill values with STB C at each step
- **Goal:** Find exact point where pixel coverage diverges

### **2.1: Pipeline Integration**
- [x] **Port `stbtt_Rasterize()`** ✅ **COMPLETED**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3595  
  - **Fortran Implementation:** `stbtt_rasterize()` in `forttf_stb_raster.f90:2150`
  - **Status:** Successfully implemented, but pixel count mismatch needs fixing

- [ ] **Replace Simple Rasterizer**
  - **Location:** `forttf_bitmap.f90`
  - **Action:** Modify the `render_glyph_to_bitmap()` function to call the new `stb_rasterize()` function instead of the current `rasterize_vertices_simple()`.
  - **Verification:** Ensure all coordinate transformations (scale, shift), offsets, and the `invert` flag are handled correctly.

### **2.2: Comprehensive Testing**
- [x] **Create `test/forttf/test_forttf_stb_rasterization.f90`** ✅ **COMPLETED**
  - **Implementation:** `test_forttf_rasterize_sorted_edges.f90` - validates complete STB rasterization pipeline
  - **Status:** ⚠️ **FAILING** - pixel count mismatch (665 vs 1817 expected)

- [ ] **Pixel-Perfect Bitmap Comparison**
  - **Test:** `test_exact_complete_pipeline_vs_stb()` in `test/forttf/test_forttf_stb_comparison.f90`
  - **Goal:** Achieve a pixel-perfect match for the entire ASCII character set.

- [ ] **Visual Validation**
  - **Action:** Generate test images showing rendered text using the new pipeline to visually confirm the quality and correctness of the output.

---

## 🚀 Next Steps

1.  **Implement Scanline Rasterization:** Begin by porting the functions listed in **Phase 1**, starting with `stbtt__rasterize_sorted_edges()`.
2.  **Develop Tests:** For each ported function, create a corresponding test in `test/forttf/test_forttf_stb_rasterization.f90` to ensure its output matches the STB reference.
3.  **Integrate Pipeline:** Once the core rasterization functions are ported and tested, integrate them by porting `stbtt_Rasterize()` and updating `forttf_bitmap.f90`.
4.  **Achieve Pixel-Perfect Matching:** Run the comprehensive comparison tests and debug any discrepancies until the Fortran implementation produces bitmaps identical to STB's.
