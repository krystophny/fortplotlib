# Pure Fortran TrueType Implementation TODO

This TODO list outlines the systematic Test-Driven Development (TDD) approach to implement a pure Fortran TrueType font parser and renderer, replacing the STB TrueType dependency. The implementation follows a bottom-up approach, starting with the lowest-level functions and building up to complete font rendering.

## 🚦 **Current Status** (Updated: June 28, 2025)

**Test Command:** `fpm test --target test_stb_comparison`

**Current State:**
- ✅ Test framework fully operational
- ✅ STB reference implementation working (metrics: 2048/-512/171)
- ✅ **Pure Fortran implementation WORKING!** (metrics: 2048/-512/171)
- ✅ **Level 1 & 2 COMPLETE:** Binary file operations and table parsing implemented
- 🎯 **Next Step:** Move to Phase 2 - Character Mapping (Level 3)

**Latest Test Results:**
```
Scale factors - STB: 0.006250 Pure: 0.007812
STB metrics: 2048/-512/171
Pure metrics: 2048/-512/171
Failed: 0 / 1 - All tests PASSED ✅
```

**🎉 BREAKTHROUGH:** Monaco font works perfectly! The pure Fortran implementation successfully:
- ✅ Reads TrueType files (`read_truetype_file()`)
- ✅ Parses TTF headers (`parse_ttf_header()`)
- ✅ Parses table directory (`parse_table_directory()`)
- ✅ Parses head, hhea, maxp tables
- ✅ Returns correct font metrics matching STB exactly
- ✅ Handles Fortran 1-based indexing correctly (offsets +1)
- ✅ Manages big-endian unsigned integers safely
- ⚠️ Scale calculation differs slightly (STB: 0.006250 vs Pure: 0.007812) - investigate
- ❌ Character mapping not implemented (stubs return 0)

**READY FOR LEVEL 3:** Character mapping implementation

## 🎯 **Project Goal**

Replace STB TrueType C library with a pure Fortran implementation that:
- Passes all existing comparison tests in `test_stb_comparison.f90`
- Provides identical API to current `fortplot_stb_truetype.f90`
- Achieves feature parity with the 23 implemented STB functions
- Maintains or improves performance for typical use cases

## 📋 **TDD Methodology - MANDATORY**

**⚠️ CRITICAL: EVERY function MUST follow RED-GREEN-REFACTOR cycle ⚠️**

1. **RED**: Modify existing comparison test to expect pure Fortran success
2. **GREEN**: Implement minimal code to make the test pass
3. **REFACTOR**: Clean up implementation while keeping tests green
4. **REPEAT**: Move to next function in dependency order

**Test Strategy:**
- Use existing `test_stb_comparison.f90` as validation framework
- **Run with: `fpm test --target test_stb_comparison`**
- Each function must pass side-by-side comparison with STB implementation
- Bitmap outputs must be pixel-perfect matches (where possible)
- Font metrics must match STB values exactly

## 🏗️ **Implementation Phases - Bottom-Up Approach**

### Phase 1: Foundation - Binary File I/O and Basic Parsing

#### ✅ Prerequisites
- [x] TDD test framework exists (`test_stb_comparison.f90`)
- [x] Pure Fortran stub module exists (`fortplot_stb.f90`)
- [x] STB reference implementation working for comparison

#### ✅ Level 1: Binary File Operations - COMPLETE!
**Goal:** Read TrueType files and parse basic headers

**Functions implemented:**
1. ✅ `read_truetype_file()` - Read entire font file into memory
2. ✅ `parse_ttf_header()` - Parse TTF/OTF file header (sfnt version, table count)
3. ✅ `parse_table_directory()` - Parse table directory entries
4. ✅ `find_table()` - Locate specific tables by tag ('head', 'hhea', etc.)

**Test Results:**
- ✅ Successfully reads Monaco font from `/System/Library/Fonts/Monaco.ttf`
- ✅ Parses TTF header correctly
- ✅ Identifies all required tables (head, hhea, hmtx, cmap)

#### ✅ Level 2: Essential Table Parsing - COMPLETE!
**Goal:** Parse critical font tables needed for basic operations

**Tables implemented:**
1. ✅ `head` table parser - Font header (units per em, bounding box)
2. ✅ `hhea` table parser - Horizontal header (ascent, descent, line gap)
3. ✅ `hmtx` table parser - Horizontal metrics (advance widths, bearings)
4. ✅ `maxp` table parser - Maximum profile (glyph count validation)

**Test Results:**
- ✅ Font metrics match STB exactly: `2048/-512/171`
- ✅ Units per EM correctly parsed for scaling calculations
- ✅ All essential tables successfully parsed

### Phase 2: Character Mapping and Glyph Lookup

#### � Level 3: Character Mapping - IN PROGRESS
**Goal:** Map Unicode codepoints to glyph indices

**Current Status:**
- ❌ `stb_find_glyph_index_pure()` returns 0 (stub implementation)
- ❌ cmap table parser not implemented
- 📋 **Test expectation:** Character 'A' should return glyph index 36

