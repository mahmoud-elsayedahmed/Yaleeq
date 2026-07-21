import 'package:flutter/material.dart';
import 'package:yaleeq_dashboard/app/theme/app_colors.dart';

/// A segmented toggle that lets the user declare whether the garment image
/// is a flat-lay / product shot or a photo of the garment worn by a person.
///
/// This maps directly to the API's `flat_lay` boolean:
///   `true`  → flat-lay / product shot (default)
///   `false` → worn by a model
class FlatLayToggle extends StatelessWidget {
  const FlatLayToggle({
    super.key,
    required this.isFlatLay,
    required this.onChanged,
  });

  final bool isFlatLay;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            _ToggleOption(
              icon: Icons.grid_on_rounded,
              label: 'Product Shot',
              subtitle: 'Flat-lay photo',
              isSelected: isFlatLay,
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: 6),
            _ToggleOption(
              icon: Icons.person_outline_rounded,
              label: 'Model Photo',
              subtitle: 'Worn by person',
              isSelected: !isFlatLay,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(64),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textHint,
                size: 22,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withAlpha(179)
                            : AppColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
