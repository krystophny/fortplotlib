# Pure Fortran TrueType Implementation TODO

## ⚠️ **CRITICAL ISSUES - ACCURACY REGRESSION DISCOVERED**

### **🚨 URGENT: June 30, 2025 - ISSUES REOPENED**
- **CURRENT STATUS:** **ACCURACY REGRESSION** - Multiple boundary rendering issues
- **PROBLEM:** Systematic horizontal band artifacts and boundary fill errors
- **ROOT CAUSE:** Fill buffer handling and edge loop closure logic incorrect
- **TARGET:** Restore 100% pixel-perfect match with STB TrueType

### **🔧 CURRENT ISSUES IDENTIFIED**

**1. Horizontal Band Artifacts**
- Systematic `112 112 112` patterns in diff bitmap (row 20, columns 12-19)
- Systematic `123 123 123` patterns in diff bitmap (row 33, columns 2-19)
- Issue: Fill buffer accumulation creating persistent horizontal bands

**2. Boundary Fill Errors**
- Left boundary issues: diff shows non-128 values at row starts
- Right boundary issues: persistent fill values extending to bitmap edge
- Issue: Edge loop closure handling differs from STB

**3. Vertical Antialiasing Works**
- Column 11 shows correct `77 77 77` pattern (vertical edge antialiasing)
- Confirms core edge processing works for some cases
- Issue: Horizontal fill logic has systematic errors

---

## 🚨 **URGENT TASKS - ACCURACY ISSUES**

### **🎯 Critical Tasks (REOPENED)**
1. ❌ **Fill buffer indexing** - STB uses different boundary conditions
2. ❌ **Edge loop closure** - Horizontal bands indicate wrong fill start/end points
3. ❌ **Boundary clipping** - Left/right edge handling differs from STB
4. ✅ **Vertical antialiasing** - Working correctly (column 11 evidence)

### **📊 Current Status**
- **Previous accuracy:** 100% (achieved but regressed)
- **Current accuracy:** **SIGNIFICANT REGRESSION** - Multiple systematic errors
- **Test bitmap:** 20x39 pixels showing horizontal band artifacts
- **Evidence:** diff_bitmap.pgm shows systematic patterns instead of random noise

### **🔍 Technical Status**
- ✅ **Vertex extraction:** Working - STB exactly (42 vertices)
- ✅ **Contour handling:** Working - Selective closing implemented
- ❌ **Edge processing:** BROKEN - Fill buffer wrong start/end positions
- ❌ **Scanline rasterization:** BROKEN - Horizontal band artifacts
- ❌ **Boundary handling:** BROKEN - Left/right edge differences from STB

---

## 📋 **DETAILED TEST PLAN - SYSTEMATIC STB VERIFICATION**

### **🔬 Phase 1: Fill Buffer Validation**
**MUST ALWAYS UPDATE TODO.md WHILE WORKING**

**1.1 Non-Vertical Edge Fill Logic**
```bash
# Test scanline filling for non-vertical edges specifically
fpm test --target test_forttf_scanline_functions
fpm test --target test_forttf_fill_active_edges
```

**STB Lines 3240-3270 (Non-vertical edge processing):**
- [ ] STB L3242: `x_top = x0 + dx * (e->sy - y_top)` → ForTTF L712: `x_top = real(...)`
- [ ] STB L3250: `x_bottom = x0 + dx * (e->ey - y_top)` → ForTTF L720: `x_bottom = real(...)`
- [ ] STB L3255: Fast path bounds check → ForTTF L731-732: `if (x_top >= 0.0_wp ...)`
- [ ] STB L3270: Brute force fallback → ForTTF L789: `call stb_brute_force_edge_clipping`

**1.2 Fill Buffer Indexing (CRITICAL)**
**STB Lines 3223 vs ForTTF Line 670:**
- [ ] STB: `stbtt__handle_clipped_edge(scanline_fill-1,(int) x0+1,e, ...)`
- [ ] ForTTF: `call stb_handle_clipped_edge(scanline_fill_buffer, int(x0) + 1, e, ...)`
- [ ] **CRITICAL:** STB effective index = `(scanline_fill-1)[(int) x0+1] = scanline_fill[x0]`
- [ ] **CRITICAL:** ForTTF effective index = `scanline_fill_buffer[int(x0) + 1]` (1-based)
- [ ] **ACTION:** Test changing ForTTF to `int(x0)` instead of `int(x0) + 1`

### **🔬 Phase 2: Boundary Handling**
**MUST ALWAYS UPDATE TODO.md WHILE WORKING**

**2.1 Left Boundary Processing**
- [ ] STB condition: `if (x0 >= 0)` then normal processing, `else` special case
- [ ] Verify our handling of negative `x0` values
- [ ] Test fill buffer write at position 0 for out-of-bounds edges

**2.2 Right Boundary Processing**
- [ ] STB condition: `if (x0 < len)` limits all edge processing
- [ ] Check if we're processing edges at positions >= width
- [ ] Verify fill buffer bounds: should be `width` elements, not `width+1`

**2.3 Edge Loop Closure Analysis**
- [ ] Compare contour closing edges between STB and ForTTF
- [ ] Check if closing edges create extra fill buffer writes
- [ ] Verify edge direction handling for contour closure

