from __future__ import annotations

import argparse
import json

from real_pipeline import detect_food_items


def main() -> int:
    parser = argparse.ArgumentParser(description="Detect food items in an image.")
    parser.add_argument("image_path", help="Path to the image to analyze")
    args = parser.parse_args()

    print(json.dumps(detect_food_items(args.image_path), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
