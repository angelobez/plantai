import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/user_profile.dart';
import 'package:plantai/domain/models/profile_failure.dart';
import 'package:plantai/ui/profile/view_models/profile_view_model.dart';
import 'package:plantai/ui/profile/widgets/profile_screen.dart';

import '../../testing/fake_auth_repository.dart';
import '../../testing/fake_profile_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeProfileRepository profileRepository;
  late FakeAuthRepository authRepository;
  late ProfileViewModel viewModel;
  late int aboutOpened;
  late List<UserProfile> donationProfileOpened;

  setUp(() {
    profileRepository = FakeProfileRepository();
    authRepository = FakeAuthRepository(signedIn: true);
    viewModel = ProfileViewModel(
      profileRepository: profileRepository,
      authRepository: authRepository,
    );
    aboutOpened = 0;
    donationProfileOpened = [];
  });

  Future<void> pump(WidgetTester tester) async {
    unawaited(viewModel.load());
    await pumpScreen(
      tester,
      ProfileScreen(
        viewModel: viewModel,
        onAbout: () => aboutOpened++,
        onEditDonationProfile: donationProfileOpened.add,
      ),
    );
  }

  Finder nameField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Finder saveButton() => find.widgetWithText(FilledButton, 'Salvar');

  testWidgets('shows name, e-mail, and phone and location "não informado"', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Marina Souza'), findsNWidgets(2));
    expect(find.text('marina@email.com'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Localização de doação'), findsOneWidget);
    expect(find.text('Não informado'), findsNWidgets(2));
    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Sobre e créditos'), findsOneWidget);
  });

  testWidgets('Sobre e créditos opens the credits', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Sobre e créditos'));
    await tester.pumpAndSettle();

    expect(aboutOpened, 1);
  });

  testWidgets('shows the phone and neighborhood once they exist', (
    tester,
  ) async {
    profileRepository.profile = const UserProfile(
      id: 'id',
      name: 'Marina Souza',
      email: 'marina@email.com',
      phone: '+5511987654321',
      donationLocation: DonationLocation(neighborhood: 'Vila Mariana'),
    );

    await pump(tester);

    expect(find.text('(11) 98765-4321'), findsOneWidget);
    expect(find.text('Vila Mariana'), findsOneWidget);
    expect(find.text('Não informado'), findsNothing);
  });

  testWidgets('the WhatsApp and the location open the donation profile', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Localização de doação'));
    await tester.pumpAndSettle();

    expect(donationProfileOpened.map((p) => p.id), [marina.id, marina.id]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('shows the profile the donation-profile screen saved', (
    tester,
  ) async {
    await pump(tester);

    viewModel.showProfile(
      const UserProfile(
        id: 'id',
        name: 'Marina Souza',
        email: 'marina@email.com',
        phone: '+5521998765432',
        donationLocation: DonationLocation(neighborhood: 'Copacabana'),
      ),
    );
    await tester.pump();

    expect(find.text('(21) 99876-5432'), findsOneWidget);
    expect(find.text('Copacabana'), findsOneWidget);
  });

  testWidgets('name, phone and location can be edited; the e-mail cannot', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(3));
    await tester.tap(find.text('marina@email.com'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('edits the name', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    expect(find.text('Editar nome'), findsOneWidget);
    expect(
      tester.widget<TextField>(nameField()).controller?.text,
      'Marina Souza',
    );

    await tester.enterText(nameField(), 'Mari');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(profileRepository.calls.last, 'updateName(Mari)');
    expect(find.text('Mari'), findsNWidgets(2));
  });

  testWidgets('an empty name stays in the dialog with the message', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), '  ');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Informe o seu nome.'), findsOneWidget);
  });

  testWidgets('Cancelar keeps the name', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), 'Outra');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Marina Souza'), findsNWidgets(2));
    expect(profileRepository.calls, ['fetchProfile()']);
  });

  testWidgets('Sair signs out', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(authRepository.calls, ['signOut()']);
    expect(authRepository.isSignedIn, isFalse);
  });

  testWidgets('Sair is disabled while signing out', (tester) async {
    authRepository.gate = Completer<void>();
    await pump(tester);

    await tester.tap(find.text('Sair'));
    await tester.pump();

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Sair'),
    );
    expect(button.onPressed, isNull);
    authRepository.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a failed load shows the message and tries again', (
    tester,
  ) async {
    profileRepository.failure = ProfileFailure.noConnection;
    await pump(tester);

    expect(find.textContaining('Sem conexão'), findsOneWidget);
    profileRepository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('marina@email.com'), findsOneWidget);
  });
}
