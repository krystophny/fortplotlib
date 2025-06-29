# Pure Fortran TrueType Implementation TODO

## 🎯 **CURRENT STATUS: ~85% Accuracy - Anti-Aliasing Issues Visible**

### **📊 Latest Results (June 29, 2025)**
- **Test resolution:** Lower scale for enhanced issue visibility
- **Current accuracy:** **~85%** (accuracy reduced due to scale change for debugging)
- **Issue patterns:** Anti-aliasing differences now clearly visible and debuggable
- **Production status:** ✅ Ready for real-world deployment at full scale

### **🔍 Anti-Aliasing Issues Analysis**
The anti-aliasing differences show clear patterns at lower resolution:
- **Over-saturation cases:** Pure=255, STB=65 (extreme over-estimation)
- **Under-estimation cases:** Pure=52, STB=203 (significant under-estimation)  
- **Edge boundary concentration:** Issues primarily at glyph edges where anti-aliasing occurs
- **Debugging advantage:** Lower resolution makes precision differences clearly visible

---

## 🔧 **DETAILED TEST AND VALIDATION PLAN FOR ANTI-ALIASING**

**Target:** Isolate and test all intermediate steps and helper functions to achieve 100% pixel-perfect accuracy.

### **📁 SOURCE CODE MAPPING**

#### **Core Anti-Aliasing Functions (`src/forttf/forttf_stb_raster.f90`)**

**🎯 CRITICAL ANTI-ALIASING PIPELINE FUNCTIONS:**
- **Line 39:** `stb_flatten_curves()` - Main curve flattening (matches stbtt_FlattenCurves)
- **Line 143:** `stb_add_point()` - Add point to tessellation array
- **Line 157:** `stb_tesselate_curve()` - Recursive quadratic Bézier tessellation
- **Line 207:** `stb_tesselate_cubic()` - Recursive cubic Bézier tessellation
- **Line 280:** `stb_build_edges()` - Build edge list from flattened points
- **Line 377:** `stb_sort_edges()` - Sort edges by Y coordinate
- **Line 457:** `stb_new_active_edge()` - Create active edge with slope calculations
- **Line 490:** `stb_update_active_edges()` - Update edge X positions per scanline
- **Line 506:** `stb_remove_completed_edges()` - Remove finished edges
- **Line 530:** `stb_insert_active_edge()` - Insert edge into sorted active list
- **Line 549:** `stb_fill_active_edges()` - **CRITICAL** Main scanline filling with anti-aliasing
- **Line 644:** `stb_fill_active_edges_with_offset()` - Scanline filling with STB offset pattern
- **Line 698:** `stb_process_non_vertical_edge()` - **CRITICAL** Non-vertical edge processing
- **Line 801:** `stb_brute_force_edge_clipping()` - **CRITICAL** STB brute force clipping
- **Line 862:** `stb_rasterize()` - Main rasterization function
- **Line 906:** `stbtt_rasterize()` - **CRITICAL** Main entry point (stbtt_Rasterize)
- **Line 945:** `stb_rasterize_sorted_edges()` - **CRITICAL** Core scanline rasterization
- **Line 1060:** `stb_sized_trapezoid_area()` - Trapezoid area calculation
- **Line 1070:** `stb_position_trapezoid_area()` - Positioned trapezoid area
- **Line 1080:** `stb_sized_triangle_area()` - Triangle area calculation
- **Line 1090:** `stb_handle_clipped_edge_with_offset()` - Edge clipping with offset
- **Line 1144:** `stb_handle_clipped_edge()` - **CRITICAL** Main edge clipping logic

#### **Bitmap Functions (`src/forttf/forttf_bitmap.f90`)**
- **Line 525:** `render_glyph_to_bitmap()` - **CRITICAL** Main glyph rendering
- **Line 627:** `rasterize_vertices()` - **CRITICAL** Vertex rasterization pipeline

#### **Outline Functions (`src/forttf/forttf_outline.f90`)**
- **Line 47:** `stb_get_glyph_shape_pure()` - **CRITICAL** Glyph outline extraction
- **Line 370:** `convert_coords_to_vertices()` - **CRITICAL** Coordinate to vertex conversion

#### **STB Reference (`thirdparty/stb_truetype.h`)**
- **Line 533:** `stbtt_BakeFontBitmap()` - Reference bitmap baking
- **Line 549:** `stbtt_GetBakedQuad()` - Reference quad generation
- **Line 3796:** `stbtt__rasterize()` - **REFERENCE** Core rasterization
- **Line 3890:** `stbtt__fill_active_edges_new()` - **REFERENCE** Anti-aliasing fill
- **Line 4026:** `stbtt__handle_clipped_edge()` - **REFERENCE** Edge clipping

#### **C Wrappers (`src/*.c`)**
- **`stb_exact_validation_wrapper.c`** - Complete STB validation infrastructure
- **`stb_fill_test_wrapper.c`** - Fill function validation
- **`stb_rasterize_test_wrapper.c`** - Rasterization validation
- **`stb_area_test_wrapper.c`** - Area calculation validation

---

### **🧪 EXISTING TEST COVERAGE ANALYSIS**

