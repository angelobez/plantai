import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/user_profile.dart';
import 'package:plantai/data/services/location/location_service.dart';
import 'package:plantai/domain/models/profile_failure.dart';
import 'package:plantai/ui/donation_profile/view_models/donation_profile_view_model.dart';

import '../../testing/fake_location_service.dart';
import '../../testing/fake_profile_repository.dart';

const marinaWithDonationProfile = UserProfile(
  id: '0190d6b4-0000-7000-8000-000000000001',
  name: 'Marina Souza',
  email: 'marina@email.com',
  phone: '+5511987654321',
  donationLocation: DonationLocation(neighborhood: 'Vila Mariana'),
);

void main() {
  late FakeProfileRepository profileRepository;
  late FakeLocationService locationService;
  late List<Uri> openedUrls;

  setUp(() {
    profileRepository = FakeProfileRepository();
    locationService = FakeLocationService();
    openedUrls = [];
  });

  DonationProfileViewModel build({UserProfile? profile}) =>
      DonationProfileViewModel(
        profileRepository: profileRepository,
        locationService: locationService,
        openUrl: (url) async {
          openedUrls.add(url);
          return true;
        },
        profile: profile,
      );

  group('starting', () {
    test('a User without a donation profile starts empty', () {
      final viewModel = build(profile: marina);

      expect(viewModel.phone, '');
      expect(viewModel.neighborhood, '');
      expect(viewModel.hasPosition, isFalse);
      expect(viewModel.currentNeighborhood, isNull);
      expect(locationService.asked, 0);
    });

    test(
      'a User with one starts with the masked phone and the neighborhood',
      () {
        final viewModel = build(profile: marinaWithDonationProfile);

        expect(viewModel.phone, '(11) 98765-4321');
        expect(viewModel.neighborhood, 'Vila Mariana');
        expect(viewModel.currentNeighborhood, 'Vila Mariana');
        // The API never sends the point back: it must be found again.
        expect(viewModel.hasPosition, isFalse);
      },
    );
  });

  group('useMyLocation', () {
    test('finds the position and suggests the neighborhood', () async {
      final viewModel = build();
      locationService.gate = Completer<void>();

      final located = viewModel.useMyLocation();
      expect(viewModel.isLocating, isTrue);
      locationService.gate!.complete();

      expect(await located, isTrue);
      expect(viewModel.isLocating, isFalse);
      expect(viewModel.hasPosition, isTrue);
      expect(viewModel.neighborhood, 'Vila Mariana');
      expect(viewModel.neighborhoodNotFound, isFalse);
      expect(locationService.geocoded, [vilaMariana]);
      expect(viewModel.locationProblem, isNull);
    });

    test('the suggested neighborhood stays editable', () async {
      final viewModel = build()..updatePhone('(11) 98765-4321');
      await viewModel.useMyLocation();

      viewModel.updateNeighborhood('Vila Clementino');
      await viewModel.save();

      expect(
        profileRepository.donationProfiles.single.neighborhood,
        'Vila Clementino',
      );
    });

    test('without a suggestion, keeps what was typed and says so', () async {
      locationService.neighborhood = null;
      final viewModel = build(profile: marinaWithDonationProfile);

      await viewModel.useMyLocation();

      expect(viewModel.hasPosition, isTrue);
      expect(viewModel.neighborhood, 'Vila Mariana');
      expect(viewModel.neighborhoodNotFound, isTrue);
    });

    for (final (result, problem, message) in [
      (
        const LocationDenied(),
        LocationProblem.denied,
        'Sem a permissão de localização não dá para saber de onde você doa. '
            'Toque em "Usar minha localização" para tentar de novo.',
      ),
      (
        const LocationDeniedForever(),
        LocationProblem.deniedForever,
        'A permissão de localização está negada. Libere a localização do '
            'PlantAí nas configurações do Android.',
      ),
      (
        const LocationServiceDisabled(),
        LocationProblem.serviceDisabled,
        'A localização do celular está desligada. Ligue e tente de novo.',
      ),
      (
        const LocationUnavailable(),
        LocationProblem.unavailable,
        'Não deu para achar a sua localização. Tente de novo.',
      ),
    ]) {
      test('${result.runtimeType} becomes ${problem.name}', () async {
        locationService.next = result;
        final viewModel = build();

        expect(await viewModel.useMyLocation(), isFalse);

        expect(viewModel.locationProblem, problem);
        expect(viewModel.locationError, message);
        expect(viewModel.hasPosition, isFalse);
        expect(locationService.geocoded, isEmpty);
      });
    }

    test('trying again after a refusal clears the problem', () async {
      locationService.next = const LocationDenied();
      final viewModel = build();
      await viewModel.useMyLocation();

      locationService.next = const LocationFound(vilaMariana);
      await viewModel.useMyLocation();

      expect(viewModel.locationProblem, isNull);
      expect(viewModel.locationError, isNull);
      expect(viewModel.hasPosition, isTrue);
    });

    test('denied for good opens the app settings', () async {
      locationService.next = const LocationDeniedForever();
      final viewModel = build();
      await viewModel.useMyLocation();

      await viewModel.openSettings();

      expect(locationService.appSettingsOpened, 1);
      expect(locationService.locationSettingsOpened, 0);
    });

    test('location off opens the location settings', () async {
      locationService.next = const LocationServiceDisabled();
      final viewModel = build();
      await viewModel.useMyLocation();

      await viewModel.openSettings();

      expect(locationService.locationSettingsOpened, 1);
      expect(locationService.appSettingsOpened, 0);
    });
  });

  group('testOnWhatsApp', () {
    test('opens wa.me with the typed number', () async {
      final viewModel = build()..updatePhone('(11) 98765-4321');

      await viewModel.testOnWhatsApp();

      expect(openedUrls, [Uri.parse('https://wa.me/5511987654321')]);
      expect(viewModel.phoneError, isNull);
    });

    test('takes the number with +55 too', () async {
      final viewModel = build()..updatePhone('+55 (11) 98765-4321');

      await viewModel.testOnWhatsApp();

      expect(openedUrls, [Uri.parse('https://wa.me/5511987654321')]);
    });

    test('a number too short opens nothing and says why', () async {
      final viewModel = build()..updatePhone('9876-5432');

      await viewModel.testOnWhatsApp();

      expect(openedUrls, isEmpty);
      expect(viewModel.phoneError, 'Digite o celular com o DDD.');
    });
  });

  group('save', () {
    Future<DonationProfileViewModel> ready() async {
      final viewModel = build()..updatePhone('(11) 98765-4321');
      await viewModel.useMyLocation();
      return viewModel;
    }

    test(
      'sends the phone as typed, the position and the neighborhood',
      () async {
        final viewModel = await ready();
        viewModel.updateNeighborhood('  Vila Mariana  ');

        final saved = await viewModel.save();

        expect(saved?.phone, '+5511987654321');
        expect(saved?.donationLocation?.neighborhood, 'Vila Mariana');
        final sent = profileRepository.donationProfiles.single;
        expect(sent.phone, '(11) 98765-4321');
        expect(sent.latitude, vilaMariana.latitude);
        expect(sent.longitude, vilaMariana.longitude);
        expect(sent.neighborhood, 'Vila Mariana');
      },
    );

    test('shows the saving state', () async {
      final viewModel = await ready();
      profileRepository.gate = Completer<void>();

      final saving = viewModel.save();
      expect(viewModel.isSaving, isTrue);
      profileRepository.gate!.complete();
      await saving;

      expect(viewModel.isSaving, isFalse);
    });

    test('INVALID_PHONE shows in the phone field', () async {
      final viewModel = await ready();
      profileRepository.failure = ProfileFailure.invalidPhone;

      expect(await viewModel.save(), isNull);

      expect(
        viewModel.phoneError,
        'Esse número não é um celular do Brasil. Confira o DDD e o número.',
      );
      expect(viewModel.saveError, isNull);
    });

    test('editing the phone clears its error', () async {
      final viewModel = await ready();
      profileRepository.failure = ProfileFailure.invalidPhone;
      await viewModel.save();

      viewModel.updatePhone('(11) 98765-4322');

      expect(viewModel.phoneError, isNull);
    });

    test('no connection offers to try again', () async {
      final viewModel = await ready();
      profileRepository.failure = ProfileFailure.noConnection;

      expect(await viewModel.save(), isNull);

      expect(
        viewModel.saveError,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      );
      expect(viewModel.canRetrySave, isTrue);

      profileRepository.failure = null;
      expect(await viewModel.save(), isNotNull);
      expect(viewModel.saveError, isNull);
    });

    test('another failure says something went wrong', () async {
      final viewModel = await ready();
      profileRepository.failure = ProfileFailure.unknown;

      await viewModel.save();

      expect(viewModel.saveError, 'Algo deu errado. Tente de novo.');
      expect(viewModel.canRetrySave, isFalse);
    });

    test('without a phone, asks for it and sends nothing', () async {
      final viewModel = build();
      await viewModel.useMyLocation();

      expect(await viewModel.save(), isNull);

      expect(viewModel.phoneError, 'Digite o celular com o DDD.');
      expect(profileRepository.calls, isEmpty);
    });

    test(
      'without a position, asks for the location and sends nothing',
      () async {
        final viewModel = build(profile: marinaWithDonationProfile);

        expect(await viewModel.save(), isNull);

        expect(
          viewModel.locationError,
          'Toque em "Usar minha localização" para confirmar de onde você doa.',
        );
        expect(profileRepository.calls, isEmpty);
      },
    );

    test('without a neighborhood, asks for it and sends nothing', () async {
      locationService.neighborhood = null;
      final viewModel = await ready();

      expect(await viewModel.save(), isNull);

      expect(viewModel.neighborhoodError, 'Digite o seu bairro.');
      expect(profileRepository.calls, isEmpty);
    });

    test('a neighborhood over 60 characters is refused', () async {
      final viewModel = await ready();
      viewModel.updateNeighborhood('a' * 61);

      expect(await viewModel.save(), isNull);

      expect(viewModel.neighborhoodError, 'Use até 60 caracteres.');
    });
  });
}
