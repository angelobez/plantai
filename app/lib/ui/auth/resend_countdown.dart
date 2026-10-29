import 'dart:async';

import 'package:flutter/foundation.dart';

/// The wait between e-mail codes ("reenvie em 0:45"), counted down once a
/// second. [onTick] runs on every second, so the ViewModel can notify.
class ResendCountdown {
  ResendCountdown({required this.duration, required this.onTick});

  /// How long to wait between codes.
  final Duration duration;

  final VoidCallback onTick;

  Timer? _timer;

  int _secondsLeft = 0;

  /// Seconds until another code can be asked for; 0 when it can.
  int get secondsLeft => _secondsLeft;

  /// Starts the wait again from [duration]: a code was just sent.
  void restart() {
    _timer?.cancel();
    _secondsLeft = duration.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsLeft -= 1;
      if (_secondsLeft <= 0) {
        _secondsLeft = 0;
        timer.cancel();
      }
      onTick();
    });
  }

  void dispose() => _timer?.cancel();
}
