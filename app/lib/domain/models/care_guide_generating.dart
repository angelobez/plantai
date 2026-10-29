/// The API is still writing the care guide (`202 CARE_GUIDE_GENERATING`):
/// ask again after [retryAfter]. Repositories that read a species with its
/// guide (the Catalog's, the garden's) throw it; `waitForCareGuide` retries.
class CareGuideGenerating implements Exception {
  const CareGuideGenerating([this.retryAfter = defaultRetryAfter]);

  /// When the answer had no `Retry-After`.
  static const defaultRetryAfter = Duration(seconds: 3);

  final Duration retryAfter;

  @override
  String toString() => 'CareGuideGenerating($retryAfter)';
}
