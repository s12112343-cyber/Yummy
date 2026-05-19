"""
Check presence and sizes of expected model files in backend/ai/models.
Run: python check_models.py
"""
from pathlib import Path

MODEL_DIR = Path(__file__).resolve().parent / "models"
expected = [
    ("food_yolo.pt", "YOLOv8 weights (.pt)"),
    ("nutrition_model.keras", "Nutrition regression model (.keras)"),
]

found = False
for fname, desc in expected:
    p = MODEL_DIR / fname
    if p.exists():
        print(f"FOUND: {fname} — {desc} ({p.stat().st_size} bytes)")
        found = True
    else:
        print(f"MISSING: {fname} — {desc}")

if not found:
    print("No model files found in backend/ai/models. Use download_models.py or place files there manually.")
else:
    print("If any files are missing, provide URLs to download or copy them into the folder.")
