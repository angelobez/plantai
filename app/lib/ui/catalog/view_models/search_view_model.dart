import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalog/catalog_repository.dart';
import '../../../data/services/api/models/species_summary.dart';
import '../../../domain/models/catalog_failure.dart';
import '../../core/view_models/safe_notify.dart';

/// Busca no Catálogo: searches as the User types, [debounce] after the last
/// change, and keeps the answer of the latest term only.
class SearchViewModel extends ChangeNotifier with SafeNotify {
  SearchViewModel({required this._catalogRepository});

  /// How long the term must stay unchanged before it is searched.
  static const debounce = Duration(milliseconds: 300);

  /// The shortest and longest term the API searches (after the trim).
  static const minTermLength = 2;
  static const maxTermLength = 50;

  final CatalogRepository _catalogRepository;

  /// The term as typed, without the spaces around it.
  String _term = '';
  String get term => _term;

  /// Whether [term] is too short to search; the screen shows a hint.
  bool get isTermTooShort => _term.length < minTermLength;

  /// The answer for [searchedTerm]; null before the first answer, or while
  /// the term is too short.
  List<SpeciesSummary>? _results;
  List<SpeciesSummary>? get results => _results;

  /// The term [results] answer, for "Salvar só com o nome".
  String? _searchedTerm;
  String? get searchedTerm => _searchedTerm;

  /// The search found nothing: the screen says so and offers to save the
  /// plant with [searchedTerm] as its name.
  bool get nothingFound => _results?.isEmpty ?? false;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  /// Why the last search failed.
  String? _error;
  String? get error => _error;

  /// Whether [retry] makes sense for [error].
  bool _canRetry = false;
  bool get canRetry => _canRetry;

  Timer? _debounceTimer;

  /// Bumped on every new term, so a late answer for an older one is dropped.
  int _run = 0;

  /// The text field changed: searches [text] once it stays the same for
  /// [debounce].
  void onQueryChanged(String text) {
    if (!_setTerm(text)) return;
    if (!isTermTooShort) {
      _debounceTimer = Timer(debounce, () => _search(_term));
    }
    notify();
  }

  /// Searches [text] at once (the keyboard's search key).
  Future<void> searchNow(String text) async {
    _debounceTimer?.cancel();
    _setTerm(text);
    if (isTermTooShort) {
      notify();
    } else {
      await _search(_term);
    }
  }

  /// Searches [term] again after a failure.
  Future<void> retry() => _search(_term);

  /// Takes [text] as the new term; whether it changed. A new term cancels
  /// the pending search and drops any answer still on its way. The caller
  /// notifies.
  bool _setTerm(String text) {
    final term = text.trim();
    if (term == _term) return false;
    _term = term;
    _debounceTimer?.cancel();
    _run++;
    _error = null;
    _canRetry = false;
    _isSearching = false;
    if (isTermTooShort) {
      _results = null;
      _searchedTerm = null;
    }
    return true;
  }

  Future<void> _search(String term) async {
    final run = ++_run;
    _isSearching = true;
    _error = null;
    _canRetry = false;
    notify();
    try {
      final results = await _catalogRepository.search(term);
      if (run != _run) return;
      _results = results;
      _searchedTerm = term;
    } on CatalogFailure catch (failure) {
      if (run != _run) return;
      _error = _message(failure);
      _canRetry = true;
    } finally {
      if (run == _run) {
        _isSearching = false;
        notify();
      }
    }
  }

  static String _message(CatalogFailure failure) => switch (failure) {
    CatalogFailure.noConnection =>
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    CatalogFailure.notFound ||
    CatalogFailure.unknown => 'Algo deu errado. Tente de novo.',
  };

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
