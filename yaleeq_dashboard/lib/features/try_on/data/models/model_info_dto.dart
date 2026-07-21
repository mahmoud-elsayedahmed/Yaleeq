import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';

/// Data-transfer object that maps the API's JSON to [ModelInfo].
class ModelInfoDto extends ModelInfo {
  const ModelInfoDto({
    required super.id,
    required super.name,
    required super.gender,
    required super.supportedCategories,
    required super.thumbnailUrl,
  });

  factory ModelInfoDto.fromJson(Map<String, dynamic> json) {
    return ModelInfoDto(
      id: json['id'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String,
      supportedCategories:
          List<String>.from(json['supported_categories'] as List<dynamic>),
      thumbnailUrl: json['thumbnail_url'] as String,
    );
  }
}
