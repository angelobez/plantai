import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/listing/listing_repository.dart';
import '../../../data/services/api/models/listing.dart';
import '../../../domain/models/listing_changes.dart';
import '../../../domain/models/listing_failure.dart';
import '../../core/view_models/safe_notify.dart';
import '../listing_failure_message.dart';

/// Meus anúncios: the donor's listings, newest first, with the effective
/// status.
///
/// [load] shows the loading state; [refresh] (pull to refresh) reads the
/// list again while the old one stays on screen. A change made through the
/// [ListingRepository] (a listing published, and later the donor's actions)
/// refreshes it too. Only the newest read counts: an older answer that comes
/// late is dropped.
///
/// The donor's actions on an active listing ([donate], [edit], [close],
/// [renew]) return whether they worked; on failure, [actionError] says why.
/// A failure that means the list on screen is out of date (the listing is
/// no longer active or is gone, has fewer seedlings, or is not in its last
/// days) reads the list again so it shows as it is now.
class MyListingsViewModel extends ChangeNotifier with SafeNotify {
  MyListingsViewModel({
    required this._listingRepository,
    DateTime Function() clock = DateTime.now,
  }) : _now = clock {
    _listingRepository.addListener(_onListingsChanged);
  }

  final ListingRepository _listingRepository;
  final DateTime Function() _now;

  /// The instant "expira em X dias" counts from.
  DateTime get now => _now();

  /// Null until the first answer.
  List<MyListing>? _listings;
  List<MyListing>? get listings => _listings;

  /// Whether the list was read and the User has no listing.
  bool get isEmpty => _listings?.isEmpty ?? false;

  /// True while the first read (or the one after an error) is running.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Why the last read failed; shown over the list when there is one.
  String? _loadError;
  String? get loadError => _loadError;

  /// Whether reading again makes sense for [loadError].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  int _run = 0;

  /// True while one of the donor's actions runs.
  bool _isActing = false;
  bool get isActing => _isActing;

  /// Why the last action failed; null after one that worked.
  String? _actionError;
  String? get actionError => _actionError;

  /// "Doei algumas": [count] seedlings, from 1 up to the quantity, left
  /// [listing]; at zero it shows as donated.
  Future<bool> donate(MyListing listing, int count) =>
      _act(() => _listingRepository.donate(listing.id, count));

  /// "Editar": applies [changes] to [listing].
  Future<bool> edit(MyListing listing, ListingChanges changes) =>
      _act(() => _listingRepository.update(listing.id, changes));

  /// "Encerrar", after the User confirmed: closes [listing] for good.
  Future<bool> close(MyListing listing) =>
      _act(() => _listingRepository.close(listing.id));

  /// "Renovar", only while [MyListing.canRenew]: [listing] expires 30 days
  /// from now.
  Future<bool> renew(MyListing listing) =>
      _act(() => _listingRepository.renew(listing.id));

  /// Failures that mean the list on screen no longer matches the API.
  static const _staleListFailures = {
    ListingFailure.notActive,
    ListingFailure.notFound,
    ListingFailure.invalidDonationCount,
    ListingFailure.renewalNotAllowed,
  };

  /// Runs one of the donor's actions. When it works, the repository tells
  /// its listeners and the list is read again ([_onListingsChanged]).
  Future<bool> _act(Future<void> Function() action) async {
    _isActing = true;
    _actionError = null;
    notify();
    try {
      await action();
      return true;
    } on ListingFailure catch (failure) {
      _actionError = listingFailureMessage(failure);
      if (_staleListFailures.contains(failure)) unawaited(refresh());
      return false;
    } finally {
      _isActing = false;
      notify();
    }
  }

  /// Reads the listings, showing the loading state.
  Future<void> load() => _read(showLoading: true);

  /// Reads the listings again, keeping the current list on screen.
  Future<void> refresh() => _read(showLoading: _listings == null);

  Future<void> _read({required bool showLoading}) async {
    final run = ++_run;
    _isLoading = showLoading;
    if (showLoading) _loadError = null;
    notify();
    try {
      final listings = await _listingRepository.myListings();
      if (!_isCurrent(run)) return;
      _listings = listings;
      _loadError = null;
      _canRetry = false;
    } on ListingFailure catch (failure) {
      if (!_isCurrent(run)) return;
      _loadError = listingFailureMessage(failure);
      _canRetry = true;
    } finally {
      if (_isCurrent(run)) {
        _isLoading = false;
        notify();
      }
    }
  }

  bool _isCurrent(int run) => run == _run && !isDisposed;

  void _onListingsChanged() {
    if (!isDisposed) refresh();
  }

  @override
  void dispose() {
    _listingRepository.removeListener(_onListingsChanged);
    super.dispose();
  }
}
