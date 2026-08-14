"""TryOn Pipeline."""

import logging
import os
from dataclasses import dataclass
from typing import List, Literal, Optional

import cv2
import numpy as np
import torch

from PIL import Image
from tqdm.auto import tqdm

from .cloth_segmentation import ClothSegmenter
from .dwpose import DWposeDetector, draw_pose
from .preprocessing import (
    BODY_COVERAGE_TO_FASHN_LABELS,
    CATEGORY_TO_BODY_COVERAGE,
    FASHN_LABELS_TO_IDS,
    AspectPreserveResize,
    ResizePad,
    create_clothing_agnostic_image,
    create_garment_image,
)
from .tryon_mmdit import TryOnModel
from .utils import (
    get_dummy_dw_keypoints,
    get_rf_schedule,
    load_checkpoint,
    normalize_uint8_to_neg1_1,
    numpy_to_torch,
    setup_logger,
    tensor_to_pil,
)


@dataclass
class PipelineOutput:
    """Pipeline output container."""

    images: List[Image.Image]


class TryOnPipeline:
    """
    TryOn inference pipeline.

    Args:
        weights_dir: Directory containing model weights (model.safetensors, dwpose/)
        device: Device to run on ('cuda', 'cpu', or None for auto-detect)
        logger: Optional logger instance

    Example:
        pipeline = TryOnPipeline(weights_dir="./weights")
        result = pipeline(person_image, garment_image, category="tops")
    """

    CATEGORY_TO_LABEL = {"tops": 1, "bottoms": 2, "one-pieces": 3}

    def __init__(
        self,
        weights_dir: str,
        device: Optional[str] = None,
        logger: Optional[logging.Logger] = None,
    ):
        self.weights_dir = os.path.abspath(weights_dir)
        self.logger = logger or setup_logger("TryOnPipeline", level=logging.INFO)

        # Setup device
        self.device = torch.device(device if device else ("cuda" if torch.cuda.is_available() else "cpu"))
        self.logger.info(f"Using device: {self.device}")

        # Setup inference dtype
        self.inference_dtype = torch.float32
        if self.device.type == "cuda" and torch.cuda.is_bf16_supported():
            self.inference_dtype = torch.bfloat16
        self.logger.info(f"Using dtype: {self.inference_dtype}")

        # Validate weights exist
        self._validate_weights()

        # Load models
        self._setup_tryon_model()
        self._setup_pose_model()
        self._setup_cloth_segmenter()

        # Setup transforms (derived from model input shape)
        h, w = self.tryon_model.input_shape
        max_dim = max(h, w)
        self.pre_resize = AspectPreserveResize(target_size=(max_dim, max_dim), mode="fit", backend="pil")
        self.resize_pad_fn = ResizePad((w, h), backend="opencv")

        # In-memory cache for person model features
        self._person_cache: dict[tuple, tuple[torch.Tensor, torch.Tensor]] = {}

    def _validate_weights(self):
        """Check that required weight files exist."""
        tryon_path = os.path.join(self.weights_dir, "model.safetensors")
        dwpose_dir = os.path.join(self.weights_dir, "dwpose")
        yolox_path = os.path.join(dwpose_dir, "yolox_l.onnx")
        dwpose_path = os.path.join(dwpose_dir, "dw-ll_ucoco_384.onnx")
        cloth_seg_path = os.path.join(self.weights_dir, "cloth_seg", "cloth_segm_u2net_latest.pth")

        missing = []
        if not os.path.exists(tryon_path):
            missing.append(tryon_path)
        if not os.path.exists(yolox_path):
            missing.append(yolox_path)
        if not os.path.exists(dwpose_path):
            missing.append(dwpose_path)
        if not os.path.exists(cloth_seg_path):
            missing.append(cloth_seg_path)

        if missing:
            raise FileNotFoundError(
                "Missing model weights:\n"
                + "\n".join(f"  - {p}" for p in missing)
                + f"\n\nPlease run:\n  python scripts/download_weights.py --weights-dir {self.weights_dir}"
            )

    def _setup_tryon_model(self):
        """Load the TryOn model."""
        model_path = os.path.join(self.weights_dir, "model.safetensors")
        self.logger.info(f"Loading TryOnModel from {model_path}")

        self.tryon_model = TryOnModel()
        state_dict = load_checkpoint(model_path, device=str(self.device))
        self.tryon_model.load_state_dict(state_dict)
        self.tryon_model.to(self.device, dtype=self.inference_dtype).eval()

        self.logger.info("TryOnModel loaded")

    def _setup_pose_model(self):
        """Load DWPose model."""
        dwpose_dir = os.path.join(self.weights_dir, "dwpose")
        self.logger.info(f"Loading DWPose from {dwpose_dir}")

        dwpose_device = f"cuda:{self.device.index or 0}" if self.device.type == "cuda" else "cpu"
        self.pose_model = DWposeDetector(checkpoints_dir=dwpose_dir, device=dwpose_device)

        self.logger.info("DWPose loaded")

    def _setup_cloth_segmenter(self):
        """Load cloth segmentation model (U2NET)."""
        cloth_seg_path = os.path.join(self.weights_dir, "cloth_seg", "cloth_segm_u2net_latest.pth")
        self.logger.info(f"Loading ClothSegmenter from {cloth_seg_path}")

        cloth_seg_device = f"cuda:{self.device.index or 0}" if self.device.type == "cuda" else "cpu"
        self.cloth_segmenter = ClothSegmenter(
            checkpoint_path=cloth_seg_path,
            device=cloth_seg_device,
            logger=self.logger,
        )

        self.logger.info("ClothSegmenter loaded")

    def _get_or_compute_person_features(
        self,
        person_image: Image.Image,
        category: str,
        segmentation_free: bool,
        num_samples: int,
        person_model_id: Optional[str] = None,
    ) -> tuple[torch.Tensor, torch.Tensor]:
        """Get precomputed or compute cached person features (pose tensor & agnostic tensor)."""
        # Create cache key
        model_tag = person_model_id or getattr(person_image, "_model_id", None) or str(id(person_image))
        cache_key = (model_tag, category, segmentation_free, num_samples)

        if cache_key in self._person_cache:
            self.logger.info(f"Reusing cached person features for model '{model_tag}' ({category})")
            cached_ca, cached_pose = self._person_cache[cache_key]
            return cached_ca.clone(), cached_pose.clone()

        # Compute from scratch
        person_image_resized = self.pre_resize(person_image, allow_upsampling=False)
        person_image_np = np.array(person_image_resized)

        # Pose detection (DWPose expects BGR)
        person_pose = self.pose_model(person_image_np[..., ::-1])
        person_pose_img = draw_pose(person_pose, person_image_np.shape[0], person_image_np.shape[1], grayscale=True)

        # Cloth segmentation (U2NET)
        if segmentation_free:
            person_seg_pred = np.zeros(person_image_np.shape[:2], dtype=np.int64)
        else:
            self.logger.info("Running cloth segmentation on person image...")
            person_seg_pred = self.cloth_segmenter.predict(person_image_np)

        # Get labels to segment based on category
        body_coverage = CATEGORY_TO_BODY_COVERAGE.get(category)
        labels_to_segment = BODY_COVERAGE_TO_FASHN_LABELS.get(body_coverage)
        labels_to_segment_indices = [FASHN_LABELS_TO_IDS[label] for label in labels_to_segment]

        # Create clothing-agnostic image
        ca_image = create_clothing_agnostic_image(
            img_np=person_image_np.copy(),
            seg_pred=person_seg_pred.copy(),
            labels_to_segment_indices=labels_to_segment_indices.copy(),
            body_coverage=body_coverage,
            disable_masking=segmentation_free,
            logger=self.logger,
        )

        # Resize/pad for model input
        ca_image = self.resize_pad_fn(ca_image, mem_padding=True)
        person_pose_img = self.resize_pad_fn(person_pose_img, interpolation=cv2.INTER_NEAREST_EXACT)

        def prepare_tensor(img: np.ndarray) -> torch.Tensor:
            t = numpy_to_torch(img).unsqueeze(0)
            t = normalize_uint8_to_neg1_1(t)
            t = t.to(self.device).repeat(num_samples, 1, 1, 1)
            return t.to(dtype=self.inference_dtype)

        ca_tensor = prepare_tensor(ca_image)
        person_pose_tensor = prepare_tensor(person_pose_img)

        # Store in cache
        self._person_cache[cache_key] = (ca_tensor, person_pose_tensor)
        self.logger.info(f"Cached person features for model '{model_tag}' ({category})")

        return ca_tensor.clone(), person_pose_tensor.clone()

    def precompute_model(self, model_id: str, person_image: Image.Image, categories: Optional[List[str]] = None):
        """Precompute features for a fixed person model across all supported categories."""
        if categories is None:
            categories = ["tops", "bottoms", "one-pieces"]
        for cat in categories:
            self._get_or_compute_person_features(
                person_image=person_image,
                category=cat,
                segmentation_free=True,
                num_samples=1,
                person_model_id=model_id,
            )

    @torch.inference_mode()
    def _sample(
        self,
        *,
        ca_images: torch.Tensor,
        garment_images: torch.Tensor,
        person_poses: torch.Tensor,
        garment_poses: torch.Tensor,
        garment_categories: torch.Tensor,
        num_timesteps: int = 20,
        time_shift_mu: float = 1.5,
        guidance_scale: float = 1.5,
        skip_cfg_last_n_steps: int = 3,
        use_tqdm: bool = True,
    ) -> List[Image.Image]:
        """Euler sampling with optimized CFG."""
        device, dtype = ca_images.device, ca_images.dtype
        batch_size = ca_images.shape[0]

        # Init noisy images
        c, h, w = self.tryon_model.channels_in, *self.tryon_model.input_shape
        images = torch.randn((batch_size, c, h, w), dtype=dtype, device=device)

        # Time schedule (from 0 -> 1)
        timesteps = get_rf_schedule(num_steps=num_timesteps, mu=time_shift_mu)

        model_kwargs = {
            "person_poses": person_poses,
            "garment_poses": garment_poses,
            "ca_images": ca_images,
            "garment_images": garment_images,
            "garment_categories": garment_categories,
        }

        # Euler sampling loop
        for step_idx, (t_curr, t_prev) in enumerate(
            tqdm(
                zip(timesteps[:-1], timesteps[1:]),
                desc="Sampling",
                total=len(timesteps) - 1,
                disable=not use_tqdm,
            )
        ):
            dt = t_prev - t_curr
            t_vec = torch.full((batch_size,), t_curr, dtype=dtype, device=device)

            # Skip CFG at final steps to save 50% compute on those steps and prevent color saturation
            if skip_cfg_last_n_steps > 0 and step_idx >= (len(timesteps) - 1) - skip_cfg_last_n_steps:
                v_guided = self.tryon_model.forward_conditional_only(images, t_vec, **model_kwargs)
            else:
                pred = self.tryon_model.forward_for_cfg(images, t_vec, **model_kwargs)
                v_c, v_u = pred["v_c"], pred["v_u"]
                v_guided = v_u + guidance_scale * (v_c - v_u)

            images = images + dt * v_guided

        images = images.to(dtype=torch.float).clamp_(-1.0, 1.0)
        return [tensor_to_pil(img, unnormalize=True) for img in images]

    @torch.inference_mode()
    def __call__(
        self,
        person_image: Image.Image,
        garment_image: Image.Image,
        category: Literal["tops", "bottoms", "one-pieces"],
        garment_photo_type: Literal["model", "flat-lay"] = "model",
        num_samples: int = 1,
        num_timesteps: int = 15,
        guidance_scale: float = 1.5,
        skip_cfg_last_n_steps: int = 3,
        seed: int = 42,
        segmentation_free: bool = True,
        person_model_id: Optional[str] = None,
    ) -> PipelineOutput:
        """
        Run virtual try-on inference with CPU performance optimizations.

        Args:
            person_image: RGB image of the person to dress.
            garment_image: RGB image of the garment (model photo or flat-lay).
            category: Garment category - "tops", "bottoms", or "one-pieces".
            garment_photo_type: "model" if garment is worn by a person,
                "flat-lay" for product shots on plain backgrounds.
            num_samples: Number of output images to generate (1-4).
            num_timesteps: Diffusion sampling steps. Higher = better quality, slower.
                Recommended on CPU: 12-15 (fast), 20 (standard).
            guidance_scale: Classifier-free guidance strength.
            skip_cfg_last_n_steps: Skip CFG for final N steps (saves 50% compute on those steps).
            seed: Random seed for reproducibility.
            segmentation_free: If True, generate without masking the person image.
            person_model_id: Optional identifier for pre-cached person models.

        Returns:
            PipelineOutput with `images` list containing generated PIL Images.
        """
        # Set seed
        torch.manual_seed(seed)
        if self.device.type == "cuda":
            torch.cuda.manual_seed_all(seed)
        np.random.seed(seed)

        # ── 1. Person Model Features (Cached or Computed) ──
        ca_tensor, person_pose_tensor = self._get_or_compute_person_features(
            person_image=person_image,
            category=category,
            segmentation_free=segmentation_free,
            num_samples=num_samples,
            person_model_id=person_model_id,
        )

        # ── 2. Garment Preprocessing ──
        garment_image = self.pre_resize(garment_image, allow_upsampling=False)
        garment_image_np = np.array(garment_image)

        garment_pose = (
            get_dummy_dw_keypoints()
            if garment_photo_type == "flat-lay"
            else self.pose_model(garment_image_np[..., ::-1])
        )
        garment_pose_img = draw_pose(garment_pose, garment_image_np.shape[0], garment_image_np.shape[1], grayscale=True)

        if garment_photo_type == "flat-lay":
            garment_seg_pred = np.zeros(garment_image_np.shape[:2], dtype=np.int64)
        else:
            self.logger.info("Running cloth segmentation on garment image...")
            garment_seg_pred = self.cloth_segmenter.predict(garment_image_np)

        body_coverage = CATEGORY_TO_BODY_COVERAGE.get(category)
        labels_to_segment = BODY_COVERAGE_TO_FASHN_LABELS.get(body_coverage)
        labels_to_segment_indices = [FASHN_LABELS_TO_IDS[label] for label in labels_to_segment]

        garment_image_processed = create_garment_image(
            img_np=garment_image_np,
            seg_pred=garment_seg_pred,
            labels_to_segment_indices=labels_to_segment_indices.copy(),
            disable_masking=garment_photo_type == "flat-lay",
        )

        # Resize/pad garment
        garment_image_processed = self.resize_pad_fn(garment_image_processed)
        garment_pose_img = self.resize_pad_fn(garment_pose_img, interpolation=cv2.INTER_NEAREST_EXACT)

        def prepare_tensor(img: np.ndarray) -> torch.Tensor:
            t = numpy_to_torch(img).unsqueeze(0)
            t = normalize_uint8_to_neg1_1(t)
            t = t.to(self.device).repeat(num_samples, 1, 1, 1)
            return t.to(dtype=self.inference_dtype)

        garment_tensor = prepare_tensor(garment_image_processed)
        garment_pose_tensor = prepare_tensor(garment_pose_img)

        garment_categories = (
            torch.tensor(self.CATEGORY_TO_LABEL[category]).unsqueeze(0).repeat(num_samples).to(self.device)
        )

        # ── 3. Run sampling ──
        self.logger.info(f"Running inference with {num_timesteps} timesteps (skip_cfg_last_n_steps={skip_cfg_last_n_steps})...")
        images = self._sample(
            ca_images=ca_tensor,
            garment_images=garment_tensor,
            person_poses=person_pose_tensor,
            garment_poses=garment_pose_tensor,
            garment_categories=garment_categories,
            num_timesteps=num_timesteps,
            guidance_scale=guidance_scale,
            skip_cfg_last_n_steps=skip_cfg_last_n_steps,
        )

        # Unpad outputs
        images = [self.resize_pad_fn.unpad(img) for img in images]

        self.logger.info(f"Generated {len(images)} images")

        return PipelineOutput(images=images)
