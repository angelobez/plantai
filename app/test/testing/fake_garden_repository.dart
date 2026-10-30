import 'dart:async';

import 'package:plantai/data/repositories/garden/garden_repository.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/data/services/api/models/plant.dart';
import 'package:plantai/domain/models/care_guide_generating.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/domain/models/new_plant.dart';
import 'package:plantai/domain/models/plant_changes.dart';

import 'fake_catalog_repository.dart';

final jiboiaPhoto = Photo(
  id: '0190e0d4-0000-7000-8000-0000000000f1',
  url: 'https://photo-storage.fake/photos/f1.jpg',
  expiresAt: DateTime.utc(2026, 11, 3, 15),
);

final pimentaPhoto = Photo(
  id: '0190e0d4-0000-7000-8000-0000000000f2',
  url: 'https://photo-storage.fake/photos/f2.jpg',
  expiresAt: DateTime.utc(2026, 11, 3, 15),
);

/// A plant of [monstera] whose care guide is written.
final monsteraDaSala = Plant(
  id: '0190e0d4-0000-7000-8000-0000000000a1',
  commonName: 'Monstera da sala',
  photo: jiboiaPhoto,
  species: monstera,
);

/// A plant saved with only a name.
final pimentaDaVo = Plant(
  id: '0190e0d4-0000-7000-8000-0000000000a2',
  commonName: 'Pimenta da vó',
  photo: pimentaPhoto,
);

/// [monsteraDaSala] in the list.
final monsteraDaSalaItem = PlantSummary(
  id: monsteraDaSala.id,
  commonName: 'Monstera da sala',
  photo: jiboiaPhoto,
  species: const PlantSpeciesSummary(
    id: '0190e0d4-0000-7000-8000-0000000000c1',
    commonName: 'Costela-de-adão',
    scientificName: 'Monstera deliciosa',
    wateringSummary: '1x por semana',
  ),
);

/// [pimentaDaVo] in the list.
final pimentaDaVoItem = PlantSummary(
  id: pimentaDaVo.id,
  commonName: 'Pimenta da vó',
  photo: pimentaPhoto,
);

/// A [GardenRepository] the test drives: [plants] answers [garden],
/// [plant] answers [plantsById], and [create] puts a new plant at the top of
/// [garden], telling the listeners. [update] changes the plant in
/// [plantsById] and [garden] (a species becomes [monstera]; a plant that has
/// one throws [GardenFailure.speciesAlreadySet]) and [remove] takes it out,
/// telling the listeners too. Every call throws [failure] when set. It
/// records the calls in [listed], [plantsAsked], [created], [updates] and
/// [removed].
///
/// Set [gate] to hold every call until the test completes it.
class FakeGardenRepository extends GardenRepository {
  FakeGardenRepository({List<PlantSummary>? garden, Map<String, Plant>? byId})
    : garden = garden ?? [monsteraDaSalaItem, pimentaDaVoItem],
      plantsById =
          byId ??
          {monsteraDaSala.id: monsteraDaSala, pimentaDaVo.id: pimentaDaVo};

  /// What [plants] answers, newest first.
  List<PlantSummary> garden;

  /// The plants [plant] knows; any other id is [GardenFailure.notFound].
  Map<String, Plant> plantsById;

  /// Thrown by the next calls, until set back to null.
  GardenFailure? failure;

  /// When set, calls wait for it before answering.
  Completer<void>? gate;

  /// How many of the next [plant] calls answer [CareGuideGenerating] (with
  /// [retryAfter]), as while another request writes the guide.
  int generating = 0;
  Duration retryAfter = const Duration(seconds: 3);

  /// How many times the list was read.
  int listed = 0;

  /// The id of every plant read, in order.
  final plantsAsked = <String>[];

  /// Every plant saved, in order.
  final created = <NewPlant>[];

  /// Every change asked for, in order, with the plant's id.
  final updates = <(String, PlantChanges)>[];

  /// The id of every plant removed, in order.
  final removed = <String>[];

  Future<void> _answer() async {
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<List<PlantSummary>> plants() async {
    listed += 1;
    await _answer();
    return List.of(garden);
  }

  @override
  Future<PlantSummary> create(NewPlant plant) async {
    created.add(plant);
    await _answer();
    final saved = PlantSummary(
      id: 'plant-${created.length}',
      commonName: plant.commonName,
      photo: jiboiaPhoto,
    );
    garden = [saved, ...garden];
    plantsById[saved.id] = Plant(
      id: saved.id,
      commonName: plant.commonName,
      photo: jiboiaPhoto,
      species: plant.speciesId == null ? null : monstera,
    );
    notifyListeners();
    return saved;
  }

  @override
  Future<Plant> plant(String id) async {
    plantsAsked.add(id);
    await _answer();
    if (generating > 0) {
      generating -= 1;
      throw CareGuideGenerating(retryAfter);
    }
    final plant = plantsById[id];
    if (plant == null) throw GardenFailure.notFound;
    return plant;
  }

  @override
  Future<PlantSummary> update(String id, PlantChanges changes) async {
    updates.add((id, changes));
    await _answer();
    final plant = plantsById[id];
    if (plant == null) throw GardenFailure.notFound;
    if (changes.speciesId != null && plant.species != null) {
      throw GardenFailure.speciesAlreadySet;
    }
    final changed = Plant(
      id: id,
      commonName: changes.commonName ?? plant.commonName,
      photo: plant.photo,
      species: changes.speciesId != null ? monstera : plant.species,
    );
    plantsById[id] = changed;
    final item = PlantSummary(
      id: id,
      commonName: changed.commonName,
      photo: changed.photo,
      species: changed.species == null
          ? null
          : PlantSpeciesSummary(
              id: changed.species!.id,
              commonName: changed.species!.commonName,
              scientificName: changed.species!.scientificName,
            ),
    );
    garden = [for (final p in garden) p.id == id ? item : p];
    notifyListeners();
    return item;
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    await _answer();
    if (plantsById.remove(id) == null) throw GardenFailure.notFound;
    garden = garden.where((plant) => plant.id != id).toList();
    notifyListeners();
  }
}
