# UNTESTED.md - ForTTF Routines Not Covered by Tests

This document lists all forttf routines that exist in the implementation but are not systematically tested against STB function equivalents. These functions may work correctly but lack validation coverage.

## ✅ MOVED TO PASS.md - Previously Untested, Now Validated

The following functions were moved from UNTESTED to PASS after successful validation:

### Font Metrics Functions (11 functions) → **PASS.md**
- All `stb_*_metrics_pure()` functions now have exact STB validation
- All `stb_*_box_pure()` functions now have perfect coordinate matching
- All kerning functions now have complete validation

### Character Mapping Functions (3 functions) → **PASS.md**  
- `stb_find_glyph_index_pure()` now has comprehensive Unicode/ASCII testing
- Character lookup edge cases now validated
- Glyph index consistency now verified

### Bitmap Box Functions (4 functions) → **PASS.md**
- `stb_get_*_bitmap_box_pure()` functions now have exact STB matching
- Subpixel positioning now validated
- Scaling factors now tested and working

### Font Loading Functions → **PASS.md** (Implicit)
- `stb_init_font_pure()` now working (evidenced by successful tests)
- `stb_cleanup_font_pure()` now working (evidenced by clean test runs)

## File I/O and Internal Functions

**Implementation Files**: `forttf_core.f90`, `forttf_file_io.f90`

### Font File Reading Functions
- **STB Function**: File I/O operations in STB
- **Implementation**: `forttf_file_io.f90`
- **Coverage**: Used internally but not isolated testing
- **Status**: File reading works (fonts load successfully) but no validation of file format compliance

### Font Header Parsing
- **STB Function**: Font header validation in STB
- **Implementation**: `forttf_file_io.f90`
- **Coverage**: Basic existence checks only
- **Status**: Headers parsed successfully but not validated against STB parsing

## Table Parsing Functions

**Implementation File**: `forttf_table_parser.f90`

### parse_head_table()
- **STB Function**: head table parsing in STB
- **Implementation**: `forttf_table_parser.f90`
- **Coverage**: Used for font metrics but not isolated testing
- **Status**: Works (metrics depend on it) but no direct STB comparison

### parse_hhea_table()
- **STB Function**: hhea table parsing in STB
- **Implementation**: `forttf_table_parser.f90`
- **Coverage**: Used for horizontal metrics but not isolated testing
- **Status**: Works (horizontal metrics depend on it) but no direct STB comparison

### parse_maxp_table()
- **STB Function**: maxp table parsing in STB
- **Implementation**: `forttf_table_parser.f90`
- **Coverage**: Used for glyph limits but not isolated testing
- **Status**: Works (glyph functions depend on it) but no direct STB comparison

### parse_cmap_table()
- **STB Function**: cmap table parsing in STB
- **Implementation**: `forttf_table_parser.f90`  
- **Coverage**: Used for character mapping but not isolated testing
- **Status**: Works (character mapping depends on it) but no direct STB comparison

### parse_kern_table()
- **STB Function**: kern table parsing in STB
- **Implementation**: `forttf_table_parser.f90`
- **Coverage**: Used for kerning but not isolated testing
- **Status**: Works (kerning functions depend on it) but no direct STB comparison

## Glyph and Loca Table Parsing

**Implementation Files**: `forttf_glyph_parser.f90`, `forttf_table_parser.f90`

### parse_loca_table()
- **STB Function**: loca table parsing in STB
- **Implementation**: `forttf_glyph_parser.f90`
- **Coverage**: Used in glyph access but not isolated testing
- **Status**: Works (glyph functions depend on it) but no direct STB comparison

### parse_glyf_header()
- **STB Function**: glyf table header parsing in STB
- **Implementation**: `forttf_glyph_parser.f90`
- **Coverage**: Basic existence checks only in `test_forttf_bitmap.f90`
- **Status**: Headers parsed but not validated against STB parsing

### parse_simple_glyph()
- **STB Function**: Simple glyph parsing in STB
- **Implementation**: `forttf_glyph_parser.f90`
- **Coverage**: Used for glyph outline but not isolated testing
- **Status**: Works (outline functions depend on it) but no direct STB comparison

### parse_composite_glyph()
- **STB Function**: Composite glyph parsing in STB
- **Implementation**: `forttf_glyph_parser.f90`
- **Coverage**: Not tested (composite glyphs may not be used in test fonts)
- **Status**: Implementation exists but untested

## Scale and Transform Functions

