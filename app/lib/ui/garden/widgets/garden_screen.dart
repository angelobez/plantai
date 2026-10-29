import 'package:flutter/material.dart';

import '../../../data/services/api/models/plant.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/leaf_icon.dart';
import '../../core/widgets/photo_image.dart';
import '../../core/widgets/tab_page.dart';
import '../view_models/garden_view_model.dart';

/// The Jardim tab, as in the Claude Design screens (`M-jardim`,
/// `M-jardim-vazio`): "N plantas" in the header and a light-green card per
/// plant, with the User's photo coming out of its left edge, the name, the
/// species and the watering line. Pulling the list down reads it again.
///
/// An empty garden invites to identify the first plant ([onIdentify]).
class GardenScreen extends StatelessWidget {
  const GardenScreen({
    super.key,
    required this.viewModel,
    required this.onPlant,
    required this.onIdentify,
  });

  final GardenViewModel viewModel;

  /// Opens the Tela da planta.
  final ValueChanged<PlantSummary> onPlant;

  /// Opens the photo flow, from the empty garden.
  final VoidCallback onIdentify;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final plants = viewModel.plants;
        final Widget body;
        if (plants == null) {
          body = viewModel.loadError != null && !viewModel.isLoading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: FormMessage(
                      error: viewModel.loadError,
                      onRetry: viewModel.canRetry ? viewModel.load : null,
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator());
        } else if (plants.isEmpty) {
          body = RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _EmptyGarden(onIdentify: onIdentify),
                ),
              ),
            ),
          );
        } else {
          body = RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: _PlantList(
              plants: plants,
              error: viewModel.loadError,
              onRetry: viewModel.canRetry ? viewModel.refresh : null,
              onPlant: onPlant,
            ),
          );
        }
        return TabPage(
          trailing: plants == null || plants.isEmpty
              ? null
              : Text(
                  plantCount(plants.length),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
          body: body,
        );
      },
    );
  }
}

/// "1 planta", "4 plantas".
String plantCount(int count) => count == 1 ? '1 planta' : '$count plantas';

class _PlantList extends StatelessWidget {
  const _PlantList({
    required this.plants,
    required this.error,
    required this.onRetry,
    required this.onPlant,
  });

  final List<PlantSummary> plants;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<PlantSummary> onPlant;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // The photos come 10 px out of the cards' left edge.
      padding: const EdgeInsets.fromLTRB(28, 18, 18, 18),
      children: [
        if (error != null) ...[
          FormMessage(error: error, onRetry: onRetry),
          const SizedBox(height: 16),
        ],
        for (final (index, plant) in plants.indexed) ...[
          if (index > 0) const SizedBox(height: 16),
          _PlantCard(plant: plant, onTap: () => onPlant(plant)),
        ],
      ],
    );
  }
}

const _photoSize = 84.0;
const _photoOutside = 10.0;

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant, required this.onTap});

  final PlantSummary plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final species = plant.species;
    final watering = switch (species) {
      null => 'Sem dicas: defina a espécie',
      PlantSpeciesSummary(:final wateringSummary?) => 'Rega · $wateringSummary',
      _ => null,
    };
    const muted = TextStyle(fontSize: 12, color: AppColors.inkMuted);
    return Material(
      color: AppColors.mist,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
          child: Row(
            children: [
              Transform.translate(
                offset: const Offset(-_photoOutside, 0),
                child: Container(
                  width: _photoSize,
                  height: _photoSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9DECD),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x261F2A22),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: PhotoImage(photo: plant.photo),
                ),
              ),
              const SizedBox(width: 14 - _photoOutside),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.commonName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(species?.commonName ?? 'Sem espécie', style: muted),
                    if (watering != null) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            size: 14,
                            color: AppColors.forest,
                          ),
                          const SizedBox(width: 5),
                          Expanded(child: Text(watering, style: muted)),
                        ],
                      ),
                    ],
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

class _EmptyGarden extends StatelessWidget {
  const _EmptyGarden({required this.onIdentify});

  final VoidCallback onIdentify;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: const LeafIcon(strokeWidth: 1.6),
      title: 'Seu jardim está vazio',
      message:
          'Tire uma foto de uma planta sua para descobrir a espécie e receber '
          'dicas de cuidado.',
      action: FilledButton.icon(
        onPressed: onIdentify,
        icon: const Icon(Icons.photo_camera_outlined, size: 20),
        label: const Text('Identificar minha primeira planta'),
      ),
    );
  }
}
