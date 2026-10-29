import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/api_exception.dart';
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
    expect(state.apiVersion, '0.0.1');
    expect(state.postgisVersion, '3.5.2');
  });

  final failures = <String, (Object, HomeFailure)>{
    'API unreachable': (
      const ApiConnectionException(),
      HomeFailure.noConnection,
    ),
    'database down': (
      const ApiException(status: 503, code: ApiErrorCode.healthCheckFailed),
      HomeFailure.databaseDown,
    ),
    'app update required': (
      const ApiException(status: 426, code: ApiErrorCode.appUpdateRequired),
      HomeFailure.updateRequired,
    ),
    'unexpected API error': (
      const ApiException(status: 500, code: 'INTERNAL_ERROR'),
      HomeFailure.unknown,
    ),
    'error that is not from the API': (StateError('bug'), HomeFailure.unknown),
  };

  for (final MapEntry(key: name, value: (error, failure)) in failures.entries) {
    test('loading -> failed ($name)', () async {
      repository.fail(error);
      await pumpEventQueue();

      final state = viewModel.state;
      expect(state, isA<HomeFailed>());
      expect((state as HomeFailed).failure, failure);
    });
  }

  test('notifies listeners on every state change', () async {
    var notifications = 0;
    viewModel.addListener(() => notifications++);

    repository.fail(const ApiConnectionException());
    await pumpEventQueue();
    viewModel.load();
    repository.succeed();
    await pumpEventQueue();

    expect(notifications, 3);
  });

  test('retrying after a failure loads again until connected', () async {
    repository.fail(const ApiConnectionException());
    await pumpEventQueue();

    viewModel.load();
    expect(viewModel.state, isA<HomeLoading>());
    expect(repository.calls, 2);

    repository.succeed();
    await pumpEventQueue();
    expect(viewModel.state, isA<HomeConnected>());
  });
}
