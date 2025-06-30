# Pure Fortran TrueType Implementation TODO

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
