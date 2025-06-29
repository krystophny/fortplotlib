# FAIL.md - ForTTF Routines That Actually Fail Tests

This document lists all forttf routines that have been tested and **ACTUALLY FAIL** their test suites.

## ❌ FAILING - Font Initialization Issues (6/18 tests failing)

### Font Loading Failures
Multiple tests fail due to font file access issues:

**Test Target**: `test_forttf_pixel_analysis` ❌
- Font initialization failed with Monaco.ttf
- STOP 1 error

**Test Target**: `test_forttf_offset_debug` ❌  
- Font initialization failed with Monaco.ttf
- STOP 1 error

**Test Target**: `test_forttf_edge_debug` ❌
- Font initialization failed with Monaco.ttf
- STOP 1 error

**Test Target**: `test_forttf_exact_stb_validation` ❌
- STB validation failed - discrepancy found
- Font initialization issues in validation steps
- STOP 1 error

**Test Target**: `test_forttf_bitmap_content` ❌
- Letter 'A' bitmap content does NOT match STB reference
- Indicates placeholder shapes instead of real text
- ERROR STOP 1

## ❌ FAILING - Pixel Accuracy Issues

### Y-Coordinate Offset Problem
**Current Issue**: Pure Fortran bitmap is shifted down by exactly 310 pixels compared to STB
**Test Results**: Match percentage: 81.66% (was 52.94% before offset fix)
**Impact**: Significant improvement from offset fix, but systematic shift remains

### Pixel Difference Analysis
- Total pixels: 452,408
- STB non-zero: 170,738  
- Pure non-zero: 169,208
- Pixel differences: 82,990
- Large negative differences (-255): 39,595 pixels (STB has content, Pure is empty)
- Large positive differences (+255): 38,089 pixels (Pure has content, STB is empty)

**Root Cause**: Y-coordinate transformation still has systematic offset despite recent fixes

## 🔧 RECENT PROGRESS - Coordinate System Fixes

### Fixed Issues:
✅ **Removed double Y-flip**: Fixed redundant Y-coordinate flipping in bitmap writing
✅ **Corrected offset signs**: Changed from `-xoff, -yoff` to `xoff, yoff` to match STB
✅ **Improved accuracy**: Match percentage improved from ~53% to ~82%

### Remaining Issue:
❌ **310-pixel vertical shift**: Pure implementation consistently shifted down by exactly 310 pixels
- Suggests systematic offset calculation error
- Both implementations have identical dimensions and offsets in output
- Issue likely in rasterization coordinate application, not bounding box calculation

## Root Cause Analysis

### Primary Issues:
1. **Font File Compatibility**: Monaco.ttf vs Helvetica.ttc path differences
2. **Y-Coordinate Offset**: Systematic 310-pixel vertical displacement  
3. **Pixel Filling Logic**: Some regions filled in Pure but empty in STB

### Font Loading Pattern:
- Tests using Helvetica.ttc: ✅ Working (test_forttf_simple_bitmap, test_forttf_debug_bitmap)
- Tests using Monaco.ttf: ❌ Failing (test_forttf_pixel_analysis, test_forttf_offset_debug)

## Priority Order for Implementation:

1. **CRITICAL**: Fix font loading failures (Monaco.ttf access issues)
2. **HIGH**: Debug 310-pixel Y-coordinate offset 
3. **MEDIUM**: Investigate pixel filling differences causing ~18% mismatch
4. **LOW**: Fine-tune remaining edge cases for pixel-perfect accuracy

## Testing Commands

### Currently Failing Tests
```bash
# Font initialization failures
fpm test --target test_forttf_pixel_analysis      # Monaco.ttf loading issue
fpm test --target test_forttf_offset_debug        # Monaco.ttf loading issue  
fpm test --target test_forttf_edge_debug          # Monaco.ttf loading issue
fpm test --target test_forttf_exact_stb_validation # Monaco.ttf + validation issues
fmp test --target test_forttf_bitmap_content      # Content mismatch

# Working tests for comparison
fpm test --target test_forttf_bitmap_export       # Works with Monaco.ttf
fpm test --target test_forttf_simple_bitmap       # Works with Helvetica.ttc
```

## Summary

**Current Status**: 72% pass rate (12/18 tests)

**Major Progress**: 
- ✅ Coordinate system largely fixed
- ✅ Bitmap rendering pipeline functional  
- ✅ Y-flipping logic corrected
- ✅ Offset calculation improvements

**Remaining Issues**:
- ❌ Font file access inconsistencies
- ❌ 310-pixel systematic Y-offset
- ❌ ~18% pixel accuracy gap (down from ~47%)

**Key Insight**: The Pure Fortran implementation is very close to STB accuracy. The remaining issues appear to be edge cases rather than fundamental algorithmic problems.