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
#     - flat_lay: bool (optional, default true — true for product shots, false if worn by someone)
#     - num_timesteps: int (optional, default 20)
#     - seed: int (optional, default 42)
#
#   Response: JSON { result_id, result_url }
#     Then use GET /api/v1/results/{result_id} to fetch the image.
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
    request.fields['flat_lay'] = 'true';   // true = product shot, false = worn by model
    request.fields['num_timesteps'] = '20';
    request.fields['seed'] = '42';
    request.files.add(await http.MultipartFile.fromPath('garment_image', imagePath));
    var response = await request.send();
    var data = jsonDecode(await response.stream.bytesToString());
    var resultUrl = data['result_url'];  // Use to fetch the generated image
    ```
    """

    model_id: str = Field(..., description="ID of the selected person model")
    category: Literal["tops", "bottoms", "one-pieces"] = Field(..., description="Garment category")
    flat_lay: bool = Field(
        default=True,
        description="true = garment is a flat-lay/product shot (default), false = garment is worn by a person",
    )
    num_timesteps: int = Field(
        default=20,
        ge=10,
        le=50,
        description="Diffusion steps — 20=fast (CPU), 30=balanced, 50=quality",
    )
    seed: int = Field(default=42, description="Random seed for reproducibility")


class TryOnResponse(BaseModel):
    """Response for POST /api/v1/try-on

    Flutter: Use the result_url to fetch and display the generated image.
    ```dart
    // After receiving the response:
    final data = jsonDecode(response.body);
    Image.network('$baseUrl${data["result_url"]}');
    ```
    """

    result_id: str = Field(..., description="Unique ID for this result — use to fetch the image")
    result_url: str = Field(..., description="URL to fetch the generated image — GET /api/v1/results/{result_id}")
    model_id: str = Field(..., description="The person model that was used")
    category: str = Field(..., description="The garment category that was used")


# ──────────────────────────────────────────────────────────────────────────────
# Error Responses
# ──────────────────────────────────────────────────────────────────────────────


class ErrorResponse(BaseModel):
    """Standard error response.

    Flutter: Check for non-2xx status codes and parse the error message.
    """

    detail: str = Field(..., description="Human-readable error message")
