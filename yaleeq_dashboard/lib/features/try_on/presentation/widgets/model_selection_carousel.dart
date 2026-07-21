import 'package:flutter/material.dart';
import 'package:yaleeq_dashboard/features/try_on/domain/entities/model_info.dart';
import 'package:yaleeq_dashboard/features/try_on/presentation/widgets/model_card.dart';

/// Horizontal scrollable carousel of [ModelCard]s.
class ModelSelectionCarousel extends StatelessWidget {
  const ModelSelectionCarousel({
    super.key,
    required this.models,
    required this.selectedModel,
    required this.onModelSelected,
  });

  final List<ModelInfo> models;
  final ModelInfo? selectedModel;
  final ValueChanged<ModelInfo> onModelSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: models.length,
        itemBuilder: (context, index) {
          final model = models[index];
          return ModelCard(
            model: model,
            isSelected: selectedModel?.id == model.id,
            onTap: () => onModelSelected(model),
          );
        },
      ),
    );
  }
}
