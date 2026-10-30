import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/listing.dart';
import 'package:plantai/domain/models/listing_failure.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';
import 'package:plantai/ui/listings/view_models/my_listings_view_model.dart';
import 'package:plantai/ui/listings/widgets/listings_tab_page.dart';
import 'package:plantai/ui/listings/widgets/my_listings_screen.dart';

import '../../testing/fake_listing_repository.dart';
import '../../testing/pump_screen.dart';

void main() {
  late FakeListingRepository repository;
  late List<ListingsTab> selected;
  late int donateCalls;

  // 30/10 at noon in São Paulo: [costelaAtiva] expires on 4/11.
  final now = DateTime.utc(2026, 10, 30, 15);

  setUp(() {
    repository = FakeListingRepository(
      mine: [costelaAtiva, espadaDoada, jiboiaEncerrada],
    );
    selected = [];
    donateCalls = 0;
  });

  Future<MyListingsViewModel> pump(
    WidgetTester tester, {
    bool withDonate = false,
  }) async {
    final viewModel = MyListingsViewModel(
      listingRepository: repository,
      clock: () => now,
    )..load();
    addTearDown(viewModel.dispose);
    await pumpScreen(
      tester,
      MyListingsScreen(
        viewModel: viewModel,
        onSelectTab: selected.add,
        onDonate: withDonate ? () => donateCalls++ : null,
      ),
    );
    return viewModel;
  }

  testWidgets('shows an active listing with its seedlings, expiry and '
      'interest', (tester) async {
    await pump(tester);

    expect(find.text('Costela-de-adão'), findsOneWidget);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('3 mudas · expira em 5 dias'), findsOneWidget);
    expect(find.text('3 pessoas tiveram interesse'), findsOneWidget);
    expect(find.byType(PhotoImage), findsNWidgets(3));
  });

  testWidgets('says "expira hoje" on the last day', (tester) async {
    repository.mine = [
      MyListing(
        id: costelaAtiva.id,
        commonName: 'Costela-de-adão',
        photo: costelaPhoto,
        status: ListingStatus.active,
        quantity: 1,
        interestCount: 0,
        // 23:00 in São Paulo, the same day as [now].
        expiresAt: DateTime.utc(2026, 10, 31, 2),
        canRenew: true,
      ),
    ];
    await pump(tester);

    expect(find.text('1 muda · expira hoje'), findsOneWidget);
    expect(find.text('Ninguém teve interesse ainda'), findsOneWidget);
  });

  testWidgets('shows donated and closed listings, without the expiry', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Doado'), findsOneWidget);
    expect(find.text('Todas as mudas foram doadas'), findsOneWidget);
    expect(find.text('5 pessoas tiveram interesse'), findsOneWidget);
    expect(find.text('Encerrado'), findsOneWidget);
    expect(find.text('2 mudas'), findsOneWidget);
    expect(find.textContaining('expira'), findsOneWidget);
  });

  testWidgets('dims donated and closed listings', (tester) async {
    await pump(tester);

    Color? background(String name) {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(MyListingRow),
      );
      final container = tester.widget<Container>(
        find.descendant(of: row, matching: find.byType(Container)).first,
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    expect(background('Costela-de-adão'), isNull);
    expect(background('Espada-de-são-jorge'), const Color(0xFFFAFBFA));
    expect(background('Jiboia'), const Color(0xFFFAFBFA));
  });

  testWidgets('"Por perto" switches to the other inner tab', (tester) async {
    await pump(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(ListingsTabPage),
        matching: find.text('Por perto'),
      ),
    );

    expect(selected, [ListingsTab.nearby]);
  });

  testWidgets('without listings, explains how to donate', (tester) async {
    repository.mine = [];
    await pump(tester, withDonate: true);

    expect(find.text('Você ainda não anunciou mudas'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Doar mudas'));
    expect(donateCalls, 1);
  });

  testWidgets('"Doar mudas" in the header starts a listing', (tester) async {
    await pump(tester, withDonate: true);

    await tester.tap(find.widgetWithText(HeaderPill, 'Doar mudas'));

    expect(donateCalls, 1);
  });

  testWidgets('the empty state has no button without the flow', (tester) async {
    repository.mine = [];
    await pump(tester);

    expect(find.text('Você ainda não anunciou mudas'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(HeaderPill), findsNothing);
  });

  testWidgets('without connection, offers "Tentar de novo"', (tester) async {
    repository.failure = ListingFailure.noConnection;
    await pump(tester);

    expect(
      find.text('Sem conexão com a internet. Confira a rede e tente de novo.'),
      findsOneWidget,
    );

    repository.failure = null;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Costela-de-adão'), findsOneWidget);
  });

  group("the donor's actions", () {
    Finder actionsOf(String name) => find.descendant(
      of: find.ancestor(
        of: find.text(name),
        matching: find.byType(MyListingRow),
      ),
      matching: find.byTooltip('Ações do anúncio'),
    );

    Future<void> choose(WidgetTester tester, String action) async {
      await tester.tap(actionsOf('Costela-de-adão'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
    }

    Finder dialogButton(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ),
    );

    testWidgets('only the active listing has the actions menu, with Editar '
        'and Encerrar', (tester) async {
      await pump(tester);

      expect(find.byTooltip('Ações do anúncio'), findsOneWidget);
      expect(actionsOf('Costela-de-adão'), findsOneWidget);
      expect(actionsOf('Espada-de-são-jorge'), findsNothing);
      expect(actionsOf('Jiboia'), findsNothing);

      await tester.tap(actionsOf('Costela-de-adão'));
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Encerrar'), findsOneWidget);
    });

    testWidgets('Editar starts from the quantity and the note, and saving '
        'updates the row', (tester) async {
      await pump(tester);
      await choose(tester, 'Editar');

      expect(find.text('Editar anúncio'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('3')),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Pegar à tarde'), findsOneWidget);

      await tester.tap(find.byTooltip('Mais uma'));
      await tester.tap(find.byTooltip('Mais uma'));
      await tester.enterText(find.byType(TextField), '  pegar de manhã ');
      await tester.tap(dialogButton('Salvar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final (id, changes) = repository.updates.single;
      expect(id, costelaAtiva.id);
      expect(changes.quantity, 5);
      expect(changes.note, 'pegar de manhã');
      expect(find.text('5 mudas · expira em 5 dias'), findsOneWidget);
    });

    testWidgets('Editar keeps the quantity between 1 and 99', (tester) async {
      await pump(tester);
      await choose(tester, 'Editar');

      await tester.tap(find.byTooltip('Menos uma'));
      await tester.tap(find.byTooltip('Menos uma'));
      await tester.pump();

      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('Editar sends only what changed: clearing the note sends it '
        'empty', (tester) async {
      await pump(tester);
      await choose(tester, 'Editar');

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(dialogButton('Salvar'));
      await tester.pumpAndSettle();

      final (_, changes) = repository.updates.single;
      expect(changes.quantity, isNull);
      expect(changes.note, '');
    });

    testWidgets('Editar without changes, or cancelled, sends nothing', (
      tester,
    ) async {
      await pump(tester);
      await choose(tester, 'Editar');
      await tester.tap(dialogButton('Salvar'));
      await tester.pumpAndSettle();

      await choose(tester, 'Editar');
      await tester.tap(find.byTooltip('Mais uma'));
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.updates, isEmpty);
    });

    testWidgets('Encerrar asks for confirmation; cancelling keeps the '
        'listing', (tester) async {
      await pump(tester);
      await choose(tester, 'Encerrar');

      expect(find.text('Encerrar anúncio?'), findsOneWidget);
      await tester.tap(dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(repository.closed, isEmpty);
      expect(find.text('Ativo'), findsOneWidget);
    });

    testWidgets('confirming Encerrar closes it: dimmed, without actions', (
      tester,
    ) async {
      await pump(tester);
      await choose(tester, 'Encerrar');

      await tester.tap(dialogButton('Encerrar'));
      await tester.pumpAndSettle();

      expect(repository.closed, [costelaAtiva.id]);
      expect(find.text('Ativo'), findsNothing);
      expect(find.text('Encerrado'), findsNWidgets(2));
      expect(find.byTooltip('Ações do anúncio'), findsNothing);
    });

    testWidgets('a failed action shows why', (tester) async {
      await pump(tester);
      repository.actionFailure = ListingFailure.noConnection;
      await choose(tester, 'Encerrar');

      await tester.tap(dialogButton('Encerrar'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(
            'Sem conexão com a internet. Confira a rede e tente de novo.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Ativo'), findsOneWidget);
    });
  });
}
