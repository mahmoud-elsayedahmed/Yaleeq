"""Pre-loaded person models registry.

This file defines the fixed set of person/mannequin images available
for virtual try-on. Users select a model from this list — they don't
upload their own person images.

To add a new model:
  1. Place the image in api/model_images/
  2. Add an entry to the MODELS dict below
  3. Restart the server

Flutter: Fetch the list via GET /api/v1/models — no need to hardcode these.
"""

import os
from typing import Dict, Any

# ──────────────────────────────────────────────────────────────────────────────
# Model Images Directory
# ──────────────────────────────────────────────────────────────────────────────
MODEL_IMAGES_DIR = os.path.join(os.path.dirname(__file__), "model_images")

# ──────────────────────────────────────────────────────────────────────────────
# Models Registry
# ──────────────────────────────────────────────────────────────────────────────
# Each model has:
#   - name: Display name (shown to the user in Flutter)
#   - image_filename: Filename in the model_images/ directory
#   - gender: "male" | "female" | "unisex"
#   - supported_categories: Which garment types work with this model
#
# NOTE: The image file MUST exist in api/model_images/ — the server will
#       fail to start if any referenced image is missing.
# ──────────────────────────────────────────────────────────────────────────────

MODELS: Dict[str, Dict[str, Any]] = {
    # ── Women ────────────────────────────────────────────────────────────
    "woman_01": {
        "name": "Woman - Style 1",
        "image_filename": "woman1.jpeg",
        "gender": "female",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    "woman_02": {
        "name": "Woman - Style 2",
        "image_filename": "woman2.jpeg",
        "gender": "female",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    # ── Men ──────────────────────────────────────────────────────────────
    "man_01": {
        "name": "Man - Casual",
        "image_filename": "man.jpeg",
        "gender": "male",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    # ── Kids ─────────────────────────────────────────────────────────────
    "boy_01": {
        "name": "Little Boy",
        "image_filename": "little_boy.jpeg",
        "gender": "male",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    "girl_01": {
        "name": "Little Girl",
        "image_filename": "little_girl.jpeg",
        "gender": "female",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    "boy_02": {
        "name": "Mid Boy",
        "image_filename": "mid_boy.jpeg",
        "gender": "male",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    "girl_02": {
        "name": "Mid Girl",
        "image_filename": "mid_girl.jpeg",
        "gender": "female",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    # ── Mannequins ───────────────────────────────────────────────────────
    "mannequin_women": {
        "name": "Women Mannequin",
        "image_filename": "women_Mannequin.png",
        "gender": "female",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    "mannequin_man": {
        "name": "Man Mannequin",
        "image_filename": "man_Mannequin.png",
        "gender": "male",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
    "mannequin_child": {
        "name": "Child Mannequin",
        "image_filename": "child_Mannequin.png",
        "gender": "unisex",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
    },
}


def get_model_image_path(model_id: str) -> str:
    """Get the full path to a model's image file.

    Args:
        model_id: The model identifier (e.g. 'woman_01')

    Returns:
        Absolute path to the image file.

    Raises:
        KeyError: If model_id is not found in the registry.
        FileNotFoundError: If the image file doesn't exist on disk.
    """
    if model_id not in MODELS:
        raise KeyError(f"Model '{model_id}' not found. Available: {list(MODELS.keys())}")

    image_path = os.path.join(MODEL_IMAGES_DIR, MODELS[model_id]["image_filename"])

    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Model image not found: {image_path}")

    return image_path


def validate_all_models() -> list[str]:
    """Validate that all registered model images exist on disk.

    Returns:
        List of missing image paths (empty if all are valid).
    """
    missing = []
    for model_id, info in MODELS.items():
        image_path = os.path.join(MODEL_IMAGES_DIR, info["image_filename"])
        if not os.path.exists(image_path):
            missing.append(f"{model_id}: {image_path}")
    return missing
