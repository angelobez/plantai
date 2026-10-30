import 'package:flutter/material.dart';

import '../../../data/services/api/models/listing.dart';
import '../../core/themes/colors.dart';
import '../view_models/my_listings_view_model.dart';
import 'edit_listing_dialog.dart';

/// What the donor can do with one of their listings in Meus anúncios, in
/// the order of the actions menu.
enum ListingAction {
  edit('Editar'),
  close('Encerrar');

  const ListingAction(this.label);

  /// The menu item's text.
  final String label;

  /// The actions [listing] offers, in menu order: none once it is donated
  /// or closed.
  static List<ListingAction> availableFor(MyListing listing) => [
    if (listing.status == ListingStatus.active)
      for (final action in values)
        if (action._isAvailableFor(listing)) action,
  ];

  /// Rules of an action on top of "the listing is active" (such as
  /// `canRenew` for Renovar).
  bool _isAvailableFor(MyListing listing) => switch (this) {
    edit || close => true,
  };
}

/// The "⋮" button of a listing row, opening its [ListingAction]s. Shows
/// nothing when the listing has none.
class ListingActionsMenu extends StatelessWidget {
  const ListingActionsMenu({
    super.key,
    required this.listing,
    required this.onSelected,
    this.enabled = true,
  });

  final MyListing listing;
  final ValueChanged<ListingAction> onSelected;

  /// False while another action runs.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final actions = ListingAction.availableFor(listing);
    if (actions.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<ListingAction>(
      tooltip: 'Ações do anúncio',
      enabled: enabled,
      icon: const Icon(Icons.more_vert, color: AppColors.inkMuted),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final action in actions)
          PopupMenuItem(value: action, child: Text(action.label)),
      ],
    );
  }
}

/// Runs [action] on [listing] through [viewModel]: asks what it needs first
/// (the Editar dialog, the Encerrar confirmation) and shows a SnackBar with
/// [MyListingsViewModel.actionError] when it fails. The list itself
/// refreshes through the repository.
Future<void> runListingAction(
  BuildContext context, {
  required MyListingsViewModel viewModel,
  required MyListing listing,
  required ListingAction action,
}) async {
  final bool worked;
  switch (action) {
    case ListingAction.edit:
      final changes = await showEditListingDialog(context, listing: listing);
      if (changes == null) return;
      worked = await viewModel.edit(listing, changes);
    case ListingAction.close:
      if (!await _confirmClose(context)) return;
      worked = await viewModel.close(listing);
  }
  final error = viewModel.actionError;
  if (worked || error == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
}

/// "Encerrar anúncio?": true when the User confirms.
Future<bool> _confirmClose(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Encerrar anúncio?'),
      content: const Text(
        'O anúncio sai do Por perto e não pode ser reaberto. Ele continua '
        'aqui em Meus anúncios, como encerrado.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Encerrar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
