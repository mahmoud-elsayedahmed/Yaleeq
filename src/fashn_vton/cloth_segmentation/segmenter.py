"""Cloth segmentation using U2NET.

Provides a ClothSegmenter class that wraps the U2NET model for cloth segmentation
and maps its output to the 18-class label scheme used by the FASHN VTON pipeline.

Based on: https://github.com/levindabhi/cloth-segmentation
License: MIT

U2NET cloth segmentation outputs 4 classes:
    - 0: background
    - 1: upper body cloth (tops, jackets, etc.)
    - 2: lower body cloth (pants, skirts, etc.)
    - 3: full body cloth (dresses, jumpsuits, etc.)

These are mapped to the FASHN 18-class scheme for compatibility with the pipeline:
    - 0 (background) → 0 (background)
    - 1 (upper body) → 3 (top)
    - 2 (lower body) → 6 (pants)
    - 3 (full body)  → 4 (dress)
"""

import logging
import os
from collections import OrderedDict
from typing import Optional, Union

import cv2
import numpy as np
import torch
import torch.nn.functional as F
import torchvision.transforms as transforms
from PIL import Image

from .u2net import U2NET

# Mapping from cloth-segmentation 4-class output to FASHN 18-class label IDs
# cloth-seg class → fashn label ID
_CLOTH_SEG_TO_FASHN = {
    0: 0,   # background → background
    1: 3,   # upper body cloth → top
    2: 6,   # lower body cloth → pants
    3: 4,   # full body cloth → dress
}


class _NormalizeImage:
    """Normalize image tensor with given mean and std (per-channel)."""

    def __init__(self, mean: float, std: float):
        self.normalize = transforms.Normalize([mean] * 3, [std] * 3)

    def __call__(self, tensor: torch.Tensor) -> torch.Tensor:
        return self.normalize(tensor)


class ClothSegmenter:
    """Cloth segmentation model using U2NET.

    Provides a predict() method compatible with the FASHN VTON pipeline,
    returning segmentation maps in the 18-class FASHN label scheme.

    Args:
        checkpoint_path: Path to the U2NET checkpoint (.pth file).
        device: Device to run inference on ('cuda', 'cpu', or None for auto-detect).
        input_size: Model input size as (height, width). Default: (768, 768).
        logger: Optional logger instance.

    Example:
        segmenter = ClothSegmenter(checkpoint_path="weights/cloth_seg/cloth_segm_u2net_latest.pth")
        seg_map = segmenter.predict(image)
        # seg_map is (H, W) numpy array with FASHN 18-class label IDs
    """

    def __init__(
        self,
        checkpoint_path: str,
        device: Optional[str] = None,
        input_size: tuple = (768, 768),
        logger: Optional[logging.Logger] = None,
    ):
        self.logger = logger or logging.getLogger("ClothSegmenter")
        self.input_size = input_size  # (H, W)
        self.device = torch.device(
            device if device else ("cuda" if torch.cuda.is_available() else "cpu")
        )

        # Preprocessing: ToTensor + Normalize(mean=0.5, std=0.5)
        self.transform = transforms.Compose([
            transforms.ToTensor(),
            _NormalizeImage(0.5, 0.5),
        ])

        # Load model
        self._load_model(checkpoint_path)

    def _load_model(self, checkpoint_path: str):
        """Load U2NET model with pretrained weights."""
        if not os.path.exists(checkpoint_path):
            raise FileNotFoundError(
                f"Cloth segmentation checkpoint not found: {checkpoint_path}\n"
                "Please run: python scripts/download_weights.py --weights-dir ./weights"
            )

        self.logger.info(f"Loading ClothSegmenter (U2NET) from {checkpoint_path}")

        self.model = U2NET(in_ch=3, out_ch=4)

        # Load checkpoint - the original model was saved with DataParallel (module. prefix)
        state_dict = torch.load(checkpoint_path, map_location="cpu", weights_only=True)

        # Strip 'module.' prefix if present (from DataParallel training)
        new_state_dict = OrderedDict()
        for k, v in state_dict.items():
            name = k[7:] if k.startswith("module.") else k
            new_state_dict[name] = v

        self.model.load_state_dict(new_state_dict)
        self.model.to(self.device).eval()

        self.logger.info("ClothSegmenter loaded")

    @torch.inference_mode()
    def predict(
        self,
        image: Union[str, Image.Image, np.ndarray],
        return_raw: bool = False,
    ) -> np.ndarray:
        """Run cloth segmentation on an image.

        Args:
            image: Input image as file path, PIL Image, or numpy array (RGB, uint8).
            return_raw: If True, return the raw 4-class segmentation instead of
                mapping to the FASHN 18-class scheme.

        Returns:
            Segmentation map as (H, W) numpy array with integer class IDs.
            If return_raw=False (default): values are FASHN 18-class label IDs.
            If return_raw=True: values are 0-3 (cloth-segmentation classes).
        """
        # Convert input to PIL Image
        if isinstance(image, str):
            pil_image = Image.open(image).convert("RGB")
        elif isinstance(image, np.ndarray):
            pil_image = Image.fromarray(image)
        elif isinstance(image, Image.Image):
            pil_image = image.convert("RGB")
        else:
            raise TypeError(f"Unsupported image type: {type(image)}")

        orig_w, orig_h = pil_image.size

        # Resize to model input size
        resized = pil_image.resize(
            (self.input_size[1], self.input_size[0]),  # PIL uses (W, H)
            Image.BICUBIC,
        )

        # Preprocess
        input_tensor = self.transform(resized)
        input_tensor = input_tensor.unsqueeze(0).to(self.device)

        # Run model
        output = self.model(input_tensor)

        # output[0] is the fused output (d0), shape: (1, 4, H, W)
        output_tensor = F.log_softmax(output[0], dim=1)
        output_tensor = torch.max(output_tensor, dim=1, keepdim=True)[1]
        output_tensor = output_tensor.squeeze(0).squeeze(0)  # (H, W)

        # Convert to numpy
        seg_raw = output_tensor.cpu().numpy().astype(np.int64)

        # Resize back to original dimensions
        if seg_raw.shape[0] != orig_h or seg_raw.shape[1] != orig_w:
            seg_raw = cv2.resize(
                seg_raw.astype(np.uint8),
                (orig_w, orig_h),
                interpolation=cv2.INTER_NEAREST,
            ).astype(np.int64)

        if return_raw:
            return seg_raw

        # Map to FASHN 18-class scheme
        seg_fashn = np.zeros_like(seg_raw)
        for cloth_cls, fashn_cls in _CLOTH_SEG_TO_FASHN.items():
            seg_fashn[seg_raw == cloth_cls] = fashn_cls

        return seg_fashn
