# FASHN VTON v1.5 - Demo Guide (CPU-Only, Cloth Segmentation via U2NET)

## Overview

This guide covers running the FASHN VTON v1.5 virtual try-on model on **CPU-only** machines (no GPU required).

We replaced the `fashn-human-parser` model (non-commercial license) with **cloth-segmentation** (U2NET, MIT license) for clothing region detection.

---

## Table of Contents

1. [Clone the Repository](#1-clone-the-repository)
2. [Create Virtual Environment and Install Dependencies](#2-create-virtual-environment-and-install-dependencies)
3. [Cloth Segmentation Model (U2NET)](#3-cloth-segmentation-model-u2net)
4. [CPU-Only Configuration (Already Done)](#4-cpu-only-configuration-already-done)
5. [Download Model Weights](#5-download-model-weights)
6. [Run the Demo](#6-run-the-demo)
7. [Summary of Code Changes](#7-summary-of-code-changes)

---

## 1. Clone the Repository

```bash
git clone https://github.com/fashn-AI/fashn-vton-1.5.git
cd fashn-vton-1.5
```

---

## 2. Create Virtual Environment and Install Dependencies

```bash
# Create and activate a virtual environment
python -m venv .venv
source .venv/bin/activate

# Install the project in editable mode
pip install -e .
```

> **Note:** The `pyproject.toml` uses `onnxruntime` (CPU) instead of `onnxruntime-gpu`. So `pip install -e .` will install everything correctly for CPU-only usage.

---

## 3. Cloth Segmentation Model (U2NET)

### Why we replaced fashn-human-parser

The `fashn-human-parser` model had a **non-commercial license**, so we replaced it with `cloth-segmentation` (U2NET) which has an **MIT license**.

### How the replacement works

| Feature | fashn-human-parser (removed) | cloth-segmentation (new) |
|---------|------------------------------|--------------------------|
| Architecture | SegFormer-B4 | U2NET |
| License | Non-commercial ❌ | MIT ✅ |
| Output classes | 18 (body parts + clothing) | 4 (background + 3 clothing regions) |
| Model size | ~244 MB | ~165 MB |

The cloth-segmentation model outputs 4 classes:
- **0**: Background
- **1**: Upper body cloth (tops, jackets)
- **2**: Lower body cloth (pants, skirts)
- **3**: Full body cloth (dresses, jumpsuits)

These are mapped to the FASHN 18-class label scheme:
- `1 (upper body)` → `3 (top)`
- `2 (lower body)` → `6 (pants)`
- `3 (full body)` → `4 (dress)`

### What this enables

- ✅ **`garment_photo_type="model"`** — extracts garment from a model photo using cloth segmentation
- ✅ **`garment_photo_type="flat-lay"`** — flat-lay photos don't need segmentation
- ✅ **`segmentation_free=True`** — skips person masking entirely (recommended)
- ⚠️ **`segmentation_free=False`** — masks clothing regions but without body part identity preservation

### Files Added

| File | Purpose |
|------|---------|
| `src/fashn_vton/cloth_segmentation/__init__.py` | Package exports |
| `src/fashn_vton/cloth_segmentation/u2net.py` | U2NET architecture (44.1M params) |
| `src/fashn_vton/cloth_segmentation/segmenter.py` | `ClothSegmenter` wrapper with `predict()` method |

---

## 4. CPU-Only Configuration (Already Done)

The model **automatically detects** whether a GPU is available. On CPU-only machines:

- Weights are loaded in `float32` precision (instead of `bfloat16` on GPU)
- DWPose runs on CPU via `onnxruntime` (not `onnxruntime-gpu`)
- Inference will be **slower** but fully functional

The `pyproject.toml` has already been changed from `onnxruntime-gpu` to `onnxruntime`.

> **Note:** If you already installed `onnxruntime-gpu` by mistake, fix it with:
> ```bash
> pip uninstall onnxruntime-gpu && pip install onnxruntime
> ```

---

## 5. Download Model Weights

```bash
python scripts/download_weights.py --weights-dir ./weights
```

This downloads (~2.2 GB total):
- `weights/model.safetensors` - TryOnModel weights
- `weights/dwpose/yolox_l.onnx` - YOLOX detector for pose estimation
- `weights/dwpose/dw-ll_ucoco_384.onnx` - DWPose keypoint model
- `weights/cloth_seg/cloth_segm_u2net_latest.pth` - U2NET cloth segmentation

After download, the directory structure will be:
```
weights/
├── model.safetensors
├── dwpose/
│   ├── yolox_l.onnx
│   └── dw-ll_ucoco_384.onnx
└── cloth_seg/
    └── cloth_segm_u2net_latest.pth
```

> **Note:** The cloth segmentation weights are downloaded from Google Drive using `gdown`. If the download fails, you can manually download from [this link](https://drive.google.com/uc?id=1mhF3yqd7R-Uje092eypktNl-RoZNuiCJ) and place the file at `weights/cloth_seg/cloth_segm_u2net_latest.pth`.

---

## 6. Run the Demo

### Option A: Using the CLI Script

```bash
python examples/basic_inference.py \
    --weights-dir ./weights \
    --person-image examples/data/model.webp \
    --garment-image examples/data/garment.webp \
    --category tops \
    --garment-photo-type model \
    --device cpu \
    --num-timesteps 20 \
    --output-dir outputs
```

**Parameters:**

| Parameter | Value | Why |
|-----------|-------|-----|
| `--weights-dir` | `./weights` | Path to downloaded weights |
| `--person-image` | `examples/data/model.webp` | The person photo |
| `--garment-image` | `examples/data/garment.webp` | The garment photo |
| `--category` | `tops` | Options: `tops`, `bottoms`, `one-pieces` |
| `--garment-photo-type` | `model` | `model` for worn garments, `flat-lay` for product shots |
| `--device` | `cpu` | Force CPU (auto-detected anyway if no GPU) |
| `--num-timesteps` | `20` | Lower = faster. Use 20 for speed, 30 for quality |
| `--output-dir` | `outputs` | Where to save generated images |

> **Tip:** `--num-timesteps 20` is recommended for CPU to keep inference time reasonable.

### Option B: Python Code

```python
from fashn_vton import TryOnPipeline
from PIL import Image

# Initialize pipeline (CPU mode)
pipeline = TryOnPipeline(weights_dir="./weights", device="cpu")

# Load images
person = Image.open("examples/data/model.webp").convert("RGB")
garment = Image.open("examples/data/garment.webp").convert("RGB")

# Run inference
result = pipeline(
    person_image=person,
    garment_image=garment,
    category="tops",
    garment_photo_type="model",       # Both "model" and "flat-lay" supported
    segmentation_free=True,           # Default: recommended for best results
    num_timesteps=20,                 # Faster on CPU
    seed=42,
)

# Save output
result.images[0].save("output.png")
print("Done! Saved to output.png")
```

### Expected Output

- The model generates a photorealistic image of the person wearing the garment
- Output is saved as PNG in the specified output directory
- On CPU with 20 timesteps, expect ~5-15 minutes depending on your CPU

---

## 7. Summary of Code Changes

### What Was Removed

| Component | Reason |
|-----------|--------|
| `fashn-human-parser` dependency | Non-commercial license |
| `FashnHumanParser` model loading | Replaced with `ClothSegmenter` |
| `_setup_hp_model()` method | Replaced with `_setup_cloth_segmenter()` |
| `self.hp_model.predict()` calls | Replaced with `self.cloth_segmenter.predict()` |
| `download_human_parser()` in download script | Replaced with `download_cloth_segmentation()` |
| `onnxruntime-gpu` dependency | Replaced with `onnxruntime` for CPU |

### What Was Added

| Component | Purpose |
|-----------|---------|
| `cloth_segmentation/` module | U2NET model + ClothSegmenter wrapper |
| `ClothSegmenter.predict()` | Returns segmentation map compatible with FASHN 18-class labels |
| `download_cloth_segmentation()` | Downloads U2NET weights from Google Drive |
| Zero-array fallback | When masking is disabled, zero arrays are used (no model call needed) |

---

## Troubleshooting

### `onnxruntime-gpu` Installation Error

If you see errors related to CUDA or `onnxruntime-gpu`:

```bash
pip uninstall onnxruntime-gpu
pip install onnxruntime
```

### Out of Memory on CPU

Try reducing `num_timesteps` to `15` or `10` (quality will decrease).

### Slow Inference

CPU inference is inherently slower. Tips:
- Use `--num-timesteps 20` (minimum recommended)
- Close other applications to free up RAM
- Use a machine with more CPU cores if possible

### Missing Weights

If you see "Missing model weights" errors:

```bash
python scripts/download_weights.py --weights-dir ./weights
```

### Cloth Segmentation Download Fails

If `gdown` fails to download from Google Drive:
1. Download manually from: https://drive.google.com/uc?id=1mhF3yqd7R-Uje092eypktNl-RoZNuiCJ
2. Place at: `weights/cloth_seg/cloth_segm_u2net_latest.pth`

---

## License

The main FASHN VTON v1.5 model is licensed under **Apache-2.0**.

Third-party components used:
- [cloth-segmentation (U2NET)](https://github.com/levindabhi/cloth-segmentation) (MIT)
- [DWPose](https://github.com/IDEA-Research/DWPose) (Apache-2.0)
- [YOLOX](https://github.com/Megvii-BaseDetection/YOLOX) (Apache-2.0)
