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
- ✅ **STB Rasterization Infrastructure**: Complete STB-compatible rasterization pipeline implemented:
  - ✅ `forttf_stb_raster.f90`: Curve flattening, edge processing, active edge management
  - ✅ All STB data structures: `stb_point_t`, `stb_edge_t`, `stb_active_edge_t`, `stb_bitmap_t`
  - ✅ Comprehensive test suite: curve flattening, edge processing, active edge management
- 🎯 **Current Priority**: Achieve pixel-perfect STB rasterization matching (Level 12B)

## 📝 Remaining TODOs

### 🎯 Level 12B: Exact STB Intermediate Function Matching - CRITICAL

**Status: IN PROGRESS** - Core bitmap rendering works but rasterization algorithm differs from STB.

**CRITICAL ISSUE:** Current Pure Fortran generates 8,544 non-zero pixels vs STB's 1,817 pixels for letter 'A'. This indicates our rasterization algorithm differs from STB's internal pipeline.

**REQUIREMENT:** Every intermediate function in STB's bitmap rendering pipeline must be ported and tested for exact matching.

---

## 🔬 STB Internal Pipeline Analysis & Testing Requirements

**CURRENT STATUS SUMMARY:**
- ✅ **Data Structures**: All STB data structures implemented and tested
- ✅ **Curve Flattening**: Complete tessellation pipeline working 
- ✅ **Edge Processing**: Edge building, sorting, and active edge management working
- ❌ **Scanline Rasterization**: MISSING - This is the critical bottleneck
- ❌ **Area Calculation**: MISSING - Required for antialiasing
- ❌ **Pipeline Integration**: MISSING - Need to replace simple rasterization

**CRITICAL ISSUE:** Current Pure Fortran generates 8,544 non-zero pixels vs STB's 1,817 pixels for letter 'A'. The Pure Fortran implementation uses a simple bounding-box fill algorithm instead of STB's sophisticated scanline rasterization with antialiasing.

**ROOT CAUSE:** The `rasterize_vertices()` function in `forttf_bitmap.f90` currently uses `rasterize_vertices_simple()` which fills a bounding box with solid pixels instead of using the STB rasterization pipeline that's been implemented in `forttf_stb_raster.f90`.


### **Phase 12B.5: Scanline Rasterization - ❌ CRITICAL MISSING**
- [ ] **stbtt__rasterize_sorted_edges()**: Main scanline processing function
- [ ] **stbtt__fill_active_edges_new()**: Anti-aliased edge filling
- [ ] **stbtt__handle_clipped_edge()**: Edge clipping for scanline boundaries
- [ ] **Coverage calculation**: Exact pixel coverage computation
- [ ] **Sub-pixel positioning**: Floating-point anti-aliasing
- [ ] **TEST**: Compare scanline buffers at each Y coordinate with STB
- [ ] **TEST**: Verify pixel coverage values match STB exactly

### **Phase 12B.6: Area Calculation Functions - ❌ CRITICAL MISSING** 
- [ ] **stbtt__sized_trapezoid_area()**: Trapezoid area for anti-aliasing
- [ ] **stbtt__position_trapezoid_area()**: Positioned trapezoid calculation
- [ ] **stbtt__sized_triangle_area()**: Triangle area for partial coverage
- [ ] **Coverage accumulation**: Exact floating-point accumulation
- [ ] **Final quantization**: Convert coverage to 0-255 pixel values
- [ ] **TEST**: Compare area calculations for individual shapes with STB
- [ ] **TEST**: Verify coverage-to-pixel conversion matches exactly

### **Phase 12B.7: Integration & Pipeline Fixing - ❌ CRITICAL MISSING**
- [ ] **Replace current simple rasterization** in `forttf_bitmap.f90` with STB pipeline
- [ ] **stbtt_Rasterize()**: Main entry point with exact parameter handling
- [ ] **Coordinate transformations**: Exact scale_x, scale_y, shift_x, shift_y handling
- [ ] **Offset handling**: Proper x_off, y_off application
- [ ] **Invert flag**: Correct winding direction handling
- [ ] **TEST**: Pixel-perfect bitmap comparison for all ASCII characters
- [ ] **TEST**: Verify intermediate results at every pipeline stage

---

## 🧪 Comprehensive Testing Strategy

### **Intermediate Function Testing (MANDATORY)**
Every STB internal function must have a corresponding test:

```fortran
! Rasterization tests ❌ MISSING
test_exact_scanline_rasterization_vs_stb()  ❌ MISSING
test_exact_pixel_coverage_vs_stb()          ❌ MISSING
test_exact_area_calculations_vs_stb()       ❌ MISSING

! Pipeline integration tests ❌ MISSING
test_exact_complete_pipeline_vs_stb()       ❌ MISSING
test_exact_coordinate_transforms_vs_stb()   ❌ MISSING
```

### **Testing Methodology**
1. **Extract STB intermediate results** using debug prints/logging
2. **Compare Fortran intermediate results** at identical pipeline stages  
3. **Verify floating-point precision** matches STB calculations
4. **Test edge cases**: tiny curves, degenerate shapes, extreme coordinates
5. **Performance comparison**: Ensure Fortran performance is reasonable

**Testing Requirements Going Forward:**
- [ ] **Pixel-perfect output**: Achieve identical bitmap output to STB ⚠️ CRITICAL  
- [ ] **Visual validation**: Generate test images showing rendered text
- [ ] **Unicode subset**: Test beyond ASCII characters
- [ ] **Edge cases**: Empty glyphs, composite glyphs, malformed fonts

---

## 🎯 Next Steps

**Priority 1: Implement Missing Scanline Rasterization**
1. Port `stbtt__rasterize_sorted_edges()` from STB to Fortran
2. Implement area calculation functions for antialiasing
3. Replace simple rasterization with STB pipeline in `forttf_bitmap.f90`
4. Add comprehensive tests for scanline processing

**Priority 2: Achieve Pixel-Perfect Matching**
1. Test intermediate scanline results against STB
2. Verify coverage calculations match exactly
3. Validate complete pipeline produces identical bitmaps

**Priority 3: Performance and Optimization**
1. Benchmark pure Fortran vs STB performance
2. Optimize hot paths in scanline rasterization
3. Test memory usage patterns

---

## 📊 Implementation Status Summary


### 🔧 IN PROGRESS (Working but Not Pixel-Perfect)
- **Basic Bitmap Rendering**: Generates visible content (8,544 pixels vs STB's 1,817)
- **Bounding Box Rasterization**: Simple fill algorithm works but differs from STB
- **Content Detection**: Pure Fortran produces filled shapes, STB produces antialiased outlines

### ❌ MISSING (Critical for Production)
- **STB Scanline Rasterization**: Core antialiasing algorithm
- **Area Calculation Functions**: Required for proper pixel coverage
- **Pipeline Integration**: Connect STB rasterizer to bitmap functions

### 🎯 IMMEDIATE NEXT TASK
**Replace simple rasterization with STB pipeline in `forttf_bitmap.f90`:**
```fortran
! Current: rasterize_vertices_simple() - fills bounding box
! Needed: stb_rasterize_edges() - antialiased scanline rendering
```

**Expected Result**: Pure Fortran generates 1,817 pixels (matching STB exactly)

---

**Ready to continue TDD and modular Fortran TrueType development.**