#!/usr/bin/env python3
"""
PetUwrite Logo Cropper
Removes text from logo image, keeping only the icon/paw portion
"""

from PIL import Image
import os

def crop_logo_text(input_path, output_path):
    """
    Crop the PetUwrite logo to remove text, keeping only the icon
    
    Args:
        input_path: Path to the original logo with text
        output_path: Path to save the cropped logo without text
    """
    try:
        # Open the image
        img = Image.open(input_path)
        print(f"✓ Loaded image: {img.size[0]}x{img.size[1]} pixels")
        
        # Get image dimensions
        width, height = img.size
        
        # The icon is typically in the top portion of the image
        # Adjust these values based on your specific logo layout
        # Default: crop to top 55% of the image (where icon usually is)
        
        # Option 1: Top 55% (if text is below)
        crop_height = int(height * 0.55)
        box = (0, 0, width, crop_height)
        
        # Option 2: If you know exact pixel coordinates, uncomment and adjust:
        # box = (left, top, right, bottom)
        # box = (0, 0, width, 300)  # Example: keep top 300 pixels
        
        # Crop the image
        cropped_img = img.crop(box)
        print(f"✓ Cropped to: {cropped_img.size[0]}x{cropped_img.size[1]} pixels")
        
        # Optional: Resize to square if needed
        # Make it square by taking the smaller dimension
        min_size = min(cropped_img.size)
        left = (cropped_img.size[0] - min_size) // 2
        top = (cropped_img.size[1] - min_size) // 2
        right = left + min_size
        bottom = top + min_size
        
        square_img = cropped_img.crop((left, top, right, bottom))
        print(f"✓ Made square: {square_img.size[0]}x{square_img.size[1]} pixels")
        
        # Save the result
        square_img.save(output_path, 'PNG')
        print(f"✓ Saved to: {output_path}")
        print(f"✓ File size: {os.path.getsize(output_path) / 1024:.1f} KB")
        
        return True
        
    except Exception as e:
        print(f"✗ Error: {e}")
        return False

def main():
    print("=" * 60)
    print("  PetUwrite Logo Cropper")
    print("  Removes text, keeps icon only")
    print("=" * 60)
    print()
    
    # Paths
    input_path = "assets/PetUwrite transparent.png"
    output_path = "assets/PetUwrite icon only.png"
    
    # Check if input exists
    if not os.path.exists(input_path):
        print(f"✗ Error: Input file not found: {input_path}")
        print(f"  Please run this script from the project root directory")
        return
    
    # Crop the logo
    print(f"📸 Processing: {input_path}")
    print()
    
    success = crop_logo_text(input_path, output_path)
    
    if success:
        print()
        print("=" * 60)
        print("✅ SUCCESS! Logo cropped successfully")
        print("=" * 60)
        print()
        print("📁 Output file: assets/PetUwrite icon only.png")
        print()
        print("🎯 Next steps:")
        print("   1. Check the cropped image")
        print("   2. If crop area is wrong, edit the 'box' values in the script")
        print("   3. Re-run the script with adjusted values")
        print()
        print("💡 To use in your app:")
        print("   Image.asset('assets/PetUwrite icon only.png')")
    else:
        print()
        print("✗ Failed to crop logo")
        print("  Try installing Pillow: pip3 install Pillow")

if __name__ == "__main__":
    main()
