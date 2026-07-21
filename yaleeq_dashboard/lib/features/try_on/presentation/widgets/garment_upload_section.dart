import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yaleeq_dashboard/app/theme/app_colors.dart';

/// Shows either an upload prompt (camera + gallery buttons)
/// or the selected garment image preview with change/remove options.
class GarmentUploadSection extends StatelessWidget {
  const GarmentUploadSection({
    super.key,
    required this.imagePath,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onRemove,
  });

  final String? imagePath;
  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: imagePath != null
          ? _ImagePreview(
              imagePath: imagePath!,
              onPickFromGallery: onPickFromGallery,
              onPickFromCamera: onPickFromCamera,
              onRemove: onRemove,
            )
          : _UploadPrompt(
              onPickFromGallery: onPickFromGallery,
              onPickFromCamera: onPickFromCamera,
            ),
    );
  }
}

// ── Upload Prompt ──────────────────────────────────────────

class _UploadPrompt extends StatelessWidget {
  const _UploadPrompt({
    required this.onPickFromGallery,
    required this.onPickFromCamera,
  });

  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            color: AppColors.textHint,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Add your garment photo',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionChip(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onPickFromGallery,
              ),
              const SizedBox(width: 16),
              _ActionChip(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: onPickFromCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Image Preview ──────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.imagePath,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onRemove,
  });

  final String imagePath;
  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(imagePath), fit: BoxFit.cover),
            _RemoveButton(onRemove: onRemove),
            _BottomActions(
              onPickFromGallery: onPickFromGallery,
              onPickFromCamera: onPickFromCamera,
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onRemove});
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      right: 10,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(230),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onPickFromGallery,
    required this.onPickFromCamera,
  });

  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xB3000000)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionChip(
              icon: Icons.photo_library_outlined,
              label: 'Change',
              onTap: onPickFromGallery,
              compact: true,
            ),
            const SizedBox(width: 12),
            _ActionChip(
              icon: Icons.camera_alt_outlined,
              label: 'Retake',
              onTap: onPickFromCamera,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Action Chip ─────────────────────────────────────

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 20,
          vertical: compact ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(51),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(102)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryLight, size: compact ? 16 : 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primaryLight,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
