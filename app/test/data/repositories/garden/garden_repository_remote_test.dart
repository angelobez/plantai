import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/garden/garden_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/models/care_guide.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/domain/models/care_guide_generating.dart';
import 'package:plantai/domain/models/garden_failure.dart';
import 'package:plantai/domain/models/new_plant.dart';

import '../../../testing/fake_http_client_adapter.dart';

const _plantId = '0190e0d4-0000-7000-8000-0000000000a1';
const _photoId = '0190e0d4-0000-7000-8000-0000000000f1';
const _speciesId = '0190e0d4-0000-7000-8000-0000000000c1';

const _photoJson = {
  'id': _photoId,
  'url': 'http://localhost:9000/plantai-photos/photos/f1.jpg?X-Amz-Signature=1',
  'expiresAt': '2026-10-29T13:00:00.000Z',
};

const _itemJson = {
  'id': _plantId,
  'commonName': 'Jiboia da sala',
  'photo': _photoJson,
  'species': {
    'id': _speciesId,
    'commonName': 'Jiboia',
    'scientificName': 'Epipremnum aureum',
    'wateringSummary': '1x por semana',
  },
};

const _plantJson = {
  'id': _plantId,
  'commonName': 'Jiboia da sala',
  'photo': _photoJson,
  'species': {
    'id': _speciesId,
    'commonName': 'Jiboia',
    'scientificName': 'Epipremnum aureum',
    'referencePhoto': {
      'url': 'https://upload.wikimedia.org/jiboia.jpg',
      'author': 'Ana Autora',
      'license': 'CC BY-SA 4.0',
      'sourceUrl': 'https://commons.wikimedia.org/wiki/File:Jiboia.jpg',
    },
    'otherNames': ['hera-do-diabo'],
    'careGuide': {
      'commonName': 'jiboia',
      'watering': {'summary': '1x por semana', 'details': 'Regue.'},
      'light': {'summary': 'Meia-sombra', 'details': 'Sem sol direto.'},
      'propagation': {'summary': 'Estaca', 'details': 'Na água.'},
    },
    'careGuideStatus': 'ready',
  },
};

