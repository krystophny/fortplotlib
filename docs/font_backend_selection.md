# Font Backend Selection Guide

This document explains how to use the runtime font backend selection feature in fortplotlib.

## Overview

Fortplotlib supports two font rendering backends:
- **STB TrueType**: Always available, built-in font renderer
- **FreeType**: Optional, provides high-quality font rendering when available

The system automatically detects which backends are available at runtime and allows you to choose between them.

## Basic Usage

### Automatic Backend Selection

By default, fortplotlib will automatically select the best available backend:

```fortran
use fortplot_text

! This will automatically use the best available backend
call init_text_system()
```

### Manual Backend Selection

You can specify which backend to prefer:

```fortran
use fortplot_text

! Prefer FreeType if available, fallback to STB
call set_font_backend_preference("freetype")
call init_text_system()

! Explicitly use STB backend
call set_font_backend_preference("stb")
call init_text_system()
```

### Checking Backend Availability

You can check which backends are available:

```fortran
use fortplot_text

logical :: stb_available, ft_available
character(len=32) :: backends(2)
integer :: count

! Check individual backends
stb_available = check_backend_availability("stb")
ft_available = check_backend_availability("freetype")

! Get list of all available backends
call list_available_backends(backends, count)
```

### Getting Current Backend

You can check which backend is currently active:

```fortran
use fortplot_text

character(len=256) :: backend_name
call get_current_font_backend(backend_name)
print *, "Current backend: ", trim(backend_name)
```

## Fallback Behavior

The system provides intelligent fallback behavior:

1. **Preferred Backend Available**: Uses the backend you specified
2. **Preferred Backend Unavailable**: Automatically falls back to the other backend
3. **No Backends Available**: Initialization fails gracefully

## FreeType Installation

To use the FreeType backend, you need FreeType installed on your system:

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install libfreetype6-dev
```

### Linux (CentOS/RHEL)
```bash
sudo yum install freetype-devel
```

### macOS
```bash
brew install freetype
```

### Windows
FreeType can be installed via vcpkg or downloaded from the official website.

## API Reference

### Functions

- `init_text_system()` - Initialize text system with current backend preference
- `cleanup_text_system()` - Clean up text system resources
- `set_font_backend_preference(backend)` - Set preferred backend ("stb" or "freetype")
- `get_current_font_backend(backend_name)` - Get name of current backend
- `check_backend_availability(backend)` - Check if backend is available
- `list_available_backends(backends, count)` - List all available backends

### Text Rendering Functions

All text rendering functions work identically regardless of backend:

- `calculate_text_width(text)` - Calculate text width in pixels
- `calculate_text_height(text)` - Calculate text height in pixels
- `render_text_to_image(...)` - Render text to image buffer
- `render_rotated_text_to_image(...)` - Render rotated text
- `get_font_metrics(...)` - Get font metrics

## Examples

### Complete Example

```fortran
program font_backend_demo
    use fortplot_text
    implicit none
    
    logical :: success
    character(len=256) :: backend_name
    
    ! Check what's available
    if (check_backend_availability("freetype")) then
        print *, "FreeType is available"
        call set_font_backend_preference("freetype")
    else
        print *, "Using STB backend"
        call set_font_backend_preference("stb")
    end if
    
    ! Initialize text system
    success = init_text_system()
    if (success) then
        call get_current_font_backend(backend_name)
        print *, "Using backend: ", trim(backend_name)
        
        ! Use text rendering functions normally
        print *, "Text width: ", calculate_text_width("Hello, World!")
        
        call cleanup_text_system()
    else
        print *, "Failed to initialize text system"
    end if
end program
```

## FreeType Runtime Detection

FreeType detection is performed automatically when you check backend availability:

```fortran
use fortplot
logical :: available

available = check_backend_availability("freetype")
if (available) then
    print *, "FreeType is available!"
else
    print *, "FreeType is not available, using STB fallback"
end if
```

## Detection Methods

The system uses multiple methods to detect FreeType, prioritized by reliability and performance:

### 1. pkg-config Detection (Preferred)
- **Speed**: Very fast
- **Reliability**: Highest
- **Coverage**: Linux, macOS, some Windows setups
- **Requirements**: pkg-config must be installed

Uses `pkg-config --libs-only-L freetype2` to find library paths and `pkg-config --modversion freetype2` for version information.

### 2. Cross-Platform System Paths
- **Speed**: Fast
- **Reliability**: Good
- **Coverage**: Linux, macOS, Windows
- **Requirements**: Standard system installation

Checks common library locations:
- **Linux**: `/usr/lib/x86_64-linux-gnu`, `/usr/lib64`, `/usr/lib`, `/lib`
- **macOS**: `/opt/homebrew/lib`, `/usr/local/lib`, `/usr/lib`
- **Windows**: `C:\Windows\System32`, `C:\Windows\SysWOW64`

### 3. Dynamic Library Loading
- **Speed**: Moderate
- **Reliability**: Highest accuracy
- **Coverage**: All platforms
- **Requirements**: FreeType runtime library

Attempts to load FreeType library using:
- `dlopen()` on Linux/macOS
- `LoadLibrary()` on Windows (future)

### 4. Function Verification
- **Speed**: Moderate
- **Reliability**: Very high
- **Coverage**: All platforms
- **Requirements**: FreeType library loaded

Verifies availability of required FreeType functions:
- `FT_Init_FreeType`
- `FT_Done_FreeType`
- `FT_New_Face`
- `FT_Done_Face`
- `FT_Set_Pixel_Sizes`
- `FT_Load_Glyph`
- `FT_Render_Glyph`
- `FT_Get_Char_Index`

## Platform-Specific Notes

### Linux Distributions

Different Linux distributions place FreeType in different locations:

- **Debian/Ubuntu**: `/usr/lib/x86_64-linux-gnu/libfreetype.so.6`
- **RedHat/CentOS**: `/usr/lib64/libfreetype.so.6`
- **Arch Linux**: `/usr/lib/libfreetype.so.6`
- **Alpine**: `/usr/lib/libfreetype.so.6`

The detection system automatically checks all common locations.

### macOS

On macOS, FreeType is typically installed via Homebrew:

- **Apple Silicon**: `/opt/homebrew/lib/libfreetype.dylib`
- **Intel**: `/usr/local/lib/libfreetype.dylib`

### Windows

Windows support is planned with these expected locations:

- **System32**: `C:\Windows\System32\freetype.dll`
- **SysWOW64**: `C:\Windows\SysWOW64\freetype.dll`

## Troubleshooting

### FreeType Not Detected

1. **Check installation**: Verify FreeType is installed
2. **Check pkg-config**: Run `pkg-config --exists freetype2`
3. **Check library paths**: Run `pkg-config --libs-only-L freetype2`
4. **Check permissions**: Ensure read access to library files

### Debug Information

Use the debug functions to get detailed information:

```fortran
use fortplot_freetype_pkg_config
type(freetype_detection_result) :: result

call detect_freetype_cross_platform(result)
print *, "Available: ", result%available
print *, "Method: ", trim(result%method_used)
print *, "Paths: ", trim(result%library_paths)
print *, "Version: ", trim(result%version)
if (len_trim(result%error_message) > 0) then
    print *, "Error: ", trim(result%error_message)
end if
```

## Technical Details

- Backend selection happens at runtime, not compile time
- FreeType is dynamically loaded when available
- No performance penalty when FreeType is not available
- All backends provide the same API interface
- Font metrics are consistent between backends
- Detection uses multiple fallback methods for maximum compatibility
- pkg-config is preferred for speed and reliability
- Dynamic loading provides the most accurate verification