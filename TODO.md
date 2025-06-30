# Pure Fortran TrueType Implementation TODO

## ⚠️ **MANDATORY DEBUGGING PRACTICE**
**🔒 RULE: When investigating issues, ALWAYS document ruled-out components in the "CONFIRMED NOT THE ISSUE" section below to prevent re-investigation of verified working code. This practice is MANDATORY for all debugging work.**

## ⚠️ **ANTIALIASING ACCURACY ISSUES**

### **🚨 Current Status: June 30, 2025**
- **MAJOR PROGRESS:** Horizontal stripe artifacts eliminated ✅
- **CURRENT ISSUE:** Non-vertical line antialiasing inconsistent
- **WORKING:** Vertical line antialiasing correct
- **SYMPTOM:** Up-down symmetric structures in diff bitmap

### **🔧 CURRENT ISSUES IDENTIFIED**

**1. Non-Vertical Line Antialiasing**
- Scattered differences throughout diff bitmap (non-128 values)
- Up-down symmetric pattern suggests edge direction issues
- Vertical lines correctly antialiased, diagonal/curved lines not

**2. Edge Processing Inconsistency**  
- STB vs ForTTF differences in non-vertical edge handling
- Likely in curve/bezier edge rasterization logic
- May be related to coordinate transformation or edge direction

---

## 🚨 **CURRENT TASKS**

### **🎯 Active Investigation**
1. ✅ **Horizontal stripes** - Fixed! No more systematic band artifacts
2. ✅ **Fill buffer indexing** - Working correctly 
3. ✅ **Vertical antialiasing** - Working perfectly
4. ❌ **Non-vertical antialiasing** - Scattered differences remain

### **📊 Current Status**
- **Major breakthrough:** Horizontal stripe artifacts eliminated ✅
- **Test bitmap:** 20x39 pixels - mostly 128 values in diff
- **Remaining:** Scattered non-vertical edge antialiasing differences
- **Pattern:** Up-down symmetric structures suggest edge direction issue

### **🔍 Technical Status**
- ✅ **Vertex extraction:** Working - matches STB (42 vertices)
- ✅ **Fill buffer logic:** Working - horizontal stripes eliminated  
- ✅ **Vertical edges:** Perfect antialiasing
- ❌ **Non-vertical edges:** Inconsistent antialiasing vs STB

---

## 🧪 **SYSTEMATIC TEST & DEBUG PLAN**

### **📋 Complete Testing Strategy**
**Goal: Achieve 100% pixel-perfect match with STB**
**Method: Test every intermediate input/output, not just final bitmap**

**Phase A: Intermediate Data Validation**
```bash
fpm test --target test_forttf_bitmap_export  # Current baseline
# Extend C wrapper if needed to expose STB intermediate data
```

**A.1 Input/Output Testing at Every Stage (forttf_stb_raster.f90):**
- [ ] **Vertex input** - Test exact vertex coordinates match STB input
- [ ] **L41-144 `stb_flatten_curves`:** INPUT vertices → OUTPUT flattened points (compare arrays)
- [ ] **L282-378 `stb_build_edges`:** INPUT points → OUTPUT edge list (compare edge coordinates/directions)
- [ ] **L379-432 `stb_sort_edges`:** INPUT unsorted edges → OUTPUT sorted edges (compare ordering)
- [ ] **L551-636 `stb_fill_active_edges`:** INPUT active edges → OUTPUT scanline/fill buffers (compare arrays)
- [ ] **L694-795 `stb_process_non_vertical_edge`:** INPUT edge → OUTPUT fill buffer writes (compare positions/values)
- [ ] **L1180+ `stb_handle_clipped_edge`:** INPUT coordinates → OUTPUT scanline values (compare exact values)

**Phase B: Function-Level Input/Output Matching**
```bash
fpm test --target test_forttf_bitmap_export > debug.log 2>&1
# May extend C wrapper to expose STB intermediate arrays for comparison
```

