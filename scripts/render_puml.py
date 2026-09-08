"""Render a PlantUML source file to PNG via the public PlantUML server.

Usage:
    python scripts/render_puml.py docs/diagrams/figure-01-use-case.puml
    python scripts/render_puml.py input.puml output.png
"""

import sys
import zlib
import urllib.request
from pathlib import Path

PLANTUML_URL = 'http://www.plantuml.com/plantuml/png/~1{}'


def encode64(data: bytes) -> str:
    chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_'
    out = []
    for i in range(0, len(data), 3):
        b1, b2, b3 = data[i], data[i + 1:i + 2], data[i + 2:i + 3]
        b2 = b2[0] if b2 else 0
        b3 = b3[0] if b3 else 0
        out.append(chars[b1 >> 2])
        out.append(chars[((b1 & 0x3) << 4) | (b2 >> 4)])
        if i + 1 < len(data):
            out.append(chars[((b2 & 0xF) << 2) | (b3 >> 6)])
        if i + 2 < len(data):
            out.append(chars[b3 & 0x3F])
    return ''.join(out)


def render(puml_path: Path, png_path: Path) -> None:
    text = puml_path.read_text(encoding='utf-8')
    compressed = zlib.compress(text.encode('utf-8'))[2:-4]
    url = PLANTUML_URL.format(encode64(compressed))
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(request) as response:
        data = response.read()
    if data.startswith(b'<'):
        raise RuntimeError(f'PlantUML server returned an error page for {puml_path}')
    png_path.write_bytes(data)
    print(f'Rendered {puml_path} -> {png_path} ({len(data)} bytes)')


def main() -> None:
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    puml_path = Path(sys.argv[1])
    png_path = Path(sys.argv[2]) if len(sys.argv) == 3 else puml_path.with_suffix('.png')
    render(puml_path, png_path)


if __name__ == '__main__':
    main()
