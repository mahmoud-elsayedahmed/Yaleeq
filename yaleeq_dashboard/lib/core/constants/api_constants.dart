/// Centralized API endpoint constants.
///
/// Change [baseUrl] to match your server:
/// - Android Emulator  → `http://10.0.2.2:8000`
/// - iOS Simulator     → `http://127.0.0.1:8000`
/// - Physical Device   → `http://<your-pc-ip>:8000`
abstract final class ApiConstants {
  // Using adb reverse tcp:8000 tcp:8000 — traffic goes over USB.
  // To revert to WiFi, use: 'http://192.168.1.7:8000'
  static const String baseUrl = 'http://127.0.0.1:8000';

  static const String healthPath = '/api/v1/health';
  static const String modelsPath = '/api/v1/models';
  static const String tryOnPath = '/api/v1/try-on';

  static String modelThumbnailPath(String modelId) =>
      '/api/v1/models/$modelId/thumbnail';

  static String fullThumbnailUrl(String relativePath) =>
      '$baseUrl$relativePath';
}
