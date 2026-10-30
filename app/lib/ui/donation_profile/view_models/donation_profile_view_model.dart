import 'package:flutter/foundation.dart';

import '../../../data/repositories/profile/profile_repository.dart';
import '../../../data/services/api/models/user_profile.dart';
import '../../../data/services/location/location_service.dart';
import '../../../domain/models/donation_profile.dart';
import '../../../domain/models/profile_failure.dart';
import '../../core/failure_messages.dart';
import '../../core/url_opener.dart';
import '../../core/view_models/safe_notify.dart';
import '../brazilian_phone.dart';

/// Why [DonationProfileViewModel.useMyLocation] found no position.
enum LocationProblem {
  /// The permission was refused; asking again may work.
  denied,

  /// Refused for good: only the Android settings give it back.
  deniedForever,

  /// The phone's location is off.
  serviceDisabled,

  /// No position came (a timeout or a plugin error).
  unavailable,
}

/// The donation profile: the WhatsApp phone and the donation location. The
/// same screen serves the Perfil and, before the form, the Primeiro anúncio.
///
/// The API never sends the point back. Saving sends a position only when one
/// was found here by [useMyLocation]; without it the saved location stays,
/// and with no saved location (the Primeiro anúncio) a position is required.
class DonationProfileViewModel extends ChangeNotifier with SafeNotify {
  DonationProfileViewModel({
    required this._profileRepository,
    required this._locationService,
    required this._openUrl,
    UserProfile? profile,
  }) : _phone = switch (profile?.phone) {
         final phone? => displayPhone(phone),
         null => '',
       },
       _neighborhood = profile?.donationLocation?.neighborhood ?? '',
       currentNeighborhood = profile?.donationLocation?.neighborhood;

  static const neighborhoodMaxLength = 60;

  final ProfileRepository _profileRepository;
  final LocationService _locationService;
  final UrlOpener _openUrl;

  /// The neighborhood of the location saved before, if any.
  final String? currentNeighborhood;

  String _phone;

  /// The phone as typed (masked by the screen).
  String get phone => _phone;

  String? _phoneError;
  String? get phoneError => _phoneError;

  String _neighborhood;
  String get neighborhood => _neighborhood;

  String? _neighborhoodError;
  String? get neighborhoodError => _neighborhoodError;

  /// The geocoder found no neighborhood at the position: the User types it.
  bool _neighborhoodNotFound = false;
  bool get neighborhoodNotFound => _neighborhoodNotFound;

  ApproximatePosition? _position;

  /// Whether a position was found here; without one, only a profile with a
  /// saved location can be saved.
  bool get hasPosition => _position != null;

  bool _isLocating = false;
  bool get isLocating => _isLocating;

  LocationProblem? _locationProblem;
  LocationProblem? get locationProblem => _locationProblem;

  String? _locationError;

  /// Why there is no position: a [locationProblem], or saving without one.
  String? get locationError => _locationError;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _saveError;
  String? get saveError => _saveError;

  /// Whether the last save failed for lack of connection.
  bool _canRetrySave = false;
  bool get canRetrySave => _canRetrySave;

  void updatePhone(String phone) {
    _phone = phone;
    if (_phoneError == null) return;
    _phoneError = null;
    notify();
  }

  void updateNeighborhood(String neighborhood) {
    _neighborhood = neighborhood;
    if (_neighborhoodError == null) return;
    _neighborhoodError = null;
    notify();
  }

  /// Opens WhatsApp on the typed number, so the User sees it is right.
  Future<void> testOnWhatsApp() async {
    final number = whatsappNumber(_phone);
    if (number == null) {
      _phoneError = _missingPhone;
      notify();
      return;
    }
    await _openUrl(Uri.parse('https://wa.me/$number'));
  }

