import '../../../domain/models/catalog_failure.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/guard_api_call.dart';
import '../../services/api/models/species.dart';
import '../../services/api/models/species_summary.dart';
import 'catalog_repository.dart';

/// [CatalogRepository] backed by the API's `/v1/species`.
class CatalogRepositoryRemote implements CatalogRepository {
  CatalogRepositoryRemote({required this._apiClient});

  final ApiClient _apiClient;

  @override
  Future<List<SpeciesSummary>> search(String term) => _guard(
    () => _apiClient.getList(
      '/v1/species',
      SpeciesSummary.fromJson,
      queryParameters: {'q': term},
    ),
  );

  @override
  Future<Species> species(String id) => _guard(
    () => _apiClient.get(
      '/v1/species/${Uri.encodeComponent(id)}',
      Species.fromJson,
    ),
  );

  static Future<T> _guard<T>(Future<T> Function() call) => guardApiCall(
    call,
    noConnection: CatalogFailure.noConnection,
    onError: (code) => switch (code) {
      ApiErrorCode.notFound => CatalogFailure.notFound,
      _ => CatalogFailure.unknown,
    },
  );
}
