/// Day counts in São Paulo's calendar, for "expira em X dias" and
/// "anunciado há X dias" (docs: "Distância e datas no app").
///
/// Brazil has had no daylight saving time since 2019, so São Paulo is always
/// UTC−3; a fixed offset spares the app a time zone database.
library;

/// São Paulo's offset from UTC, all year.
const saoPauloUtcOffset = Duration(hours: -3);

/// The calendar day [instant] falls on in São Paulo, as a UTC midnight.
DateTime saoPauloDay(DateTime instant) {
  final local = instant.toUtc().add(saoPauloUtcOffset);
  return DateTime.utc(local.year, local.month, local.day);
}

/// How many São Paulo calendar days go from [from] to [to]: 0 on the same
/// day (even 23 h apart), 1 from 23:59 to 00:01, negative when [to] comes
/// first.
int saoPauloDaysBetween(DateTime from, DateTime to) =>
    saoPauloDay(to).difference(saoPauloDay(from)).inDays;
