"""Генерирует иконки MilkChat (волнистый тёмно-зелёный пузырь на ярко-зелёном фоне)
для Android, Web, Windows, macOS и Linux.  Запуск: python3 tool/make_icons.py"""
import math
import os
from PIL import Image, ImageDraw

BG = (34, 221, 68)
FG = (27, 82, 48)
ROOT = os.path.join(os.path.dirname(__file__), '..')


def bubble_points(size, cx=0.5, cy=0.47, r=0.30, lobes=12, depth=0.03):
    pts = []
    for i in range(720):
        a = 2 * math.pi * i / 720
        rr = r + depth * abs(math.cos(lobes / 2 * a))
        pts.append(((cx + rr * math.cos(a)) * size, (cy + rr * math.sin(a)) * size))
    return pts


def draw_icon(size, background=True, scale=1.0):
    ss = 4
    s = size * ss
    img = Image.new('RGBA', (s, s), BG + (255,) if background else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = 0.30 * scale
    d.polygon(bubble_points(s, r=r, depth=0.03 * scale), fill=FG)
    # хвостик в левом нижнем углу
    cx, cy = 0.5, 0.47
    tail = [
        ((cx - r * 0.62) * s, (cy + r * 0.55) * s),
        ((cx - r * 0.86) * s, (cy + r * 1.30) * s),
        ((cx - r * 0.15) * s, (cy + r * 0.92) * s),
    ]
    d.polygon(tail, fill=FG)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    path = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


master = draw_icon(1024)
save(master, 'assets/icon/icon.png')
save(draw_icon(1024, background=False), 'assets/icon/foreground.png')

for name, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    save(draw_icon(px), f'android/app/src/main/res/mipmap-{name}/ic_launcher.png')

save(draw_icon(32), 'web/favicon.png')
for px in (192, 512):
    save(draw_icon(px), f'web/icons/Icon-{px}.png')
    save(draw_icon(px, scale=0.8), f'web/icons/Icon-maskable-{px}.png')

master.save(os.path.join(ROOT, 'windows/runner/resources/app_icon.ico'),
            sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

mac = os.path.join(ROOT, 'macos/Runner/Assets.xcassets/AppIcon.appiconset')
if os.path.isdir(mac):
    for px in (16, 32, 64, 128, 256, 512, 1024):
        save(draw_icon(px), f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{px}.png')
print('ok')
