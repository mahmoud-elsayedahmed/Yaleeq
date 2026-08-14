"""Yaleq Virtual Try-On API — FastAPI Application.

This is the main entry point for the FastAPI server that wraps the
FASHN VTON v1.5 pipeline. It provides REST endpoints for Flutter
(or any HTTP client) to perform virtual try-on.

──────────────────────────────────────────────────────────
  HOW TO RUN:
    cd /home/masri/Documents/yaleeq/Yaleq
    uvicorn api.main:app --host 0.0.0.0 --port 8000

  DOCS (Swagger):
    http://localhost:8000/docs
──────────────────────────────────────────────────────────

──────────────────────────────────────────────────────────
  FLUTTER ENDPOINTS SUMMARY:
──────────────────────────────────────────────────────────

  1. GET  /api/v1/health
     → Check if server is up and pipeline is loaded.
     → Call on app startup.

  2. GET  /api/v1/models
     → Get list of available person models (id, name, gender, thumbnail_url).
     → Display in a GridView for user selection.

  3. GET  /api/v1/models/{model_id}/thumbnail
     → Get thumbnail image for a specific model.
     → Use as image source in the models grid:
       Image.network('$baseUrl/api/v1/models/$modelId/thumbnail')

   4. POST /api/v1/try-on  (multipart/form-data)
      → THE MAIN ENDPOINT — Send garment image + model_id + category.
      → Returns JSON { result_id, result_url, model_id, category }
      → Flutter usage:
          var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/try-on'));
          request.fields['model_id'] = 'woman_01';
          request.fields['category'] = 'tops';
          request.fields['flat_lay'] = 'true';  // true = product shot, false = worn by model
          request.files.add(await http.MultipartFile.fromPath('garment_image', filePath));
          var response = await request.send();
          var data = jsonDecode(await response.stream.bytesToString());
          // Fetch result: Image.network('$baseUrl${data["result_url"]}')

   5. GET  /api/v1/results/{result_id}
      → Get the generated try-on image by result ID.
      → Returns the image as binary PNG.
      → Flutter usage: Image.network('$baseUrl/api/v1/results/$resultId')

──────────────────────────────────────────────────────────
"""

import io
import logging
import os
import uuid
from contextlib import asynccontextmanager
from typing import Literal, Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, StreamingResponse, JSONResponse
from PIL import Image

from .models_registry import MODELS, get_model_image_path, validate_all_models
from .schemas import ErrorResponse, HealthResponse, ModelInfo, ModelsListResponse, TryOnResponse

# ──────────────────────────────────────────────────────────────────────────────
# Global state — Pipeline is loaded once at startup and shared across requests.
# ──────────────────────────────────────────────────────────────────────────────
pipeline = None
pipeline_device = "unknown"

# Results storage — generated images are saved to disk and tracked here.
RESULTS_DIR = os.path.join(os.path.dirname(__file__), "results")
results_registry: dict[str, dict] = {}  # result_id -> {path, model_id, category}

logger = logging.getLogger("yaleq-api")
logging.basicConfig(level=logging.INFO, format="%(asctime)s — %(name)s — %(levelname)s — %(message)s")


