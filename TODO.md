# Pure Fortran TrueType Implementation TODO

This TODO list tracks the remaining steps to achieve a pure Fortran replacement for the STB TrueType C library, with feature parity and test-driven development.

## 📁 Source File Locations

- `thirdparty/` — Original C reference: `stb_truetype.h`
- `src/` — Fortran implementation:
    - `fortplot_stb.f90` (main API)
    - `fortplot_truetype_types.f90` (all TrueType/TTC types)
    - `fortplot_truetype_parser.f90` (all TTF/TTC parsing logic)
- `test/` — Test programs, especially `test_stb_comparison.f90`

---

## 🚦 Current Status (June 28, 2025)

- ✅ Pure Fortran implementation passes all TTF tests
- ❌ TTC files: Not yet supported by pure implementation
- 🎯 Next: Add TTC (TrueType Collection) support and finish modularization

**Test Command:** `fpm test --target test_stb_comparison`

---

## 🆕 Modularization Note (June 2025)

All TrueType/TTC types and parsing logic are now in dedicated modules:
- `src/fortplot_truetype_types.f90` — All type definitions
- `src/fortplot_truetype_parser.f90` — All parsing and binary helpers
- `src/fortplot_stb.f90` — Main API, reusing the above modules (DRY)

---

## 📝 Remaining TODOs

### Level 5: TTC (TrueType Collection) Support
- [ ] `is_ttc_file()` - Detect TTC file format ('ttcf' signature)
- [ ] `parse_ttc_header()` - Parse TTC header (version, numFonts, offsets)
- [ ] `get_ttc_font_offset()` - Get offset for specific font index
- [ ] `get_number_of_fonts()` - Count fonts in TTC
- [ ] Update all parsing and initialization to work with font-specific offsets
- [ ] Ensure all tests in `test_stb_comparison.f90` pass for both TTF and TTC fonts

### Next Phases (after TTC)
- [ ] OS/2 metrics and bounding boxes
- [ ] Kerning support
- [ ] Glyph outline parsing and bitmap rendering
- [ ] Subpixel and advanced rendering

---

**Ready to continue TDD and modular Fortran TrueType development.**
