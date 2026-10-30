import 'package:flutter/material.dart';

import '../../../data/services/api/models/listing.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/photo_image.dart';
import '../listing_texts.dart';
import '../view_models/my_listings_view_model.dart';
import 'listing_actions.dart';
import 'listings_tab_page.dart';

/// Meus anúncios, the second inner tab of Por perto, as in the Claude
/// Design screen `M-meus-anuncios`: one row per listing, newest first, with
/// the photo, the name, the status pill, the seedlings left with "expira em
/// X dias" and how many Users had interest. Donated and closed listings are
/// dimmed. Pulling the list down reads it again.
///
/// With [onDonate], "Doar mudas" sits in the header and, without listings,
/// in the empty state, which explains how to donate.
class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({
    super.key,
    required this.viewModel,
    required this.onSelectTab,
    this.onDonate,
  });

  final MyListingsViewModel viewModel;

  /// Switches to the other inner tab.
  final ValueChanged<ListingsTab> onSelectTab;

  /// Starts a listing from a new photo of the seedling.
  final VoidCallback? onDonate;

  @override
  Widget build(BuildContext context) {
    return ListingsTabPage(
      selected: ListingsTab.mine,
      onSelect: onSelectTab,
      trailing: onDonate == null
          ? null
          : HeaderPill(icon: Icons.add, label: 'Doar mudas', onTap: onDonate),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
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
                    child: _NoListings(onDonate: onDonate),
                  ),
                ),
              ),
            );
          }
          final error = viewModel.loadError;
          final now = viewModel.now;
          return RefreshIndicator(
            onRefresh: viewModel.refresh,
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
                for (final listing in listings)
                  MyListingRow(
                    listing: listing,
                    now: now,
                    actionsEnabled: !viewModel.isActing,
                    onAction: (action) => runListingAction(
                      context,
                      viewModel: viewModel,
                      listing: listing,
                      action: action,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One listing of Meus anúncios. An active listing has the donor's actions
/// menu at the right ([ListingActionsMenu]); a donated or closed one is
/// dimmed, with none.
class MyListingRow extends StatelessWidget {
  const MyListingRow({
    super.key,
    required this.listing,
    required this.now,
    this.onAction,
    this.actionsEnabled = true,
  });

  final MyListing listing;

  /// The instant "expira em X dias" counts from.
  final DateTime now;

  /// Runs the action chosen in the menu; without it, the row has no menu.
  final ValueChanged<ListingAction>? onAction;

  /// False while another action runs.
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final isOver = listing.status.isOver;
    final details = switch (listing.status) {
      ListingStatus.active =>
        '${seedlingCount(listing.quantity)} · '
            '${expiresInText(listing.expiresAt, now)}',
      ListingStatus.donated => 'Todas as mudas foram doadas',
      ListingStatus.closed => seedlingCount(listing.quantity),
    };
    const muted = TextStyle(fontSize: 13, color: AppColors.inkMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isOver ? const Color(0xFFFAFBFA) : null,
        border: const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isOver ? const Color(0xFFE6EAE7) : const Color(0xFFE3EEE5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Opacity(
              opacity: isOver ? 0.6 : 1,
              child: PhotoImage(photo: listing.photo),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        listing.commonName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isOver ? AppColors.inkMuted : AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(status: listing.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(details, style: muted),
                const SizedBox(height: 2),
                Text(
                  interestCountText(listing.interestCount),
                  style: listing.interestCount > 0 && !isOver
                      ? const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        )
                      : muted,
                ),
              ],
            ),
          ),
          if (onAction case final onAction?)
            ListingActionsMenu(
              listing: listing,
              enabled: actionsEnabled,
              onSelected: onAction,
            ),
        ],
      ),
    );
  }
}

/// "Ativo", "Doado" or "Encerrado".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final ListingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      ListingStatus.active => (
        'Ativo',
        const Color(0xFFDCEBDF),
        const Color(0xFF2E5237),
      ),
      ListingStatus.donated => (
        'Doado',
        const Color(0xFFE6EAE7),
        const Color(0xFF3A453D),
      ),
      ListingStatus.closed => (
        'Encerrado',
        const Color(0xFFE6EAE7),
        const Color(0xFF3A453D),
      ),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _NoListings extends StatelessWidget {
  const _NoListings({required this.onDonate});

  final VoidCallback? onDonate;

  @override
  Widget build(BuildContext context) {
    final onDonate = this.onDonate;
    return EmptyState(
      icon: const Icon(Icons.volunteer_activism_outlined),
      title: 'Você ainda não anunciou mudas',
      message:
          'Toque em "Doar mudas" aqui, com uma foto da muda, ou na tela de '
          'uma planta do seu jardim, para anunciar as mudas que sobram.',
      action: onDonate == null
          ? null
          : FilledButton(onPressed: onDonate, child: const Text('Doar mudas')),
    );
  }
}
