import 'package:flutter/material.dart';

import '../../../data/services/api/models/listing.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/photo_image.dart';
import '../listing_texts.dart';
import '../view_models/nearby_view_model.dart';
import 'listings_tab_page.dart';
import 'location_problem_view.dart';

/// Mudas por perto, the first inner tab of Por perto, as in the Claude
/// Design screens `M-perto`, `M-perto-vazio` and `M-localizacao`: "até
/// 30 km" in the header and one row per neighbor's listing, nearest first,
/// with the photo, the names, the seedlings and the green line "a cerca de
/// N km · Bairro". Pulling the list down asks for the location and reads it
/// again; scrolling to its end reads the next page.
///
/// Without listings, "Doar a primeira" ([onDonate]); without a location,
/// the Localização negada screen.
class NearbyScreen extends StatelessWidget {
  const NearbyScreen({
    super.key,
    required this.viewModel,
    required this.onSelectTab,
    required this.onOpen,
    required this.onDonate,
  });

  final NearbyViewModel viewModel;

  /// Switches to the other inner tab.
  final ValueChanged<ListingsTab> onSelectTab;

  /// Opens the Detalhe do anúncio.
  final ValueChanged<NearbyListing> onOpen;

  /// Starts a listing from a new photo of the seedling.
  final VoidCallback onDonate;

  /// How close to the end of the list the next page starts loading.
  static const _loadMoreExtent = 400.0;

  @override
  Widget build(BuildContext context) {
    return ListingsTabPage(
      selected: ListingsTab.nearby,
      onSelect: onSelectTab,
      trailing: const HeaderPill(
        icon: Icons.location_on_outlined,
        label: 'até 30 km',
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.locationProblem case final problem?
              when !viewModel.isLoading) {
            return LocationProblemView(
              problem: problem,
              onRetry: viewModel.load,
              onOpenSettings: viewModel.openSettings,
            );
          }
          final listings = viewModel.listings;
          if (listings == null) {
            return viewModel.loadError != null && !viewModel.isLoading
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
          }
          if (listings.isEmpty) {
            return RefreshIndicator(
              onRefresh: viewModel.refresh,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: EmptyState(
                      icon: const Icon(Icons.spa_outlined),
                      title: 'Nenhuma muda a até 30 km ainda',
                      message:
                          'Que tal começar? Uma muda sua pode ser a primeira '
                          'do bairro.',
                      action: FilledButton(
                        onPressed: onDonate,
                        child: const Text('Doar a primeira'),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          final error = viewModel.loadError;
          return RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Only while scrolling: never during a layout.
                if (notification is ScrollUpdateNotification &&
                    notification.metrics.extentAfter < _loadMoreExtent) {
                  viewModel.loadMore();
                }
                return false;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: FormMessage(
                        error: error,
                        onRetry: viewModel.canRetry ? viewModel.refresh : null,
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 10, 18, 4),
                    child: Text(
                      'Doações de vizinhos a até 30 km',
                      style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
                    ),
                  ),
                  for (final listing in listings)
                    NearbyListingRow(
                      listing: listing,
                      onTap: () => onOpen(listing),
                    ),
                  if (viewModel.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (viewModel.loadMoreError case final error?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: FormMessage(
                        error: error,
                        onRetry: viewModel.loadMore,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One neighbor's listing: the photo, the common name, "Nome científico ·
/// N mudas" and the green line "a cerca de N km · Bairro".
class NearbyListingRow extends StatelessWidget {
  const NearbyListingRow({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final NearbyListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      ?listing.scientificName,
      seedlingCount(listing.quantity),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFE3EEE5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: PhotoImage(photo: listing.photo),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.commonName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${distanceText(listing.distanceKm)} · '
                    '${listing.neighborhood}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
