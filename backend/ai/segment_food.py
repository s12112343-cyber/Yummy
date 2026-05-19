from __future__ import annotations

import argparse
import json

from real_pipeline import detect_food_items, segment_food_items


def main() -> int:
    parser = argparse.ArgumentParser(description="Segment food items and estimate quantity.")
    parser.add_argument("image_path", help="Path to the image to analyze")
    parser.add_argument(
        "--detections-json",
        default="",
        help="Optional JSON string with detectedItems from the detection stage",
    )
    args = parser.parse_args()

    if args.detections_json.strip():
        payload = json.loads(args.detections_json)
        detected_items = payload.get("detectedItems", [])
    else:
        detected_items = detect_food_items(args.image_path)["detectedItems"]

    print(json.dumps(segment_food_items(args.image_path, detected_items), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
