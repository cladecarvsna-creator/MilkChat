"""Генерирует иконки MilkChat для Android, Web, Windows и macOS из
assets/icon/source.png (тёмно-зелёный цветок на ярко-зелёном фоне).
Запуск: python3 tool/make_icons.py  (нужен Pillow)"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = Image.open(os.path.join(ROOT, 'assets/icon/source.png')).convert('RGBA')
BG = SRC.getpixel((4, 4))


def icon(size, scale=1.0):
    """Квадратная иконка; scale < 1 уменьшает рисунок (для maskable-иконок)."""
    if scale == 1.0:
        return SRC.resize((size, size), Image.LANCZOS)
    img = Image.new('RGBA', SRC.size, BG)
    inner = SRC.resize((int(SRC.width * scale),) * 2, Image.LANCZOS)
    off = (SRC.width - inner.width) // 2
    img.paste(inner, (off, off))
    return img.resize((size, size), Image.LANCZOS)


def foreground():
    """Только цветок на прозрачном фоне."""
    px = SRC.load()
    out = Image.new('RGBA', SRC.size, (0, 0, 0, 0))
    po = out.load()
    for y in range(SRC.height):
        for x in range(SRC.width):
            r, g, b, a = px[x, y]
            if g < 200:  # всё, что не ярко-зелёный фон
                po[x, y] = (r, g, b, a)
    return out


def save(img, path):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


save(icon(1024), 'assets/icon/icon.png')
save(foreground().resize((1024, 1024), Image.LANCZOS), 'assets/icon/foreground.png')

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
