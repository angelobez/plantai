import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/listing/listing_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/location/location_service.dart';
import 'package:plantai/data/services/session/session_store.dart';
import 'package:plantai/domain/models/listing_changes.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/domain/models/new_listing.dart';

import '../../../testing/fake_http_client_adapter.dart';

const _listingId = '0190e0d4-0000-7000-8000-0000000000b1';
const _photoId = '0190e0d4-0000-7000-8000-0000000000f1';
const _plantId = '0190e0d4-0000-7000-8000-0000000000a1';
const _speciesId = '0190e0d4-0000-7000-8000-0000000000c1';

const _listingJson = {
  'id': _listingId,
  'commonName': 'Costela-de-adão',
  'photo': {
    'id': _photoId,
    'url': 'http://localhost:9000/plantai-photos/photos/f1.jpg?X-Amz=1',
    'expiresAt': '2026-10-29T13:00:00.000Z',
  },
  'status': 'active',
  'quantity': 3,
  'interestCount': 2,
  'expiresAt': '2026-11-28T12:00:00.000Z',
  'canRenew': false,
};

void main() {
  late FakeHttpClientAdapter adapter;
  late ListingRepositoryRemote repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = FakeHttpClientAdapter(
      (_) async => jsonResponse(201, _listingJson),
    );
    repository = ListingRepositoryRemote(
      apiClient: ApiClient(
        baseUrl: 'http://api.test',
        appVersion: '0.3.0',
        updateRequired: UpdateRequired(),
        sessionStore: await SessionStore.load(),
        httpClientAdapter: adapter,
      ),
    );
  });

  Future<Object?> sentJson() async =>
      jsonDecode(utf8.decode(await adapter.bodies.single));

  test('create posts the listing and answers it as in Meus anúncios', () async {
    final listing = await repository.create(
      const NewListing(
        photoId: _photoId,
        commonName: 'Costela-de-adão',
        quantity: 3,
        speciesId: _speciesId,
        plantId: _plantId,
        note: ' Pegar à tarde ',
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/listings');
    expect(await sentJson(), {
      'photoId': _photoId,
      'commonName': 'Costela-de-adão',
      'quantity': 3,
      'speciesId': _speciesId,
      'plantId': _plantId,
      'note': 'Pegar à tarde',
    });
    expect(listing.id, _listingId);
    expect(listing.status, ListingStatus.active);
    expect(listing.quantity, 3);
    expect(listing.interestCount, 2);
    expect(listing.expiresAt, DateTime.utc(2026, 11, 28, 12));
    expect(listing.canRenew, isFalse);
    expect(listing.photo.id, _photoId);
  });

  test('create leaves out what the listing does not have', () async {
    await repository.create(
      const NewListing(
        photoId: _photoId,
        commonName: 'Espada-de-são-jorge',
        quantity: 1,
        note: '   ',
      ),
    );

    expect(await sentJson(), {
      'photoId': _photoId,
      'commonName': 'Espada-de-são-jorge',
      'quantity': 1,
    });
  });

  test('create tells the listeners', () async {
    var notified = 0;
    repository.addListener(() => notified++);

    await repository.create(
      const NewListing(photoId: _photoId, commonName: 'Jiboia', quantity: 1),
    );

    expect(notified, 1);
  });

  test('myListings reads the User’s listings', () async {
    adapter.respond = (_) async => jsonResponse(200, [
      _listingJson,
      {..._listingJson, 'status': 'donated', 'quantity': 0},
      {..._listingJson, 'status': 'something-new'},
    ]);

    final listings = await repository.myListings();

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/v1/me/listings');
    expect(listings.map((listing) => listing.status), [
      ListingStatus.active,
      ListingStatus.donated,
      ListingStatus.closed,
    ]);
  });

  test('myListings reads the note, null without one', () async {
    adapter.respond = (_) async => jsonResponse(200, [
      {..._listingJson, 'note': 'Pegar à tarde'},
      {..._listingJson, 'note': null},
    ]);

    final listings = await repository.myListings();

    expect(listings.map((listing) => listing.note), ['Pegar à tarde', null]);
  });

  test('update patches only the fields it has, trimming the note, and tells '
      'the listeners', () async {
    adapter.respond = (_) async =>
        jsonResponse(200, {..._listingJson, 'quantity': 7});
    var notified = 0;
    repository.addListener(() => notified++);

    final listing = await repository.update(
      _listingId,
      const ListingChanges(quantity: 7, note: '  pegar de manhã '),
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/v1/listings/$_listingId');
    expect(await sentJson(), {'quantity': 7, 'note': 'pegar de manhã'});
    expect(listing.quantity, 7);
    expect(notified, 1);
  });

  test('update sends an empty note to clear it', () async {
    adapter.respond = (_) async => jsonResponse(200, _listingJson);

    await repository.update(_listingId, const ListingChanges(note: '   '));

    expect(await sentJson(), {'note': ''});
  });

  test('close posts to close and tells the listeners', () async {
    adapter.respond = (_) async =>
        jsonResponse(200, {..._listingJson, 'status': 'closed'});
    var notified = 0;
    repository.addListener(() => notified++);

    final listing = await repository.close(_listingId);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/listings/$_listingId/close');
    expect(listing.status, ListingStatus.closed);
    expect(notified, 1);
  });

  const nearbyJson = {
    'id': _listingId,
    'commonName': 'Costela-de-adão',
    'scientificName': 'Monstera deliciosa',
    'photo': {
      'id': _photoId,
      'url': 'http://localhost:9000/plantai-photos/photos/f1.jpg?X-Amz=1',
      'expiresAt': '2026-10-29T13:00:00.000Z',
    },
    'quantity': 3,
    'distanceKm': 0,
    'neighborhood': 'Vila Mariana',
  };
  const position = ApproximatePosition(latitude: -23.5874, longitude: -46.6345);

  test(
    'nearby asks for the page with the location in the header only',
    () async {
      adapter.respond = (_) async => jsonResponse(200, [
        nearbyJson,
        {...nearbyJson, 'scientificName': null, 'distanceKm': 4},
      ]);

      final listings = await repository.nearby(from: position, page: 2);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/v1/listings/nearby');
      expect(request.queryParameters, {'page': '2'});
      expect(request.headers['X-Search-Location'], '-23.587400,-46.634500');
      expect(request.uri.toString(), isNot(contains('23.58')));
      expect(listings.map((listing) => listing.distanceKm), [0, 4]);
      expect(listings.first.scientificName, 'Monstera deliciosa');
      expect(listings.last.scientificName, isNull);
      expect(listings.first.neighborhood, 'Vila Mariana');
    },
  );

  test('the location never turns into an exponent', () async {
    adapter.respond = (_) async => jsonResponse(200, <Object>[]);

    await repository.nearby(
      from: const ApproximatePosition(latitude: 0.0000001, longitude: -1e-7),
    );

    expect(
      adapter.requests.single.headers['X-Search-Location'],
      '0.000000,-0.000000',
    );
  });

  test('detail reads the listing with the location in the header', () async {
    adapter.respond = (_) async => jsonResponse(200, {
      ...nearbyJson,
      'status': 'closed',
      'note': null,
      'donorFirstName': 'Marina',
      'createdAt': '2026-10-27T15:00:00.000Z',
      'careGuide': {
        'commonName': 'Costela-de-adão',
        'watering': {'summary': '1x por semana', 'details': 'Regue.'},
        'light': {'summary': 'Meia-sombra', 'details': 'Sem sol.'},
        'propagation': {'summary': 'Estaca', 'details': 'Corte.'},
      },
    });

    final detail = await repository.detail(_listingId, from: position);

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/v1/listings/$_listingId');
    expect(request.headers['X-Search-Location'], '-23.587400,-46.634500');
    expect(detail.status, ListingStatus.closed);
    expect(detail.note, isNull);
    expect(detail.donorFirstName, 'Marina');
    expect(detail.createdAt, DateTime.utc(2026, 10, 27, 15));
    expect(detail.careGuide?.watering.summary, '1x por semana');
  });

  test('detail of a missing listing is notFound', () async {
    adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');

    await expectLater(
      repository.detail(_listingId, from: position),
      throwsA(ListingFailure.notFound),
    );
  });

  test('donate posts the count and tells the listeners', () async {
    adapter.respond = (_) async =>
        jsonResponse(200, {..._listingJson, 'quantity': 1});
    var notified = 0;
    repository.addListener(() => notified++);

    final listing = await repository.donate(_listingId, 2);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/listings/$_listingId/donations');
    expect(await sentJson(), {'count': 2});
    expect(listing.quantity, 1);
    expect(notified, 1);
  });

  test('renew posts to renew and tells the listeners', () async {
    adapter.respond = (_) async => jsonResponse(200, {
      ..._listingJson,
      'expiresAt': '2026-11-29T12:00:00.000Z',
    });
    var notified = 0;
    repository.addListener(() => notified++);

    final listing = await repository.renew(_listingId);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/listings/$_listingId/renew');
    expect(listing.expiresAt, DateTime.utc(2026, 11, 29, 12));
    expect(notified, 1);
  });

  test('interest posts to interest and answers the WhatsApp link', () async {
    const whatsappUrl =
        'https://wa.me/5511987654321?text=Oi%2C%20Marina!%20Vi%20no%20PlantA%C3%AD';
    adapter.respond = (_) async =>
        jsonResponse(200, {'whatsappUrl': whatsappUrl});
    var notified = 0;
    repository.addListener(() => notified++);

    final url = await repository.interest(_listingId);

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/listings/$_listingId/interest');
    expect(url, Uri.parse(whatsappUrl));
    expect(url.queryParameters['text'], 'Oi, Marina! Vi no PlantAí');
    expect(notified, 0, reason: 'the User’s own listings did not change');
  });

  group('failures', () {
    Future<ListingFailure?> failureOf(Future<Object?> Function() call) async {
      try {
        await call();
        return null;
      } on ListingFailure catch (failure) {
        return failure;
      }
    }

    Future<ListingFailure?> createFailure() => failureOf(
      () => repository.create(
        const NewListing(photoId: _photoId, commonName: 'Jiboia', quantity: 1),
      ),
    );

    test('DONATION_PROFILE_REQUIRED', () async {
      adapter.respond = (_) async =>
          problemResponse(409, 'DONATION_PROFILE_REQUIRED');

      expect(await createFailure(), ListingFailure.donationProfileRequired);
    });

    test('NOT_FOUND', () async {
      adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');

      expect(await createFailure(), ListingFailure.notFound);
    });

    test('LISTING_NOT_ACTIVE', () async {
      adapter.respond = (_) async => problemResponse(409, 'LISTING_NOT_ACTIVE');

      expect(
        await failureOf(() => repository.close(_listingId)),
        ListingFailure.notActive,
      );
    });

    test('INVALID_DONATION_COUNT', () async {
      adapter.respond = (_) async =>
          problemResponse(400, 'INVALID_DONATION_COUNT');

      expect(
        await failureOf(() => repository.donate(_listingId, 4)),
        ListingFailure.invalidDonationCount,
      );
    });

    test('RENEWAL_NOT_ALLOWED', () async {
      adapter.respond = (_) async =>
          problemResponse(409, 'RENEWAL_NOT_ALLOWED');

      expect(
        await failureOf(() => repository.renew(_listingId)),
        ListingFailure.renewalNotAllowed,
      );
    });

    test('OWN_LISTING', () async {
      adapter.respond = (_) async => problemResponse(409, 'OWN_LISTING');

      expect(
        await failureOf(() => repository.interest(_listingId)),
        ListingFailure.ownListing,
      );
    });

    test('LISTING_NOT_ACTIVE on the interest', () async {
      adapter.respond = (_) async => problemResponse(409, 'LISTING_NOT_ACTIVE');

      expect(
        await failureOf(() => repository.interest(_listingId)),
        ListingFailure.notActive,
      );
    });

    test('a failed action does not tell the listeners', () async {
      adapter.respond = (_) async => problemResponse(404, 'NOT_FOUND');
      var notified = 0;
      repository.addListener(() => notified++);

      expect(
        await failureOf(
          () =>
              repository.update(_listingId, const ListingChanges(quantity: 2)),
        ),
        ListingFailure.notFound,
      );
      expect(notified, 0);
    });

    test('any other code', () async {
      adapter.respond = (_) async => problemResponse(400, 'VALIDATION_FAILED');

      expect(await createFailure(), ListingFailure.unknown);
    });

    test('no connection', () async {
      adapter.respond = (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );

      expect(
        await failureOf(repository.myListings),
        ListingFailure.noConnection,
      );
    });
  });
}
