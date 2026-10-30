import 'dart:async';

import 'package:plantai/data/repositories/profile/profile_repository.dart';
import 'package:plantai/data/services/api/models/user_profile.dart';
import 'package:plantai/domain/models/donation_profile.dart';
import 'package:plantai/domain/models/profile_failure.dart';

const marina = UserProfile(
  id: '0190d6b4-0000-7000-8000-000000000001',
  name: 'Marina Souza',
  email: 'marina@email.com',
);

/// A [ProfileRepository] the test drives: it keeps [profile], records the
/// calls and answers with [failure] (when set) or success.
///
/// Set [gate] to hold every call until the test completes it.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({this.profile = marina});

  UserProfile profile;

  /// Thrown by the next calls, until set back to null.
  ProfileFailure? failure;

  /// When set, calls wait for it before answering.
  Completer<void>? gate;

  /// Every call, such as `fetchProfile()` or `updateName(Marina)`.
  final calls = <String>[];

  Future<void> _answer(String call) async {
    calls.add(call);
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }

  @override
  Future<UserProfile> fetchProfile() async {
    await _answer('fetchProfile()');
    return profile;
  }

  @override
  Future<UserProfile> updateName(String name) async {
    await _answer('updateName($name)');
    return profile = UserProfile(
      id: profile.id,
      name: name,
      email: profile.email,
      phone: profile.phone,
      donationLocation: profile.donationLocation,
    );
  }

  /// The donation profiles saved, in order.
  final donationProfiles = <DonationProfile>[];

  /// What [updateDonationProfile] stores as the phone, in place of the
  /// API's E.164.
  String savedPhone = '+5511987654321';

  @override
  Future<UserProfile> updateDonationProfile(DonationProfile changes) async {
    await _answer('updateDonationProfile(${changes.neighborhood})');
    donationProfiles.add(changes);
    return profile = UserProfile(
      id: profile.id,
      name: profile.name,
      email: profile.email,
      phone: savedPhone,
      donationLocation: DonationLocation(neighborhood: changes.neighborhood),
    );
  }
}
