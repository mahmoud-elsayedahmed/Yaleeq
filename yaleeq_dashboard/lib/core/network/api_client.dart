import 'package:dio/dio.dart';
import 'package:yaleeq_dashboard/core/constants/api_constants.dart';

/// Factory for the pre-configured [Dio] instance.
///
/// [receiveTimeout] is intentionally very long (1 hour) because the
/// try-on inference can take 30-60 minutes on CPU.
abstract final class ApiClient {
  static Dio create() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(hours: 2),
        sendTimeout: const Duration(minutes: 5),
      ),
    )..interceptors.add(LogInterceptor(requestBody: true, responseBody: false));
  }
}
