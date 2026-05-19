from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any, Dict, List

import requests


BASE_DIR = Path(__file__).resolve().parent
BACKEND_DIR = BASE_DIR.parent
ENV_FILE = BACKEND_DIR / ".env"


class AIModelError(RuntimeError):
    pass


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")

        if key and key not in os.environ:
            os.environ[key] = value


def _require_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise AIModelError(f"Missing required environment variable: {name}")
    return value


def _prediction_bbox(prediction: Dict[str, Any]) -> List[float]:
    if {"x", "y", "width", "height"}.issubset(prediction):
        x = float(prediction["x"])
        y = float(prediction["y"])
        width = float(prediction["width"])
        height = float(prediction["height"])
        return [x - (width / 2.0), y - (height / 2.0), x + (width / 2.0), y + (height / 2.0)]

    if "bbox" in prediction and isinstance(prediction["bbox"], (list, tuple)):
        bbox = list(prediction["bbox"])
        if len(bbox) >= 4:
            return [float(bbox[0]), float(bbox[1]), float(bbox[2]), float(bbox[3])]

    return [0.0, 0.0, 0.0, 0.0]


def _estimate_total_grams(raw_result: Any, image_width: float, image_height: float) -> float:
    if isinstance(raw_result, dict):
        predictions = raw_result.get("predictions") or raw_result.get("results") or []
    elif hasattr(raw_result, "predictions"):
        predictions = getattr(raw_result, "predictions") or []
    elif isinstance(raw_result, list):
        predictions = raw_result
    else:
        predictions = []

    total_area = max(1.0, float(image_width) * float(image_height))
    total_grams = 0.0

    for prediction in predictions:
        if not isinstance(prediction, dict):
            continue

        x1, y1, x2, y2 = _prediction_bbox(prediction)
        bbox_area = max(0.0, (x2 - x1) * (y2 - y1))
        area_ratio = bbox_area / total_area
        total_grams += max(5.0, round(area_ratio * 420.0, 1))

    return round(total_grams, 1)


def _normalize_item_name(prediction: Dict[str, Any]) -> str:
    value = prediction.get("class") or prediction.get("label") or prediction.get("name") or "AI estimated meal"
    return str(value).strip() or "AI estimated meal"


def _estimate_item_grams(prediction: Dict[str, Any], image_width: float, image_height: float) -> float:
    total_area = max(1.0, float(image_width) * float(image_height))
    x1, y1, x2, y2 = _prediction_bbox(prediction)
    bbox_area = max(0.0, (x2 - x1) * (y2 - y1))
    area_ratio = bbox_area / total_area
    return round(max(5.0, round(area_ratio * 420.0, 1)), 1)


def _extract_predictions(raw_result: Any) -> List[Dict[str, Any]]:
    if isinstance(raw_result, dict):
        predictions = raw_result.get("predictions") or raw_result.get("results") or []
    elif hasattr(raw_result, "predictions"):
        predictions = getattr(raw_result, "predictions") or []
    elif isinstance(raw_result, list):
        predictions = raw_result
    else:
        predictions = []

    return [prediction for prediction in predictions if isinstance(prediction, dict)]


def analyze_food_image(image_path: str) -> Dict[str, Any]:
    _load_env_file(ENV_FILE)

    api_key = _require_env("ROBOFLOW_API_KEY")
    model_id = _require_env("ROBOFLOW_MODEL_ID")
    api_url = _require_env("ROBOFLOW_API_URL")

    request_url = f"{api_url.rstrip('/')}/{model_id.lstrip('/')}"
    raw_result = None

    # Prefer inference_sdk client if available (user requested). Fall back to requests.
    try:
        InferenceHTTPClient = None
        try:
            # Try direct import form most users expect
            from inference_sdk import InferenceHTTPClient as InferenceHTTPClient  # type: ignore
        except Exception:
            try:
                import inference_sdk  # type: ignore
                InferenceHTTPClient = getattr(inference_sdk, "InferenceHTTPClient", None)
            except Exception:
                InferenceHTTPClient = None

        if InferenceHTTPClient is not None:
            try:
                client = InferenceHTTPClient(api_url=api_url, api_key=api_key)
                # Try passing file-like first, otherwise pass path
                try:
                    with open(image_path, "rb") as f:
                        raw_result = client.infer(f, model_id=model_id)
                except Exception:
                    raw_result = client.infer(image_path, model_id=model_id)
            except Exception:
                # If inference client usage fails, fall back to HTTP requests
                raw_result = None

        if raw_result is None:
            with open(image_path, "rb") as image_file:
                response = requests.post(
                    request_url,
                    params={"api_key": api_key, "format": "json"},
                    files={"file": image_file},
                    headers={
                        "User-Agent": "RoboflowAnalyzer/1.0",
                        "Accept": "application/json",
                    },
                    timeout=120,
                )

            if response.status_code >= 400:
                raise AIModelError(f"Roboflow HTTP {response.status_code}: {response.text}")

            raw_result = response.json()
    except requests.RequestException as error:
        raise AIModelError(f"Roboflow request failed: {error}") from error
    except ValueError as error:
        raise AIModelError("Roboflow returned invalid JSON") from error

    image_meta = raw_result.get("image") if isinstance(raw_result, dict) else {}
    image_width = float((image_meta or {}).get("width") or 1)
    image_height = float((image_meta or {}).get("height") or 1)
    predictions = _extract_predictions(raw_result)

    def _prediction_confidence(pred: Dict[str, Any]) -> float:
        for k in ("confidence", "score", "probability"):
            if k in pred:
                try:
                    return float(pred.get(k) or 0.0)
                except Exception:
                    continue
        return 0.0

    def _format_bbox(pred: Dict[str, Any]) -> List[int]:
        x1, y1, x2, y2 = _prediction_bbox(pred)
        # clamp and convert to ints
        try:
            return [int(round(x1)), int(round(y1)), int(round(x2)), int(round(y2))]
        except Exception:
            return [0, 0, 0, 0]

    items = [
        {
            "name": _normalize_item_name(prediction),
            "confidence": round(_prediction_confidence(prediction), 4),
            "bbox": _format_bbox(prediction),
        }
        for prediction in predictions
    ]

    if not items:
        items = [
            {
                "name": "AI estimated meal",
                "confidence": 0.0,
                "bbox": [0, 0, 0, 0],
            }
        ]

    return {
        "success": True,
        "model": "roboflow-food-ingredients",
        "items": items,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze a food image with Roboflow.")
    parser.add_argument("image_path", help="Path to the image to analyze")
    args = parser.parse_args()

    try:
        result = analyze_food_image(args.image_path)
    except Exception as error:
        payload = {
            "success": False,
            "model": "roboflow-food-ingredients",
            "items": [],
            "message": str(error),
        }
        print(json.dumps(payload, ensure_ascii=False))
        return 1

    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
