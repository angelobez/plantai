import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/identification_failure.dart';
import 'package:plantai/ui/identification/view_models/candidates_view_model.dart';

import '../../testing/fake_identification_repository.dart';

const _photoId = '0190e0d4-0000-7000-8000-0000000000aa';

void main() {
  late FakeIdentificationRepository repository;

  setUp(() => repository = FakeIdentificationRepository());

  CandidatesViewModel viewModel() => CandidatesViewModel(
    identificationRepository: repository,
    photoId: _photoId,
  );

  group('identify', () {
    test(
      'is identifying while Pl@ntNet answers, then shows the candidates',
      () async {
        repository.gate = Completer();
        final vm = viewModel();

        final done = vm.identify();
        expect(vm.stage, IdentificationStage.identifying);
        repository.gate!.complete();
        await done;

        expect(repository.identified, [_photoId]);
        expect(vm.stage, IdentificationStage.candidates);
        expect(vm.candidates, [jiboiaCandidate, pinnatumCandidate]);
        expect(vm.remainingToday, 7);
        expect(vm.error, isNull);
      },
    );

    test('not_recognized leads to Foto não reconhecida', () async {
      repository.identification = notRecognized;
      final vm = viewModel();

      await vm.identify();

      expect(vm.stage, IdentificationStage.notRecognized);
      expect(vm.candidates, isEmpty);
    });

    test('IDENTIFICATION_DAILY_LIMIT leads to Limite diário', () async {
      repository.failure = IdentificationFailure.dailyLimit;
      final vm = viewModel();

      await vm.identify();

      expect(vm.stage, IdentificationStage.dailyLimit);
      expect(vm.error, isNull);
    });

    for (final (failure, message) in [
      (
        IdentificationFailure.noConnection,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      ),
      (
        IdentificationFailure.serviceUnavailable,
        'O Pl@ntNet, que identifica as plantas, não respondeu. Tente de novo '
            'em instantes; esta tentativa não contou.',
      ),
      (IdentificationFailure.unknown, 'Algo deu errado. Tente de novo.'),
    ]) {
      test('$failure shows its message with "Tentar de novo"', () async {
        repository.failure = failure;
        final vm = viewModel();

        await vm.identify();

        expect(vm.stage, IdentificationStage.failed);
        expect(vm.error, message);
        expect(vm.canRetry, isTrue);
      });
    }

    test('NOT_FOUND says the photo is gone, without retry', () async {
      repository.failure = IdentificationFailure.notFound;
      final vm = viewModel();

      await vm.identify();

      expect(vm.stage, IdentificationStage.failed);
      expect(vm.error, 'Essa foto não está mais disponível. Tire outra foto.');
      expect(vm.canRetry, isFalse);
    });

    test('"Tentar de novo" identifies again and clears the error', () async {
      repository.failure = IdentificationFailure.noConnection;
      final vm = viewModel();
      await vm.identify();

      repository.failure = null;
      await vm.identify();

      expect(repository.identified, [_photoId, _photoId]);
      expect(vm.stage, IdentificationStage.candidates);
      expect(vm.error, isNull);
    });
  });

  group('choose', () {
    test('answers the species of the candidate', () async {
      final vm = viewModel();
      await vm.identify();
      repository.gate = Completer();

      final chosen = vm.choose(1);
      expect(vm.isChoosing, isTrue);
      repository.gate!.complete();

      expect(await chosen, jiboiaSpecies);
      expect(repository.choices, [(recognized.id, 1)]);
      expect(vm.isChoosing, isFalse);
      expect(vm.choiceError, isNull);
    });

    test('ignores a second tap while choosing', () async {
      final vm = viewModel();
      await vm.identify();
      repository.gate = Completer();

      final first = vm.choose(0);
      expect(await vm.choose(1), isNull);
      repository.gate!.complete();
      await first;

      expect(repository.choices, [(recognized.id, 0)]);
    });

    for (final (failure, message) in [
      (
        IdentificationFailure.noConnection,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      ),
      (
        IdentificationFailure.alreadyChosen,
        'Você já escolheu uma opção para esta foto. Identifique de novo para '
            'escolher outra.',
      ),
      (IdentificationFailure.unknown, 'Algo deu errado. Tente de novo.'),
    ]) {
      test('$failure keeps the candidates and shows a message', () async {
        final vm = viewModel();
        await vm.identify();
        repository.failure = failure;

        expect(await vm.choose(0), isNull);

        expect(vm.stage, IdentificationStage.candidates);
        expect(vm.choiceError, message);
      });
    }

    test('"nenhuma destas" records it and lets the screen go on', () async {
      final vm = viewModel();
      await vm.identify();

      expect(await vm.chooseNone(), isTrue);

      expect(repository.choices, [(recognized.id, null)]);
    });

    test('"nenhuma destas" goes on when it was already recorded', () async {
      final vm = viewModel();
      await vm.identify();
      repository.failure = IdentificationFailure.alreadyChosen;

      expect(await vm.chooseNone(), isTrue);
      expect(vm.choiceError, isNull);
    });

    test('"nenhuma destas" offline stays, with the message', () async {
      final vm = viewModel();
      await vm.identify();
      repository.failure = IdentificationFailure.noConnection;

      expect(await vm.chooseNone(), isFalse);
      expect(
        vm.choiceError,
        'Sem conexão com a internet. Confira a rede e tente de novo.',
      );
    });

    test('a new choice clears the last error', () async {
      final vm = viewModel();
      await vm.identify();
      repository.failure = IdentificationFailure.noConnection;
      await vm.choose(0);

      repository.failure = null;
      await vm.choose(0);

      expect(vm.choiceError, isNull);
    });
  });
}
