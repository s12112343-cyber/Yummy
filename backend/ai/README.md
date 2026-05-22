# Food AI pipeline

This folder contains the staged image analysis flow used by the meal photo feature.

## Stages

1. `predict_food_items.py` - YOLOv8 food detection.
2. `segment_food.py` - FoodSAM / SAM segmentation and quantity estimation.
3. `predict_nutrition.py` - EfficientNetB3 nutrition regression.
4. `analyze_food_image.py` - Orchestrates the full pipeline, classifies the whole meal with `onnx-community/swin-finetuned-food101-ONNX`, and returns the final JSON.

## Current mode

The runtime now expects real model files. If a required model is missing, it returns a clear error instead of inventing values.

## Real model files

- `models/food_yolo.pt` for food detection.
- `models/nutrition_model.keras` for nutrition regression.
- `models/foodsam/` or a SAM checkpoint file for segmentation.

Meal classification uses the Hugging Face ONNX model `onnx-community/swin-finetuned-food101-ONNX` by default. Set `FOOD_MEAL_MODEL_ID` if you want to override it, and adjust `DETECTED_MEAL_THRESHOLD` to control when the UI shows the detected meal card.

## Run locally

```powershell
python ai/analyze_food_image.py "C:\path\to\meal.jpg"
```

If you want to use a custom Python interpreter, set `AI_PYTHON_COMMAND` in the backend environment.

Recommended environment:

- Python 3.11 or 3.12.
- `AI_PYTHON_COMMAND` pointing to that interpreter.
- `FOOD_YOLO_MODEL_PATH` pointing to `food_yolo.pt`.
- `NUTRITION_MODEL_PATH` pointing to `nutrition_model.keras`.
- `FOODSAM_CHECKPOINT_PATH` or `SAM_CHECKPOINT_PATH` for segmentation, if available.
