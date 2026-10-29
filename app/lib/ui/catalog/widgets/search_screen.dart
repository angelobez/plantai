import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/api/models/species_summary.dart';
import '../../auth/widgets/form_message.dart';
import '../../core/themes/colors.dart';
import '../../core/widgets/photo_image.dart';
import '../view_models/search_view_model.dart';

/// Busca no Catálogo, as in the Claude Design screen (`M-busca`): the field
/// on top, the results with reference photo, name, scientific name and
/// "também chamada de…", and below them "Salvar só com o nome “termo”".
/// When nothing is found, it says so and offers the same button.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.viewModel,
    required this.onSpecies,
    this.onSaveNameOnly,
  });

  final SearchViewModel viewModel;

  /// A result was tapped.
  final ValueChanged<SpeciesSummary> onSpecies;

  /// "Salvar só com o nome", with the term as typed (trimmed). The button
  /// shows, disabled, while this is null.
  final ValueChanged<String>? onSaveNameOnly;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  SearchViewModel get _viewModel => widget.viewModel;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              controller: _query,
              onChanged: _viewModel.onQueryChanged,
              onSubmitted: _viewModel.searchNow,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) => _Body(
                  viewModel: _viewModel,
                  onSpecies: widget.onSpecies,
                  onSaveNameOnly: widget.onSaveNameOnly,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Voltar',
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.mist,
                foregroundColor: AppColors.ink,
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.chevron_left, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    SearchViewModel.maxTermLength,
                  ),
                ],
                style: const TextStyle(fontSize: 16, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Buscar espécie pelo nome',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.inkMuted,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppColors.mist,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.forest),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.viewModel,
    required this.onSpecies,
    required this.onSaveNameOnly,
  });

  final SearchViewModel viewModel;
  final ValueChanged<SpeciesSummary> onSpecies;
  final ValueChanged<String>? onSaveNameOnly;

  @override
  Widget build(BuildContext context) {
    final results = viewModel.results;
    final term = viewModel.searchedTerm;
    final error = viewModel.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Always there, so the list does not jump when it shows.
        SizedBox(
          height: 2,
          child: viewModel.isSearching
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: FormMessage(
                    error: error,
                    onRetry: viewModel.canRetry ? viewModel.retry : null,
                  ),
                )
              else if (viewModel.isTermTooShort)
                const _Hint(
                  'Digite pelo menos 2 letras do nome popular ou científico.',
                )
              else if (results != null && term != null) ...[
                if (results.isEmpty)
                  _NothingFound(term: term)
                else ...[
                  _Count(results.length),
                  for (final species in results)
                    _ResultRow(
                      species: species,
                      onTap: () => onSpecies(species),
                    ),
                ],
                _SaveNameOnly(
                  term: term,
                  nothingFound: results.isEmpty,
                  onPressed: onSaveNameOnly,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        count == 1 ? '1 espécie no Catálogo' : '$count espécies no Catálogo',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({required this.term});

  final String term;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Semantics(
        liveRegion: true,
        child: Text(
          'Não achei “$term” no Catálogo',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.species, required this.onTap});

  final SpeciesSummary species;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final alsoCalled = species.matchedAlternativeName;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 64,
                child: ReferencePhotoImage(photo: species.referencePhoto),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    species.commonName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    species.scientificName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  if (alsoCalled != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'também chamada de $alsoCalled',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forest,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Não achou?" (or, with nothing found, just the explanation) and the
/// button to save the plant with the name typed.
class _SaveNameOnly extends StatelessWidget {
  const _SaveNameOnly({
    required this.term,
    required this.nothingFound,
    required this.onPressed,
  });

  final String term;
  final bool nothingFound;
  final ValueChanged<String>? onPressed;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!nothingFound) ...[
            const Text(
              'Não achou?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            'Você pode salvar só com o nome que digitou. Sem espécie, a planta '
            'fica sem dicas de cuidado, mas dá para definir depois.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onPressed == null ? null : () => onPressed(term),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              foregroundColor: AppColors.forest,
              side: const BorderSide(color: AppColors.forest, width: 1.5),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              'Salvar só com o nome “$term”',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
