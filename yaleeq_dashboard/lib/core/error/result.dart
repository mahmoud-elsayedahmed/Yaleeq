import 'package:yaleeq_dashboard/core/error/failures.dart';

/// A lightweight alternative to `Either` that leverages Dart 3 sealed classes
/// for exhaustive pattern-matching.
///
/// ```dart
/// final result = await repository.getModels();
/// switch (result) {
///   case Success(:final data): handleData(data);
///   case Err(:final failure):  handleError(failure);
/// }
/// ```
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