**Functions to implement:**
1. ⏳ `parse_cmap_table()` - Character to glyph mapping table
2. ⏳ `find_glyph_index_pure()` - Unicode codepoint → glyph index lookup
3. ⏳ Support for multiple cmap subtables (platform/encoding pairs)
4. ⏳ Handle common formats: format 0, 4, 12

**TDD Next Steps:**
```fortran
! 1. RED: Test currently passes but glyph index is 0 instead of 36
glyph_index = stb_find_glyph_index_pure(pure_font, iachar('A'))
! Should return 36 to match STB implementation

! 2. GREEN: Implement cmap table parsing and glyph lookup
! 3. REFACTOR: Optimize and support multiple cmap formats
```

### Phase 3: Font Metrics and Scaling

#### 🔲 Level 4: Scaling and Metrics
**Goal:** Calculate font scaling and provide accurate metrics

**Functions to implement:**
1. [ ] `stb_scale_for_pixel_height_pure()` - Calculate scale factor
2. [ ] `stb_scale_for_mapping_em_to_pixels_pure()` - EM-based scaling
3. [ ] `stb_get_font_bounding_box_pure()` - Overall font bounding box
4. [ ] `stb_get_glyph_hmetrics_pure()` - Glyph advance width and bearing

**Test Strategy:**
- Target exact scale factor match: `0.006711` for 16px DejaVu Sans
- Verify font bounding box: `(-2090, -948, 3673, 2524)`
- Test glyph 'A' metrics: advance `1401`, bearing `16`

**Critical Calculations:**
```fortran
! Scale factor = desired_pixel_height / units_per_em
scale = real(pixel_height, wp) / real(head_table%units_per_em, wp)
```

### Phase 4: Advanced Metrics and Kerning

#### 🔲 Level 5: Extended Metrics
**Goal:** Support OS/2 metrics and bounding boxes

**Functions to implement:**
1. [ ] `OS/2` table parser - Extended font metrics
2. [ ] `stb_get_font_vmetrics_os2_pure()` - OS/2 vertical metrics
3. [ ] `stb_get_codepoint_box_pure()` - Character bounding box
4. [ ] `stb_get_glyph_box_pure()` - Glyph bounding box

**Test Strategy:**
- OS/2 metrics should match: `1556/-492/410`
- Character 'A' bbox: `(16, 0, 1384, 1493)`

#### 🔲 Level 6: Kerning Support
**Goal:** Implement kerning calculations

**Functions to implement:**
1. [ ] `kern` table parser - Kerning pairs
2. [ ] `stb_get_codepoint_kern_advance_pure()` - Character pair kerning
3. [ ] `stb_get_glyph_kern_advance_pure()` - Glyph pair kerning
4. [ ] `stb_get_kerning_table_length_pure()` - Kerning table access

**Test Strategy:**
- A-V kerning should return `-131` units
- Kerning table length should be `2727` entries

### Phase 5: Glyph Outline Processing

#### 🔲 Level 7: Glyph Outline Parsing
**Goal:** Parse and process TrueType glyph outlines

**Functions to implement:**
1. [ ] `glyf` table parser - Glyph outline data
2. [ ] `loca` table parser - Glyph location offsets
3. [ ] Parse simple glyph outlines (straight lines and curves)
4. [ ] Parse composite glyph outlines (references to other glyphs)
5. [ ] Convert outline coordinates to scaled pixel coordinates

**Test Strategy:**
- Focus on simple glyphs first (like 'A')
- Verify outline point coordinates after scaling
- Test composite glyph decomposition

**Critical Components:**
- Quadratic Bézier curve handling
- Coordinate scaling and transformation
- On-curve vs off-curve point processing

### Phase 6: Bitmap Rasterization

#### 🔲 Level 8: Basic Bitmap Rendering
**Goal:** Rasterize glyph outlines to bitmap format

**Functions to implement:**
1. [ ] `stb_get_codepoint_bitmap_pure()` - Render character to bitmap
2. [ ] `stb_get_glyph_bitmap_pure()` - Render glyph to bitmap
3. [ ] `stb_make_codepoint_bitmap_pure()` - Render into user buffer
4. [ ] `stb_make_glyph_bitmap_pure()` - Render glyph into user buffer

**Test Strategy:**
- Character 'A' bitmap should be `138x150` pixels at test scale
- Bitmap should visually match STB output
- Memory allocation/deallocation must work correctly

**Rasterization Algorithm:**
1. Scan-line based rasterization
2. Curve tessellation for quadratic Béziers
3. Anti-aliasing using coverage calculation
4. Proper handling of winding rules

#### 🔲 Level 9: Bounding Box Calculations
**Goal:** Calculate precise bitmap bounding boxes

**Functions to implement:**
1. [ ] `stb_get_codepoint_bitmap_box_pure()` - Character bitmap bounds
2. [ ] `stb_get_glyph_bitmap_box_pure()` - Glyph bitmap bounds