# ──────────────────────────────────────────────────────────────────────────────
# Lifespan — Load the ML pipeline once on startup, release on shutdown.
# ──────────────────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the TryOnPipeline on startup.

    The pipeline takes ~30-60s to load (depending on CPU/GPU).
    Once loaded, it stays in memory for all requests.
    """
    global pipeline, pipeline_device

    # Create results directory
    os.makedirs(RESULTS_DIR, exist_ok=True)
    logger.info(f"Results directory: {RESULTS_DIR}")

    # Validate model images exist
    missing = validate_all_models()
    if missing:
        logger.error("Missing model images:\n" + "\n".join(f"  - {m}" for m in missing))
        raise FileNotFoundError(f"Missing model images: {missing}")

    # Set optimal CPU threading
    import torch
    num_threads = os.cpu_count() or 8
    torch.set_num_threads(num_threads)
    logger.info(f"Configured PyTorch CPU threads: {num_threads}")

    # Load the try-on pipeline
    logger.info("Loading TryOnPipeline... (this may take 30-60 seconds)")
    from fashn_vton import TryOnPipeline

    pipeline = TryOnPipeline(weights_dir="./weights")
    pipeline_device = str(pipeline.device)
    logger.info(f"Pipeline loaded on device: {pipeline_device}")

    # Pre-warm person model cache for instant inference on fixed models
    logger.info("Pre-caching fixed person models...")
    for mid in list(MODELS.keys()):
        try:
            img_path = get_model_image_path(mid)
            p_img = Image.open(img_path).convert("RGB")
            pipeline.precompute_model(mid, p_img, MODELS[mid]["supported_categories"])
        except Exception as e:
            logger.warning(f"Could not pre-cache model {mid}: {e}")
    logger.info("Fixed person models cache ready!")

    yield  # ← Server is running and accepting requests

    # Cleanup on shutdown
    logger.info("Shutting down — releasing pipeline resources...")
    pipeline = None


# ──────────────────────────────────────────────────────────────────────────────
# FastAPI App
# ──────────────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Yaleq — Virtual Try-On API",
    description=(
        "REST API for virtual garment try-on powered by FASHN VTON v1.5.\n\n"
        "Upload a garment image, select a pre-loaded person model, and get "
        "a photorealistic image of the person wearing the garment."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# ──────────────────────────────────────────────────────────────────────────────
# CORS — Allow Flutter app to connect from any origin.
#
# Flutter: If you're running on a different port or device, CORS must
# be enabled. This allows all origins (*) for development. In production,
# restrict to your app's domain.
# ──────────────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ══════════════════════════════════════════════════════════════════════════════
#  ENDPOINT 1: Health Check
# ══════════════════════════════════════════════════════════════════════════════
#
#  Flutter: Call this on app startup to verify the server is ready.
#
#  GET /api/v1/health
#
#  Response:
#    {
#      "status": "ok",
#      "device": "cpu",
#      "models_loaded": true
#    }
#
# ══════════════════════════════════════════════════════════════════════════════


@app.get(
    "/api/v1/health",
    response_model=HealthResponse,
    tags=["System"],
    summary="Health check — verify server and pipeline are ready",
)
async def health_check():
    """Check if the API server is running and the ML pipeline is loaded.

    Flutter usage:
    ```dart
    final response = await http.get(Uri.parse('$baseUrl/api/v1/health'));
    final data = jsonDecode(response.body);
    if (data['status'] == 'ok' && data['models_loaded'] == true) {
      // Server is ready — proceed to load models list
    }
    ```
    """
    return HealthResponse(
        status="ok",
        device=pipeline_device,
        models_loaded=pipeline is not None,
    )


# ══════════════════════════════════════════════════════════════════════════════
#  ENDPOINT 2: List Available Models
# ══════════════════════════════════════════════════════════════════════════════
#
#  Flutter: Fetch this once and cache it. Display in a GridView.
#
#  GET /api/v1/models
#
#  Response:
#    {
#      "models": [
#        {
#          "id": "woman_01",
#          "name": "Woman - Fashion Model",
#          "gender": "female",
#          "supported_categories": ["tops", "bottoms", "one-pieces"],
#          "thumbnail_url": "/api/v1/models/woman_01/thumbnail"
#        },
#        ...
#      ],
#      "total": 5
#    }
#
# ══════════════════════════════════════════════════════════════════════════════


@app.get(
    "/api/v1/models",
    response_model=ModelsListResponse,
    tags=["Models"],
    summary="List all available person models",
)
async def list_models():
    """Get the list of all pre-loaded person models available for try-on.

    Flutter usage:
    ```dart
    final response = await http.get(Uri.parse('$baseUrl/api/v1/models'));
    final data = jsonDecode(response.body);
    final models = (data['models'] as List)
        .map((m) => ModelInfo.fromJson(m))
        .toList();
    // Display in GridView.builder(...)
    ```
    """
    models_list = []
    for model_id, info in MODELS.items():
        models_list.append(
            ModelInfo(
                id=model_id,
                name=info["name"],
                gender=info["gender"],
                supported_categories=info["supported_categories"],
                thumbnail_url=f"/api/v1/models/{model_id}/thumbnail",
            )
        )

    return ModelsListResponse(models=models_list, total=len(models_list))


# ══════════════════════════════════════════════════════════════════════════════
#  ENDPOINT 3: Get Model Thumbnail
# ══════════════════════════════════════════════════════════════════════════════
#
#  Flutter: Use as the image source in the models grid.
#
#  GET /api/v1/models/{model_id}/thumbnail
#
#  Response: image/jpeg or image/webp binary
#
#  Flutter usage:
#    Image.network('$baseUrl/api/v1/models/$modelId/thumbnail')
#
# ══════════════════════════════════════════════════════════════════════════════


@app.get(
    "/api/v1/models/{model_id}/thumbnail",
    tags=["Models"],
    summary="Get thumbnail image for a specific model",
    responses={
        200: {"content": {"image/*": {}}, "description": "Model thumbnail image"},
        404: {"model": ErrorResponse, "description": "Model not found"},
    },
)
async def get_model_thumbnail(model_id: str):
    """Get the thumbnail/preview image for a person model.

    Flutter usage:
    ```dart
    // Simply use Image.network — no parsing needed
    Image.network(
      '$baseUrl/api/v1/models/$modelId/thumbnail',
      fit: BoxFit.cover,
    )
    ```
    """
    try:
        image_path = get_model_image_path(model_id)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"Model '{model_id}' not found")
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))

    # Determine content type from extension
    ext = image_path.rsplit(".", 1)[-1].lower()
    content_type_map = {
        "webp": "image/webp",
        "jpeg": "image/jpeg",
        "jpg": "image/jpeg",
        "png": "image/png",
    }
    content_type = content_type_map.get(ext, "image/jpeg")

    with open(image_path, "rb") as f:
        image_bytes = f.read()

    return Response(content=image_bytes, media_type=content_type)


# ══════════════════════════════════════════════════════════════════════════════
#  ENDPOINT 4: Virtual Try-On  ★ MAIN ENDPOINT ★
# ══════════════════════════════════════════════════════════════════════════════
#
#  Flutter: This is the core endpoint — send garment image + model_id + category.
#
#  POST /api/v1/try-on
#  Content-Type: multipart/form-data
#
#  Form Fields:
#    - garment_image: File (JPEG/PNG/WebP — the garment to try on)
#    - model_id: str (e.g. "woman_01")
#    - category: str ("tops" | "bottoms" | "one-pieces")
#    - flat_lay: bool (optional, default true — true for product shots, false if worn by model)
#    - num_timesteps: int (optional, default 20)
#    - seed: int (optional, default 42)
#
#  Response: JSON { result_id, result_url, model_id, category }
#
#  Flutter example:
#    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/try-on'));
#    request.fields['model_id'] = 'woman_01';
#    request.fields['category'] = 'tops';
#    request.fields['flat_lay'] = 'true';   // true = product shot, false = worn by model
#    request.fields['num_timesteps'] = '20';
#    request.files.add(
#      await http.MultipartFile.fromPath('garment_image', imagePath),
#    );
#    var response = await request.send();
#    if (response.statusCode == 200) {
#      var data = jsonDecode(await response.stream.bytesToString());
#      var resultUrl = data['result_url'];
#      // Display: Image.network('$baseUrl$resultUrl')
#    }
#
# ══════════════════════════════════════════════════════════════════════════════


@app.post(
    "/api/v1/try-on",
    response_model=TryOnResponse,
    tags=["Try-On"],
    summary="Generate virtual try-on image",
    responses={
        200: {"model": TryOnResponse, "description": "Try-on result with image URL"},
        400: {"model": ErrorResponse, "description": "Invalid request"},
        404: {"model": ErrorResponse, "description": "Model not found"},
        503: {"model": ErrorResponse, "description": "Pipeline not loaded"},
    },
)
async def try_on(
    garment_image: UploadFile = File(..., description="Garment image file (JPEG/PNG/WebP)"),
    model_id: str = Form(..., description="ID of the person model to use (e.g. 'woman_01')"),
    category: Literal["tops", "bottoms", "one-pieces"] = Form(..., description="Garment category"),
    flat_lay: bool = Form(
        default=True,
        description="true = garment is a flat-lay/product shot (default), false = garment is worn by a person",
    ),
    num_timesteps: int = Form(default=15, ge=5, le=50, description="Diffusion steps (12-15=fast CPU, 20=standard)"),
    skip_cfg_last_n_steps: int = Form(default=3, ge=0, le=10, description="Skip CFG on final N steps (saves 50% compute on those steps)"),
    seed: int = Form(default=42, description="Random seed for reproducibility"),
):
    """Generate a photorealistic try-on image.

    The user uploads a garment photo and selects a pre-loaded person model.
    The API generates an image of the person wearing the garment, saves it,
    and returns a JSON response with the result URL.

    **Processing time:** ~1-3 minutes on CPU with caching & fast steps, ~10-30 seconds on GPU.

    Flutter usage:
    ```dart
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/try-on'));

    // Required fields
    request.fields['model_id'] = selectedModelId;       // e.g. 'woman_01'
    request.fields['category'] = selectedCategory;       // 'tops', 'bottoms', 'one-pieces'

    // Optional fields
    request.fields['flat_lay'] = 'true';     // true = product shot, false = worn by model
    request.fields['num_timesteps'] = '15';
    request.fields['seed'] = '42';

    // Garment image file
    request.files.add(
      await http.MultipartFile.fromPath('garment_image', garmentImagePath),
    );

    // Send and get result
    var response = await request.send();
    if (response.statusCode == 200) {
      final data = jsonDecode(await response.stream.bytesToString());
      final resultUrl = '$baseUrl${data["result_url"]}';
      // Display: Image.network(resultUrl)
    } else {
      final body = await response.stream.bytesToString();
      final error = jsonDecode(body)['detail'];
      // Show error to user
    }
    ```
    """
    # ── Validate pipeline is loaded ──
    if pipeline is None:
        raise HTTPException(status_code=503, detail="Pipeline not loaded yet. Please wait for server startup.")

    # ── Validate model_id exists ──
    if model_id not in MODELS:
        available = list(MODELS.keys())
        raise HTTPException(
            status_code=404,
            detail=f"Model '{model_id}' not found. Available models: {available}",
        )

    # ── Validate category is supported by this model ──
    supported = MODELS[model_id]["supported_categories"]
    if category not in supported:
        raise HTTPException(
            status_code=400,
            detail=f"Category '{category}' not supported by model '{model_id}'. Supported: {supported}",
        )

    # ── Validate garment image ──
    # Note: Some clients (e.g. curl) send webp files as application/octet-stream,
    # so we accept that too. The actual image validity is checked when PIL opens it.
    allowed_types = {"image/", "application/octet-stream", "multipart/form-data"}
    content_type_header = garment_image.content_type or ""
    if content_type_header and not any(content_type_header.startswith(t) for t in allowed_types):
        raise HTTPException(status_code=400, detail=f"Invalid file type: {content_type_header}. Expected an image file.")

    # ── Convert flat_lay bool to garment_photo_type string ──
    garment_photo_type = "flat-lay" if flat_lay else "model"

    # ── Load images ──
    try:
        # Load person model image (pre-stored on server)
        person_image_path = get_model_image_path(model_id)
        person_image = Image.open(person_image_path).convert("RGB")

        # Load garment image (uploaded by user)
        garment_bytes = await garment_image.read()
        garment_pil = Image.open(io.BytesIO(garment_bytes)).convert("RGB")
    except Exception as e:
        logger.error(f"Error loading images: {e}")
        raise HTTPException(status_code=400, detail=f"Error loading images: {str(e)}")

    # ── Run inference ──
    try:
        logger.info(
            f"Starting try-on: model={model_id}, category={category}, "
            f"flat_lay={flat_lay}, steps={num_timesteps}, skip_cfg_last_n={skip_cfg_last_n_steps}, seed={seed}"
        )

        result = pipeline(
            person_image=person_image,
            garment_image=garment_pil,
            category=category,
            garment_photo_type=garment_photo_type,
            num_timesteps=num_timesteps,
            skip_cfg_last_n_steps=skip_cfg_last_n_steps,
            seed=seed,
            segmentation_free=True,  # Best quality — recommended default
            person_model_id=model_id,
        )

        # Save result image to disk with a unique ID
        result_id = str(uuid.uuid4())
        result_path = os.path.join(RESULTS_DIR, f"{result_id}.png")
        output_image = result.images[0]
        output_image.save(result_path, format="PNG")

        # Track the result
        results_registry[result_id] = {
            "path": result_path,
            "model_id": model_id,
            "category": category,
        }

        logger.info(f"Try-on complete: result_id={result_id}, model={model_id}, category={category}")

        # ── Return JSON with result info ──
        # Flutter: use result_url to fetch the generated image
        return TryOnResponse(
            result_id=result_id,
            result_url=f"/api/v1/results/{result_id}",
            model_id=model_id,
            category=category,
        )

    except Exception as e:
        logger.error(f"Inference error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Try-on inference failed: {str(e)}")


# ══════════════════════════════════════════════════════════════════════════════
#  ENDPOINT 5: Get Try-On Result
# ══════════════════════════════════════════════════════════════════════════════
#
#  Flutter: Use this to fetch the generated image after a try-on request.
#
#  GET /api/v1/results/{result_id}
#
#  Response: image/png binary (the generated try-on image)
#
#  Flutter usage:
#    Image.network('$baseUrl/api/v1/results/$resultId')
#
# ══════════════════════════════════════════════════════════════════════════════


@app.get(
    "/api/v1/results/{result_id}",
    tags=["Results"],
    summary="Get a generated try-on result image",
    responses={
        200: {"content": {"image/png": {}}, "description": "Generated try-on image"},
        404: {"model": ErrorResponse, "description": "Result not found"},
    },
)
async def get_result(result_id: str):
    """Fetch a previously generated try-on image by its result ID.

    Flutter usage:
    ```dart
    // Option 1: Direct network image
    Image.network('$baseUrl/api/v1/results/$resultId')

    // Option 2: Download bytes for caching
    final response = await http.get(Uri.parse('$baseUrl/api/v1/results/$resultId'));
    if (response.statusCode == 200) {
      final imageBytes = response.bodyBytes;
      // Display: Image.memory(imageBytes)
      // Or save locally for caching
    }
    ```
    """
    # Check in-memory registry first
    if result_id in results_registry:
        result_path = results_registry[result_id]["path"]
    else:
        # Fallback: check if file exists on disk (e.g. after server restart)
        result_path = os.path.join(RESULTS_DIR, f"{result_id}.png")

    if not os.path.exists(result_path):
        raise HTTPException(status_code=404, detail=f"Result '{result_id}' not found.")

    with open(result_path, "rb") as f:
        image_bytes = f.read()

    return Response(
        content=image_bytes,
        media_type="image/png",
        headers={
            "Content-Disposition": f"inline; filename=tryon_{result_id}.png",
        },
    )
