/// The pt-BR texts the listing screens share: quantities, interest, days
/// and distance.
library;

import '../core/sao_paulo_days.dart';

/// "1 muda", "3 mudas".
String seedlingCount(int count) => count == 1 ? '1 muda' : '$count mudas';

/// "Ninguém teve interesse ainda", "1 pessoa teve interesse", "3 pessoas
/// tiveram interesse": a count, never names.
String interestCountText(int count) => switch (count) {
  0 => 'Ninguém teve interesse ainda',
  1 => '1 pessoa teve interesse',
  _ => '$count pessoas tiveram interesse',
};

/// "expira hoje", "expira em 1 dia", "expira em 5 dias", counted in São
/// Paulo's calendar days from [now].
String expiresInText(DateTime expiresAt, DateTime now) {
  final days = saoPauloDaysBetween(now, expiresAt);
  return switch (days) {
    <= 0 => 'expira hoje',
    1 => 'expira em 1 dia',
    _ => 'expira em $days dias',
  };
}

/// "Anunciado hoje", "Anunciado há 1 dia", "Anunciado há 3 dias", counted
/// in São Paulo's calendar days until [now].
String postedAgoText(DateTime createdAt, DateTime now) {
  final days = saoPauloDaysBetween(createdAt, now);
  return switch (days) {
    <= 0 => 'Anunciado hoje',
    1 => 'Anunciado há 1 dia',
    _ => 'Anunciado há $days dias',
  };
}

/// "menos de 1 km" for 0, "a cerca de N km" otherwise: the API already
/// rounds [distanceKm] to an integer, and never sends the exact distance.
String distanceText(int distanceKm) =>
    distanceKm <= 0 ? 'menos de 1 km' : 'a cerca de $distanceKm km';
