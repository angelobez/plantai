import 'package:json_annotation/json_annotation.dart';

import 'user_profile.dart';

part 'auth_tokens.g.dart';

/// `{ accessToken, refreshToken, user }`: the answer of every API route that
/// signs the User in.
@JsonSerializable(createToJson: false)
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);

  final String accessToken;
  final String refreshToken;
  final UserProfile user;
}
