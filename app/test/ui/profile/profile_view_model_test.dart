import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/profile_failure.dart';
import 'package:plantai/ui/profile/view_models/profile_view_model.dart';

import '../../testing/fake_auth_repository.dart';
import '../../testing/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository profileRepository;
  late FakeAuthRepository authRepository;
  late ProfileViewModel viewModel;

  setUp(() {
    profileRepository = FakeProfileRepository();
    authRepository = FakeAuthRepository(signedIn: true);
    viewModel = ProfileViewModel(
      profileRepository: profileRepository,
      authRepository: authRepository,
    );
  });

  group('load', () {
    test('reads the profile, loading meanwhile', () async {
      profileRepository.gate = Completer<void>();

      final loading = viewModel.load();
      expect(viewModel.isLoading, isTrue);
      profileRepository.gate!.complete();
      await loading;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.profile?.name, 'Marina Souza');
      expect(viewModel.loadError, isNull);
    });

    test('without a connection, says so', () async {
      profileRepository.failure = ProfileFailure.noConnection;

      await viewModel.load();

      expect(viewModel.profile, isNull);
      expect(viewModel.loadError, contains('Sem conexão'));
    });

    test('trying again after a failure clears the message', () async {
      profileRepository.failure = ProfileFailure.unknown;
      await viewModel.load();
      expect(viewModel.loadError, isNotNull);

      profileRepository.failure = null;
      await viewModel.load();

      expect(viewModel.loadError, isNull);
      expect(viewModel.profile, isNotNull);
    });
  });

  group('saveName', () {
    setUp(() => viewModel.load());

    test('saves the trimmed name and shows what the API saved', () async {
      final saved = await viewModel.saveName('  Mari  ');

      expect(saved, isTrue);
      expect(profileRepository.calls.last, 'updateName(Mari)');
      expect(viewModel.profile?.name, 'Mari');
      expect(viewModel.nameError, isNull);
    });

    test('rejects an empty name without calling the API', () async {
      final saved = await viewModel.saveName('   ');

      expect(saved, isFalse);
      expect(viewModel.nameError, 'Informe o seu nome.');
      expect(profileRepository.calls, ['fetchProfile()']);
    });

    test('rejects a name over 80 characters', () async {
      final saved = await viewModel.saveName('a' * 81);

      expect(saved, isFalse);
      expect(viewModel.nameError, 'Use até 80 caracteres.');
    });

    test('is saving while the API answers', () async {
      profileRepository.gate = Completer<void>();

      final saving = viewModel.saveName('Mari');
      expect(viewModel.isSavingName, isTrue);
      profileRepository.gate!.complete();
      await saving;

      expect(viewModel.isSavingName, isFalse);
    });

    test('keeps the old name and says what went wrong', () async {
      profileRepository.failure = ProfileFailure.noConnection;

      final saved = await viewModel.saveName('Mari');

      expect(saved, isFalse);
      expect(viewModel.profile?.name, 'Marina Souza');
      expect(viewModel.nameError, contains('Sem conexão'));
    });

    test('clearNameError forgets the last error', () async {
      await viewModel.saveName('');

      viewModel.clearNameError();

      expect(viewModel.nameError, isNull);
    });
  });

  group('signOut', () {
    test('ends the session', () async {
      await viewModel.signOut();

      expect(authRepository.calls, ['signOut()']);
      expect(authRepository.isSignedIn, isFalse);
    });

    test('is signing out while it waits', () async {
      authRepository.gate = Completer<void>();

      final signingOut = viewModel.signOut();
      expect(viewModel.isSigningOut, isTrue);
      authRepository.gate!.complete();
      await signingOut;
    });
  });
}
