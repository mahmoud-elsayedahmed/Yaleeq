# FASHN VTON v1.5 - Changes Summary & Demo Guide

## What Was Done

### 1. Replaced `fashn-human-parser` with `cloth-segmentation` (U2NET)

The original `fashn-human-parser` model (SegFormer-B4, non-commercial license) was removed.
We replaced it with **`cloth-segmentation`** (U2NET, MIT license) from [levindabhi/cloth-segmentation](https://github.com/levindabhi/cloth-segmentation).

| Model | Architecture | License | Classes | Size |
|-------|-------------|---------|---------|------|
| fashn-human-parser (removed) | SegFormer-B4 | **Non-commercial** ❌ | 18 (body parts + clothing) | ~244 MB |
| cloth-segmentation (new) | U2NET | **MIT** ✅ | 4 (background, upper, lower, full body cloth) | ~165 MB |

**How the mapping works:**

| cloth-segmentation class | → | FASHN 18-class label |
|---|---|---|
| 0 (background) | → | 0 (background) |
| 1 (upper body cloth) | → | 3 (top) |
| 2 (lower body cloth) | → | 6 (pants) |
| 3 (full body cloth) | → | 4 (dress) |

### 2. CPU-Only Configuration

- Changed `onnxruntime-gpu` to `onnxruntime` in [pyproject.toml](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/pyproject.toml)
- The pipeline auto-detects CPU and uses `float32` precision

---

## Files Created

| File | Purpose |
|------|---------|
| [cloth_segmentation/__init__.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/cloth_segmentation/__init__.py) | Package init, exports `ClothSegmenter` |
| [cloth_segmentation/u2net.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/cloth_segmentation/u2net.py) | U2NET architecture (44.1M params, 4-channel output) |
| [cloth_segmentation/segmenter.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/cloth_segmentation/segmenter.py) | `ClothSegmenter` wrapper class with `predict()` method |

## Files Modified

| File | Change |
|------|--------|
| [agnostic.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/preprocessing/agnostic.py) | Removed `from fashn_human_parser import ...`, defined all constants locally |
| [preprocessing/__init__.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/preprocessing/__init__.py) | Added `CATEGORY_TO_BODY_COVERAGE` export |
| [pipeline.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py) | Added `ClothSegmenter` loading, uses real segmentation instead of zero arrays |
| [pyproject.toml](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/pyproject.toml) | Removed `fashn-human-parser`, changed `onnxruntime-gpu` to `onnxruntime` |
| [download_weights.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/scripts/download_weights.py) | Added `download_cloth_segmentation()` for U2NET weights |
| [basic_inference.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/examples/basic_inference.py) | Restored default `garment_photo_type` to `model` |
| [debug_masks.py](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/scripts/debug_masks.py) | Uses `ClothSegmenter` instead of `FashnHumanParser` |

---

## How to Run the Demo

```bash
# 1. Clone & setup
git clone https://github.com/fashn-AI/fashn-vton-1.5.git
cd fashn-vton-1.5
python -m venv .venv && source .venv/bin/activate
pip install -e .

# 2. Download weights (~2.2 GB total)
python scripts/download_weights.py --weights-dir ./weights

# 3. Run inference
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

> [!IMPORTANT]
> Both `--garment-photo-type model` and `flat-lay` are now fully supported.
> `--num-timesteps 20` is recommended for CPU to keep time reasonable (~5-15 min).

See [DEMO_GUIDE.md](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/DEMO_GUIDE.md) for the complete documentation with troubleshooting.

---

## Known Limitations

The cloth-segmentation model detects **clothing regions only** (not body parts like face, hair, arms, legs). This means:

- ✅ **Garment extraction** (`garment_photo_type="model"`) works fully
- ✅ **Flat-lay mode** (`garment_photo_type="flat-lay"`) works fully
- ✅ **Segmentation-free mode** (`segmentation_free=True`) works fully
- ⚠️ **Masking mode** (`segmentation_free=False`) works for clothing detection but lacks body part identity preservation (face, hair, etc. won't be explicitly excluded from the mask)

For best results, use `segmentation_free=True` (the default).
