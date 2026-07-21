import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yaleeq_dashboard/app/theme/app_colors.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/cubit/try_on_cubit.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/cubit/try_on_state.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/category_selector.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/flat_lay_toggle.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/garment_upload_section.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/generating_overlay.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/model_selection_carousel.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/result_preview.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/section_heading.dart';

/// Main (and only) screen — a single scrollable page with four sections:
///
/// 1. **Choose Your Model** — horizontal card carousel
/// 2. **Garment Category** — pill selector
/// 3. **Upload Garment** — camera / gallery
/// 4. **Image Type** — flat-lay toggle (product shot vs model photo)
///
/// Overlays: [GeneratingOverlay] during processing, [ResultPreview] on success.
class TryOnPage extends StatelessWidget {
  const TryOnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TryOnCubit, TryOnState>(
      listenWhen: (prev, curr) =>
          prev.errorMessage != curr.errorMessage &&
          curr.errorMessage != null,
      listener: _onErrorChanged,
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              const _BackgroundGradient(),
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _AppBar(modelsStatus: state.modelsStatus),
                    SliverToBoxAdapter(
                      child: _Body(state: state),
                    ),
                  ],
                ),
              ),
              if (state.generationStatus == GenerationStatus.generating)
                GeneratingOverlay(
                  onCancel: context.read<TryOnCubit>().cancelGeneration,
                ),
              if (state.generationStatus == GenerationStatus.success &&
                  state.resultImage != null)
                ResultPreview(
                  imageBytes: state.resultImage!,
                  onClose: context.read<TryOnCubit>().clearResult,
                  onTryAgain: context.read<TryOnCubit>().clearResult,
                ),
            ],
          ),
        );
      },
    );
  }

  void _onErrorChanged(BuildContext context, TryOnState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.errorMessage!),
        backgroundColor: AppColors.error,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => context.read<TryOnCubit>().clearError(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Private page-level widgets
// ═══════════════════════════════════════════════════════════

class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D0D1A),
            Color(0xFF1A1A2E),
            Color(0xFF0D0D1A),
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// ── App Bar ────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar({required this.modelsStatus});
  final ModelsStatus modelsStatus;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Yal',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text: 'eeq',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _ServerDot(status: modelsStatus),
        ),
      ],
    );
  }
}

class _ServerDot extends StatelessWidget {
  const _ServerDot({required this.status});
  final ModelsStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ModelsStatus.loaded => (AppColors.success, 'Online'),
      ModelsStatus.loading || ModelsStatus.initial => (AppColors.accent, 'Connecting'),
      ModelsStatus.error => (AppColors.error, 'Offline'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(128),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Body ───────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.state});
  final TryOnState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TryOnCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Choose Your Model',
          subtitle: 'Select who will try on the garment',
        ),
        _buildModelsSection(context),
        const SectionHeading(
          title: 'Garment Category',
          subtitle: 'What type of clothing?',
        ),
        CategorySelector(
          categories: state.selectedModel?.supportedCategories ?? [],
          selectedCategory: state.selectedCategory,
          onCategorySelected: cubit.selectCategory,
        ),
        const SectionHeading(
          title: 'Upload Garment',
          subtitle: 'Take a photo or pick from gallery',
        ),
        GarmentUploadSection(
          imagePath: state.garmentImagePath,
          onPickFromGallery: cubit.pickGarmentFromGallery,
          onPickFromCamera: cubit.pickGarmentFromCamera,
          onRemove: cubit.removeGarment,
        ),
        const SectionHeading(
          title: 'Image Type',
          subtitle: 'How is the garment shown in your photo?',
        ),
        FlatLayToggle(
          isFlatLay: state.flatLay,
          onChanged: cubit.toggleFlatLay,
        ),
        const SizedBox(height: 32),
        _GenerateButton(
          canGenerate: state.canGenerate,
          onPressed: cubit.generateTryOn,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildModelsSection(BuildContext context) {
    if (state.modelsStatus == ModelsStatus.loading ||
        state.modelsStatus == ModelsStatus.initial) {
      return const SizedBox(
        height: 190,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.modelsStatus == ModelsStatus.error) {
      return SizedBox(
        height: 190,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Could not load models',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: context.read<TryOnCubit>().loadModels,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ModelSelectionCarousel(
      models: state.models,
      selectedModel: state.selectedModel,
      onModelSelected: context.read<TryOnCubit>().selectModel,
    );
  }
}

// ── Generate Button ────────────────────────────────────────

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.canGenerate,
    required this.onPressed,
  });

  final bool canGenerate;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: canGenerate ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: canGenerate
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  )
                : null,
            color: canGenerate ? null : AppColors.cardFill,
            borderRadius: BorderRadius.circular(16),
            boxShadow: canGenerate
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(102),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                color: canGenerate ? Colors.white : AppColors.textHint,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Generate Try-On',
                style: TextStyle(
                  color: canGenerate ? Colors.white : AppColors.textHint,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