**B.1 Systematic Input/Output Validation:**
- [ ] **L282-378 `stb_build_edges`:** Compare INPUT vertex arrays and OUTPUT edge arrays element-by-element
- [ ] **L379-432 `stb_sort_edges`:** Compare INPUT/OUTPUT edge ordering - must be identical
- [ ] **L459-491 `stb_new_active_edge`:** Compare INPUT edge and OUTPUT active_edge struct fields
- [ ] **L551-636 `stb_fill_active_edges`:** Compare INPUT active edges and OUTPUT scanline_buffer/scanline_fill_buffer arrays
- [ ] **L694-795 `stb_process_non_vertical_edge`:** Compare INPUT coordinates and OUTPUT buffer modifications
- [ ] **L940-1125 `stb_rasterize_sorted_edges`:** Compare INPUT edges and OUTPUT pixel array per scanline

**Phase C: Extend C Wrapper for Deep Testing**
```bash
# Add STB intermediate data exposure to C wrapper if needed
# Test intermediate arrays: points, edges, active_edges, scanline_buffers
```

**C.1 Enhanced C Wrapper Testing:**
- [ ] **Expose STB edge arrays** - Compare STB edge list with ForTTF edge list
- [ ] **Expose STB scanline buffers** - Compare per-scanline fill buffer states
- [ ] **Expose STB active edge lists** - Compare active edges per Y-coordinate
- [ ] **Intermediate array dumps** - Export STB intermediate data for exact comparison

### **🎯 Validation Criteria**
**Success Metrics:**
- [ ] `diff_bitmap.pgm` contains only `128` values (perfect match)
- [ ] All function debug logs show identical processing between STB and ForTTF
- [ ] Zero up-down symmetric patterns in difference bitmap
- [ ] 100% pixel accuracy confirmed

### **📝 Current Work Log**
**Active Investigation:** Non-vertical edge antialiasing inconsistencies
**Next Step:** Add debug output to L694-795 `stb_process_non_vertical_edge` function
**Target:** Identify coordinate precision differences in diagonal/curved edges

### **📂 Key Files and Line Numbers**

**ForTTF Implementation (src/forttf/forttf_stb_raster.f90):**
- `stb_flatten_curves` (L41-144) - Curve flattening
- `stb_build_edges` (L282-378) - Edge list creation
- `stb_sort_edges` (L379-432) - Edge Y-ordering
- `stb_new_active_edge` (L459-491) - Active edge creation
- `stb_fill_active_edges` (L551-636) - Active edge processing
- `stb_process_non_vertical_edge` (L694-795) - Non-vertical edge handling
- `stb_rasterize_sorted_edges` (L940-1125) - Main scanline loop
- `stb_handle_clipped_edge` (L1180+) - Fill buffer writes

**STB Reference (thirdparty/stb_truetype.h):**
- `stbtt__fill_active_edges` (L2882-2923) - Old active edge fill
- `stbtt__rasterize_sorted_edges` (L2924+) - Main rasterization loop
- `stbtt__handle_clipped_edge` (L3028-3081) - Clipped edge handling
- `stbtt__fill_active_edges_new` (L3082-3300) - New active edge fill with antialiasing
  - **CRITICAL:** L3096-3097 - Vertical edge handling
  - **CRITICAL:** L3114-3129 - Non-vertical edge coordinate calculation
  - **CRITICAL:** L3129+ - Fast path bounds checking

**C Wrappers (src/):**
- `stb_truetype_wrapper.c` - Main STB interface wrapper (26KB)
- `stb_exact_validation_wrapper.c` - Exact validation wrapper (11KB)
- `stb_fill_test_wrapper.c` - Fill buffer testing wrapper
- `stb_edge_debug_wrapper.c` - Edge debugging wrapper
- `stb_buffer_debug_wrapper.c` - Buffer state debugging wrapper
- `stb_handle_clipped_edge_wrapper.c` - Clipped edge testing wrapper
- `stb_debug_wrapper.c` - General debug wrapper
- `stb_edge_capture.c` - Edge capture wrapper
- `stb_rasterize_test_wrapper.c` - Rasterization testing wrapper

**Test Files (test/forttf/):**
- `test_forttf_bitmap_export.f90` - Main bitmap comparison test
- `test_forttf_stb_comparison.f90` - STB vs ForTTF comparison
- `test_forttf_exact_stb_validation.f90` - Exact validation test
- `test_stb_debug_wrapper.f90` - Debug wrapper test
- `test_forttf_stb_rasterization.f90` - Rasterization test

