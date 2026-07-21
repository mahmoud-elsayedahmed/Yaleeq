import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yaleeq_dashboard/app/theme/app_colors.dart';

/// Full-screen result overlay with pinch-to-zoom and save/share actions.
class ResultPreview extends StatelessWidget {
  const ResultPreview({
    super.key,
    required this.imageBytes,
    required this.onClose,
    required this.onTryAgain,
  });

  final Uint8List imageBytes;
  final VoidCallback onClose;
  final VoidCallback onTryAgain;

  Future<void> _shareImage(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final name =
          'yaleeq_tryon_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Yaleeq Virtual Try-On',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF2000000), // 95 % black
      child: SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: onClose),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(imageBytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
            _BottomBar(
              onSave: () => _shareImage(context),
              onTryAgain: onTryAgain,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Text(
            'Your Look',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onSave,
    required this.onTryAgain,
  });

  final VoidCallback onSave;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(204),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BarButton(
              icon: Icons.download_rounded,
              label: 'Save & Share',
              isPrimary: true,
              onTap: onSave,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _BarButton(
              icon: Icons.refresh_rounded,
              label: 'Try Again',
              isPrimary: false,
              onTap: onTryAgain,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                )
              : null,
          color: isPrimary ? null : AppColors.cardFill,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary
              ? null
              : Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
