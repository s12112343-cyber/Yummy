"""
Run a quick AI environment check.

Checks:
- Python version
- import ultralytics, tensorflow, PIL, cv2, numpy
- existence of backend/ai/models/food_yolo.pt and backend/ai/models/nutrition_model.keras

Usage:
  python test_ai_environment.py

The script exits with 0 when imports succeed (even if model files are missing),
but prints clear messages about missing model files. If imports fail, it prints
the import error details.
"""
from __future__ import annotations

import sys
import platform
from pathlib import Path


def check_import(name: str):
    try:
        module = __import__(name)
        return True, f"OK: imported {name} ({getattr(module, '__version__', 'version unknown')})"
    except Exception as e:
        return False, f"MISSING: {name} import failed: {e}"


def main():
    print("AI environment test")
    print("Python:", platform.python_version())

    checks = [
        ("ultralytics", "ultralytics"),
        ("tensorflow", "tensorflow"),
        ("PIL", "PIL"),
        ("cv2", "cv2"),
        ("numpy", "numpy"),
    ]

    any_fail = False
    for label, name in checks:
        ok, msg = check_import(name)
        print(msg)
        if not ok:
            any_fail = True

    models_dir = Path(__file__).resolve().parent / "models"
    yolo = models_dir / "food_yolo.pt"
    nutrition = models_dir / "nutrition_model.keras"

    if yolo.exists():
        print(f"FOUND: {yolo} ({yolo.stat().st_size} bytes)")
    else:
        print(f"MISSING: {yolo} — Place the real YOLO food model at this path.")

    if nutrition.exists():
        print(f"FOUND: {nutrition} ({nutrition.stat().st_size} bytes)")
    else:
        print(f"MISSING: {nutrition} — Place the trained nutrition regression model here.")

    if any_fail:
        print("One or more imports failed. Fix Python environment before running real inference.")
        return 2

    print("Environment import checks passed. Model files may still be missing — see messages above.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
