import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/catalog/catalog_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/data/services/api/models/care_guide.dart';
import 'package:plantai/domain/models/care_guide_generating.dart';
import 'package:plantai/domain/models/catalog_failure.dart';

import '../../../testing/fake_http_client_adapter.dart';

const _id = '0190e0d4-0000-7000-8000-0000000000bb';

const _photoJson = {
  'url':
      'http://localhost:9000/plantai-photos/species/bb.jpg?X-Amz-Signature=1',
  'author': 'Ana Autora',
  'license': 'CC BY-SA 4.0',
  'sourceUrl': 'https://commons.wikimedia.org/wiki/File:Monstera.jpg',
};

const _itemJson = {
  'id': _id,
  'commonName': 'Costela-de-adão',
  'scientificName': 'Monstera deliciosa',
  'referencePhoto': _photoJson,
  'matchedAlternativeName': 'banana-de-macaco',
};

const _speciesJson = {
  'id': _id,
  'commonName': 'Costela-de-adão',
  'scientificName': 'Monstera deliciosa',
  'referencePhoto': _photoJson,
  'otherNames': ['banana-de-macaco', 'imbé'],
  'careGuide': {
    'commonName': 'costela-de-adão',
    'watering': {
      'summary': '1x por semana',
      'details': 'Regue quando a terra secar.',
    },
    'light': {'summary': 'Meia-sombra', 'details': 'Sem sol direto.'},
    'propagation': {'summary': 'Estaca', 'details': 'Corte um nó do caule.'},
  },
  'careGuideStatus': 'ready',
};

void main() {
  late FakeHttpClientAdapter adapter;
  late CatalogRepositoryRemote repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter(
      (_) async => jsonResponse(200, [_itemJson]),
    );
    repository = CatalogRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.2.0',
        updateRequired: UpdateRequired(),
        sessionStore: await SessionStore.load(),
        httpClientAdapter: adapter,
      ),
    );
  });

  test('search sends the term as q and parses the results', () async {
    final results = await repository.search('banana');

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/v1/species');
    expect(request.uri.queryParameters, {'q': 'banana'});

    final item = results.single;
    expect(item.id, _id);
    expect(item.commonName, 'Costela-de-adão');
    expect(item.scientificName, 'Monstera deliciosa');
    expect(item.matchedAlternativeName, 'banana-de-macaco');
    expect(item.referencePhoto.url, _photoJson['url']);
    expect(item.referencePhoto.author, 'Ana Autora');
    expect(item.referencePhoto.license, 'CC BY-SA 4.0');
    expect(item.referencePhoto.sourceUrl, _photoJson['sourceUrl']);
  });

  test('a result without an alternative name has it null', () async {
    adapter.respond = (_) async => jsonResponse(200, [
      {..._itemJson, 'matchedAlternativeName': null},
    ]);

    final results = await repository.search('costela');

    expect(results.single.matchedAlternativeName, isNull);
  });

  test('species reads one species with its other names', () async {
    adapter.respond = (_) async => jsonResponse(200, _speciesJson);

    final species = await repository.species(_id);

    expect(adapter.requests.single.path, '/v1/species/$_id');
    expect(species.commonName, 'Costela-de-adão');
    expect(species.scientificName, 'Monstera deliciosa');
    expect(species.otherNames, ['banana-de-macaco', 'imbé']);
    expect(species.referencePhoto.sourceUrl, _photoJson['sourceUrl']);
    expect(species.careGuideStatus, CareGuideStatus.ready);
    expect(species.careGuide?.watering.summary, '1x por semana');
    expect(species.careGuide?.light.details, 'Sem sol direto.');
    expect(species.careGuide?.propagation.summary, 'Estaca');
  });

  test(
    'species waits up to a minute, while Claude may be writing the guide',
    () async {
      adapter.respond = (_) async => jsonResponse(200, _speciesJson);

      await repository.species(_id);

      expect(
        adapter.requests.single.receiveTimeout,
        const Duration(seconds: 60),
      );
    },
  );

  test('an unavailable care guide comes as null', () async {
    adapter.respond = (_) async => jsonResponse(200, {
      ..._speciesJson,
      'careGuide': null,
      'careGuideStatus': 'unavailable',
    });

    final species = await repository.species(_id);

    expect(species.careGuide, isNull);
    expect(species.careGuideStatus, CareGuideStatus.unavailable);
  });

  test(
    'CARE_GUIDE_GENERATING becomes CareGuideGenerating with the Retry-After',
    () async {
      adapter.respond = (_) async => ResponseBody.fromString(
        jsonEncode({'status': 202, 'code': 'CARE_GUIDE_GENERATING'}),
        202,
        headers: {
          Headers.contentTypeHeader: ['application/problem+json'],
          'retry-after': ['3'],
        },
      );

      await expectLater(
        repository.species(_id),
        throwsA(
          isA<CareGuideGenerating>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 3),
          ),
        ),
      );
    },
  );

  test('no connection becomes CatalogFailure.noConnection', () async {
    adapter.respond = (options) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'refused',
    );

    await expectLater(
      repository.search('jiboia'),
      throwsA(CatalogFailure.noConnection),
    );
    await expectLater(
      repository.species(_id),
      throwsA(CatalogFailure.noConnection),
    );
  });

  test('NOT_FOUND becomes CatalogFailure.notFound', () async {
    adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');

    await expectLater(
      repository.species(_id),
      throwsA(CatalogFailure.notFound),
    );
  });

  for (final (code, status) in [
    ('VALIDATION_FAILED', 400),
    ('INTERNAL_ERROR', 500),
  ]) {
    test('$code becomes CatalogFailure.unknown', () async {
      adapter.respond = (_) async => problemResponse(status, code);

      await expectLater(
        repository.search('jiboia'),
        throwsA(CatalogFailure.unknown),
      );
    });
  }
}
