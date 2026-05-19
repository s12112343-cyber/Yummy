from __future__ import annotations

import argparse
import json

from real_pipeline import detect_food_items, predict_nutrition_from_items, segment_food_items


def main() -> int:
	parser = argparse.ArgumentParser(description="Predict nutrition from detected food items.")
	parser.add_argument("image_path", nargs="?", default="", help="Path to the image file")
	parser.add_argument(
		"--items-json",
		default="",
		help="Optional JSON string of segmented items from the segmentation stage",
	)
	args = parser.parse_args()

	items = []
	if args.items_json.strip():
		payload = json.loads(args.items_json)
		items = payload.get("segmentedItems", payload.get("items", []))
	elif args.image_path.strip():
		detections = detect_food_items(args.image_path)
		items = segment_food_items(args.image_path, detections["detectedItems"])["segmentedItems"]

	if not args.image_path.strip():
		raise SystemExit("image_path is required when no items JSON is provided")

	print(json.dumps(predict_nutrition_from_items(args.image_path, items), ensure_ascii=False))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

