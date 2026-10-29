import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/identification/identification_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/models/identification.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/domain/models/identification_failure.dart';

import '../../../testing/fake_http_client_adapter.dart';

const _photoId = '0190e0d4-0000-7000-8000-0000000000aa';
const _identificationId = '0190e0d4-0000-7000-8000-0000000000ii';

const _imageJson = {
  'url': 'https://bs.plantnet.org/image/m/1',
  'author': 'Ana Ribeiro',
  'license': 'CC BY-SA',
  'sourceUrl': 'https://bs.plantnet.org/image/o/1',
};

const _identificationJson = {
  'id': _identificationId,
  'result': 'recognized',
  'candidates': [
    {
      'scientificName': 'Epipremnum aureum',
      'commonName': 'Jiboia',
      'score': 0.81,
      'images': [_imageJson],
    },
    {
      'scientificName': 'Epipremnum pinnatum',
      'commonName': null,
      'score': 0.1,
      'images': <Object>[],
    },
  ],
  'remainingToday': 7,
};

void main() {
  late FakeHttpClientAdapter adapter;
  late IdentificationRepositoryRemote repository;

  Future<void> answering(
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) async {
    adapter = FakeHttpClientAdapter(handler);
    repository = IdentificationRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.2.0',
        updateRequired: UpdateRequired(),
        sessionStore: await SessionStore.load(),
        httpClientAdapter: adapter,
      ),
    );
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await answering((_) async => jsonResponse(201, _identificationJson));
  });

  Future<Map<String, dynamic>> sentBody(int index) async =>
      jsonDecode(utf8.decode(await adapter.bodies[index]))
          as Map<String, dynamic>;

  test('identify posts the photo id and parses the candidates', () async {
    final identification = await repository.identify(_photoId);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/identifications');
    expect(await sentBody(0), {'photoId': _photoId});
    // Pl@ntNet takes ~2 s, but up to 10 s, plus GBIF.
    expect(request.receiveTimeout, ApiClient.slowReceiveTimeout);

    expect(identification.id, _identificationId);
    expect(identification.result, IdentificationResult.recognized);
    expect(identification.remainingToday, 7);
    final [first, second] = identification.candidates;
    expect(first.scientificName, 'Epipremnum aureum');
    expect(first.displayName, 'Jiboia');
    expect(first.score, 0.81);
    expect(first.images.single.author, 'Ana Ribeiro');
    expect(first.images.single.sourceUrl, 'https://bs.plantnet.org/image/o/1');
    expect(second.commonName, isNull);
    expect(second.displayName, 'Epipremnum pinnatum');
    expect(second.images, isEmpty);
  });

  test('identify reads a photo that was not recognized', () async {
    await answering(
      (_) async => jsonResponse(201, {
        'id': _identificationId,
        'result': 'not_recognized',
        'candidates': <Object>[],
        'remainingToday': 9,
      }),
    );

    final identification = await repository.identify(_photoId);

    expect(identification.result, IdentificationResult.notRecognized);
    expect(identification.candidates, isEmpty);
  });

  test('choose posts the index and parses the species', () async {
    await answering(
      (_) async => jsonResponse(200, {
        'species': {
          'id': '0190e0d4-0000-7000-8000-0000000000c1',
          'commonName': 'Epipremnum aureum',
          'scientificName': 'Epipremnum aureum',
          'referencePhoto': _imageJson,
          'matchedAlternativeName': null,
        },
      }),
    );

    final species = await repository.choose(_identificationId, 1);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/identifications/$_identificationId/choice');
    expect(await sentBody(0), {'candidateIndex': 1});
    expect(species.id, '0190e0d4-0000-7000-8000-0000000000c1');
    expect(species.scientificName, 'Epipremnum aureum');
    expect(species.referencePhoto.author, 'Ana Ribeiro');
  });

  test('chooseNone posts none: true and takes the 204', () async {
    await answering((_) async => ResponseBody.fromString('', 204));

    await repository.chooseNone(_identificationId);

    final request = adapter.requests.single;
    expect(request.path, '/v1/identifications/$_identificationId/choice');
    expect(await sentBody(0), {'none': true});
  });

  for (final (code, status, failure) in [
    ('IDENTIFICATION_DAILY_LIMIT', 429, IdentificationFailure.dailyLimit),
    (
      'IDENTIFICATION_SERVICE_UNAVAILABLE',
      503,
      IdentificationFailure.serviceUnavailable,
    ),
    ('IDENTIFICATION_ALREADY_CHOSEN', 409, IdentificationFailure.alreadyChosen),
    ('NOT_FOUND', 404, IdentificationFailure.notFound),
    ('INTERNAL_ERROR', 500, IdentificationFailure.unknown),
  ]) {
    test('$code becomes $failure', () async {
      await answering((_) async => problemResponse(status, code));

      await expectLater(repository.identify(_photoId), throwsA(failure));
      await expectLater(
        repository.choose(_identificationId, 0),
        throwsA(failure),
      );
    });
  }

  test('no connection becomes noConnection', () async {
    await answering(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );

    await expectLater(
      repository.identify(_photoId),
      throwsA(IdentificationFailure.noConnection),
    );
    await expectLater(
      repository.chooseNone(_identificationId),
      throwsA(IdentificationFailure.noConnection),
    );
  });
}
