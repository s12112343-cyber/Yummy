from PIL import Image
import os

# Paths (relative to this script)
base = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
in_path = os.path.join(base, 'assets', 'images', 'logo_white.png')
out_path = os.path.join(base, 'assets', 'images', 'logo_white_foreground.png')

print('Input:', in_path)
print('Output:', out_path)

if not os.path.exists(in_path):
    raise FileNotFoundError(f"Input file not found: {in_path}")

# Settings
bg_size = (1024, 1024)
scale = 1.4  # 85% of original size; adjust if needed

img = Image.open(in_path).convert('RGBA')
w, h = img.size
new_size = (int(w * scale), int(h * scale))
img = img.resize(new_size, Image.LANCZOS)

bg = Image.new('RGBA', bg_size, (0, 0, 0, 0))
pos = ((bg_size[0] - img.width) // 2, (bg_size[1] - img.height) // 2)
bg.paste(img, pos, img)
bg.save(out_path)

print('Done: created', out_path)