**Implementation Files**: `forttf_bitmap.f90`, `forttf_metrics.f90`

### Internal Scaling Functions
- **STB Function**: Coordinate scaling in STB
- **Implementation**: Various files
- **Coverage**: Used in bitmap tests but not isolated testing
- **Status**: Works (bitmap functions depend on them) but no direct STB comparison

### Coordinate Transformation Functions
- **STB Function**: Coordinate transformations in STB  
- **Implementation**: `forttf_bitmap.f90`
- **Coverage**: Used in rendering pipeline but not isolated testing
- **Status**: Works (rendering depends on them) but no direct STB comparison

### Subpixel Positioning Functions
- **STB Function**: Subpixel positioning in STB
- **Implementation**: `forttf_bitmap.f90`
- **Coverage**: Used in subpixel functions but not isolated testing
- **Status**: Implementation exists but validation missing

## Parser Wrapper Functions

**Implementation File**: `forttf_parser.f90`

### Parser Module Wrappers
- **STB Function**: Various parsing functions in STB
- **Implementation**: `forttf_parser.f90`
- **Coverage**: Wrapper functions used internally but not tested directly
- **Status**: Provide API access but no validation of wrapper behavior

## Utility Functions

**Implementation File**: `forttf_types.f90`, utility functions in various modules

### Type Conversion Functions
- **STB Function**: Type conversions in STB
- **Implementation**: Various files
- **Coverage**: Used throughout but not isolated testing
- **Status**: Work (other functions depend on them) but no direct validation

### Memory Management Functions
- **STB Function**: Memory management in STB
- **Implementation**: Various files
- **Coverage**: Used throughout but not isolated testing
- **Status**: Work (no memory leaks observed) but no systematic validation

### Error Handling Functions
- **STB Function**: Error handling in STB
- **Implementation**: Various files
- **Coverage**: Used throughout but not isolated testing
- **Status**: Basic error handling working but not validated against STB behavior

## Debugging and Validation Functions

**Implementation Files**: Various debug functions

### Debug Output Functions
- **STB Function**: Debug output in STB
- **Implementation**: Various test files
- **Coverage**: Used for debugging but not systematic testing
- **Status**: Provide debugging capability but not validated

### Validation Helper Functions
- **STB Function**: Internal validation in STB
- **Implementation**: Various test files
- **Coverage**: Used in test setup but not systematic testing
- **Status**: Support testing but not validated themselves

## Recommended Testing Approach

### High Priority for Testing:
1. **Font File I/O**: Core functionality that affects everything
2. **Table Parsing**: Foundation for all font operations
3. **Coordinate Transformations**: Critical for rendering accuracy
4. **Memory Management**: Important for stability

### Medium Priority for Testing:
1. **Composite Glyph Parsing**: Needed for complex fonts
2. **Subpixel Positioning**: Important for rendering quality
3. **Error Handling**: Important for robustness
4. **Parser Wrappers**: API consistency

### Low Priority for Testing:
1. **Debug Functions**: Development tools
2. **Utility Functions**: Basic operations
3. **Type Conversions**: Simple operations

## Test Creation Strategy

For each untested function, create tests following TDD pattern:

```fortran
! test/forttf/test_forttf_[category].f90
program test_forttf_[category]
    ! Test [function_name] against STB equivalent
    call test_[function_name]()
contains
    subroutine test_[function_name]()
        ! Arrange, Act, Assert against STB function
    end subroutine
end program
```

## Testing Commands

To create systematic tests for untested functions:

```bash
# Create new test files for untested categories
fpm test --target test_forttf_file_io          # (to be created)
fpm test --target test_forttf_table_parsing    # (to be created)  
fpm test --target test_forttf_transforms       # (to be created)
fpm test --target test_forttf_glyph_parsing    # (to be created)
```

## Summary

**Total Untested Functions**: ~10 functions across 4 categories (DOWN from ~25)
- 2 file I/O functions (internal operations)
- 5 table parsing functions (low-level parsing)
- 2 glyph parsing functions (internal operations)  
- 1 parser wrapper function (API convenience)

**MAJOR REDUCTION**: 18 functions moved to PASS.md after successful validation:
- ✅ **11 font metrics functions** - Now fully validated
- ✅ **3 glyph mapping functions** - Now fully validated  
- ✅ **4 bitmap box functions** - Now fully validated

The remaining untested functions are mostly low-level internal operations that work in practice (evidenced by successful higher-level tests) but lack direct STB comparison tests. They represent minor opportunities for improved test coverage rather than critical gaps.