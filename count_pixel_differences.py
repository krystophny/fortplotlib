#!/usr/bin/env python3
"""Count exact pixel differences between STB and Pure bitmaps"""

def count_pixel_differences():
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
    
    # Count differences
    total_pixels = min(len(stb_pixels), len(pure_pixels))
    differences = 0
    
    for i in range(total_pixels):
        if stb_pixels[i] != pure_pixels[i]:
            differences += 1
    
    accuracy = (total_pixels - differences) * 100.0 / total_pixels
    
    print(f"Total pixels: {total_pixels}")
    print(f"Different pixels: {differences}")
    print(f"Accuracy: {accuracy:.2f}%")
    
    # Show first 10 differences for analysis
    print("\nFirst 10 differences:")
    diff_count = 0
    for i in range(total_pixels):
        if stb_pixels[i] != pure_pixels[i] and diff_count < 10:
            row = i // 20
            col = i % 20
            print(f"Pixel {i} (row {row}, col {col}): STB={stb_pixels[i]}, Pure={pure_pixels[i]}, Diff={pure_pixels[i] - stb_pixels[i]}")
            diff_count += 1

if __name__ == "__main__":
    count_pixel_differences()