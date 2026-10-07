"""Генерирует иконки MilkChat для Android, Web, Windows и macOS из
assets/icon/source.png (тёмно-зелёный цветок с мягкой серой тенью).
Запуск: python3 tool/make_icons.py  (нужен Pillow)"""
import os
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = Image.open(os.path.join(ROOT, 'assets/icon/source.png')).convert('RGBA')
FLOWER = (53, 83, 77)
SHADOW = (40, 36, 36)
WHITE = (255, 255, 255, 255)


def logo():
    """Цветок и его тень на прозрачном фоне: на белом выглядит как исходник."""
    px = SRC.load()
    w, h = SRC.size
    mask = Image.new('L', SRC.size, 0)
    shadow = Image.new('L', SRC.size, 0)
    pm, ps = mask.load(), shadow.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if abs(r - FLOWER[0]) + abs(g - FLOWER[1]) + abs(b - FLOWER[2]) < 40:
                pm[x, y] = 255
            v = (r + g + b) / 3
            ps[x, y] = int(max(0, min(255, (255 - v) / (255 - SHADOW[0]) * 255 * a / 255)))
    # Край цветка сглаживаем, тень под ним продолжаем, чтобы не было светлого ободка.
    mask = mask.filter(ImageFilter.GaussianBlur(0.7))
    shadow = shadow.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6))
    out = Image.new('RGBA', SRC.size, SHADOW + (0,))
    out.putalpha(shadow)
    flower = Image.new('RGBA', SRC.size, FLOWER + (255,))
    flower.putalpha(mask)
    return Image.alpha_composite(out, flower)


LOGO = logo()


def icon(size, scale=1.0):
    """Квадратная иконка на белом фоне; scale < 1 уменьшает рисунок (maskable)."""
    img = Image.new('RGBA', LOGO.size, WHITE)
    inner = LOGO.resize((int(LOGO.width * scale),) * 2, Image.LANCZOS)
    off = (LOGO.width - inner.width) // 2
    img.alpha_composite(inner, (off, off))
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


save(LOGO.resize((512, 512), Image.LANCZOS), 'assets/icon/logo.png')
save(icon(1024), 'assets/icon/icon.png')

for name, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    save(icon(px), f'android/app/src/main/res/mipmap-{name}/ic_launcher.png')

save(icon(32), 'web/favicon.png')
for px in (192, 512):
    save(icon(px), f'web/icons/Icon-{px}.png')
    save(icon(px, scale=0.8), f'web/icons/Icon-maskable-{px}.png')

icon(256).save(os.path.join(ROOT, 'windows/runner/resources/app_icon.ico'),
               sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

mac = os.path.join(ROOT, 'macos/Runner/Assets.xcassets/AppIcon.appiconset')
if os.path.isdir(mac):
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(icon(px), f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{px}.png')
print('ok')