---

## ✅ **CONFIRMED NOT THE ISSUE - RULED OUT COMPONENTS**

**⚠️ MANDATORY PRACTICE: Always document ruled-out issues to avoid repeating investigative work ⚠️**

### **🔍 June 30, 2025 Investigation - Components Confirmed Working**

**✅ VERIFIED WORKING CORRECTLY:**

**1. Vertex Extraction (src/forttf/forttf_stb_raster.f90:L41-144)**
- ✅ **Input verification:** 42 vertices extracted - exact match with STB
- ✅ **Coordinate accuracy:** Vertex coordinates identical to STB reference
- ✅ **Parse logic:** `convert_coords_to_vertices` working correctly
- ✅ **Debug output:** Vertex type, x/y coordinates, control points all correct

**2. Edge Building and Sorting (src/forttf/forttf_stb_raster.f90:L282-432)**
- ✅ **Edge list creation:** `stb_build_edges` produces correct edge arrays
- ✅ **Y-ordering:** `stb_sort_edges` correctly sorts edges by Y-coordinate
- ✅ **Edge coordinates:** Input/output edge coordinates verified correct
- ✅ **Edge direction:** Direction calculations working correctly

**3. Horizontal Stripe Artifacts (MAJOR FIX CONFIRMED)**
- ✅ **Fill buffer indexing:** Fixed - no more systematic band artifacts
- ✅ **Scanline processing:** Working correctly across all Y-coordinates
- ✅ **Vertical edge antialiasing:** Perfect pixel-level accuracy achieved
- ✅ **Stripe elimination:** Confirmed - no horizontal bands in diff bitmap

**4. Non-Vertical Edge Coordinate Processing (src/forttf/forttf_stb_raster.f90:L694-795)**
- ✅ **Input parameters:** x0, dx, y_top, y_bottom values correct
- ✅ **Coordinate clipping:** x_top, x_bottom calculations using proper 32-bit precision
- ✅ **STB bounds checking:** Fast path condition `x_top >= 0 && x_bottom >= 0 && x_top < width && x_bottom < width` working
- ✅ **Scanline coordinate calculation:** Exact match with STB arithmetic using `real32` precision

**5. Area Calculation Functions (src/forttf/forttf_stb_raster.f90:L1081-1119)**
- ✅ **stb_position_trapezoid_area:** Correctly calls `stb_sized_trapezoid_area(height, tx1-tx0, bx1-bx0)`
- ✅ **stb_sized_trapezoid_area:** Exact implementation match with STB - `(top_width + bottom_width) * 0.5 * height`
- ✅ **32-bit precision arithmetic:** Using `real32` calculations to exactly match STB float precision
- ✅ **STB bounds checking:** `max(-1.01, min(1.01, area))` clamping correctly applied
- ✅ **Safe width handling:** `max(0.0, width)` for negative width protection

**6. Single Pixel Coverage Scenarios**
- ✅ **Simple case logic:** `int(x_top) == int(x_bottom)` condition working correctly
- ✅ **Height calculation:** `(sy1 - sy0) * active_edge%direction` correct
- ✅ **Area computation:** Trapezoid area calculation producing correct coverage values
- ✅ **Buffer accumulation:** `scanline_buffer[x+1] += area` working correctly

**7. Active Edge Processing (src/forttf/forttf_stb_raster.f90:L551-636)**
- ✅ **Edge activation:** Active edges correctly identified and processed
- ✅ **Y-coordinate matching:** Edges activated at correct scanlines
- ✅ **Edge traversal:** `active_edge%next` pointer logic working correctly
- ✅ **Fill buffer updates:** Both `scanline_buffer` and `scanline_fill_buffer` updated correctly

**8. Precision and Arithmetic Accuracy**
- ❌ **32-bit float matching:** NOT the issue - differences persist despite real32 usage
- ✅ **Coordinate calculation precision:** `x_top = real(real(x0, real32) + real(dx, real32) * ...)` working
- ✅ **No systematic errors:** Debug output shows correct coordinate progression
- ✅ **Floating-point consistency:** No NaN or infinity values detected