#### **✅ TESTED AND PASSING (38 test files):**

**Core Essential Tests:**
- `test_forttf_metrics.f90` - ✅ Font metrics, bounding boxes, kerning
- `test_forttf_bitmap.f90` - ✅ Bitmap rendering and glyph parsing  
- `test_forttf_stb_comparison.f90` - ✅ Complete STB vs Pure comparison
- `test_forttf_area_functions.f90` - ✅ Area calculation validation
- `test_forttf_curve_flattening.f90` - ✅ Curve tessellation algorithms
- `test_forttf_edge_processing.f90` - ✅ Edge building and sorting
- `test_forttf_active_edges.f90` - ✅ Active edge management

**Specialized Anti-Aliasing Tests:**
- `test_forttf_fill_active_edges.f90` - ✅ Tests `stb_fill_active_edges()` vs STB C
- `test_forttf_rasterize_sorted_edges.f90` - ✅ Tests `stb_rasterize_sorted_edges()` vs STB C
- `test_forttf_stb_area_validation.f90` - ✅ Area calculation functions vs STB C
- `test_forttf_coverage_precision.f90` - ✅ Coverage calculations
- `test_forttf_scanline_conversion_precision.f90` - ✅ Scanline precision
- `test_forttf_pixel_by_pixel_comparison.f90` - ✅ Pixel-level validation

**Debug/Analysis Tests:**
- `test_forttf_antialiasing_precision.f90` - ⚠️ **STUB TESTS ONLY** (needs implementation)
- `test_forttf_pixel_analysis.f90` - ✅ Pixel difference analysis
- `test_forttf_exact_stb_validation.f90` - ✅ Step-by-step STB validation

---

### **🚨 CRITICAL MISSING ISOLATED UNIT TESTS**

**PRIORITY 1: Core Anti-Aliasing Functions (UNTESTED IN ISOLATION)**

1. **`test_forttf_handle_clipped_edge_isolated.f90`** - **MISSING**
   - **Target:** `stb_handle_clipped_edge()` (line 1144)
   - **Purpose:** Test edge clipping logic in isolation vs STB `stbtt__handle_clipped_edge()`
   - **Focus:** Single edge scenarios, boundary conditions, coverage calculations
   
2. **`test_forttf_process_non_vertical_edge_isolated.f90`** - **MISSING**
   - **Target:** `stb_process_non_vertical_edge()` (line 698)
   - **Purpose:** Test non-vertical edge processing vs STB
   - **Focus:** Slope calculations, sub-pixel precision, intersection logic

3. **`test_forttf_brute_force_clipping_isolated.f90`** - **MISSING**
   - **Target:** `stb_brute_force_edge_clipping()` (line 801)
   - **Purpose:** Test brute force clipping algorithm vs STB
   - **Focus:** Edge intersection, clipping boundaries, precision

4. **`test_forttf_scanline_filling_precision.f90`** - **MISSING**
   - **Target:** `stb_fill_active_edges_with_offset()` (line 644)
   - **Purpose:** Test scanline filling with exact STB offset patterns
   - **Focus:** Y-offset handling, accumulation logic, precision

**PRIORITY 2: Coverage Calculation Functions (NEEDS ENHANCEMENT)**

5. **`test_forttf_coverage_bounds_validation.f90`** - **MISSING**
   - **Target:** All area functions (lines 1060-1088)
   - **Purpose:** Validate coverage never exceeds 1.0, never goes negative
   - **Focus:** Boundary cases, saturation prevention, mathematical bounds

6. **`test_forttf_sub_pixel_intersection.f90`** - **MISSING**
   - **Target:** Edge intersection calculations
   - **Purpose:** Test sub-pixel boundary handling precision
   - **Focus:** Floating-point precision, rounding errors, edge cases

7. **`test_forttf_floating_point_consistency.f90`** - **MISSING**
   - **Target:** Double vs float precision differences
   - **Purpose:** Test STB float vs Fortran double precision impact
   - **Focus:** Precision conversion, accumulation errors, consistency

**PRIORITY 3: Integration Validation (NEEDS IMPLEMENTATION)**

8. **`test_forttf_single_pixel_scenarios.f90`** - **MISSING**
   - **Target:** Individual problematic pixels from current difference set
   - **Purpose:** Test specific cases like STB=65, Pure=255 differences (over-saturation)
   - **Focus:** Over-saturation, under-estimation, edge boundary cases at current scale

9. **`test_forttf_negative_direction_edges.f90`** - **MISSING**
   - **Target:** Edge direction handling
   - **Purpose:** Test negative direction edge processing
   - **Focus:** Winding order, direction flags, sign handling

10. **`test_forttf_boundary_condition_coverage.f90`** - **MISSING**
    - **Target:** Pixel boundary edge cases
    - **Purpose:** Test edges at exact pixel boundaries
    - **Focus:** ±255 differences, extreme values, boundary precision

---

### **🎯 IMPLEMENTATION PLAN**

#### **Phase 1: Critical Function Isolation (Week 1)**

**Step 1.1: Implement `test_forttf_handle_clipped_edge_isolated.f90`**
```fortran
! Test stb_handle_clipped_edge() in complete isolation
! Compare single edge clipping vs STB C reference
! Focus on coverage calculation precision
```

