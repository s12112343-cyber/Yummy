from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Sequence, Tuple

try:
    import numpy as np
except Exception:  # pragma: no cover - runtime dependency only
    np = None

try:
    from PIL import Image
except Exception:  # pragma: no cover - runtime dependency only
    Image = None


try:
    import tensorflow as tf
except Exception:  # pragma: no cover - runtime dependency only
    tf = None


BASE_DIR = Path(__file__).resolve().parent
MODELS_DIR = BASE_DIR / "models"


class AIModelError(RuntimeError):
    pass


@dataclass(frozen=True)
class DetectedItem:
    name: str
    confidence: float
    bbox: Tuple[int, int, int, int]


def _normalize_name(value: str) -> str:
    return value.strip().lower().replace(" ", "_")


def _resolve_model_path(env_name: str, default_relative: str) -> Path:
    configured = os.getenv(env_name)
    if configured:
        candidate = Path(configured)
        if not candidate.is_absolute():
            candidate = MODELS_DIR / candidate
        return candidate
    return MODELS_DIR / default_relative


def _require_file(path: Path, label: str) -> Path:
    if not path.exists():
        raise AIModelError(f"Missing {label} model file: {path}")
    return path


@lru_cache(maxsize=1)
def _load_yolo_model():
    try:
        from ultralytics import YOLO
    except Exception as error:
        raise AIModelError(
            "Ultralytics is not installed. Install backend/ai/requirements.txt in Python 3.11/3.12."
        ) from error

    model_path = _require_file(
        _resolve_model_path("FOOD_YOLO_MODEL_PATH", "food_yolo.pt"),
        "YOLO food detection",
    )
    return YOLO(str(model_path))


@lru_cache(maxsize=1)
def _load_nutrition_model():
    if tf is None:
        raise AIModelError(
            "TensorFlow is not installed. Use Python 3.11/3.12 and install backend/ai/requirements.txt."
        )

    model_path = _require_file(
        _resolve_model_path("NUTRITION_MODEL_PATH", "nutrition_model.keras"),
        "nutrition regression",
    )
    return tf.keras.models.load_model(model_path)


def _load_image(image_path: str) -> Image.Image:
    if Image is None:
        raise AIModelError(
            "Pillow is not installed. Install backend/ai/requirements.txt in Python 3.11/3.12."
        )

    try:
        return Image.open(image_path).convert("RGB")
    except Exception as error:
        raise AIModelError(f"Unable to open image: {image_path}") from error


def _image_size(image_path: str) -> Tuple[int, int]:
    with _load_image(image_path) as image:
        return image.size


def detect_food_items(image_path: str) -> Dict[str, Any]:
    model = _load_yolo_model()
    results = model.predict(
        source=image_path,
        conf=float(os.getenv("FOOD_YOLO_CONF", "0.25")),
        verbose=False,
    )

    detected_items: List[Dict[str, Any]] = []
    if not results:
        return {"detectedItems": detected_items, "detectionModel": "yolov8", "image": {"path": image_path}}

    first = results[0]
    names = getattr(first, "names", {}) or {}
    boxes = getattr(first, "boxes", None)

    if boxes is None:
        return {"detectedItems": detected_items, "detectionModel": "yolov8", "image": {"path": image_path}}

    for box in boxes:
        cls_index = int(box.cls[0]) if getattr(box, "cls", None) is not None else 0
        label = _normalize_name(str(names.get(cls_index, "food")))
        confidence = float(box.conf[0]) if getattr(box, "conf", None) is not None else 0.5
        x1, y1, x2, y2 = [int(round(value)) for value in box.xyxy[0].tolist()]

        detected_items.append(
            {
                "name": label,
                "confidence": round(confidence, 2),
                "bbox": [x1, y1, x2, y2],
            }
        )

    return {
        "detectedItems": detected_items,
        "detectionModel": "yolov8",
        "image": {"path": image_path},
    }


def _load_segmentation_predictor():
    if np is None:
        raise AIModelError(
            "NumPy is not installed. Install backend/ai/requirements.txt in Python 3.11/3.12."
        )

    checkpoint = os.getenv("FOODSAM_CHECKPOINT_PATH") or os.getenv("SAM_CHECKPOINT_PATH")
    if not checkpoint:
        return None

    try:
        from segment_anything import SamPredictor, sam_model_registry
    except Exception:
        return None

    checkpoint_path = Path(checkpoint)
    if not checkpoint_path.is_absolute():
        checkpoint_path = MODELS_DIR / checkpoint_path

    if not checkpoint_path.exists():
        return None

    model_type = os.getenv("SAM_MODEL_TYPE", "vit_h")
    registry = sam_model_registry.get(model_type)
    if registry is None:
        return None

    device = os.getenv("SAM_DEVICE", "cpu").lower()
    if device not in {"cpu", "cuda"}:
        device = "cpu"
    sam = registry(checkpoint=str(checkpoint_path))
    sam.to(device=device)
    return SamPredictor(sam)


