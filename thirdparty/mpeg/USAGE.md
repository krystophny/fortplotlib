# MPEG Encoder API Usage

This document describes how to use the PVRG-MPEG codec API to encode a sequence of bitmaps in memory to an MPEG video file.

## Overview

The PVRG-MPEG codec requires YUV 4:2:0 format input data and produces MPEG-1 compliant video streams. To encode bitmap sequences, you need to:

1. Convert your bitmaps to YUV 4:2:0 format
2. Initialize the codec structures
3. Configure encoding parameters
4. Provide frame data through the I/O buffer system
5. Execute the encoding sequence

## API Structure

### Core Data Structures

```c
#include "globals.h"

// Global structures (defined as extern in globals.h)
IMAGE *CImage;      // Current image configuration
FRAME *CFrame;      // Frame component definitions  
FSTORE *CFStore;    // Frame storage buffers
```

### Key Functions

```c
// Structure initialization
void MakeImage();           // Initialize image structure
void MakeFrame();           // Initialize frame structure  
void MakeFStore();          // Initialize frame storage

// Encoding functions
void MpegEncodeSequence();  // Encode complete sequence
void MpegEncodeIPBDFrame(); // Encode single frame

// I/O functions
void ReadFS();              // Read frame data from files
void WriteFS();             // Write frame data to files
```

## Basic Encoding Workflow

### 1. Initialize Structures

```c
#include "globals.h"

// Initialize codec structures
MakeImage();
MakeFrame();

// Configure image parameters
CImage->Width = 352;        // Frame width (must be multiple of 16)
CImage->Height = 240;       // Frame height (must be multiple of 16)
CImage->StreamFileName = "output.mpg";  // Output MPEG file
CImage->MpegMode = 0;       // Standard MPEG mode

// Configure frame components (Y, U, V)
CFrame->NumberComponents = 3;

// Component 0: Y (Luminance) - full resolution
CFrame->Width[0] = 352;
CFrame->Height[0] = 240;
CFrame->PWidth[0] = 352;    // Picture width
CFrame->PHeight[0] = 240;   // Picture height
strcpy(CFrame->ComponentFilePrefix[0], "frame");
strcpy(CFrame->ComponentFileSuffix[0], ".Y");

// Component 1: U (Chrominance) - quarter resolution  
CFrame->Width[1] = 176;
CFrame->Height[1] = 120;
CFrame->PWidth[1] = 176;
CFrame->PHeight[1] = 120;
strcpy(CFrame->ComponentFilePrefix[1], "frame");
strcpy(CFrame->ComponentFileSuffix[1], ".U");

// Component 2: V (Chrominance) - quarter resolution
CFrame->Width[2] = 176;
CFrame->Height[2] = 120;
CFrame->PWidth[2] = 176;
CFrame->PHeight[2] = 120;
strcpy(CFrame->ComponentFilePrefix[2], "frame");
strcpy(CFrame->ComponentFileSuffix[2], ".V");
```

### 2. Configure Encoding Parameters

```c
// Set global encoding parameters (defined in mpeg.c)
extern int StartFrame, LastFrame;
extern int FrameSkip, FrameInterval;
extern int InitialQuant;
extern int Rate, BufferSize;

StartFrame = 0;             // First frame number
LastFrame = 29;             // Last frame number (30 frames total)
FrameSkip = 1;              // Frame skip factor
FrameInterval = 2;          // P-frame interval
InitialQuant = 10;          // Initial quantization (2-31)
Rate = 0;                   // Bit rate (0 = variable rate)
BufferSize = 327680;        // VBV buffer size
```

### 3. Provide Frame Data

The codec expects YUV component files for each frame. For in-memory bitmaps:

