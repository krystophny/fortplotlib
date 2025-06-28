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

- `fpm test--target test_forttf_*` — Run all `forttf` tests
- `fpm test --target test_forttf_metrics` — Run metrics comparison tests
- `fpm test --target test_forttf_mapping` — Run character mapping tests
- `fpm test --target test_forttf_bitmap` — Run bitmap rendering tests
- `fpm test --target test_forttf_bitmap_content` — Run bitmap content comparison tests
- `fpm test --target test_forttf_stb_rasterization` — Run STB rasterization pipeline tests


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

## 🔬 Phase 1: Port STB Scanline Rasterization Functions

**Target Fortran File:** `src/forttf/forttf_stb_raster.f90`

**Methodology:** Each function must be ported from `thirdparty/stb_truetype.h` to its Fortran equivalent. A corresponding test must be created in `test/forttf/test_forttf_stb_rasterization.f90` to validate the output against the original C function.

### **1.1: Main Scanline Processing**
- [ ] **Port `stbtt__rasterize_sorted_edges()`**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3331
  - **Fortran Target:** `stb_rasterize_sorted_edges()` in `forttf_stb_raster.f90`
  - **Description:** This is the core function that iterates through scanlines and manages active edges to generate the bitmap.

- [ ] **Port `stbtt__fill_active_edges_new()`**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3269
  - **Fortran Target:** `stb_fill_active_edges()` in `forttf_stb_raster.f90`
  - **Description:** Fills a scanline based on the list of active edges, calculating pixel coverage for anti-aliasing.

- [ ] **Port `stbtt__handle_clipped_edge()`**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3244
  - **Fortran Target:** `stb_handle_clipped_edge()` in `forttf_stb_raster.f90`
  - **Description:** Handles edges that are clipped at the scanline boundaries.

### **1.2: Area Calculation for Anti-Aliasing**
- [ ] **Port `stbtt__sized_trapezoid_area()`**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3197
  - **Fortran Target:** `stb_sized_trapezoid_area()` in `forttf_stb_raster.f90`
  - **Description:** Calculates the area of a trapezoid for anti-aliasing coverage.

- [ ] **Port `stbtt__position_trapezoid_area()`**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3185
  - **Fortran Target:** `stb_position_trapezoid_area()` in `forttf_stb_raster.f90`
  - **Description:** Calculates trapezoid area with sub-pixel positioning.

- [ ] **Port `stbtt__sized_triangle_area()`**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3192
  - **Fortran Target:** `stb_sized_triangle_area()` in `forttf_stb_raster.f90`
  - **Description:** Calculates the area of a triangle for partial coverage at the edges of shapes.

---

## 🛠️ Phase 2: Integrate and Validate the New Pipeline

### **2.1: Pipeline Integration**
- [ ] **Port `stbtt_Rasterize()`**
  - **C Reference:** `thirdparty/stb_truetype.h`, line 3595
  - **Fortran Target:** `stb_rasterize()` in `forttf_bitmap.f90`
  - **Description:** This function is the main entry point for the STB rasterizer. It orchestrates the entire process, from handling vertices to producing the final bitmap.

- [ ] **Replace Simple Rasterizer**
  - **Location:** `forttf_bitmap.f90`
  - **Action:** Modify the `render_glyph_to_bitmap()` function to call the new `stb_rasterize()` function instead of the current `rasterize_vertices_simple()`.
  - **Verification:** Ensure all coordinate transformations (scale, shift), offsets, and the `invert` flag are handled correctly.

### **2.2: Comprehensive Testing**
- [ ] **Create `test/forttf/test_forttf_stb_rasterization.f90`**
  - **Objective:** Add specific tests for each newly ported function (`stb_rasterize_sorted_edges`, `stb_fill_active_edges`, etc.) to verify their correctness against the C implementation.

- [ ] **Pixel-Perfect Bitmap Comparison**
  - **Test:** `test_exact_complete_pipeline_vs_stb()` in `test/forttf/test_forttf_stb_comparison.f90`
  - **Goal:** Achieve a pixel-perfect match for the entire ASCII character set. The test should compare the bitmap generated by the Fortran code with the one from STB and assert that they are identical.

- [ ] **Visual Validation**
  - **Action:** Generate test images showing rendered text using the new pipeline to visually confirm the quality and correctness of the output.

---

## 🚀 Next Steps

1.  **Implement Scanline Rasterization:** Begin by porting the functions listed in **Phase 1**, starting with `stbtt__rasterize_sorted_edges()`.
2.  **Develop Tests:** For each ported function, create a corresponding test in `test/forttf/test_forttf_stb_rasterization.f90` to ensure its output matches the STB reference.
3.  **Integrate Pipeline:** Once the core rasterization functions are ported and tested, integrate them by porting `stbtt_Rasterize()` and updating `forttf_bitmap.f90`.
4.  **Achieve Pixel-Perfect Matching:** Run the comprehensive comparison tests and debug any discrepancies until the Fortran implementation produces bitmaps identical to STB's.