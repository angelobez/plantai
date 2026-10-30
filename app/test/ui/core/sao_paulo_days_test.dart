import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/core/sao_paulo_days.dart';

void main() {
  test('the São Paulo day of an instant is the UTC day 3 h earlier', () {
    // 01:30 UTC is still 22:30 of the day before in São Paulo.
    expect(
      saoPauloDay(DateTime.utc(2026, 11, 1, 1, 30)),
      DateTime.utc(2026, 10, 31),
    );
    expect(
      saoPauloDay(DateTime.utc(2026, 11, 1, 3)),
      DateTime.utc(2026, 11, 1),
    );
  });

  test('the São Paulo day does not depend on the device time zone', () {
    final instant = DateTime.utc(2026, 11, 1, 2, 59);

    expect(saoPauloDay(instant.toLocal()), saoPauloDay(instant));
  });

  group('saoPauloDaysBetween', () {
    test('is 0 within the same day, even 23 h apart', () {
      expect(
        saoPauloDaysBetween(
          DateTime.utc(2026, 11, 1, 3, 1), // 00:01 in São Paulo
          DateTime.utc(2026, 11, 2, 2, 59), // 23:59 in São Paulo
        ),
        0,
      );
    });

    test('is 1 across midnight in São Paulo, even 2 min apart', () {
      expect(
        saoPauloDaysBetween(
          DateTime.utc(2026, 11, 2, 2, 59), // 23:59 in São Paulo
          DateTime.utc(2026, 11, 2, 3, 1), // 00:01 of the next day
        ),
        1,
      );
    });

    test('counts whole days, and goes negative backwards', () {
      final from = DateTime.utc(2026, 10, 30, 15);

      expect(saoPauloDaysBetween(from, DateTime.utc(2026, 11, 29, 15)), 30);
      expect(saoPauloDaysBetween(from, DateTime.utc(2026, 10, 27, 15)), -3);
    });
  });
}
