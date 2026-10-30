import 'dart:async';

import 'package:plantai/data/repositories/catalog/catalog_repository.dart';
import 'package:plantai/data/services/api/models/care_guide.dart';
import 'package:plantai/data/services/api/models/reference_photo.dart';
import 'package:plantai/data/services/api/models/species.dart';
import 'package:plantai/data/services/api/models/species_summary.dart';
import 'package:plantai/domain/models/care_guide_generating.dart';
import 'package:plantai/domain/models/catalog_failure.dart';

const monsteraPhoto = ReferencePhoto(
  url: 'https://photo-storage.fake/species/monstera.jpg',
  author: 'Ana Autora',
  license: 'CC BY-SA 4.0',
  sourceUrl: 'https://commons.wikimedia.org/wiki/File:Monstera.jpg',
);

const costelaDeAdao = SpeciesSummary(
  id: '0190e0d4-0000-7000-8000-0000000000c1',
  commonName: 'Costela-de-adão',
  scientificName: 'Monstera deliciosa',
  referencePhoto: monsteraPhoto,
  matchedAlternativeName: 'banana-de-macaco',
);

const filodendro = SpeciesSummary(
  id: '0190e0d4-0000-7000-8000-0000000000c2',
  commonName: 'Filodendro-ondulado',
  scientificName: 'Thaumatophyllum bipinnatifidum',
  referencePhoto: ReferencePhoto(
    url: 'https://upload.wikimedia.org/thaumatophyllum.jpg',
    author: 'Bruno Botânico',
    license: 'CC BY 4.0',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Thaumatophyllum.jpg',
  ),
);

const monsteraCareGuide = CareGuide(
  commonName: 'costela-de-adão',
  watering: CareTip(
    summary: '1x por semana',
    details: 'Regue quando os 2 a 3 cm de cima da terra estiverem secos.',
  ),
  light: CareTip(
    summary: 'Meia-sombra',
    details: 'Gosta de muita claridade, mas sem sol direto.',
  ),
  propagation: CareTip(
    summary: 'Estaca',
    details: 'Corte um pedaço do caule com um nó e deixe na água.',
  ),
);

const monstera = Species(
  id: '0190e0d4-0000-7000-8000-0000000000c1',
  commonName: 'Costela-de-adão',
  scientificName: 'Monstera deliciosa',
  referencePhoto: monsteraPhoto,
  otherNames: ['banana-de-macaco', 'imbé'],
  careGuide: monsteraCareGuide,
  careGuideStatus: CareGuideStatus.ready,
);

/// [monstera] when Claude failed to write its guide this time.
const monsteraWithoutGuide = Species(
  id: '0190e0d4-0000-7000-8000-0000000000c1',
  commonName: 'Costela-de-adão',
  scientificName: 'Monstera deliciosa',
  referencePhoto: monsteraPhoto,
  otherNames: ['banana-de-macaco', 'imbé'],
);

/// A [CatalogRepository] the test drives: [search] answers [results] and
/// [species] answers [speciesById], or both throw [failure] when set. It
/// records the calls in [searches] and [speciesAsked].
///
/// Set [gate] to hold every call until the test completes it.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({
    this.results = const [costelaDeAdao, filodendro],
    Map<String, Species>? speciesById,
  }) : speciesById = speciesById ?? {monstera.id: monstera};

  /// What every search answers, whatever the term.
  List<SpeciesSummary> results;

  /// The species [species] knows; any other id is [CatalogFailure.notFound].
  Map<String, Species> speciesById;

  /// Thrown by the next calls, until set back to null.
  CatalogFailure? failure;

  /// When set, calls wait for it before answering.
  Completer<void>? gate;

  /// How many of the next [species] calls answer [CareGuideGenerating]
  /// (with [retryAfter]), as while another request writes the guide.
  int generating = 0;
  Duration retryAfter = const Duration(seconds: 3);

  /// The term of every search, in order.
  final searches = <String>[];

  /// The id of every species read, in order.
  final speciesAsked = <String>[];

  Future<void> _answer() async {
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<List<SpeciesSummary>> search(String term) async {
    searches.add(term);
    await _answer();
    return results;
  }

  @override
  Future<Species> species(String id) async {
    speciesAsked.add(id);
    await _answer();
    if (generating > 0) {
      generating -= 1;
      throw CareGuideGenerating(retryAfter);
    }
    final species = speciesById[id];
    if (species == null) throw CatalogFailure.notFound;
    return species;
  }
}
