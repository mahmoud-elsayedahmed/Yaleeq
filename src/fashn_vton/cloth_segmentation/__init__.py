"""Cloth segmentation module using U2NET.

Replaces the fashn-human-parser model with an MIT-licensed U2NET-based
cloth segmentation model from levindabhi/cloth-segmentation.
"""

from .segmenter import ClothSegmenter

__all__ = ["ClothSegmenter"]
