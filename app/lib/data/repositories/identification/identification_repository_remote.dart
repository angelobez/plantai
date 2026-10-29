import '../../../domain/models/identification_failure.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/guard_api_call.dart';
import '../../services/api/models/identification.dart';
import '../../services/api/models/species_summary.dart';
import 'identification_repository.dart';

/// [IdentificationRepository] backed by the API's `/v1/identifications`.
class IdentificationRepositoryRemote implements IdentificationRepository {
  IdentificationRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<Identification> identify(String photoId) => _guard(
    () => _apiClient.post(
      '/v1/identifications',
      {'photoId': photoId},
      Identification.fromJson,
      receiveTimeout: ApiClient.slowReceiveTimeout,
    ),
  );

  @override
  Future<SpeciesSummary> choose(String identificationId, int candidateIndex) =>
      _guard(
        () => _apiClient.post(
          _choicePath(identificationId),
          {'candidateIndex': candidateIndex},
          (json) =>
              SpeciesSummary.fromJson(json['species'] as Map<String, dynamic>),
        ),
      );

  @override
  Future<void> chooseNone(String identificationId) => _guard(
    () => _apiClient.postWithoutBody(_choicePath(identificationId), {
      'none': true,
    }),
  );

  static String _choicePath(String identificationId) =>
      '/v1/identifications/${Uri.encodeComponent(identificationId)}/choice';

  static Future<T> _guard<T>(Future<T> Function() call) => guardApiCall(
    call,
    noConnection: IdentificationFailure.noConnection,
    onError: (code) => switch (code) {
      ApiErrorCode.identificationDailyLimit => IdentificationFailure.dailyLimit,
      ApiErrorCode.identificationServiceUnavailable =>
        IdentificationFailure.serviceUnavailable,
      ApiErrorCode.identificationAlreadyChosen =>
        IdentificationFailure.alreadyChosen,
      ApiErrorCode.notFound => IdentificationFailure.notFound,
      _ => IdentificationFailure.unknown,
    },
  );
}