**Test Strategy:**
- Bitmap bounding boxes must match STB exactly
- Test various scales and characters

### Phase 7: Subpixel Positioning

#### 🔲 Level 10: Subpixel Precision
**Goal:** Support fractional positioning for high-quality rendering

**Functions to implement:**
1. [ ] `stb_get_codepoint_bitmap_subpixel_pure()` - Subpixel positioned character
2. [ ] `stb_get_glyph_bitmap_subpixel_pure()` - Subpixel positioned glyph
3. [ ] `stb_make_codepoint_bitmap_subpixel_pure()` - Subpixel into buffer
4. [ ] `stb_make_glyph_bitmap_subpixel_pure()` - Subpixel glyph into buffer
5. [ ] `stb_get_*_bitmap_box_subpixel_pure()` - Subpixel bounding boxes

**Test Strategy:**
- Test with shift values `(0.25, 0.75)` from existing tests
- Compare bitmap dimensions: should get `110x120` for test case
- Verify subpixel positioning affects rendering quality

### Phase 8: Advanced Rendering (Optional)

#### 🔲 Level 11: Prefiltered Rendering
**Goal:** High-quality rendering with oversampling

**Functions to implement:**
1. [ ] `stb_make_codepoint_bitmap_subpixel_prefilter_pure()` - Advanced character rendering
2. [ ] `stb_make_glyph_bitmap_subpixel_prefilter_pure()` - Advanced glyph rendering

**Test Strategy:**
- Compare output quality with STB prefiltered functions
- Test various oversampling settings

## 🧪 **Testing Strategy**

### Test Evolution Approach
1. **Start with failing tests** - Modify `test_stb_comparison.f90` to expect pure success
2. **Implement incrementally** - Each function should make specific tests pass
3. **Maintain regression tests** - Previous functions must continue working
4. **Add specific validation** - Create focused tests for each new capability

### Validation Criteria
- **Exact metric matches** - Font metrics must match STB values precisely
- **Visual bitmap comparison** - Rendered bitmaps should be visually identical
- **Memory safety** - No memory leaks or segmentation faults
- **Performance baseline** - Should not be significantly slower than STB

### Test Data
- **Primary**: DejaVu Sans (known good font with existing test values)
- **Secondary**: Helvetica (test cross-platform compatibility)
- **Edge cases**: Various font formats and sizes

## 📚 **Documentation Requirements**

### Implementation Documentation
- [ ] Document TrueType file format understanding
- [ ] Algorithm documentation for rasterization
- [ ] Performance analysis and optimization notes
- [ ] Memory management strategy

### API Documentation
- [ ] Update function documentation in `fortplot_stb.f90`
- [ ] Add usage examples for complex functions
- [ ] Document differences from STB (if any)

## 🎯 **Success Criteria**

### Minimum Viable Implementation
- [ ] All 23 STB functions have working pure Fortran equivalents
- [ ] `test_stb_comparison.f90` passes with pure implementation enabled
- [ ] No regressions in existing `fortplot_text.f90` functionality
- [ ] Basic font rendering produces correct output

### Optimal Implementation
- [ ] Performance within 2x of STB for typical use cases
- [ ] Support for additional TrueType features not in STB
- [ ] Comprehensive error handling and validation
- [ ] Extensible architecture for future enhancements

## 🚀 **Implementation Priority**

**Phase 1-3 (Essential):** File I/O through font metrics - enables basic text rendering
**Phase 4-5 (Important):** Kerning and outline processing - enables quality typography
**Phase 6-7 (Critical):** Bitmap rendering - core functionality replacement
**Phase 8 (Optional):** Advanced features - quality improvements

## 📝 **Development Notes**

### Fortran-Specific Considerations
- **⚠️ CRITICAL: No unsigned integers** - Fortran lacks native unsigned types
  - Use `integer(c_int32_t)` for 32-bit values, handle overflow carefully
  - TrueType uses big-endian unsigned values - implement safe conversion functions
  - Watch for integer overflow when reading large offset values
- **⚠️ CRITICAL: 1-based indexing** - Fortran arrays start at 1, TrueType at 0
  - Add +1 to all TrueType file offsets for Fortran array access
  - Be consistent: `tables(i)%offset = read_be_uint32(font_data, offset + 8) + 1`
  - Double-check all array bounds and offset calculations
- **⚠️ Endianness handling** - TrueType is big-endian, ensure proper byte order
  - Use `read_be_uint32()`, `read_be_uint16()` functions consistently
  - Test on both little-endian (Intel) and big-endian systems if possible

### General Development
- Follow SOLID principles and 88-character line limit from `CLAUDE.md`
- Use Test-Driven Development religiously - no implementation without failing tests
- Start simple - get basic functionality working before optimizing
- Reference STB implementation for algorithm guidance but don't copy code
- Document design decisions and trade-offs
- Plan for incremental testing and validation

**Ready to begin TDD implementation of pure Fortran TrueType parser and renderer.**
