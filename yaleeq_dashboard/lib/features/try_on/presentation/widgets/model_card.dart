import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:yaleeq_dashboard/app/theme/app_colors.dart';
import 'package:yaleeq_dashboard/core/constants/api_constants.dart';
import 'package:yaleeq_dashboard/core/constants/model_assets.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';

/// A single selectable model card for the horizontal carousel.
///
/// Shows the model thumbnail with a gradient name overlay.
/// When [isSelected] is true, it gets a glowing purple border and checkmark.
class ModelCard extends StatelessWidget {
  const ModelCard({
    super.key,
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final ModelInfo model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(77),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumbnail(thumbnailUrl: model.thumbnailUrl, modelId: model.id),
              _NameOverlay(model: model),
              if (isSelected) const _CheckBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.thumbnailUrl, required this.modelId});
  final String thumbnailUrl;
  final String modelId;

  @override
  Widget build(BuildContext context) {
    final localAsset = ModelAssets.assetPath(modelId);

    return CachedNetworkImage(
      imageUrl: ApiConstants.fullThumbnailUrl(thumbnailUrl),
      fit: BoxFit.cover,
      placeholder: (context, url) => localAsset != null
          ? Image.asset(localAsset, fit: BoxFit.cover)
          : Container(
              color: AppColors.surfaceLight,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorWidget: (context, url, error) => localAsset != null
          ? Image.asset(localAsset, fit: BoxFit.cover)
          : Container(
              color: AppColors.surfaceLight,
              child: const Icon(
                Icons.person_outline,
                color: AppColors.textHint,
                size: 40,
              ),
            ),
    );
  }
}

class _NameOverlay extends StatelessWidget {
  const _NameOverlay({required this.model});
  final ModelInfo model;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              model.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  model.gender == 'female' ? Icons.female : Icons.male,
                  color: AppColors.textSecondary,
                  size: 12,
                ),
                const SizedBox(width: 2),
                Text(
                  model.gender,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      ),
    );
  }
}
