import '../../../domain/models/care_guide_generating.dart';
import 'api_exception.dart';

/// How long a call that may have Claude write a care guide can take: the API
/// answers it only after Claude did (5 to 10 s, under a minute at worst).
const careGuideReceiveTimeout = Duration(seconds: 60);

/// Runs [call], a read that answers a care guide, turning `202
/// CARE_GUIDE_GENERATING` into [CareGuideGenerating]. Put it inside the
/// repository's `guardApiCall`, which then lets it through.
Future<T> careGuideCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on ApiException catch (error) {
    if (error.code != ApiErrorCode.careGuideGenerating) rethrow;
    throw CareGuideGenerating(
      error.retryAfter ?? CareGuideGenerating.defaultRetryAfter,
    );
  }
}
