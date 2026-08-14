import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:yaleeq_dashboard/core/constants/api_constants.dart';
import 'package:yaleeq_dashboard/features/try_on/data/models/model_info_dto.dart';

/// Talks directly to the FastAPI server via [Dio].
class TryOnRemoteDataSource {
  const TryOnRemoteDataSource(this._dio);

  final Dio _dio;

  Future<bool> checkHealth() async {
    final response =
        await _dio.get<Map<String, dynamic>>(ApiConstants.healthPath);
    final data = response.data!;
    return data['status'] == 'ok' && data['models_loaded'] == true;
  }

  Future<List<ModelInfoDto>> getModels() async {
    final response =
        await _dio.get<Map<String, dynamic>>(ApiConstants.modelsPath);
    final data = response.data!;
    return (data['models'] as List<dynamic>)
        .map((e) => ModelInfoDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sends the try-on request and returns the generated image bytes.
  ///
  /// Two-step flow matching the API contract:
  ///  1. POST /api/v1/try-on → JSON `{ result_id, result_url, ... }`
  ///  2. GET  /api/v1/results/{result_id} → image/png bytes
  Future<Uint8List> generateTryOn({
    required String modelId,
    required String category,
    required String garmentImagePath,
    required CancelToken cancelToken,
    bool flatLay = true,
    int numTimesteps = 15,
    int seed = 42,
  }) async {
    // Step 1: POST try-on request → JSON response
    final formData = FormData.fromMap({
      'model_id': modelId,
      'category': category,
      'flat_lay': flatLay.toString(),
      'num_timesteps': numTimesteps.toString(),
      'seed': seed.toString(),
      'garment_image': await MultipartFile.fromFile(
        garmentImagePath,
        filename: 'garment.jpg',
      ),
    });

    final jsonResponse = await _dio.post<Map<String, dynamic>>(
      ApiConstants.tryOnPath,
      data: formData,
      cancelToken: cancelToken,
    );

    final resultUrl = jsonResponse.data!['result_url'] as String;

    // Step 2: GET the generated image from result_url
    final imageResponse = await _dio.get<List<int>>(
      resultUrl,
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancelToken,
    );

    return Uint8List.fromList(imageResponse.data!);
  }
}