  /// Finds the approximate position (asking for the permission now) and
  /// fills the neighborhood with the geocoder's suggestion, which the User
  /// may still correct. Whether a position was found.
  Future<bool> useMyLocation() async {
    _isLocating = true;
    _locationProblem = null;
    _locationError = null;
    notify();
    try {
      final result = await _locationService.currentPosition();
      switch (result) {
        case LocationFound(:final position):
          _position = position;
          final suggestion = await _locationService.suggestNeighborhood(
            position,
          );
          _neighborhoodNotFound = suggestion == null;
          if (suggestion != null) {
            _neighborhood = suggestion;
            _neighborhoodError = null;
          }
          return true;
        case LocationDenied():
          _setProblem(LocationProblem.denied);
        case LocationDeniedForever():
          _setProblem(LocationProblem.deniedForever);
        case LocationServiceDisabled():
          _setProblem(LocationProblem.serviceDisabled);
        case LocationUnavailable():
          _setProblem(LocationProblem.unavailable);
      }
      return false;
    } finally {
      _isLocating = false;
      notify();
    }
  }

  /// Opens the Android settings that fix the [locationProblem]: the app's
  /// permissions, or the location switch.
  Future<void> openSettings() async {
    switch (_locationProblem) {
      case LocationProblem.deniedForever:
        await _locationService.openAppSettings();
      case LocationProblem.serviceDisabled:
        await _locationService.openLocationSettings();
      case LocationProblem.denied || LocationProblem.unavailable || null:
        break;
    }
  }

  /// Saves the profile; the profile as the API saved it, or null when
  /// something is missing or saving failed (the errors say why).
  Future<UserProfile?> save() async {
    final position = _position;
    final neighborhood = _neighborhood.trim();
    final missingLocation = position == null && currentNeighborhood == null;
    _phoneError = whatsappNumber(_phone) == null ? _missingPhone : null;
    _neighborhoodError = missingLocation ? null : _validate(neighborhood);
    if (missingLocation) {
      _locationProblem = null;
      _locationError =
          'Toque em "Usar minha localização" para confirmar de onde você doa.';
    }
    if (_phoneError != null || _neighborhoodError != null || missingLocation) {
      notify();
      return null;
    }

    _isSaving = true;
    _saveError = null;
    _canRetrySave = false;
    notify();
    try {
      return await _profileRepository.updateDonationProfile(
        DonationProfile(
          phone: _phone,
          latitude: position?.latitude,
          longitude: position?.longitude,
          neighborhood: neighborhood,
        ),
      );
    } on ProfileFailure catch (failure) {
      switch (failure) {
        case ProfileFailure.invalidPhone:
          _phoneError =
              'Esse número não é um celular do Brasil. Confira o DDD e o '
              'número.';
        case ProfileFailure.noConnection:
          _saveError = noConnectionMessage;
          _canRetrySave = true;
        case ProfileFailure.unknown:
          _saveError = unknownFailureMessage;
      }
      return null;
    } finally {
      _isSaving = false;
      notify();
    }
  }

  void _setProblem(LocationProblem problem) {
    _locationProblem = problem;
    _locationError = switch (problem) {
      LocationProblem.denied =>
        'Sem a permissão de localização não dá para saber de onde você doa. '
            'Toque em "Usar minha localização" para tentar de novo.',
      LocationProblem.deniedForever =>
        'A permissão de localização está negada. Libere a localização do '
            'PlantAí nas configurações do Android.',
      LocationProblem.serviceDisabled =>
        'A localização do celular está desligada. Ligue e tente de novo.',
      LocationProblem.unavailable =>
        'Não deu para achar a sua localização. Tente de novo.',
    };
  }

  static String? _validate(String neighborhood) {
    if (neighborhood.isEmpty) return 'Digite o seu bairro.';
    if (neighborhood.length > neighborhoodMaxLength) {
      return 'Use até $neighborhoodMaxLength caracteres.';
    }
    return null;
  }

  static const _missingPhone = 'Digite o celular com o DDD.';
}
