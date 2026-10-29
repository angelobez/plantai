import 'package:flutter/foundation.dart';

/// Whether the API refused this app version (`426 APP_UPDATE_REQUIRED`).
///
/// `ApiClient` raises it on any call; the router listens to it and sends the
/// user to "Atualize o PlantAí". It never goes back down: only a new build of
/// the app fixes it.
class UpdateRequired extends ChangeNotifier {
  bool _isRequired = false;
  bool get isRequired => _isRequired;

  void raise() {
    if (_isRequired) return;
    _isRequired = true;
    notifyListeners();
  }
}