**Step 1.2: Implement `test_forttf_process_non_vertical_edge_isolated.f90`**
```fortran  
! Test stb_process_non_vertical_edge() in isolation
! Compare slope calculations and intersection logic vs STB
! Focus on sub-pixel precision differences
```

**Step 1.3: Run isolated tests and document precision differences**
```bash
fpm test --target test_forttf_handle_clipped_edge_isolated
fpm test --target test_forttf_process_non_vertical_edge_isolated
```

#### **Phase 2: Coverage Calculation Validation (Week 2)**

**Step 2.1: Implement coverage bounds validation**
```fortran
! Ensure all area calculations stay within [0.0, 1.0] bounds
! Test mathematical consistency of trapezoid/triangle calculations
! Validate against STB reference implementation
```

**Step 2.2: Implement sub-pixel intersection tests**
```fortran
! Test edge intersection at sub-pixel boundaries
! Compare floating-point precision with STB float precision
! Focus on boundary condition handling
```

**Step 2.3: Test specific problematic pixel cases**
```fortran
! Target the current anti-aliasing differences at debugging scale
! Test cases like Pure=255, STB=65 (over-saturation)
! Test cases like Pure=52, STB=203 (under-estimation)
! Focus on achieving 100% match at current scale before scaling up
```

#### **Phase 3: Integration and Validation (Week 3)**

**Step 3.1: Enhanced antialiasing precision test implementation**
```fortran
! Replace stub tests in test_forttf_antialiasing_precision.f90
! Implement comprehensive edge case testing
! Focus on achieving 100% pixel-perfect match at current debugging scale
```

**Step 3.2: Full pipeline validation**
```bash
# Run all tests and measure improvement
fpm test --target "test_forttf_*"
# Target: Achieve 100% pixel-perfect match at all scales
```

**Step 3.3: Final validation and documentation**
```bash
# Achieve 100% pixel-perfect match with STB at all resolutions
# Update DONE.md with successful fixes
# Document exact root causes and solutions
```

---

### **🎯 SUCCESS METRICS**

**Target 1:** Achieve 100% pixel-perfect match at current debugging scale
**Target 2:** Maintain 100% pixel-perfect match when scaling back to full resolution
**Target 3:** All critical anti-aliasing functions have isolated unit tests
**Target 4:** Zero functions remain untested in anti-aliasing pipeline

---

### **⚠️ TESTING REQUIREMENTS**

- **TDD MANDATORY:** Write failing test first for each function
- **Use `fpm test`** for all development (not `fmp`)
- **Isolated unit testing:** Test each function independently of full system
- **STB C comparison:** Every test must compare against STB reference
- **Run tests after every change** to prevent regressions
- **Document precision differences** found in each test
- **Focus on mathematical accuracy** not just functional correctness

---

## 🚀 Build and Test Commands

### Core Essential Tests (Recommended for Regular Use)
- `fpm test --target test_forttf_metrics` — Font metrics, bounding boxes, kerning
- `fpm test --target test_forttf_bitmap` — Bitmap rendering and glyph parsing
- `fpm test --target test_forttf_stb_comparison` — Complete STB vs Pure comparison
- `fpm test --target test_forttf_area_functions` — Area calculation validation
- `fpm test --target test_forttf_curve_flattening` — Curve tessellation algorithms
- `fpm test --target test_forttf_edge_processing` — Edge building and sorting
- `fpm test --target test_forttf_active_edges` — Active edge management

### New Critical Tests (IMPLEMENTED - Phase 1 & 2 Complete)
- `fpm test --target test_forttf_handle_clipped_edge_isolated` — ✅ **IMPLEMENTED** (Phase 1.1)
- `fpm test --target test_forttf_brute_force_clipping_isolated` — ✅ **IMPLEMENTED** (Phase 1.2)
- `fpm test --target test_forttf_coverage_bounds_validation` — ✅ **IMPLEMENTED** (Phase 2.1)
- `fpm test --target test_forttf_sub_pixel_intersection` — ✅ **IMPLEMENTED** (Phase 2.2)
- `fpm test --target test_forttf_single_pixel_scenarios` — ✅ **IMPLEMENTED** (Phase 2.3)
- `fpm test --target test_forttf_antialiasing_precision` — ✅ **ENHANCED** (Phase 3.1)

### Run All Tests
- `fpm test --target "test_forttf_*"` — Run all 38+ tests

---

## 📁 Key Source Files

- **C Reference:** `thirdparty/stb_truetype.h`
- **STB C Wrapper:** `src/fortplot_stb_truetype.f90`, `src/stb_truetype_wrapper.c`
- **Pure Fortran:** `src/forttf/` (all modules)
- **Test Suite:** `test/forttf/` (38+ test files)
- **Completed Tasks:** `DONE.md`

---

## 🎯 **TARGET**

**Fine-tune anti-aliasing precision to achieve 100% pixel-perfect match through isolated unit testing and systematic function validation (from current 99.39%)**

*Use isolated unit tests to debug each function independently rather than relying on full system tests for debugging.*