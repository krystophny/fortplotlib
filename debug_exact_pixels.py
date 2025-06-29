#!/usr/bin/env python3
"""Debug exact pixel differences with conversion"""

def debug_pixels():
    # Read STB bitmap
    with open('stb_bitmap.pgm', 'r') as f:
        stb_lines = f.readlines()
    
    # Read Pure bitmap  
    with open('pure_bitmap.pgm', 'r') as f:
        pure_lines = f.readlines()
    
    # Skip header (P2, dimensions, max value)
    stb_pixels = []
    pure_pixels = []
    
    for line in stb_lines[3:]:  # Skip P2, dimensions, 255
        pixels = line.strip().split()
        stb_pixels.extend([int(p) for p in pixels if p])
    
    for line in pure_lines[3:]:  # Skip P2, dimensions, 255  
        pixels = line.strip().split()
        pure_pixels.extend([int(p) for p in pixels if p])
    
    # Show specific problematic pixels
    problematic_indices = [108, 114, 125, 126, 137, 142, 143, 162, 168, 174]
    
    print("Detailed analysis of problematic pixels:")
    for idx in problematic_indices:
        if idx < len(stb_pixels) and idx < len(pure_pixels):
            stb_val = stb_pixels[idx]
            pure_val = pure_pixels[idx]
            
            # Convert signed to unsigned for comparison
            stb_unsigned = stb_val if stb_val >= 0 else 256 + stb_val
            pure_unsigned = pure_val if pure_val >= 0 else 256 + pure_val
            
            row = idx // 20
            col = idx % 20
            
            print(f"Pixel {idx} (row {row}, col {col}):")
            print(f"  STB:  signed={stb_val:4d}, unsigned={stb_unsigned:3d}")
            print(f"  Pure: signed={pure_val:4d}, unsigned={pure_unsigned:3d}")
            print(f"  Diff: {pure_unsigned - stb_unsigned:4d}")
            print()

if __name__ == "__main__":
    debug_pixels()