"""Pydantic schemas for the Virtual Try-On API.

These schemas define the request/response models for all API endpoints.
Flutter developers should use these as reference for building their data models.
"""

from typing import List, Literal, Optional

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────────────────────────────────────
# Health Check
# ──────────────────────────────────────────────────────────────────────────────


class HealthResponse(BaseModel):
    """Response for GET /api/v1/health

    Flutter: Use this on app startup to verify the server is ready.
    """

    status: str = Field(..., description="Server status — 'ok' means ready to accept requests")
    device: str = Field(..., description="Compute device being used — 'cpu' or 'cuda'")
    models_loaded: bool = Field(..., description="Whether the ML pipeline is loaded and ready")


# ──────────────────────────────────────────────────────────────────────────────
# Models (Person/Mannequin Catalog)
# ──────────────────────────────────────────────────────────────────────────────


class ModelInfo(BaseModel):
    """Information about a single pre-loaded person model.

    Flutter: Display these in a GridView or horizontal ListView for selection.
    """

    id: str = Field(..., description="Unique model identifier — e.g. 'model_01'")
    name: str = Field(..., description="Display name — e.g. 'Woman - Casual'")
    gender: Literal["male", "female", "unisex"] = Field(..., description="Gender of the model")
    supported_categories: List[Literal["tops", "bottoms", "one-pieces"]] = Field(
        ..., description="Which garment categories this model supports"
    )
    thumbnail_url: str = Field(
        ..., description="URL to fetch the model's thumbnail image — GET /api/v1/models/{id}/thumbnail"
    )


class ModelsListResponse(BaseModel):
    """Response for GET /api/v1/models

    Flutter: Fetch this once and cache it — the model list doesn't change at runtime.
    """

    models: List[ModelInfo] = Field(..., description="List of all available person models")
    total: int = Field(..., description="Total number of models")


# ──────────────────────────────────────────────────────────────────────────────
# Try-On
# ──────────────────────────────────────────────────────────────────────────────
# NOTE: The try-on request uses multipart/form-data (not JSON) because it
# includes a file upload. The form fields are defined below.
#
# Flutter endpoint usage:
#   POST /api/v1/try-on
#   Content-Type: multipart/form-data
#
#   Fields:
#     - garment_image: File (the garment photo — JPEG/PNG/WebP)
#     - model_id: String (ID from the models list)
#     - category: String ("tops" | "bottoms" | "one-pieces")
#     - garment_photo_type: String (optional, default "flat-lay")
#     - num_timesteps: int (optional, default 20)
#     - seed: int (optional, default 42)
#
#   Response: image/png binary — use Image.memory(responseBytes) in Flutter
# ──────────────────────────────────────────────────────────────────────────────


class TryOnFormFields(BaseModel):
    """Documentation-only schema for the try-on form fields.

    NOTE: This is NOT used as a request body — FastAPI reads these as Form() fields
    alongside the UploadFile. This schema exists purely for documentation.

    Flutter example (using http package):
    ```dart
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/try-on'));
    request.fields['model_id'] = selectedModelId;
    request.fields['category'] = 'tops';
    request.fields['garment_photo_type'] = 'flat-lay';
    request.fields['num_timesteps'] = '20';
    request.fields['seed'] = '42';
    request.files.add(await http.MultipartFile.fromPath('garment_image', imagePath));
    var response = await request.send();
    var imageBytes = await response.stream.toBytes();
    // Display with Image.memory(imageBytes)
    ```
    """

    model_id: str = Field(..., description="ID of the selected person model")
    category: Literal["tops", "bottoms", "one-pieces"] = Field(..., description="Garment category")
    garment_photo_type: Literal["model", "flat-lay"] = Field(
        default="flat-lay",
        description="'flat-lay' for product shots (most common), 'model' if garment is worn by someone",
    )
    num_timesteps: int = Field(
        default=20,
        ge=10,
        le=50,
        description="Diffusion steps — 20=fast (CPU), 30=balanced, 50=quality",
    )
    seed: int = Field(default=42, description="Random seed for reproducibility")


# ──────────────────────────────────────────────────────────────────────────────
# Error Responses
# ──────────────────────────────────────────────────────────────────────────────


class ErrorResponse(BaseModel):
    """Standard error response.

    Flutter: Check for non-2xx status codes and parse the error message.
    """

    detail: str = Field(..., description="Human-readable error message")