void main() {
  late FakeHttpClientAdapter adapter;
  late GardenRepositoryRemote repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter(
      (_) async => jsonResponse(200, [_itemJson]),
    );
    repository = GardenRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.2.0',
        updateRequired: UpdateRequired(),
        sessionStore: await SessionStore.load(),
        httpClientAdapter: adapter,
      ),
    );
  });

  Future<Object?> sentJson() async =>
      jsonDecode(utf8.decode(await adapter.bodies.single));

  test('plants reads the list with each species', () async {
    final plants = await repository.plants();

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/v1/plants');
    final plant = plants.single;
    expect(plant.id, _plantId);
    expect(plant.commonName, 'Jiboia da sala');
    expect(plant.photo.id, _photoId);
    expect(plant.photo.expiresAt, DateTime.utc(2026, 10, 29, 13));
    expect(plant.species?.commonName, 'Jiboia');
    expect(plant.species?.scientificName, 'Epipremnum aureum');
    expect(plant.species?.wateringSummary, '1x por semana');
  });

  test('a plant saved with only a name has no species', () async {
    adapter.respond = (_) async => jsonResponse(200, [
      {..._itemJson, 'species': null},
    ]);

    final plants = await repository.plants();

    expect(plants.single.species, isNull);
  });

  test('create posts the photo, the name and the species', () async {
    adapter.respond = (_) async => jsonResponse(201, _itemJson);

    final plant = await repository.create(
      const NewPlant(
        photoId: _photoId,
        commonName: 'Jiboia da sala',
        speciesId: _speciesId,
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/plants');
    expect(await sentJson(), {
      'photoId': _photoId,
      'commonName': 'Jiboia da sala',
      'speciesId': _speciesId,
    });
    expect(plant.id, _plantId);
  });

  test('create without a species sends no speciesId', () async {
    adapter.respond = (_) async =>
        jsonResponse(201, {..._itemJson, 'species': null});

    await repository.create(
      const NewPlant(photoId: _photoId, commonName: 'Pimenta da vó'),
    );

    expect(await sentJson(), {
      'photoId': _photoId,
      'commonName': 'Pimenta da vó',
    });
  });

  test('create tells its listeners the garden changed', () async {
    adapter.respond = (_) async => jsonResponse(201, _itemJson);
    var changes = 0;
    repository.addListener(() => changes += 1);

    await repository.create(
      const NewPlant(photoId: _photoId, commonName: 'Jiboia'),
    );

    expect(changes, 1);
  });

  test('a create that fails changes nothing', () async {
    adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');
    var changes = 0;
    repository.addListener(() => changes += 1);

    await expectLater(
      repository.create(const NewPlant(photoId: _photoId, commonName: 'J')),
      throwsA(GardenFailure.notFound),
    );
    expect(changes, 0);
  });

  test('update patches only the fields it is given', () async {
    adapter.respond = (_) async => jsonResponse(200, _itemJson);

    final plant = await repository.update(
      _plantId,
      commonName: 'Jiboia da sala',
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/v1/plants/$_plantId');
    expect(await sentJson(), {'commonName': 'Jiboia da sala'});
    expect(plant.commonName, 'Jiboia da sala');
  });

  test('update tells its listeners, and a failed one does not', () async {
    var changes = 0;
    repository.addListener(() => changes += 1);
    adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');

    await expectLater(
      repository.update(_plantId, commonName: 'J'),
      throwsA(GardenFailure.notFound),
    );
    expect(changes, 0);

    adapter.respond = (_) async => jsonResponse(200, _itemJson);
    await repository.update(_plantId, commonName: 'Jiboia da sala');
    expect(changes, 1);
  });

  test('remove deletes the plant and tells its listeners', () async {
    adapter.respond = (_) async => ResponseBody.fromString('', 204);
    var changes = 0;
    repository.addListener(() => changes += 1);

    await repository.remove(_plantId);

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/v1/plants/$_plantId');
    expect(changes, 1);
  });

  test('a remove that fails changes nothing', () async {
    adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');
    var changes = 0;
    repository.addListener(() => changes += 1);

    await expectLater(
      repository.remove(_plantId),
      throwsA(GardenFailure.notFound),
    );
    expect(changes, 0);
  });

  test('plant reads one plant with its species and care guide', () async {
    adapter.respond = (_) async => jsonResponse(200, _plantJson);

    final plant = await repository.plant(_plantId);

    final request = adapter.requests.single;
    expect(request.path, '/v1/plants/$_plantId');
    expect(request.receiveTimeout, const Duration(seconds: 60));
    expect(plant.commonName, 'Jiboia da sala');
    expect(plant.photo.id, _photoId);
    expect(plant.species?.otherNames, ['hera-do-diabo']);
    expect(plant.species?.referencePhoto.author, 'Ana Autora');
    expect(plant.species?.careGuideStatus, CareGuideStatus.ready);
    expect(plant.species?.careGuide?.light.summary, 'Meia-sombra');
  });

  test('a plant saved with only a name reads without a species', () async {
    adapter.respond = (_) async =>
        jsonResponse(200, {..._plantJson, 'species': null});

    final plant = await repository.plant(_plantId);

    expect(plant.species, isNull);
  });

  test(
    'CARE_GUIDE_GENERATING becomes CareGuideGenerating with the Retry-After',
    () async {
      adapter.respond = (_) async => ResponseBody.fromString(
        jsonEncode({'status': 202, 'code': 'CARE_GUIDE_GENERATING'}),
        202,
        headers: {
          Headers.contentTypeHeader: ['application/problem+json'],
          'retry-after': ['5'],
        },
      );

      await expectLater(
        repository.plant(_plantId),
        throwsA(
          isA<CareGuideGenerating>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 5),
          ),
        ),
      );
    },
  );

  test('no connection becomes GardenFailure.noConnection', () async {
    adapter.respond = (options) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused',
    );

    await expectLater(repository.plants(), throwsA(GardenFailure.noConnection));
    await expectLater(
      repository.plant(_plantId),
      throwsA(GardenFailure.noConnection),
    );
  });

  test('NOT_FOUND becomes GardenFailure.notFound', () async {
    adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');

    await expectLater(
      repository.plant(_plantId),
      throwsA(GardenFailure.notFound),
    );
  });

  for (final (code, status) in [
    ('VALIDATION_FAILED', 400),
    ('INTERNAL_ERROR', 500),
  ]) {
    test('$code becomes GardenFailure.unknown', () async {
      adapter.respond = (_) async => problemResponse(status, code);

      await expectLater(repository.plants(), throwsA(GardenFailure.unknown));
    });
  }
}