```c
// Convert your bitmap data to YUV 4:2:0 format
void convert_bitmap_to_yuv(unsigned char *rgb_data, int width, int height,
                          unsigned char *y_data, unsigned char *u_data, unsigned char *v_data)
{
    // RGB to YUV conversion (ITU-R BT.601)
    for (int i = 0; i < width * height; i++) {
        unsigned char r = rgb_data[i*3];
        unsigned char g = rgb_data[i*3+1]; 
        unsigned char b = rgb_data[i*3+2];
        
        y_data[i] = (unsigned char)(0.299 * r + 0.587 * g + 0.114 * b);
    }
    
    // Subsample chrominance (4:2:0)
    for (int y = 0; y < height; y += 2) {
        for (int x = 0; x < width; x += 2) {
            int idx = (y/2) * (width/2) + (x/2);
            int src_idx = y * width + x;
            
            unsigned char r = rgb_data[src_idx*3];
            unsigned char g = rgb_data[src_idx*3+1];
            unsigned char b = rgb_data[src_idx*3+2];
            
            u_data[idx] = (unsigned char)(-0.147 * r - 0.289 * g + 0.436 * b + 128);
            v_data[idx] = (unsigned char)(0.615 * r - 0.515 * g - 0.100 * b + 128);
        }
    }
}

// Write YUV data to temporary files for each frame
void write_frame_components(int frame_num, unsigned char *y_data, 
                           unsigned char *u_data, unsigned char *v_data)
{
    char filename[256];
    FILE *fp;
    
    // Write Y component
    sprintf(filename, "frame%d.Y", frame_num);
    fp = fopen(filename, "wb");
    fwrite(y_data, 1, 352 * 240, fp);
    fclose(fp);
    
    // Write U component  
    sprintf(filename, "frame%d.U", frame_num);
    fp = fopen(filename, "wb");
    fwrite(u_data, 1, 176 * 120, fp);
    fclose(fp);
    
    // Write V component
    sprintf(filename, "frame%d.V", frame_num);
    fp = fopen(filename, "wb");
    fwrite(v_data, 1, 176 * 120, fp);
    fclose(fp);
}
```

### 4. Execute Encoding

```c
// Encode the sequence
MpegEncodeSequence();

// Clean up temporary files
for (int i = StartFrame; i <= LastFrame; i++) {
    char filename[256];
    sprintf(filename, "frame%d.Y", i);
    unlink(filename);
    sprintf(filename, "frame%d.U", i);
    unlink(filename);
    sprintf(filename, "frame%d.V", i);
    unlink(filename);
}
```

## Complete Example

```c
#include "globals.h"

int main() {
    // Initialize codec
    MakeImage();
    MakeFrame();
    
    // Configure for 352x240 MPEG
    CImage->Width = 352;
    CImage->Height = 240;
    CImage->StreamFileName = "output.mpg";
    
    // Set up YUV components
    setup_yuv_components();
    
    // Configure encoding parameters
    StartFrame = 0;
    LastFrame = 29;
    InitialQuant = 10;
    
    // Convert bitmap sequence to YUV files
    for (int i = 0; i <= 29; i++) {
        unsigned char *bitmap = load_bitmap(i);  // Your bitmap loading function
        unsigned char *y_data = malloc(352 * 240);
        unsigned char *u_data = malloc(176 * 120);
        unsigned char *v_data = malloc(176 * 120);
        
        convert_bitmap_to_yuv(bitmap, 352, 240, y_data, u_data, v_data);
        write_frame_components(i, y_data, u_data, v_data);
        
        free(y_data);
        free(u_data);
        free(v_data);
    }
    
    // Encode to MPEG
    MpegEncodeSequence();
    
    // Clean up
    cleanup_temp_files();
    
    return 0;
}
```

## Notes

- Frame dimensions must be multiples of 16 for MPEG compliance
- The codec expects YUV 4:2:0 format (Y at full resolution, U/V at quarter resolution)
- Temporary files are required as the codec reads frame data from files
- Rate control can be enabled by setting the `Rate` parameter (bits/second)
- Quantization values range from 2 (high quality) to 31 (low quality)