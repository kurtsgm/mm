# /// script
# requires-python = ">=3.11,<3.14"
# dependencies = ["rembg[cpu]==2.0.84", "pillow==12.3.0"]
# ///
"""Rebuild Margo's transparent sprite from the checked-in full-body source.

Run: uv run art_source/npcs/margo/prepare.py
The model is downloaded to rembg's user cache on first use, never into the repo.
"""

from pathlib import Path
import json

from PIL import Image
from rembg import new_session, remove


def main():
    source_dir = Path(__file__).resolve().parent
    project = source_dir.parents[2]
    source = Image.open(source_dir / "full-body-source.webp").convert("RGB")
    result = remove(source, session=new_session("isnet-general-use"))
    # Remove near-invisible model residue outside the silhouette while preserving
    # a soft antialiased edge; otherwise alpha bounds extend to the canvas edges.
    alpha = result.getchannel("A").point(lambda value: round(max(0, value - 8) * 255 / 247))
    result.putalpha(alpha)
    if alpha.getextrema() != (0, 255) or alpha.getpixel((0, 0)) != 0:
        raise ValueError("The result must include transparent background and opaque body")
    output = project / "content/npcs/margo/idle.webp"
    output.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, "WEBP", quality=85, method=6, alpha_quality=100)
    print(json.dumps({
        "output": str(output),
        "size": result.size,
        "alpha_bbox": alpha.getbbox(),
        "foot_ratio": alpha.getbbox()[3] / result.height,
        "bytes": output.stat().st_size,
    }, indent=2))


if __name__ == "__main__":
    main()
