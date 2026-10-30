import 'package:flutter/material.dart';

import '../../../data/repositories/profile/profile_repository.dart';
import '../../../data/services/api/models/user_profile.dart';
import '../../../domain/models/profile_failure.dart';
import '../../core/failure_messages.dart';

/// The start of every listing ("Doar mudas"): reads the User's profile, so
/// the caller knows whether the Primeiro anúncio comes before the form
/// ([UserProfile.hasDonationProfile]), then calls [onProfile] with it.
///
/// While reading, a dialog that cannot be closed covers the screen. A
/// failure shows a [SnackBar] with the message and, without connection,
/// "Tentar de novo".
Future<void> startListing(
  BuildContext context, {
  required ProfileRepository profileRepository,
  required ValueChanged<UserProfile> onProfile,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: _StartingDialog()),
  );
  try {
    final profile = await profileRepository.fetchProfile();
    navigator.pop();
    onProfile(profile);
  } on ProfileFailure catch (failure) {
    navigator.pop();
    final canRetry = failure == ProfileFailure.noConnection;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(canRetry ? noConnectionMessage : unknownFailureMessage),
        action: canRetry && context.mounted
            ? SnackBarAction(
                label: 'Tentar de novo',
                onPressed: () {
                  if (!context.mounted) return;
                  startListing(
                    context,
                    profileRepository: profileRepository,
                    onProfile: onProfile,
                  );
                },
              )
            : null,
      ),
    );
  }
}

class _StartingDialog extends StatelessWidget {
  const _StartingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 16),
          Expanded(child: Text('Um instante…')),
        ],
      ),
    );
  }
}
