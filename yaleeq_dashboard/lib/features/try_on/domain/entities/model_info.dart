import 'package:equatable/equatable.dart';

/// Pure domain entity representing a person model available for try-on.
///
/// This entity lives in the domain layer and has zero knowledge of JSON,
/// HTTP, or any data-source concern.
class ModelInfo extends Equatable {
  const ModelInfo({
    required this.id,
    required this.name,
    required this.gender,
    required this.supportedCategories,
    required this.thumbnailUrl,
  });

  final String id;
  final String name;
  final String gender;
  final List<String> supportedCategories;

  /// Relative URL path — e.g. `/api/v1/models/woman_01/thumbnail`.
  final String thumbnailUrl;

  @override
  List<Object?> get props => [id, name, gender, supportedCategories, thumbnailUrl];
}
