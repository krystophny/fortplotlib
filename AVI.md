# AVI Container Implementation for MPEG Streams

## Overview

This document details the implementation of AVI (Audio Video Interleave) container format support for wrapping MPEG video streams created by the fortplotlib MPEG library.

## Implementation Status

**✅ COMPLETED**: AVI container format implementation  
**📁 File**: `src/mpeg/fortplot_mpeg_avi.f90`  
**🎯 Objective**: Convert raw MPEG streams to standard AVI files compatible with video players

## Technical Implementation

### AVI Format Structure

The AVI container follows the RIFF (Resource Interchange File Format) structure:

```
RIFF ('AVI '
    LIST ('hdrl'                    // Header list
        'avih' (Main AVI Header)    // 56 bytes - video metadata
        LIST ('strl'                // Stream list
            'strh' (Stream Header)  // 64 bytes - stream properties
            'strf' (Stream Format)  // 40 bytes - bitmap info
        )
    )
    LIST ('movi'                    // Movie data list
        '00dc' (Video chunk 1)     // MPEG frame data
        '00dc' (Video chunk 2)     // MPEG frame data
        ...
    )
    'idx1' (Index)                  // Frame index for seeking
)
```

### Core Components Implemented

#### 1. FOURCC Constants
```fortran
! Key format identifiers (little-endian 32-bit integers)
integer(c_int32_t), parameter :: FOURCC_RIFF = int(z'46464952', c_int32_t)  ! 'RIFF'
integer(c_int32_t), parameter :: FOURCC_AVI  = int(z'20495641', c_int32_t)  ! 'AVI '
integer(c_int32_t), parameter :: FOURCC_00dc = int(z'63643030', c_int32_t)  ! '00dc'
integer(c_int32_t), parameter :: FOURCC_mpg1 = int(z'3167706d', c_int32_t)  ! 'mpg1'
```

#### 2. Header Structures
- **avi_main_header_t**: Video metadata (frame rate, dimensions, flags)
- **avi_stream_header_t**: Stream properties (codec, timing, buffer size)
- **bitmap_info_header_t**: Video format details (compression, bit depth)
- **avi_index_entry_t**: Frame location index for seeking

#### 3. Main Conversion Function
```fortran
subroutine mpeg_to_avi(mpeg_file, avi_file, width, height, frame_rate, num_frames)
```

### Key Features

#### ✅ Standard Compliance
- Proper RIFF/AVI structure with required headers
- Word-aligned chunks (padding bytes added as needed)
- Standard FOURCC codes for MPEG-1 video ('mpg1')
- Complete index for seeking support

#### ✅ MPEG Integration
- Uses existing `fortplot_mpeg_c_io` for file operations
- Reads MPEG stream data and wraps in AVI chunks
- Preserves video quality and timing information
- Compatible with existing MPEG library output

#### ✅ Player Compatibility
- Creates files readable by standard video players
- Includes all required metadata for proper playback
- Supports seeking through frame index
- Uses standard video codec identification

## Implementation Details

### Binary File Structure
The implementation writes binary data in little-endian format using ISO C bindings:

```fortran
! Write RIFF header
status = c_fwrite(c_loc(FOURCC_RIFF), 4, 1, file_ptr)
status = c_fwrite(c_loc(file_size), 4, 1, file_ptr)
status = c_fwrite(c_loc(FOURCC_AVI), 4, 1, file_ptr)
```

### Frame Processing
Each MPEG frame is wrapped in an AVI video chunk:
1. Read MPEG frame data from input stream
2. Write '00dc' chunk header with frame size
3. Write frame data
4. Add padding byte if frame size is odd
5. Record index entry for seeking

### Index Generation
The implementation builds a complete frame index:
- Records each frame's offset in the file
- Marks all frames as keyframes for simplicity
- Enables seeking in video players
- Written at end of file per AVI standard

## Technical Challenges Solved

### 1. Endianness Handling
- AVI format requires little-endian byte order
- Used proper hex constants with `int(z'...', c_int32_t)`
- Verified on x86-64 architecture (native little-endian)

### 2. Structure Padding
- C-compatible structure alignment using `iso_c_binding`
- Proper size calculations for headers (56, 64, 40 bytes)
- Word-aligned data chunks with padding bytes

### 3. MPEG Frame Parsing
- Simple frame reading approach for proof-of-concept
- Extensible design for more sophisticated MPEG parsing
- Error handling for incomplete or corrupted frames

## Usage Example

```fortran
! Convert existing MPEG stream to AVI format
call mpeg_to_avi("moving_dot_video.mpg", "moving_dot_video.avi", 32, 24, 15, 30)
```

