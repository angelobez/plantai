import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/repositories/listing/listing_repository_remote.dart';
import 'package:plantai/data/services/api/api_client.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/data/services/api/update_required.dart';
import 'package:plantai/data/services/session/session_store.dart';
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
