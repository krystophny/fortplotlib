# DESIGN.md

## PVRG-MPEG Codec Design and Architecture

This document provides a detailed analysis of the code design and structure of the PVRG-MPEG codec implementation.

## Overall Architecture

The PVRG-MPEG codec follows a modular C design with clear separation of concerns across multiple source files. The architecture is built around a pipeline approach for both encoding and decoding MPEG-1 video streams.

### Core Design Patterns

1. **Global State Management**: Extensive use of global variables and structures to maintain encoder/decoder state (`mpeg.c:87-95`)
2. **Modular Function Design**: Each major operation (DCT, quantization, motion estimation) is isolated into dedicated modules
3. **Stream-based I/O**: Bit-level stream operations abstracted through a unified interface (`stream.c`, `system.h:30-41`)
4. **Table-driven Processing**: Huffman coding and quantization use pre-computed lookup tables

## Key Data Structures

### Image and Frame Management (`globals.h:147-186`)

**IMAGE Structure** (`globals.h:147-153`)
- `StreamFileName`: Output MPEG stream file
- `MpegMode`: Operating mode (encode/decode)  
- `Height`/`Width`: Video dimensions

**FRAME Structure** (`globals.h:155-166`)
- `ComponentFilePrefix[3][200]`: Y, U, V component file paths
- `PHeight[3]`/`PWidth[3]`: Physical component dimensions
- `hf[3]`/`vf[3]`: Horizontal/vertical sampling factors

**FSTORE Structure** (`globals.h:168-171`)
- `Iob[3]`: I/O buffers for Y, U, V components
- Used for frame buffering during motion estimation

### Memory Management (`mem.h:31-42`)

**MEM Structure** (`mem.h:37-42`)
- `data`: Raw image data pointer
- `width`/`height`: Dimensions
- `len`: Data length
- Provides unified memory abstraction for image blocks

### Bitstream I/O (`system.h:30-41`)

**IOBUF Structure** (`system.h:32-41`)
- `hpos`/`vpos`: Current position in image
- `hor`/`ver`: Block dimensions  
- `width`/`height`: Total image size
- `mem`: Pointer to underlying memory block

### Huffman Coding (`huffman.h:26-40`)

**DHUFF Structure** (Decoder) (`huffman.h:29-33`)
- `state[512]`: State transition table for decoding
- `NumberStates`: Total states in decoder FSM

**EHUFF Structure** (Encoder) (`huffman.h:35-40`)
- `Hlen`: Code lengths array
- `Hcode`: Huffman codes array
- `n`: Number of codes

### Statistics and Rate Control (`globals.h:173-186`)

**STAT Structure** (`globals.h:173-180`)
- `mean`, `mse`: Mean and mean square error
- `snr`, `psnr`, `mrsnr`: Signal-to-noise ratios
- `entropy`: Entropy measure

**RATE Structure** (`globals.h:182-186`)
- `position`, `size`: Buffer position and size
- `baseq`: Base quantization parameter

## Processing Pipeline

### Encoding Pipeline (`mpeg.c:46-49`)

1. **Main Entry Point** (`mpeg.c:46`)
   - Command line parsing and initialization

2. **Sequence Encoding** (`mpeg.c:47`)
   - `MpegEncodeSequence()`: Top-level encoding coordinator
   - Handles GOP (Group of Pictures) structure

3. **Frame Encoding** (`mpeg.c:49`)  
   - `MpegEncodeIPBDFrame()`: Encodes I, P, B, and D frames
   - Coordinates motion estimation, DCT, quantization

4. **Macroblock Processing** (`mpeg.c:73-76`)
   - `MpegEncodeMDU()`: Processes 16x16 macroblocks
   - `MpegFindMType()`: Determines macroblock coding type
   - `MpegCompressMType()`: Applies compression

### Decoding Pipeline (`mpeg.c:48,50`)

1. **Sequence Decoding** (`mpeg.c:48`)
   - `MpegDecodeSequence()`: Top-level decoder coordinator

2. **Frame Decoding** (`mpeg.c:50`)
   - `MpegDecodeIPBDFrame()`: Reconstructs video frames
   - Handles inverse quantization, IDCT, motion compensation

## Key Algorithms

### DCT Transform (`transform.c:40-53`)

**Forward DCT** (`transform.c:40`)
- `ReferenceDct()`: 8x8 forward DCT implementation
- Uses separable 1D transforms with precomputed matrices (`dct.h:41-105`)

**Inverse DCT** (`transform.c:41`)
- `ReferenceIDct()`: 8x8 inverse DCT
- Matrix coefficients stored in `dct.h:106-170`