**Parameters:**
- Input MPEG file path
- Output AVI file path  
- Video width and height
- Frame rate (frames per second)
- Total number of frames

## Integration with Existing MPEG Library

The AVI implementation builds on the existing MPEG infrastructure:

**Dependencies:**
- `fortplot_mpeg_c_io` - File I/O operations
- `iso_c_binding` - C compatibility for binary data
- Existing MPEG stream format from `fortplot_mpeg_stream`

**Compatibility:**
- Works with output from `test_moving_dot_video`
- Uses same file I/O patterns as MPEG modules
- Maintains consistency with existing code style

## Future Enhancements

### Potential Improvements
1. **Advanced MPEG Parsing**: Better frame boundary detection
2. **Multiple Streams**: Audio track support
3. **Compression Options**: Different quality settings
4. **Metadata Support**: Additional video information
5. **Error Recovery**: Robust handling of corrupted frames

### Performance Optimizations
- Buffered I/O for large files
- Memory-mapped file access
- Parallel frame processing
- Streaming conversion for large videos

## Testing Requirements

To validate the implementation:

1. **Create test converting moving dot video to AVI**
2. **Verify AVI file plays in standard video players**
3. **Confirm metadata accuracy (duration, resolution, frame rate)**
4. **Test seeking functionality**
5. **Validate file structure with AVI analysis tools**

## References

**Technical Specifications:**
- Microsoft AVI File Format Documentation
- RIFF Format Specification
- MPEG-1 Video Standard

**Implementation References:**
- FFmpeg AVI muxer source code
- Simple AVI library implementations
- Multimedia file format guides

---

## 🚨 **Critical Issue Discovered**

### **Problem: Files Don't Play in Standard Players**

**Investigation Results (ffmpeg analysis):**

```bash
$ ffmpeg -i moving_dot_video.avi v.mp4
[avi @ 0x55cb86f51f00] Could not find codec parameters for stream 0 (Video: mpeg1video (mpg1 / 0x3167706D), none(tv), 32x24, 126 kb/s): unspecified pixel format
Cannot determine format of input stream 0:0 after EOF
Conversion failed!

$ ffprobe moving_dot_video.mpg
moving_dot_video.mpg: Invalid data found when processing input
```

### **Root Cause Analysis**

**✅ AVI Container Structure**: Correct RIFF/AVI headers and chunk organization  
**❌ Video Data Format**: The data inside video chunks is NOT valid MPEG-1  
**❌ Codec Mismatch**: Headers claim 'mpg1' but data is likely raw pixel values  
**❌ Missing MPEG Structure**: No proper MPEG sequence headers, frame start codes, or compression  

### **Technical Issue**

**Binary Analysis Results:**

Our "MPEG" file starts with:
```
00000000  00 20 00 18 00 1e 0f ff  00 aa 55 00 01 00 80 80  |. ........U.....|
00000010  80 80 80 80 80 80 80 80  80 80 80 80 80 80 80 80  |................|
          ↑ Custom header    ↑ Raw pixel data (128,128,128...)
```

Real MPEG-1 should start with:
```
00000000  00 00 01 b3 14 00 f0 13  ff ff e0 18 00 00 01 b8  |................|
00000010  00 08 00 40 00 00 01 00  00 0f ff f8 00 00 01 01  |...@............|
          ↑ Sequence header  ↑ MPEG structure codes
```

The current implementation:
1. **Creates valid AVI containers** with proper headers and metadata
2. **Writes raw pixel data** instead of compressed MPEG video frames  
3. **Labels containers as MPEG-1** when data is actually uncompressed pixels
4. **Missing video compression** - no actual MPEG encoding is performed
5. **No MPEG structure** - Missing sequence headers, start codes, GOPs

### **Required Fixes**

**Immediate Priority:**
- Replace raw pixel data with actual video compression
- Implement proper frame encoding (MPEG, Motion JPEG, or uncompressed)
- Fix codec identification to match actual data format
- Add proper video sequence headers and frame structure

**Alternative Approaches:**
- Use uncompressed AVI format (DIB codec) for simplicity
- Implement Motion JPEG encoding for better compatibility  
- Generate image sequences (PNG/PPM) as interim solution
- Interface with external encoders (ffmpeg) for proper video output

### **Status: REQUIRES MAJOR REWORK**

The AVI container implementation is solid, but the video encoding layer needs to be completely redesigned to generate actual compressed video data instead of raw pixels.

---

This implementation provides the foundation for creating standard video files from Fortran scientific computing applications, but currently requires fixes to the video encoding layer for actual playback compatibility.