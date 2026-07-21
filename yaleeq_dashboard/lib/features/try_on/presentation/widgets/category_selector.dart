import 'package:flutter/material.dart';
import 'package:yaleeq_dashboard/app/theme/app_colors.dart';

/// Row of pill-shaped category toggle buttons.
///
/// If [categories] is empty (no model selected yet), shows a placeholder hint.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _EmptyPlaceholder();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: categories.map((category) {
          final isSelected = selectedCategory == category;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _CategoryPill(
                category: category,
                isSelected: isSelected,
                onTap: () => onCategorySelected(category),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Private sub-widgets ────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Center(
          child: Text(
            'Select a model first',
            style: TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon => switch (category) {
        'tops' => Icons.checkroom,
        'bottoms' => Icons.straighten,
        'one-pieces' => Icons.dry_cleaning,
        _ => Icons.category,
      };

  String get _label => switch (category) {
        'tops' => 'Tops',
        'bottoms' => 'Bottoms',
        'one-pieces' => 'Full Body',
        _ => category,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                )
              : null,
          color: isSelected ? null : AppColors.cardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.cardBorder,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              color: isSelected ? Colors.white : AppColors.textHint,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              _label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
