import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/domain/models/health_failure.dart';
import 'package:plantai/ui/home/view_models/home_view_model.dart';

import '../../testing/fake_health_repository.dart';

void main() {
  late FakeHealthRepository repository;
  late HomeViewModel viewModel;

  setUp(() {
    repository = FakeHealthRepository();
    viewModel = HomeViewModel(healthRepository: repository);
  });

  tearDown(() => viewModel.dispose());

  test('starts loading the API health', () {
    expect(viewModel.state, isA<HomeLoading>());
    expect(repository.calls, 1);
  });

  test('loading -> connected with the API and PostGIS versions', () async {
    repository.succeed(apiVersion: '0.0.1', postgisVersion: '3.5.2');
    await pumpEventQueue();

    final state = viewModel.state;
    expect(state, isA<HomeConnected>());
    state as HomeConnected;
    expect(state.health.apiVersion, '0.0.1');
    expect(state.health.postgisVersion, '3.5.2');
  });

  for (final failure in HealthFailure.values) {
    test('loading -> failed (${failure.name})', () async {
      repository.fail(failure);
      await pumpEventQueue();

      final state = viewModel.state;
      expect(state, isA<HomeFailed>());
      expect((state as HomeFailed).failure, failure);
    });
  }

  test(
    'loading -> failed (unknown) on an error that is not a HealthFailure',
    () async {
      repository.throwUnexpected(StateError('bug'));
      await pumpEventQueue();

      final state = viewModel.state;
      expect(state, isA<HomeFailed>());
      expect((state as HomeFailed).failure, HealthFailure.unknown);
    },
  );

  test('notifies listeners on every state change', () async {
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    repository.fail(HealthFailure.noConnection);
    await pumpEventQueue();
    viewModel.load();
    repository.succeed();
    await pumpEventQueue();

    expect(notifications, 3);
  });

  test('retrying after a failure loads again until connected', () async {
    repository.fail(HealthFailure.noConnection);
    await pumpEventQueue();

    viewModel.load();
    expect(viewModel.state, isA<HomeLoading>());
    expect(repository.calls, 2);

    repository.succeed();
    await pumpEventQueue();
    expect(viewModel.state, isA<HomeConnected>());
  });
}
