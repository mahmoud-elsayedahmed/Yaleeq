/// Maps each model ID to its local asset filename.
///
/// These are bundled fallback images used when the API thumbnail
/// cannot be loaded (e.g. server is offline).
abstract final class ModelAssets {
  static const String _basePath = 'assets/model_images';

  /// model-id → image filename (matching api/model_images/).
  static const Map<String, String> _filenames = {
    'woman_01': 'woman1.jpeg',
    'woman_02': 'woman2.jpeg',
    'man_01': 'man.jpeg',
    'boy_01': 'little_boy.jpeg',
    'girl_01': 'little_girl.jpeg',
    'boy_02': 'mid_boy.jpeg',
    'girl_02': 'mid_girl.jpeg',
    'mannequin_women': 'women_Mannequin.png',
    'mannequin_man': 'man_Mannequin.png',
    'mannequin_child': 'child_Mannequin.png',
  };

  /// Returns the asset path for a given [modelId], or `null` if unknown.
  static String? assetPath(String modelId) {
    final filename = _filenames[modelId];
    if (filename == null) return null;
    return '$_basePath/$filename';
  }
}
