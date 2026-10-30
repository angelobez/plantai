import 'package:flutter/material.dart';

import '../../../data/services/api/models/listing.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/care_guide/care_guide_view.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/photo_image.dart';
import '../../core/widgets/photo_panel_scroll.dart';
import '../../core/widgets/round_back_button.dart';
import '../listing_texts.dart';
import '../view_models/listing_detail_view_model.dart';
import 'location_problem_view.dart';

/// Detalhe do anúncio, as in the Claude Design screen `M-anuncio`: the
/// photo on top and a white panel with the names, the seedlings, the
/// distance and neighborhood, "Doado por" with "Anunciado há X dias", the
/// note and, when the species has them ready, the care tips. Never the
/// donor's phone.
///
/// At the bottom, "Tenho interesse" on an active listing, which records the
/// interest and opens the donor's WhatsApp; on one that is no longer
/// active, a notice in its place.
class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.viewModel});

  final ListingDetailViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final listing = viewModel.listing;
        final Widget body;
        if (listing != null) {
          body = _ListingView(listing: listing, now: viewModel.now);
        } else if (viewModel.isLoading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (viewModel.locationProblem case final problem?) {
          body = SafeArea(
            child: LocationProblemView(
              problem: problem,
              onRetry: viewModel.load,
              onOpenSettings: viewModel.openSettings,
            ),
          );
        } else {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FormMessage(
                error: viewModel.loadError,
                onRetry: viewModel.canRetry ? viewModel.load : null,
              ),
            ),
          );
        }
        return Scaffold(
          body: TopLeftOverlay(body: body, overlay: const RoundBackButton()),
          bottomNavigationBar: listing == null
              ? null
              : _BottomBar(
                  child: viewModel.isAvailable
                      ? _InterestButton(
                          donorFirstName: listing.donorFirstName,
                          error: viewModel.interestError,
                          onPressed: viewModel.isShowingInterest
                              ? null
                              : viewModel.showInterest,
                        )
                      : const _UnavailableNotice(),
                ),
        );
      },
    );
  }
}

class _ListingView extends StatelessWidget {
  const _ListingView({required this.listing, required this.now});

  final ListingDetail listing;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scientificName = listing.scientificName;
    final note = listing.note;
    final careGuide = listing.careGuide;
    return PhotoPanelScroll(
      photo: PhotoImage(photo: listing.photo),
      photoHeight: 270,
      children: [
        Text(
          listing.commonName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        if (scientificName != null)
          Text(
            scientificName,
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.inkMuted,
            ),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(label: seedlingCount(listing.quantity)),
            _Pill(
              icon: Icons.location_on_outlined,
              label:
                  '${distanceText(listing.distanceKm)} · '
                  '${listing.neighborhood}',
              color: AppColors.forest,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DonorRow(
          firstName: listing.donorFirstName,
          postedAgo: postedAgoText(listing.createdAt, now),
        ),
        if (note != null) ...[
          const SizedBox(height: 14),
          Text(
            '“$note”',
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF3A453D),
            ),
          ),
        ],
        if (careGuide != null) ...[
          const SizedBox(height: 18),
          const Text(
            'Dicas de cuidado',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          CareGuideView(careGuide: careGuide),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.icon, this.color = AppColors.ink});

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Doado por Marina" and "Anunciado há 3 dias", between dividers.
class _DonorRow extends StatelessWidget {
  const _DonorRow({required this.firstName, required this.postedAgo});

  final String firstName;
  final String postedAgo;

  @override
  Widget build(BuildContext context) {
    final initial = firstName.isEmpty ? '?' : firstName.characters.first;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFC9DECD),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial.toUpperCase(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doado por $firstName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  postedAgo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: child,
        ),
      ),
    );
  }
}

/// "Tenho interesse", with what it does under it and, when the last tap
/// failed, why above it.
class _InterestButton extends StatelessWidget {
  const _InterestButton({
    required this.donorFirstName,
    required this.error,
    required this.onPressed,
  });

  final String donorFirstName;
  final String? error;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Tenho interesse'),
        ),
        const SizedBox(height: 6),
        Text(
          'Abre o WhatsApp de $donorFirstName com uma mensagem pronta.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

/// In place of "Tenho interesse" on a listing that is no longer active.
class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EAE7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Este anúncio não está mais disponível',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A453D),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'As mudas já foram doadas ou o anúncio foi encerrado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
