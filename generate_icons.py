import os
import shutil
import subprocess
from PIL import Image

src_path = '/Users/rebuild/.gemini/antigravity/scratch/test_with_shadow.png'
iconset_dir = '/Users/rebuild/.gemini/antigravity/scratch/MedReminder/Resources/AppIcon.iconset'
icns_path = '/Users/rebuild/.gemini/antigravity/scratch/MedReminder/Resources/AppIcon.icns'

os.makedirs(iconset_dir, exist_ok=True)
img = Image.open(src_path).convert('RGBA')

sizes = [
    (16, 'icon_16x16.png'),
    (32, 'icon_16x16@2x.png'),
    (32, 'icon_32x32.png'),
    (64, 'icon_32x32@2x.png'),
    (128, 'icon_128x128.png'),
    (256, 'icon_128x128@2x.png'),
    (256, 'icon_256x256.png'),
    (512, 'icon_256x256@2x.png'),
    (512, 'icon_512x512.png'),
    (1024, 'icon_512x512@2x.png'),
]

for size, filename in sizes:
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(os.path.join(iconset_dir, filename), 'PNG')
    print(f"Generated {filename} ({size}x{size})")

# Run iconutil
cmd = ['iconutil', '-c', 'icns', iconset_dir, '-o', icns_path]
subprocess.check_call(cmd)
print(f"Successfully generated {icns_path}")
