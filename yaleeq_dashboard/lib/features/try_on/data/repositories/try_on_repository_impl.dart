import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:yaleeq_dashboard/core/error/failures.dart';
import 'package:yaleeq_dashboard/core/error/result.dart';
import 'package:yaleeq_dashboard/features/try_on/data/datasources/try_on_remote_datasource.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/repositories/try_on_repository.dart';

/// Concrete repository that delegates to [TryOnRemoteDataSource]
/// and translates Dio exceptions into typed [Failure]s.
class TryOnRepositoryImpl implements TryOnRepository {
  TryOnRepositoryImpl(this._remote);

  final TryOnRemoteDataSource _remote;
  CancelToken? _activeCancelToken;

  // ── Health ──────────────────────────────────────────────

  @override
  Future<Result<bool>> checkHealth() async {
    try {
      final healthy = await _remote.checkHealth();
      return Success(healthy);
    } on DioException catch (e) {
      return Err(_mapDio(e));
    } catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  // ── Models ──────────────────────────────────────────────

  @override
  Future<Result<List<ModelInfo>>> getModels() async {
    try {
      final models = await _remote.getModels();
      return Success(models);
    } on DioException catch (e) {
      return Err(_mapDio(e));
    } catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  // ── Try-On ──────────────────────────────────────────────

  @override
  Future<Result<Uint8List>> generateTryOn({
    required String modelId,
    required String category,
    required String garmentImagePath,
    bool flatLay = true,
    int numTimesteps = 15,
    int seed = 42,
  }) async {
    _activeCancelToken = CancelToken();
    try {
      final bytes = await _remote.generateTryOn(
        modelId: modelId,
        category: category,
        garmentImagePath: garmentImagePath,
        cancelToken: _activeCancelToken!,
        flatLay: flatLay,
        numTimesteps: numTimesteps,
        seed: seed,
      );
      return Success(bytes);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return const Err(CancelledFailure());
      }
      return Err(_mapDio(e));
    } catch (e) {
      return Err(UnexpectedFailure(e.toString()));
    }
  }

  @override
  void cancelCurrentGeneration() {
    _activeCancelToken?.cancel('User cancelled');
    _activeCancelToken = null;
  }

  // ── Helpers ─────────────────────────────────────────────

  Failure _mapDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const NetworkFailure('Connection timed out. The server may be busy.'),
      DioExceptionType.connectionError => const NetworkFailure(),
      DioExceptionType.badResponse => _extractServerFailure(e),
      DioExceptionType.cancel => const CancelledFailure(),
      _ => UnexpectedFailure(e.message ?? 'Unknown network error'),
    };
  }

  ServerFailure _extractServerFailure(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    final detail = (data is Map)
        ? (data['detail'] ?? 'Server error').toString()
        : 'Server error ($statusCode)';
    return ServerFailure(detail, statusCode: statusCode);
  }
}