def segment_food_items(image_path: str, detected_items: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    width, height = _image_size(image_path)
    total_area = float(width * height)
    predictor = _load_segmentation_predictor()
    image = _load_image(image_path)
    items: List[Dict[str, Any]] = []

    if predictor is not None:
        predictor.set_image(np.array(image))

    for item in detected_items:
        bbox = item.get("bbox") or [0, 0, 0, 0]
        x1, y1, x2, y2 = [int(value) for value in bbox]
        confidence = float(item.get("confidence") or 0.5)
        name = _normalize_name(str(item.get("name", "food")))

        area_ratio = 0.0
        mask = None

        if predictor is not None:
            box = np.array([x1, y1, x2, y2], dtype=np.float32)
            masks, scores, _ = predictor.predict(box=box, multimask_output=False)
            if masks is not None and len(masks) > 0:
                mask = masks[0].astype(bool)
                area_ratio = float(mask.sum()) / total_area if total_area > 0 else 0.0

        if mask is None:
            bbox_area = max(1.0, float(max(0, x2 - x1) * max(0, y2 - y1)))
            area_ratio = bbox_area / total_area if total_area > 0 else 0.0

        estimated_grams = max(5.0, round(area_ratio * float(os.getenv("PLATE_REFERENCE_GRAMS", "420")), 1))

        items.append(
            {
                "name": name,
                "confidence": round(confidence, 2),
                "bbox": [x1, y1, x2, y2],
                "areaRatio": round(area_ratio, 3),
                "estimatedGrams": estimated_grams,
                "maskSource": "sam" if mask is not None else "bbox",
            }
        )

    return {
        "segmentedItems": items,
        "segmentationModel": "foodsam" if predictor is not None else "bbox",
        "image": {"width": width, "height": height, "path": image_path},
    }


def _prepare_crop(image: Image.Image, bbox: Sequence[int], target_size: Tuple[int, int]):
    if np is None or tf is None:
        raise AIModelError(
            "NumPy and TensorFlow are required for nutrition regression. Use Python 3.11/3.12."
        )

    x1, y1, x2, y2 = [int(value) for value in bbox]
    width, height = image.size
    x1 = max(0, min(x1, width - 1))
    y1 = max(0, min(y1, height - 1))
    x2 = max(x1 + 1, min(x2, width))
    y2 = max(y1 + 1, min(y2, height))

    crop = image.crop((x1, y1, x2, y2)).resize(target_size)
    array = np.asarray(crop).astype(np.float32)
    array = tf.keras.applications.efficientnet.preprocess_input(array)
    return np.expand_dims(array, axis=0)


def _predict_item_nutrition(image_path: str, item: Dict[str, Any]) -> Dict[str, float]:
    if tf is None:
        raise AIModelError(
            "TensorFlow is not installed. Use Python 3.11/3.12 and install backend/ai/requirements.txt."
        )

    model = _load_nutrition_model()
    image = _load_image(image_path)
    target_shape = getattr(model, "input_shape", None)

    if isinstance(target_shape, list):
        image_shape = target_shape[0]
    else:
        image_shape = target_shape

    if not image_shape or len(image_shape) < 3:
        image_shape = (None, 300, 300, 3)

    height = int(image_shape[1] or 300)
    width = int(image_shape[2] or 300)
    crop_batch = _prepare_crop(image, item["bbox"], (width, height))

    grams_value = np.array([[float(item.get("estimatedGrams") or 0.0)]], dtype=np.float32)

    if len(model.inputs) >= 2:
        prediction = model.predict([crop_batch, grams_value], verbose=0)
    else:
        prediction = model.predict(crop_batch, verbose=0)

    values = np.array(prediction).reshape(-1)
    if values.size < 4:
        raise AIModelError(
            f"Nutrition model must return at least 4 values, got shape {np.array(prediction).shape}"
        )

    calories, protein, carbs, fat = [float(value) for value in values[:4]]
    return {
        "calories": round(calories, 1),
        "protein": round(protein, 1),
        "carbs": round(carbs, 1),
        "fat": round(fat, 1),
    }


def predict_nutrition_from_items(image_path: str, items: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    predicted_items: List[Dict[str, Any]] = []
    totals = {
        "estimatedGrams": 0.0,
        "calories": 0.0,
        "protein": 0.0,
        "carbs": 0.0,
        "fat": 0.0,
    }

    for item in items:
        nutrition = _predict_item_nutrition(image_path, item)
        grams = float(item.get("estimatedGrams") or 0.0)

        predicted_item = {
            **item,
            **nutrition,
            "nutritionModel": "efficientnetb3",
        }

        totals["estimatedGrams"] += grams
        totals["calories"] += nutrition["calories"]
        totals["protein"] += nutrition["protein"]
        totals["carbs"] += nutrition["carbs"]
        totals["fat"] += nutrition["fat"]
        predicted_items.append(predicted_item)

    return {
        "items": predicted_items,
        "total": {
            "estimatedGrams": round(totals["estimatedGrams"], 1),
            "calories": round(totals["calories"], 1),
            "protein": round(totals["protein"], 1),
            "carbs": round(totals["carbs"], 1),
            "fat": round(totals["fat"], 1),
        },
        "nutritionModel": "efficientnetb3",
    }


def build_meal_name(items: Sequence[Dict[str, Any]]) -> str:
    names = [str(item.get("name", "food")).replace("_", " ").title() for item in items if item.get("name")]
    if not names:
        return "Estimated Meal"
    if len(names) == 1:
        return f"{names[0]} Plate"
    return f"{names[0]} and {names[1]} Plate" if len(names) == 2 else f"{names[0]} {names[1]} Plate"


def analyze_food_image(image_path: str) -> Dict[str, Any]:
    detection = detect_food_items(image_path)
    segmentation = segment_food_items(image_path, detection["detectedItems"])
    nutrition = predict_nutrition_from_items(image_path, segmentation["segmentedItems"])

    return {
        "mealName": build_meal_name(nutrition["items"]),
        "items": nutrition["items"],
        "total": nutrition["total"],
        "note": "Estimated using YOLO food detection, FoodSAM/SAM segmentation, and EfficientNetB3 nutrition regression.",
        "stages": {
            "detection": detection["detectionModel"],
            "segmentation": segmentation["segmentationModel"],
            "nutrition": nutrition["nutritionModel"],
        },
        "image": detection.get("image", {}),
    }