**9. Edge Array Building and Validation (CONFIRMED JUNE 30, 2025)**
- ✅ **Edge count accuracy:** 48 edges correctly built from 53 points, 3 contours
- ✅ **Edge coordinates:** First 5 edges show proper y0/y1/x0/x1 values with correct ranges
- ✅ **Winding direction:** Invert flags (0/1) correctly set per edge
- ✅ **Edge array structure:** All stb_edge_t fields populated correctly
- ✅ **Point-to-edge conversion:** Proper transformation from flattened curve points to edge segments

**10. PNG Export Enhancement (COMPLETED JUNE 30, 2025)**
- ✅ **RGB conversion:** Grayscale bitmap correctly converted to RGB format
- ✅ **Color-coded differences:** Red=STB higher, Blue=Pure higher, Gray=identical
- ✅ **Visual analysis support:** Both PGM and PNG outputs for flexible viewing
- ✅ **File generation:** All three outputs (stb_bitmap, pure_bitmap, diff_bitmap) in both formats

**11. Final Pixel Conversion and Accumulation (VALIDATED JUNE 30, 2025)**
- ✅ **Coverage calculation:** Real-valued coverage correctly computed (0.025→6, 1.164→255, etc.)
- ✅ **Integer conversion:** `abs(k_val) * 255.0 + 0.5` rounding working correctly
- ✅ **Value clamping:** Proper bounds checking (0-255 range enforced)
- ✅ **Accumulation logic:** `sum_val + scanline_buffer(i+1)` accumulating correctly
- ✅ **Coordinate mapping:** Y-flip and stride calculations working correctly

**NOT THE ISSUE - CONFIRMED WORKING:**
- Vertex extraction and parsing
- Edge building and sorting algorithms (48 edges from 53 points validated)
- Horizontal stripe artifacts (FIXED)
- Vertical edge antialiasing (PERFECT)
- Non-vertical coordinate calculations (but may have different order)
- Area calculation functions (formula correct, but application may differ)
- Single-pixel coverage scenarios
- Active edge processing logic
- PNG export functionality (color-coded difference visualization)
- Final pixel conversion and accumulation (coverage→integer mapping validated)

**NOT THE ISSUE - RULED OUT:**
- Float32 vs Float64 precision (confirmed NOT the cause)
- Basic arithmetic operations (all match STB formulas)

### **🎯 CURRENT REMAINING ISSUE (June 30, 2025)**
**Systematic algorithmic differences:** 83 pixel differences (10.6%) with deviations up to ±247
**Pattern:** Large systematic discrepancies indicating fundamental algorithmic differences
**Root cause:** Subtle edge processing and coverage accumulation order differences

### **⚠️ MAJOR ALGORITHMIC FIXES IMPLEMENTED**
**COMPLETED FIXES:**
- ✅ **Edge sorting algorithm**: Fixed to always run quicksort + insertion sort (like STB)
- ✅ **Active edge insertion**: Changed from sorted order to front insertion (LIFO like STB)
- ✅ **32-bit precision arithmetic**: Verified area calculations use exact STB float32 precision
- ✅ **Coordinate system**: Confirmed Y-flipping is correct for our setup

**CURRENT STATUS:** 83 pixel differences (10.6%) remain after major algorithmic fixes
**REQUIREMENT:** Must achieve 100% pixel-perfect accuracy with STB reference

**CRITICAL CONFIRMED:** This is NOT a precision issue - it's algorithmic differences!

**REMAINING ALGORITHMIC ISSUES:**
- **Edge traversal order** during scanline processing may differ from STB LIFO pattern
- **Edge state management timing** - subtle differences in active/inactive transitions
- **Coverage accumulation sequence** - order of operations when multiple edges affect same pixels
- **Edge deactivation patterns** - different linked list traversal affecting subsequent calculations

**INVESTIGATION FOCUS:**
1. ✅ Edge processing order (LIFO insertion implemented)
2. **Edge traversal order** during scanline filling
3. **Multi-edge intersection handling** - coverage accumulation sequence
4. **Edge deactivation timing** - when edges are removed vs processed
5. **Boundary condition handling** - edges at exact pixel boundaries

**HYPOTHESIS:** Remaining differences are due to subtle edge interaction algorithms, not basic processing order

**DEBUGGING RULE:** Always add ruled-out components to this section to prevent re-investigation of confirmed working code.
