from pathlib import Path
import subprocess
import zlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "docs" / "deliverable3_assets"
ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"


def encode3(b1, b2, b3):
    c1 = b1 >> 2
    c2 = ((b1 & 0x3) << 4) | (b2 >> 4)
    c3 = ((b2 & 0xF) << 2) | (b3 >> 6)
    c4 = b3 & 0x3F
    return ALPHABET[c1] + ALPHABET[c2] + ALPHABET[c3] + ALPHABET[c4]


def encode64(data):
    result = []
    for index in range(0, len(data), 3):
        chunk = data[index:index + 3]
        if len(chunk) == 1:
            result.append(encode3(chunk[0], 0, 0)[:2])
        elif len(chunk) == 2:
            result.append(encode3(chunk[0], chunk[1], 0)[:3])
        else:
            result.append(encode3(*chunk))
    return "".join(result)


def plantuml_url(source):
    compressed = zlib.compress(source.encode("utf-8"), 9)[2:-4]
    return "https://www.plantuml.com/plantuml/png/" + encode64(compressed)


def run(*args):
    browser_cli = r"C:\Users\anoti\AppData\Roaming\npm\agent-browser.cmd"
    subprocess.run([browser_cli, "--session", "folio-d3", *args], check=True)


def crop_browser_background(path):
    image = Image.open(path).convert("RGB")
    pixels = image.load()
    left, top, right, bottom = 0, 0, image.width, image.height

    def dark_row(y):
        samples = [pixels[x, y] for x in range(0, image.width, max(1, image.width // 100))]
        return sum(max(rgb) < 35 for rgb in samples) / len(samples) > 0.85

    def dark_col(x):
        samples = [pixels[x, y] for y in range(0, image.height, max(1, image.height // 100))]
        return sum(max(rgb) < 35 for rgb in samples) / len(samples) > 0.85

    while top < bottom and dark_row(top):
        top += 1
    while bottom > top and dark_row(bottom - 1):
        bottom -= 1
    while left < right and dark_col(left):
        left += 1
    while right > left and dark_col(right - 1):
        right -= 1
    image.crop((left, top, right, bottom)).save(path)


for source_path in sorted(ASSETS.glob("*.puml")):
    output_path = source_path.with_suffix(".png")
    run("open", plantuml_url(source_path.read_text(encoding="utf-8")))
    run("wait", "--load", "networkidle")
    run("screenshot", "--full", str(output_path))
    crop_browser_background(output_path)
    print(output_path)

run("close")
