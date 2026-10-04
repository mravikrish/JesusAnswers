"""Builds assets/stories/ — one picture per Bible Story — from the originals in art/stories/,
and assets/books/ — one picture per book of the Bible — from the originals in art/books/.

Usage:  python tool/build_story_images.py

Originals are named after the story id (art/stories/<id>.png or .jpg) or the book code
(art/books/GEN.png, art/books/1SA.jpg …) and are never changed. Each is resized to at most
MAX_SIZE on its longer side (sharp on a phone, whether it is the full-width picture at the
top of a story or a card in the list), flattened onto the night-sky colour if it has
transparency, and saved as a progressive JPEG — a fraction of the size of a PNG, which
keeps the APK small.

Every story needs its picture. A book without one yet is listed and skipped: the app shows
its story's picture, or a painting of Jesus, until it has its own. Each book's 'scene' in
tool/bible/books.json describes the picture to make.
"""
import io
import json
import os
import sys

from PIL import Image

MAX_SIZE = 1080
QUALITY = 78
MIDNIGHT = (0x0A, 0x14, 0x30)


def build(src, out, ids, label, required):
    os.makedirs(src, exist_ok=True)
    os.makedirs(out, exist_ok=True)
    originals = {os.path.splitext(f)[0]: f for f in os.listdir(src)
                 if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp'))}
    missing = [i for i in ids if i not in originals]
    if missing and required:
        sys.exit(f'✗ no picture in {src}/ for: {", ".join(missing)}')
    if missing:
        print(f'  · no picture yet in {src}/ for {len(missing)} of {len(ids)}: {", ".join(missing)}')
    for extra in sorted(set(originals) - set(ids)):
        print(f'  · {originals[extra]} matches no {label} — skipped')

    before = after = 0
    built = [i for i in ids if i in originals]
    for item in built:
        path = os.path.join(src, originals[item])
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
        open(os.path.join(out, f'{item}.jpg'), 'wb').write(buf.getvalue())
        before += os.path.getsize(path)
        after += len(buf.getvalue())
        print(f'▸ {item:16} {im.width}×{im.height}  {os.path.getsize(path) / 1e6:5.1f} MB → {len(buf.getvalue()) / 1e3:4.0f} KB')

    # Remove pictures left over from stories or books that no longer have an original.
    for f in os.listdir(out):
        if f.endswith('.jpg') and os.path.splitext(f)[0] not in built:
            os.remove(os.path.join(out, f))
    print(f'✓ {len(built)} {label} pictures, {before / 1e6:.1f} MB → {after / 1e6:.1f} MB')


def main():
    stories = [s['id'] for s in json.load(open('tool/bible/stories.json', encoding='utf-8'))['stories']]
    build('art/stories', 'assets/stories', stories, 'story', required=True)
    books = [b['code'] for b in json.load(open('tool/bible/books.json', encoding='utf-8'))['books']]
    build('art/books', 'assets/books', books, 'book', required=False)


if __name__ == '__main__':
    main()
