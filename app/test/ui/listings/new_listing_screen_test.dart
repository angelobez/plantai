import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/domain/models/listing_draft.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/listings/view_models/new_listing_view_model.dart';
import 'package:plantai/ui/listings/widgets/new_listing_screen.dart';

import '../../testing/fake_garden_repository.dart';
import '../../testing/fake_listing_repository.dart';
import '../../testing/fake_photo_picker.dart';
import '../../testing/fake_photo_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeListingRepository listingRepository;
  late FakePhotoRepository photoRepository;
  late List<MyListing> published;
  late int profileAsked;
  late bool profileSaved;

  setUp(() {
    listingRepository = FakeListingRepository();
    photoRepository = FakePhotoRepository();
    published = [];
    profileAsked = 0;
    profileSaved = true;
  });

  Future<NewListingViewModel> pump(
    WidgetTester tester, {
    ListingDraft? draft,
  }) async {
    final viewModel = NewListingViewModel(
      listingRepository: listingRepository,
      photoRepository: photoRepository,
      photoPicker: FakePhotoPicker(),
      draft: draft ?? ListingDraft.fromPlant(monsteraDaSala),
    );
    addTearDown(viewModel.dispose);
    await pumpScreen(
      tester,
      NewListingScreen(
        viewModel: viewModel,
        onPublished: published.add,
        onDonationProfileRequired: () async {
          profileAsked++;
          return profileSaved;
        },
      ),
      below: const Text('Planta'),
    );
    return viewModel;
  }

  Finder publishButton() =>
      find.widgetWithText(FilledButton, 'Publicar anúncio');

  Future<void> publish(WidgetTester tester) async {
    await tester.ensureVisible(publishButton());
    await tester.tap(publishButton());
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the plant’s photo, name and read-only species', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Doar mudas'), findsOneWidget);
    final photo = tester.widget<PhotoImage>(find.byType(PhotoImage));
    expect(photo.photo, same(jiboiaPhoto));
    expect(find.text('Foto da planta do seu jardim'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Monstera da sala'), findsOneWidget);
    expect(find.text('Monstera deliciosa'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0/200'), findsOneWidget);
    expect(
      find.text('Fica visível por 30 dias para quem está a até 30 km.'),
      findsOneWidget,
    );
  });

  testWidgets('a plant without a species says so', (tester) async {
    await pump(tester, draft: ListingDraft.fromPlant(pimentaDaVo));

    expect(find.text('Sem espécie'), findsOneWidget);
  });

  testWidgets('"Tirar outra foto da muda" swaps the photo', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Tirar outra foto da muda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(photoRepository.uploads, hasLength(1));
    final photo = tester.widget<PhotoImage>(find.byType(PhotoImage));
    expect(photo.photo.id, 'photo-1');
    expect(find.text('Foto da muda'), findsOneWidget);
  });

  testWidgets('the stepper goes from 1 to 99', (tester) async {
    await pump(tester);

    final less = find.byTooltip('Menos uma');
    final more = find.byTooltip('Mais uma');
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.remove),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(more);
    await tester.tap(more);
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(less);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('counts the note up to 200 characters', (tester) async {
    await pump(tester);

    final note = find.byType(TextField).last;
    await tester.enterText(note, 'Pegar à tarde');
    await tester.pump();
    expect(find.text('13/200'), findsOneWidget);

    await tester.enterText(note, 'a' * 250);
    await tester.pump();
    expect(find.text('200/200'), findsOneWidget);
  });

  testWidgets('publishes what the form says', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Monstera da sala'),
      'Costela-de-adão',
    );
    await tester.tap(find.byTooltip('Mais uma'));
    await tester.enterText(find.byType(TextField).last, 'Pegar à tarde');
    await publish(tester);

    final sent = listingRepository.created.single;
    expect(sent.commonName, 'Costela-de-adão');
    expect(sent.quantity, 2);
    expect(sent.note, 'Pegar à tarde');
    expect(sent.plantId, monsteraDaSala.id);
    expect(published.single.commonName, 'Costela-de-adão');
  });

  testWidgets('an empty name says so and publishes nothing', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Monstera da sala'),
      '  ',
    );
    await publish(tester);

    expect(find.text('Dê um nome para a planta.'), findsOneWidget);
    expect(listingRepository.created, isEmpty);
    expect(published, isEmpty);
  });

  testWidgets('DONATION_PROFILE_REQUIRED asks for the profile, then '
      'publishes', (tester) async {
    listingRepository.createFailures.add(
      ListingFailure.donationProfileRequired,
    );
    await pump(tester);

    await publish(tester);

    expect(profileAsked, 1);
    expect(listingRepository.created, hasLength(2));
    expect(published, hasLength(1));
  });

  testWidgets('leaving the Primeiro anúncio publishes nothing', (tester) async {
    listingRepository.createFailures.add(
      ListingFailure.donationProfileRequired,
    );
    profileSaved = false;
    await pump(tester);

    await publish(tester);

    expect(profileAsked, 1);
    expect(listingRepository.created, hasLength(1));
    expect(published, isEmpty);
  });

  testWidgets('without connection, offers "Tentar de novo"', (tester) async {
    listingRepository.failure = ListingFailure.noConnection;
    await pump(tester);

    await publish(tester);
    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    listingRepository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(published, hasLength(1));
  });
}
