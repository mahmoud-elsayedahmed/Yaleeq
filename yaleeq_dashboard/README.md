# 👕 Yaleeq Virtual Try-On Dashboard

Yaleeq Dashboard is a state-of-the-art Flutter client application designed for virtual garment try-ons. It provides a sleek, high-fidelity user interface that communicates with a FastAPI backend running the FASHN VTON deep learning engine. Through this application, users can select a human/mannequin avatar, choose a garment category, upload flat-lay garment photos, and instantly generate virtual fittings.

---

## 🚀 Key Technical Highlights

1. **Clean Architecture (DDD-Lite):** Structured with a strict separation of concerns into **Domain**, **Data**, and **Presentation** layers. This ensures testing capability, modularity, and clean dependency rules (dependencies only point inwards).
2. **Cubit State Management (Bloc):** Implements `flutter_bloc` to manage unidirectional data flow. The UI responds reactively to state modifications based on distinct state machine transitions (`ModelsStatus` and `GenerationStatus`).
3. **Cancellable Inference Engine:** Utilizes Dio's `CancelToken` to handle lengthy backend calculations. Users can cancel the inference request midway, immediately closing the active socket connection and releasing CPU/GPU resources on the server.
4. **Extreme-Timeout Tolerance Network Layer:** Features a pre-configured HTTP `Dio` client tailored with a **1-hour Receive Timeout** to account for CPU-bound model inference, which typically spans 15 to 45 minutes on average machine specs.
5. **Dynamic Server-Driven Metadata:** Features zero client-side hardcoding of models or genders. The app queries backend configurations via a REST API schema and dynamically updates available categories, genders, and thumbnail assets.
6. **Optimized Image Processing Pipelines:** Uses the native camera and gallery plugins but applies downscaling constraints (max width/height of `1024px`, quality `90%`) to dramatically reduce network payload sizes and prevent server memory bottlenecks.
7. **Premium Glassmorphic Dark UI Theme:** Implemented with a customized premium color scheme, bouncing scroll physics, visual status dots showing server connectivity, radial gradients, custom-painted loading animations, and gesture-driven zoom features (`InteractiveViewer`).

---

## 📁 Repository Structure & Directory Mapping

The codebase strictly follows standard clean architecture conventions:

```text
lib/
├── app/
│   ├── app.dart                  # Application entry configuration widget (MaterialApp, BLoC injector)
│   └── theme/
│       ├── app_colors.dart       # Curated dark-mode theme color palette configuration
│       └── app_theme.dart        # Global ThemeData definitions (Typography, Material3 widgets styling)
├── core/
│   ├── constants/
│   │   └── api_constants.dart    # API paths, base URLs, and route mapping definitions
│   ├── error/
│   │   ├── failures.dart         # Sealed failure hierarchy (Server, Network, Cancelled, Unexpected)
│   │   └── result.dart           # Sealed class wrapper Result<T> (Success/Err pattern)
│   └── network/
│       └── api_client.dart       # Factory for configuring the Dio client (Timeouts, LogInterceptor)
├── features/
│   └── try_on/
│       ├── data/
│       │   ├── datasources/
│       │   │   └── try_on_remote_datasource.dart   # RAW API calls (health, getModels, generateTryOn)
│       │   ├── models/
│       │   │   └── model_info_dto.dart             # JSON serialization / DTO logic
│       │   └── repositories/
│       │       └── try_on_repository_impl.dart    # Concrete implementation of TryOnRepository
│       ├── domain/
│       │   ├── entities/
│       │   │   └── model_info.dart                 # Decoupled business entity for avatar models
│       │   └── repositories/
│       │       └── try_on_repository.dart          # Repository contract interface definition
│       └── presentation/
│           ├── cubit/
│           │   ├── try_on_cubit.dart               # Controller logic (pick image, choose category, submit)
│           │   └── try_on_state.dart               # Immutable UI state class
│           ├── pages/
│           │   └── try_on_page.dart                # Main container page with Slivers layout
│           └── widgets/
│               ├── category_selector.dart          # Segmented clothing categories selector (tops/bottoms/etc)
│               ├── garment_upload_section.dart     # Camera/Gallery image picker panel with preview & remove
│               ├── generating_overlay.dart         # Fullscreen loading screen with elapsed timer & rotating messages
│               ├── model_card.dart                 # Horizontal list item displaying model thumbnail & metadata
│               ├── model_selection_carousel.dart   # Horizontal slider component holding avatars
│               ├── result_preview.dart             # Zoomable visual rendering layout with share & retry actions
│               └── section_heading.dart            # Typography block indicating visual sections
└── main.dart                                       # Setup, system overlay configuring, and bootstrap entry
```

---

## ⚙️ Architectural Layer Separation

### 1. Domain Layer (`domain/`)
The core of the feature, entirely independent of third-party libraries, JSON formats, or backend framework changes.
* **Entities (`ModelInfo`):** Models that represent avatars. Includes `id`, `name`, `gender`, `supportedCategories`, and relative `thumbnailUrl`. Extends `Equatable` for state change optimizations.
* **Repositories Contract (`TryOnRepository`):** Declares abstract contracts for fetching model registries, running inference, checking system health, and invoking thread cancellation.

### 2. Data Layer (`data/`)
Handles the communication logic and translates technical infrastructure interfaces to business logic formats.
* **Data Sources (`TryOnRemoteDataSource`):** Interacts directly with the API endpoints. Transmits arguments as `FormData` for multipart image uploads.
* **Models (`ModelInfoDto`):** Adapts JSON objects parsed from the server database into clean domain entities.
* **Repositories Concrete Implementations (`TryOnRepositoryImpl`):** Handles network exception mapping (`DioException`), detects network cancellation signals (`DioExceptionType.cancel`), and converts raw exceptions into standard domain failures.

