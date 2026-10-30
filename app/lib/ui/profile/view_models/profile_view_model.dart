import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth/auth_repository.dart';
import '../../../data/repositories/profile/profile_repository.dart';
import '../../../data/services/api/models/user_profile.dart';
import '../../../domain/models/profile_failure.dart';
import '../../auth/validators.dart';
import '../../core/view_models/safe_notify.dart';

/// Perfil: shows the profile, changes the name and signs out. Once signed
/// out, the router takes the User to Login.
class ProfileViewModel extends ChangeNotifier with SafeNotify {
  ProfileViewModel({
    required this._profileRepository,
    required this._authRepository,
  });

  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Why the profile could not be read; the screen offers to try again.
  String? _loadError;
  String? get loadError => _loadError;

  bool _isSavingName = false;
  bool get isSavingName => _isSavingName;

  /// What is wrong with the new name, or why saving it failed.
  String? _nameError;
  String? get nameError => _nameError;

  bool _isSigningOut = false;
  bool get isSigningOut => _isSigningOut;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notify();
    try {
      _profile = await _profileRepository.fetchProfile();
    } on ProfileFailure catch (failure) {
      _loadError = _message(failure);
    } finally {
      _isLoading = false;
      notify();
    }
  }

  /// Whether the name was saved.
  Future<bool> saveName(String name) async {
    _nameError = validateName(name);
    if (_nameError != null) {
      notify();
      return false;
    }

    _isSavingName = true;
    notify();
    try {
      _profile = await _profileRepository.updateName(name.trim());
      return true;
    } on ProfileFailure catch (failure) {
      _nameError = _message(failure);
      return false;
    } finally {
      _isSavingName = false;
      notify();
    }
  }

  /// Forgets the last name error, for a fresh edit.
  void clearNameError() {
    if (_nameError == null) return;
    _nameError = null;
    notify();
  }

  Future<void> signOut() async {
    _isSigningOut = true;
    notify();
    try {
      await _authRepository.signOut();
    } finally {
      // The screen may be gone by now: the router left for Login.
      _isSigningOut = false;
      notify();
    }
  }

  static String _message(ProfileFailure failure) => switch (failure) {
    ProfileFailure.noConnection =>
      'Sem conexão com a internet. Confira a rede e tente de novo.',
    ProfileFailure.unknown => 'Algo deu errado. Tente de novo.',
  };
}
