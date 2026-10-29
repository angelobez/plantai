import 'dart:async';

import '../../../domain/models/care_guide_generating.dart';

/// After this long without an answer, the screen says "gerando dicas…": a
/// first opening waits while Claude writes the guide.
const careGuideSlowAnswer = Duration(seconds: 2);

/// How long to keep asking while the API answers `CARE_GUIDE_GENERATING`.
const careGuideGiveUpAfter = Duration(seconds: 60);

/// What the species and plant screens show when the care guide did not
/// come: Claude failed, or [waitForCareGuide] gave up.
const careGuideUnavailableMessage = 'Dicas indisponíveis no momento.';

/// Runs [load] (a repository read that answers a care guide) until it stops
/// throwing [CareGuideGenerating]: each time, it waits the answer's
/// `Retry-After` and asks again. Once the waits would pass
/// [careGuideGiveUpAfter], it gives up and rethrows the last
/// [CareGuideGenerating].
///
/// [onGenerating] is called when the screen should say "gerando dicas…": on
/// the first [CareGuideGenerating], or when the first answer takes longer
/// than [careGuideSlowAnswer]. It stops early, rethrowing, once [isCancelled]
/// (the ViewModel was disposed). Any other error goes straight through.
Future<T> waitForCareGuide<T>(
  Future<T> Function() load, {
  required void Function() onGenerating,
  bool Function() isCancelled = _never,
}) async {
  var waited = Duration.zero;
  final slow = Timer(careGuideSlowAnswer, onGenerating);
  try {
    while (true) {
      try {
        return await load();
      } on CareGuideGenerating catch (generating) {
        slow.cancel();
        final wait = generating.retryAfter;
        if (isCancelled() || waited + wait > careGuideGiveUpAfter) rethrow;
        onGenerating();
        await Future<void>.delayed(wait);
        waited += wait;
        if (isCancelled()) rethrow;
      }
    }
  } finally {
    slow.cancel();
  }
}

bool _never() => false;
