import '../../../domain/models/garden_failure.dart';
import '../../../domain/models/new_plant.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/care_guide_call.dart';
import '../../services/api/guard_api_call.dart';
import '../../services/api/models/plant.dart';
import 'garden_repository.dart';

/// [GardenRepository] backed by the API's `/v1/plants`.
class GardenRepositoryRemote extends GardenRepository {
  GardenRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<List<PlantSummary>> plants() =>
      _guard(() => _apiClient.getList('/v1/plants', PlantSummary.fromJson));

  @override
  Future<PlantSummary> create(NewPlant plant) async {
    final saved = await _guard(
      () => _apiClient.post('/v1/plants', {
        'photoId': plant.photoId,
        'commonName': plant.commonName,
        'speciesId': ?plant.speciesId,
      }, PlantSummary.fromJson),
    );
    notifyListeners();
    return saved;
  }

  @override
  Future<Plant> plant(String id) => _guard(
    () => careGuideCall(
      () => _apiClient.get(
        _plantPath(id),
        Plant.fromJson,
        receiveTimeout: careGuideReceiveTimeout,
      ),
    ),
  );

  static String _plantPath(String id) =>
      '/v1/plants/${Uri.encodeComponent(id)}';

  static Future<T> _guard<T>(Future<T> Function() call) => guardApiCall(
    call,
    noConnection: GardenFailure.noConnection,
    onError: (code) => switch (code) {
      ApiErrorCode.notFound => GardenFailure.notFound,
      _ => GardenFailure.unknown,
    },
  );
}
