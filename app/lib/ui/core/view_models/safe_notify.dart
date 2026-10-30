import 'package:flutter/foundation.dart';

/// For a ViewModel whose async work can end after its screen is gone (and
/// the ViewModel disposed): [notify] then does nothing instead of throwing.
mixin SafeNotify on ChangeNotifier {
  bool _disposed = false;

  /// Whether [dispose] ran; long work checks it to stop early.
  @protected
  bool get isDisposed => _disposed;

  /// [notifyListeners], unless the ViewModel is disposed.
  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
