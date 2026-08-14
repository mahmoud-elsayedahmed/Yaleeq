import 'dart:typed_data';

import 'package:yaleeq_dashboard/core/error/result.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';

/// Contract for the try-on data operations.
///
/// The domain layer depends on this interface; the concrete implementation
/// lives in the data layer and is injected at app startup.
abstract interface class TryOnRepository {
  Future<Result<bool>> checkHealth();

  Future<Result<List<ModelInfo>>> getModels();

  Future<Result<Uint8List>> generateTryOn({
    required String modelId,
    required String category,
    required String garmentImagePath,
    bool flatLay = true,
    int numTimesteps = 15,
    int seed = 42,
  });

  void cancelCurrentGeneration();
}
