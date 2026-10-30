import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/user_profile.dart';
import 'package:plantai/data/services/location/location_service.dart';
import 'package:plantai/domain/models/profile_failure.dart';
import 'package:plantai/ui/donation_profile/view_models/donation_profile_view_model.dart';
import 'package:plantai/ui/donation_profile/widgets/donation_profile_screen.dart';

import '../../testing/fake_location_service.dart';
import '../../testing/fake_profile_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeProfileRepository profileRepository;
  late FakeLocationService locationService;
  late List<Uri> openedUrls;
  late List<UserProfile> saved;

  setUp(() {
    profileRepository = FakeProfileRepository();
    locationService = FakeLocationService();
    openedUrls = [];
    saved = [];
  });

  Future<DonationProfileViewModel> pump(
    WidgetTester tester, {
    UserProfile? profile,
    bool firstListing = false,
  }) async {
    final viewModel = DonationProfileViewModel(
      profileRepository: profileRepository,
      locationService: locationService,
      openUrl: (url) async {
        openedUrls.add(url);
        return true;
      },
      profile: profile,
    );
    addTearDown(viewModel.dispose);
    await pumpScreen(
      tester,
      firstListing
          ? DonationProfileScreen.firstListing(
              viewModel: viewModel,
              onSaved: saved.add,
            )
          : DonationProfileScreen.profile(
              viewModel: viewModel,
              onSaved: saved.add,
            ),
      below: const Text('Perfil'),
    );
    return viewModel;
  }

  Finder field(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(Column));
  Finder textFieldUnder(String label) =>
      find.descendant(of: field(label).first, matching: find.byType(TextField));

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the fields, the location button and the privacy note', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Perfil de doação'), findsOneWidget);
    expect(
      find.text('Como os vizinhos falam com você e de onde você doa'),
      findsOneWidget,
    );
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Testar no WhatsApp'), findsOneWidget);
    expect(find.text('Usar minha localização'), findsOneWidget);
    expect(
      find.text(
        'Só mostramos o bairro e a distância aproximada, nunca o seu '
        'endereço.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Salvar'), findsOneWidget);
    expect(locationService.asked, 0);
  });

  testWidgets('as the Primeiro anúncio, says "Antes de doar" and "Continuar"', (
    tester,
  ) async {
    await pump(tester, firstListing: true);

    expect(find.text('Antes de doar'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continuar'), findsOneWidget);
  });

  testWidgets('masks the phone as it is typed', (tester) async {
    await pump(tester);

    await tester.enterText(textFieldUnder('WhatsApp'), '11987654321');
    await tester.pump();

    expect(
      tester.widget<TextField>(textFieldUnder('WhatsApp')).controller?.text,
      '(11) 98765-4321',
    );
  });

  testWidgets('"Testar no WhatsApp" opens wa.me with the typed number', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(textFieldUnder('WhatsApp'), '11987654321');

    await tapText(tester, 'Testar no WhatsApp');

    expect(openedUrls, [Uri.parse('https://wa.me/5511987654321')]);
  });

  testWidgets('uses the location, suggests the neighborhood and lets it be '
      'corrected before saving', (tester) async {
    await pump(tester);
    await tester.enterText(textFieldUnder('WhatsApp'), '11987654321');

    await tapText(tester, 'Usar minha localização');

    expect(find.text('Localização encontrada pelo GPS'), findsOneWidget);
    expect(
      tester.widget<TextField>(textFieldUnder('Bairro')).controller?.text,
      'Vila Mariana',
    );

    await tester.enterText(textFieldUnder('Bairro'), 'Vila Clementino');
    await tapText(tester, 'Salvar');

    expect(
      profileRepository.donationProfiles.single.neighborhood,
      'Vila Clementino',
    );
    expect(saved.single.donationLocation?.neighborhood, 'Vila Clementino');
  });

  testWidgets('INVALID_PHONE shows under the phone field', (tester) async {
    await pump(tester);
    await tester.enterText(textFieldUnder('WhatsApp'), '1133334444');
    await tapText(tester, 'Usar minha localização');
    profileRepository.failure = ProfileFailure.invalidPhone;

    await tapText(tester, 'Salvar');

    expect(
      find.text(
        'Esse número não é um celular do Brasil. Confira o DDD e o número.',
      ),
      findsOneWidget,
    );
    expect(saved, isEmpty);
  });

  testWidgets('no connection on save offers "Tentar de novo"', (tester) async {
    await pump(tester);
    await tester.enterText(textFieldUnder('WhatsApp'), '11987654321');
    await tapText(tester, 'Usar minha localização');
    profileRepository.failure = ProfileFailure.noConnection;

    await tapText(tester, 'Salvar');

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );
    profileRepository.failure = null;
    await tapText(tester, 'Tentar de novo');

    expect(saved, hasLength(1));
  });

  testWidgets('location denied for good offers the Android settings', (
    tester,
  ) async {
    locationService.next = const LocationDeniedForever();
    await pump(tester);

    await tapText(tester, 'Usar minha localização');

    expect(
      find.text(
        'A permissão de localização está negada. Libere a localização do '
        'PlantAí nas configurações do Android.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Abrir as configurações do Android');
    expect(locationService.appSettingsOpened, 1);
  });

  testWidgets('location off offers to turn it on', (tester) async {
    locationService.next = const LocationServiceDisabled();
    await pump(tester);

    await tapText(tester, 'Usar minha localização');

    expect(
      find.text(
        'A localização do celular está desligada. Ligue e tente de novo.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Ligar a localização');
    expect(locationService.locationSettingsOpened, 1);
  });

  testWidgets('denied shows the message and the button tries again', (
    tester,
  ) async {
    locationService.next = const LocationDenied();
    await pump(tester);

    await tapText(tester, 'Usar minha localização');

    expect(find.textContaining('Sem a permissão de localização'), findsOne);
    expect(find.text('Abrir as configurações do Android'), findsNothing);

    locationService.next = const LocationFound(vilaMariana);
    await tapText(tester, 'Usar minha localização');
    expect(find.text('Localização encontrada pelo GPS'), findsOneWidget);
  });

  testWidgets('editing an existing profile shows the phone and the '
      'neighborhood, and saves without a new location', (tester) async {
    await pump(
      tester,
      profile: const UserProfile(
        id: 'id',
        name: 'Marina Souza',
        email: 'marina@email.com',
        phone: '+5511987654321',
        donationLocation: DonationLocation(neighborhood: 'Vila Mariana'),
      ),
    );

    expect(
      tester.widget<TextField>(textFieldUnder('WhatsApp')).controller?.text,
      '(11) 98765-4321',
    );
    expect(
      find.text(
        'Hoje: Vila Mariana. Se você mudou de lugar, use a localização de '
        'novo.',
      ),
      findsOneWidget,
    );

    await tapText(tester, 'Salvar');
    final sent = profileRepository.donationProfiles.single;
    expect(sent.latitude, isNull);
    expect(sent.neighborhood, 'Vila Mariana');
    expect(saved, hasLength(1));
    expect(locationService.asked, 0);
  });

  testWidgets('without a saved location, saving asks for the location', (
    tester,
  ) async {
    await pump(tester, firstListing: true);
    await tester.enterText(textFieldUnder('WhatsApp'), '11987654321');

    await tapText(tester, 'Continuar');

    expect(
      find.text(
        'Toque em "Usar minha localização" para confirmar de onde você doa.',
      ),
      findsOneWidget,
    );
    expect(profileRepository.calls, isEmpty);
  });

  testWidgets('back returns without saving', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil'), findsOneWidget);
    expect(saved, isEmpty);
  });
}