**Quantization** (`transform.c:43-46`)
- `MPEGIntraQuantize()`/`MPEGNonIntraQuantize()`: Forward quantization
- `MPEGIntraIQuantize()`/`MPEGNonIntraIQuantize()`: Inverse quantization
- Implements MPEG-1 quantization rules with dead-zone

### Motion Estimation (`me.c:38-41`)

**Block Matching** (`me.c:39-41`)
- `BruteMotionEstimation()`: Full search motion estimation
- `HPFastBME()`: Hierarchical/fast search algorithms
- `InterpolativeBME()`: B-frame bidirectional estimation

**Motion Vector Storage** (`mpeg.c:97-100`)
- `FMX[][]`, `FMY[][]`: Forward motion vectors
- `BMX[][]`, `BMY[][]`: Backward motion vectors
- Stored per macroblock in 2D arrays

### Huffman Coding (`huffman.c:39-44`)

**Encoding** (`huffman.c:40`)
- `Encode()`: Variable length encoding using lookup tables
- Tables generated from `ctables.h` includes

**Decoding** (`huffman.c:41`)  
- `Decode()`: State machine-based VLC decoding
- No lookahead required - single bit decisions

### Run-Length Coding (`codec.c:41-46`)

**AC Coefficient Coding** (`codec.c:41,43`)
- `EncodeAC()`/`DecodeAC()`: RLE for AC coefficients
- Combined with Huffman coding for final bitstream

**DC Coefficient Coding** (`codec.c:45-46`)
- `EncodeDC()`/`DecodeDC()`: DC differential coding
- Separate Huffman tables for DC coefficients

## Bitstream Structure

### MPEG Markers (`marker.h:26-50`)

- `PSC` (0x00): Picture Start Code (`marker.h:26`)
- `VSSC` (0xb3): Video Sequence Start Code (`marker.h:32`)
- `GOPSC` (0xb8): Group of Pictures Start Code (`marker.h:44`)
- `MBSC` (1): Macroblock Start Code (`marker.h:47`)

### Header Processing (`marker.c:36-50`)

- `WriteVSHeader()`/`ReadVSHeader()`: Video sequence headers
- `WriteGOPHeader()`/`ReadGOPHeader()`: GOP headers  
- `WritePictureHeader()`/`ReadPictureHeader()`: Picture headers
- `WriteMBHeader()`/`ReadMBHeader()`: Macroblock headers

## Stream I/O Architecture (`stream.c:36-49`)

### Bit-level Operations
- `mputv()`/`mgetv()`: Variable bit width put/get (`stream.c:43-44`)
- `mputb()`/`mgetb()`: Single bit operations (`stream.c:42`)

### File Management
- `mropen()`/`mrclose()`: Read stream open/close (`stream.c:37-38`)
- `mwopen()`/`mwclose()`: Write stream open/close (`stream.c:39-40`)

### Alignment and Seeking
- `readalign()`: Byte alignment for markers (`stream.c:36`)
- `mwseek()`/`mrseek()`: Stream positioning (`stream.c:47-48`)

## Error Handling (`globals.h:113-125`)

Comprehensive error code system:
- `ERROR_HUFFMAN_READ` (2): Invalid Huffman codes
- `ERROR_MARKER` (4): Malformed MPEG markers  
- `ERROR_PREMATURE_EOF` (7): Unexpected end of stream
- `ERROR_MEMORY` (12): Memory allocation failures

## Optimization Features

### SSE2 Support (`transform.c:34-36`, `me.c:32-34`)
- Conditional compilation for SIMD acceleration
- Enhanced DCT and motion estimation performance

### Memory Efficiency
- Bounded value macros (`mem.h:44-54`) prevent overflow
- Efficient block-based memory allocation

## Global State Variables (`mpeg.c:87-150`)

### Frame Stores (`mpeg.c:87-95`)
- `CFStore`: Current frame being processed
- `CFSBase`/`CFSNext`: Reference frames for motion compensation
- `CFSMid`: Interpolated frame for B-pictures

### MPEG Parameters (`mpeg.c:115-139`)
- `HorizontalSize`/`VerticalSize`: Video dimensions
- `Prate`: Picture rate (frame rate)
- `Brate`: Bit rate for rate control
- `PType`: Picture type (I/P/B/D)

### Quantization Control (`mpeg.c:141-150`)
- `SQuant`: Slice quantization parameter
- `MType`: Current macroblock type
- Rate control variables for quality management

This architecture demonstrates a well-structured approach to MPEG-1 video compression, with clear separation between algorithmic components and efficient stream processing capabilities.