### **🔬 Phase 3: Systematic Pixel Comparison**
**MUST ALWAYS UPDATE TODO.md WHILE WORKING**

**3.1 Horizontal Band Investigation**
- [ ] Row 20 cols 12-19: persistent `112` values = `pure_val - stb_val = -32`
- [ ] Row 33 cols 2-19: persistent `123` values = different pattern
- [ ] Debug exactly which edges write to these fill buffer positions
- [ ] Compare fill buffer state before/after each edge for problematic rows

**3.2 Vertical Edge Validation (WORKING)**
- [ ] Column 11: `77 77 77` pattern confirms correct vertical antialiasing
- [ ] Use this as reference for correct behavior
- [ ] Identify why vertical works but horizontal doesn't

### **🔬 Phase 4: STB Algorithm Deep Dive**
**MUST ALWAYS UPDATE TODO.md WHILE WORKING**

**4.1 Reference Implementation Study**
```c
// STB stbtt__fill_active_edges_new() - lines ~3200-3300 in stb_truetype.h:
// Line ~3220: if (x0 < len) {
// Line ~3222:   stbtt__handle_clipped_edge(scanline,(int) x0,e, x0,y_top, x0,y_bottom);
// Line ~3223:   stbtt__handle_clipped_edge(scanline_fill-1,(int) x0+1,e, x0,y_top, x0,y_bottom);
// Line ~3225:   stbtt__handle_clipped_edge(scanline_fill-1,0,e, x0,y_top, x0,y_bottom);

// STB accumulation loop - lines ~3330-3340:
// Line ~3333: sum += scanline2[i];
// Line ~3334: k = scanline[i] + sum;
```

**STB to ForTTF Line Mapping:**
- [ ] STB L3220 `if (x0 < len)` → ForTTF L663 `if (x0 < real(width, wp))`
- [ ] STB L3222 `scanline,(int) x0` → ForTTF L666 `scanline_buffer, int(x0)`
- [ ] STB L3223 `scanline_fill-1,(int) x0+1` → ForTTF L670 `scanline_fill_buffer, int(x0) + 1`
- [ ] STB L3225 `scanline_fill-1,0` → ForTTF L675 `scanline_fill_buffer, 0`
- [ ] STB L3333 `sum += scanline2[i]` → ForTTF L1049 `sum_val = sum_val + scanline_fill_buffer(i + 1)`
- [ ] STB L3334 `k = scanline[i] + sum` → ForTTF L1050 `k_val = scanline_buffer(i + 1) + sum_val`

**Critical Index Mapping:**
- [ ] STB `scanline_fill-1` pointer offset vs ForTTF 1-based indexing
- [ ] STB `(int) x0+1` with `-1` offset = effective index `x0`
- [ ] ForTTF `int(x0) + 1` without offset = effective index `x0+1`
- [ ] **HYPOTHESIS:** Our indexing is off by +1 compared to STB

**4.2 Edge Cases Documentation**
- [ ] Document when STB uses fast path vs brute force
- [ ] Document exact boundary conditions for each code path
- [ ] Document fill buffer size and indexing scheme differences

### **🔬 Phase 5: Debugging Infrastructure**
**MUST ALWAYS UPDATE TODO.md WHILE WORKING**

**5.1 Enhanced Debug Output**
- [ ] Add fill buffer state logging for problematic rows
- [ ] Log which edges contribute to each fill position
- [ ] Compare edge coordinates and directions with STB debug output

**5.2 Pixel-by-Pixel Analysis**
- [ ] Create test that shows exact fill buffer values causing differences
- [ ] Isolate single problematic edge and trace through entire pipeline
- [ ] Generate minimal test case with single edge causing horizontal band

### **📝 WORKING NOTES SECTION**
**UPDATE THIS SECTION WITH EVERY CHANGE**

**Current Investigation:**
- Working on: Phase 1.2 - Fill Buffer Indexing Analysis
- Finding: STB uses pointer offset trick: `scanline_fill-1` + `x0+1` = effective index `x0`
- Next step: Test hypothesis that ForTTF fill buffer indexing is off by +1

**Key Files to Monitor:**
- `src/forttf/forttf_stb_raster.f90` - Main rasterization logic
- `test/forttf/test_forttf_bitmap_export.f90` - Visual comparison test
- `diff_bitmap.pgm` - Evidence of systematic errors

---

## 📋 **HISTORICAL REFERENCE**

This TODO list documented the complete journey from 89.36% accuracy to 100% pixel-perfect matching. The critical breakthrough was identifying and fixing the edge direction calculation inconsistency in the scanline fill buffer algorithm.

**Key insight:** The issue was not in individual function implementations (which were all correct), but in the consistency between different edge processing code paths. A single missing multiplication by `active_edge%direction` was causing systematic errors throughout the rasterization pipeline.

The fix demonstrates the importance of:
1. Comprehensive debugging infrastructure
2. Systematic root cause analysis
3. Consistency verification across all code paths
4. Pixel-level validation against reference implementations

**Result:** A complete, production-ready pure Fortran TrueType implementation with verified 100% accuracy.
