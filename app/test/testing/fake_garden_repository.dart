import 'dart:async';

import 'package:plantai/data/repositories/garden/garden_repository.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/data/services/api/models/plant.dart';
import 'package:plantai/domain/models/care_guide_generating.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/domain/models/new_plant.dart';

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
/// [plant] answers [plantsById], [create] puts a new plant at the top of
/// [garden], [update] renames one and [remove] takes it out, each telling
/// the listeners. Every call throws [failure] when set. It records the calls
/// in [listed], [plantsAsked], [created], [updated] and [removed].
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

  /// Every update, in order: the id and the fields given.
  final updated = <({String id, String? commonName, String? speciesId})>[];

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
  Future<PlantSummary> update(
    String id, {
    String? commonName,
    String? speciesId,
  }) async {
    updated.add((id: id, commonName: commonName, speciesId: speciesId));
    await _answer();
    final index = garden.indexWhere((plant) => plant.id == id);
    final plant = plantsById[id];
    if (index < 0 || plant == null) throw GardenFailure.notFound;
    final item = garden[index];
    final renamed = PlantSummary(
      id: id,
      commonName: commonName ?? item.commonName,
      photo: item.photo,
      species: item.species,
    );
    garden = [...garden]..[index] = renamed;
    plantsById[id] = Plant(
      id: id,
      commonName: renamed.commonName,
      photo: plant.photo,
      species: plant.species,
    );
    notifyListeners();
    return renamed;
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