### 3. Presentation Layer (`presentation/`)
Responsible for the user experience, layout drawing, and application state processing.
* **Cubit Controller (`TryOnCubit`):** Coordinates selection interactions, gallery and camera image picker triggers, and network generation states.
* **UI Widgets:** Split into single-responsibility custom components. Uses responsive constraints, and builds custom painters (e.g. `_GradientRingPainter`) for custom loaders.

---

## 🔌 API Integration Contracts & Endpoints

The dashboard client communicates directly with the following backend API layout:

### 1. Health Status check
* **Route:** `GET /api/v1/health`
* **Purpose:** Evaluates whether model weights are properly initialized and if the system is ready to receive inference requests.
* **Response payload:**
  ```json
  {
    "status": "ok",
    "models_loaded": true
  }
  ```

### 2. Retrieve Model Avatars
* **Route:** `GET /api/v1/models`
* **Purpose:** Downloads list of all pre-configured models/mannequins.
* **Response payload:**
  ```json
  {
    "models": [
      {
        "id": "woman_01",
        "name": "Woman - Style 1",
        "gender": "female",
        "supported_categories": ["tops", "bottoms", "one-pieces"],
        "thumbnail_url": "/api/v1/models/woman_01/thumbnail"
      }
    ]
  }
  ```

### 3. Fetch Model Thumbnail
* **Route:** `GET /api/v1/models/{model_id}/thumbnail`
* **Purpose:** Streams visual representation of avatar cards.
* **Response format:** Image bytes (`image/jpeg` or `image/png`).

### 4. Run Try-On Inference
* **Route:** `POST /api/v1/try-on`
* **Content-Type:** `multipart/form-data`
* **Parameters sent:**
  * `model_id`: Identifier of selected avatar (String)
  * `category`: Fit mapping configuration (`tops` | `bottoms` | `one-pieces`)
  * `garment_photo_type`: `flat-lay` (Default, represents static garment photo)
  * `num_timesteps`: Inferences execution steps count (`20` for quick CPU demo runs)
  * `seed`: Randomization indicator (`42`)
  * `garment_image`: Image file input (Multipart)
* **Response format:** Returns generated raw output image byte stream (`image/png`).

---

## ⏱️ Network Timeouts & Cancellation Flow

Because FASHN VTON inferences on CPU are computationally heavy, traditional network timeout setups will crash the application. Yaleeq App overrides default behavior with specialized network constraints:

```dart
BaseOptions(
  baseUrl: ApiConstants.baseUrl,
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(hours: 1), // Extended to 60 minutes for CPU try-on rendering
  sendTimeout: const Duration(minutes: 5),
)
```

### Cancellation Architecture Flow:
1. When generating starts, a unique `CancelToken` is registered on the Dio repository implementation level.
2. The UI enters `GenerationStatus.generating` state, displaying the full-screen overlay.
3. If the user clicks **Cancel**, `cancelCurrentGeneration()` calls `_activeCancelToken?.cancel('User cancelled')`.
4. This instantly halts the network stream, sends a socket disconnect, and emits `CancelledFailure`.
5. The UI catches the `CancelledFailure` inside `TryOnCubit` and resets the interface back to `GenerationStatus.idle` without throwing error notifications to the user.

---

## 🎨 Visual System & Branding Parameters

The app utilizes a tailored color system designed for dark interfaces:

* **Dark Background Canvas:** Deep Navy (`0xFF0D0D1A`) & Slate Indigo (`0xFF1A1A2E`)
* **Primary Accent Color:** Vivid Purple (`0xFF6C5CE7`) and Light Lilac (`0xFFA29BFE`)
* **Secondary Highlight:** Sunrise Yellow (`0xFFFDCB6E`)
* **Semantic Status Indicators:** Successful Green (`0xFF00B894`) & Alert Red (`0xFFFF6B6B`)
* **Card Backings:** Transparent glassmorphism fills (8% Opacity: `0x14FFFFFF`) with fine borders (10% Opacity: `0x1AFFFFFF`)

---

## 🛠️ Step-by-Step Setup and Execution Guide

### 1. Setting Up the Host Connection Base URL
Open [api_constants.dart](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/yaleeq_dashboard/lib/core/constants/api_constants.dart) and configure the target IP based on your debug configuration:

* **Android Emulator:** Needs `http://10.0.2.2:8000` (maps to host localhost loopback).
* **iOS Simulator / Web client:** Needs `http://127.0.0.1:8000`.
* **Physical Device over USB connection:**
  If you run the client on a real phone via USB, you can forward traffic directly without needing local network IP matching:
  ```bash
  adb reverse tcp:8000 tcp:8000
  ```
  After running this command, set `baseUrl` in Dart to `http://127.0.0.1:8000`.
* **Physical Device over Local Wi-Fi Network:**
  Change `baseUrl` to your computer's local IP address (e.g. `http://192.168.1.7:8000`). Ensure the FastAPI backend is running with host bind configured:
  ```bash
  uvicorn api.main:app --host 0.0.0.0 --port 8000
  ```

### 2. Launching the App
1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
2. Check device attachments:
   ```bash
   flutter devices
   ```
3. Run the development environment:
   ```bash
   flutter run
   ```
4. Build a production bundle (Android APK):
   ```bash
   flutter build apk --release
   ```
   For iOS builds:
   ```bash
   flutter build ipa --release
   ```
