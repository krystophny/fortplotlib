# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

- **Build the program**: `make` - Compiles all source files and creates the `mpeg` executable
- **Clean build artifacts**: `make clean` - Removes object files and the executable
- **Lint check**: `make lcheck` - Runs lint on all C source files to check for potential issues

## Testing

- **Test decoder**: `mpeg -d -s short.mpg short` - Decodes the test sequence `short.mpg` into component files
- **Test encoder**: `mpeg -a 0 -b 6 short -s short2.mpg` - Encodes component files back to MPEG format
- **Expected output files**: `short0.Y`, `short0.U`, `short0.V` through `short6.Y`, `short6.U`, `short6.V` (352x240 Y, 176x120 U/V)

## Architecture

This is the PVRG-MPEG codec (Portable Video Research Group), a complete MPEG-1 encoder/decoder implementation in C from Stanford University, circa 1993.

### Core Components

- **`mpeg.c`**: Main entry point and high-level encoding/decoding routines
- **`codec.c`**: Core MPEG coding algorithms and quantization
- **`huffman.c`**: Huffman entropy coding implementation
- **`transform.c`**: DCT transform and inverse transform operations  
- **`me.c`**: Motion estimation algorithms including telescopic search
- **`marker.c`**: MPEG bitstream parsing and marker handling
- **`stream.c`**: Bitstream I/O operations
- **`io.c`**: File I/O and buffer management

### Key Headers

- **`globals.h`**: Global definitions and structures
- **`system.h`**: I/O buffer definitions
- **`dct.h`**: DCT transform tables and definitions
- **`huffman.h`**: Huffman coding tables
- **`qtables.h`**: Quantization tables

### Data Flow

1. **Encoding**: Raw YUV component files → DCT transform → Quantization → Huffman coding → MPEG bitstream
2. **Decoding**: MPEG bitstream → Huffman decoding → Inverse quantization → Inverse DCT → YUV component files

The codec operates on YCbCr (YUV) 4:2:0 format files and supports all MPEG frame types (I, P, B frames) with motion compensation and rate control.

### Build System

Uses a traditional Unix Makefile with:
- Compiler flags: `-O` (optimization)
- Dependencies tracked for header files
- Lint support for code quality checking
- Manual lexer generation (commented out) for Huffman table modification