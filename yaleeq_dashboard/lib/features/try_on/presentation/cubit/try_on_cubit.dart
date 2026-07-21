import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yaleeq_dashboard/core/error/failures.dart';
import 'package:yaleeq_dashboard/core/error/result.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/repositories/try_on_repository.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/cubit/try_on_state.dart';

/// Manages the entire try-on flow: load models → select → upload → generate.
class TryOnCubit extends Cubit<TryOnState> {
  TryOnCubit({
    required TryOnRepository repository,
    ImagePicker? imagePicker,
  })  : _repository = repository,
        _imagePicker = imagePicker ?? ImagePicker(),
        super(const TryOnState());

  final TryOnRepository _repository;
  final ImagePicker _imagePicker;

  // ── Models ──────────────────────────────────────────────

  Future<void> loadModels() async {
    emit(state.copyWith(modelsStatus: ModelsStatus.loading));

    final result = await _repository.getModels();
    if (isClosed) return;

    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
          models: data,
          modelsStatus: ModelsStatus.loaded,
        ));
      case Err(:final failure):
        emit(state.copyWith(
          errorMessage: failure.message,
          modelsStatus: ModelsStatus.error,
        ));
    }
  }

  // ── Selection ───────────────────────────────────────────

  void selectModel(ModelInfo model) {
    // Reset category if the new model doesn't support the current one.
    final keepCategory = state.selectedCategory != null &&
        model.supportedCategories.contains(state.selectedCategory);

    emit(state.copyWith(
      selectedModel: model,
      clearSelectedCategory: !keepCategory,
      selectedCategory: keepCategory ? state.selectedCategory : null,
    ));
  }

  void selectCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }

  // ── Flat Lay Toggle ────────────────────────────────────

  void toggleFlatLay(bool value) {
    emit(state.copyWith(flatLay: value));
  }

  // ── Garment Image ───────────────────────────────────────

  Future<void> pickGarmentFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (image != null) {
        emit(state.copyWith(garmentImagePath: image.path));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Could not access gallery. Please check permissions.',
      ));
    }
  }

  Future<void> pickGarmentFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (image != null) {
        emit(state.copyWith(garmentImagePath: image.path));
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Could not access camera. Please check permissions.',
      ));
    }
  }

  void removeGarment() {
    emit(state.copyWith(clearGarmentImagePath: true));
  }

  // ── Generation ──────────────────────────────────────────

  Future<void> generateTryOn() async {
    if (!state.canGenerate) return;

    emit(state.copyWith(
      generationStatus: GenerationStatus.generating,
      clearResultImage: true,
      clearErrorMessage: true,
    ));

    final result = await _repository.generateTryOn(
      modelId: state.selectedModel!.id,
      category: state.selectedCategory!,
      garmentImagePath: state.garmentImagePath!,
      flatLay: state.flatLay,
    );

    if (isClosed) return;

    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
          resultImage: data,
          generationStatus: GenerationStatus.success,
        ));
      case Err(:final failure):
        if (failure is CancelledFailure) {
          emit(state.copyWith(generationStatus: GenerationStatus.idle));
        } else {
          emit(state.copyWith(
            errorMessage: failure.message,
            generationStatus: GenerationStatus.error,
          ));
        }
    }
  }

  void cancelGeneration() {
    _repository.cancelCurrentGeneration();
    emit(state.copyWith(generationStatus: GenerationStatus.idle));
  }

  void clearResult() {
    emit(state.copyWith(
      generationStatus: GenerationStatus.idle,
      clearResultImage: true,
    ));
  }

  void clearError() {
    emit(state.copyWith(clearErrorMessage: true));
  }
}
