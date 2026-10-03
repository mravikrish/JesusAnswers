"""Builds assets/stories/ — one picture per Bible Story — from the originals in art/stories/.

Usage:  python tool/build_story_images.py

Originals are named after the story id (art/stories/<id>.png or .jpg) and are never
changed. Each is resized to at most MAX_SIZE on its longer side (sharp on a phone,
whether it is the full-width picture at the top of a story or a card in the list),
flattened onto the night-sky colour if it has transparency, and saved as a
progressive JPEG — a fraction of the size of a PNG, which keeps the APK small.
"""
import io
import json
import os
import sys

from PIL import Image

SRC = 'art/stories'
OUT = 'assets/stories'
MAX_SIZE = 1080
QUALITY = 78
MIDNIGHT = (0x0A, 0x14, 0x30)


def main():
    os.makedirs(OUT, exist_ok=True)
    ids = [s['id'] for s in json.load(open('tool/bible/stories.json', encoding='utf-8'))['stories']]
    originals = {os.path.splitext(f)[0]: f for f in os.listdir(SRC)
                 if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))}
    missing = [i for i in ids if i not in originals]
    if missing:
        sys.exit(f'✗ no picture in {SRC}/ for: {", ".join(missing)}')
    for extra in sorted(set(originals) - set(ids)):
        print(f'  · {originals[extra]} matches no story id — skipped')

    before = after = 0
    for story_id in ids:
        path = os.path.join(SRC, originals[story_id])
        im = Image.open(path)
        if im.mode in ('RGBA', 'LA', 'P'):
            im = im.convert('RGBA')
            bg = Image.new('RGB', im.size, MIDNIGHT)
            bg.paste(im, mask=im.getchannel('A'))
            im = bg
        else:
            im = im.convert('RGB')
        im.thumbnail((MAX_SIZE, MAX_SIZE), Image.LANCZOS)
        buf = io.BytesIO()
        im.save(buf, 'JPEG', quality=QUALITY, optimize=True, progressive=True)
        out = os.path.join(OUT, f'{story_id}.jpg')
        open(out, 'wb').write(buf.getvalue())
        before += os.path.getsize(path)
        after += len(buf.getvalue())
        print(f'▸ {story_id:16} {im.width}×{im.height}  {os.path.getsize(path) / 1e6:5.1f} MB → {len(buf.getvalue()) / 1e3:4.0f} KB')

    # Remove pictures left over from stories that no longer exist.
    for f in os.listdir(OUT):
        if os.path.splitext(f)[0] not in ids:
            os.remove(os.path.join(OUT, f))
    print(f'✓ {len(ids)} story pictures, {before / 1e6:.1f} MB → {after / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
