from PIL import Image
import os

src_path = '/Users/rebuild/.gemini/antigravity/scratch/test_with_shadow.png'
res_dir = '/Users/rebuild/.gemini/antigravity/scratch/MedReminder/Resources'
img = Image.open(src_path).convert('RGBA')

# 1. Menu bar icon: 18pt @2x = 36x36 px
menu_icon = img.resize((36, 36), Image.Resampling.LANCZOS)
menu_icon.save(os.path.join(res_dir, 'menu_icon.png'), 'PNG')
print("Saved menu_icon.png (36x36)")

# 2. Row icon: 26pt @3x = 78x78 px
row_icon = img.resize((78, 78), Image.Resampling.LANCZOS)
row_icon.save(os.path.join(res_dir, 'row_icon.png'), 'PNG')
print("Saved row_icon.png (78x78)")

# 3. Empty state icon: 52pt @3x = 156x156 px
empty_icon = img.resize((156, 156), Image.Resampling.LANCZOS)
empty_icon.save(os.path.join(res_dir, 'empty_icon.png'), 'PNG')
print("Saved empty_icon.png (156x156)")

print("All optimized assets generated successfully!")
