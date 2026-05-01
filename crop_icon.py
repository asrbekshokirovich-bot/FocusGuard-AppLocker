import os
from PIL import Image

input_path = r"C:\Users\User\Downloads\FocusGuardIcon.png"
output_dir = r"c:\Users\User\Desktop\Saas project 1\Project app locker\assets"
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "logo.png")

try:
    img = Image.open(input_path).convert("RGBA")
    # Get bounding box of non-transparent pixels
    *rgb, a = img.split()
    bbox = a.getbbox()
    if bbox:
        img_cropped = img.crop(bbox)
        img_cropped.save(output_path)
        print(f"Success. Cropped from {img.size} to {img_cropped.size}. Saved to {output_path}")
    else:
        print("Image is entirely transparent.")
except Exception as e:
        # If Pillow is missing, try running via a quick powershell download or handle it
    print(f"Error: {e}")
