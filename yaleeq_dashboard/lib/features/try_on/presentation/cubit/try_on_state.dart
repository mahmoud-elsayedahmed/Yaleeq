import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';

enum ModelsStatus { initial, loading, loaded, error }

enum GenerationStatus { idle, generating, success, error }

class TryOnState extends Equatable {
  const TryOnState({
    this.modelsStatus = ModelsStatus.initial,
    this.generationStatus = GenerationStatus.idle,
    this.models = const [],
    this.selectedModel,
    this.selectedCategory,
    this.flatLay = true,
    this.garmentImagePath,
    this.resultImage,
    this.errorMessage,
  });

  final ModelsStatus modelsStatus;
  final GenerationStatus generationStatus;
  final List<ModelInfo> models;
  final ModelInfo? selectedModel;
  final String? selectedCategory;

  /// `true` = garment is a flat-lay / product shot (default).
  /// `false` = garment is worn by a person in the photo.
  final bool flatLay;

  final String? garmentImagePath;
  final Uint8List? resultImage;
  final String? errorMessage;

  /// All three inputs must be selected before generation is allowed.
  bool get canGenerate =>
      selectedModel != null &&
      selectedCategory != null &&
      garmentImagePath != null &&
      generationStatus != GenerationStatus.generating;

  TryOnState copyWith({
    ModelsStatus? modelsStatus,
    GenerationStatus? generationStatus,
    List<ModelInfo>? models,
    ModelInfo? selectedModel,
    bool clearSelectedModel = false,
    String? selectedCategory,
    bool clearSelectedCategory = false,
    bool? flatLay,
    String? garmentImagePath,
    bool clearGarmentImagePath = false,
    Uint8List? resultImage,
    bool clearResultImage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TryOnState(
      modelsStatus: modelsStatus ?? this.modelsStatus,
      generationStatus: generationStatus ?? this.generationStatus,
      models: models ?? this.models,
      selectedModel:
          clearSelectedModel ? null : (selectedModel ?? this.selectedModel),
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      flatLay: flatLay ?? this.flatLay,
      garmentImagePath: clearGarmentImagePath
          ? null
          : (garmentImagePath ?? this.garmentImagePath),
      resultImage:
          clearResultImage ? null : (resultImage ?? this.resultImage),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        modelsStatus,
        generationStatus,
        models,
        selectedModel,
        selectedCategory,
        flatLay,
        garmentImagePath,
        resultImage,
        errorMessage,
      ];
}
