import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/ui/listings/listing_texts.dart';

void main() {
  // 12:00 in São Paulo.
  final now = DateTime.utc(2026, 10, 30, 15);

  test('seedlingCount', () {
    expect(seedlingCount(1), '1 muda');
    expect(seedlingCount(3), '3 mudas');
    expect(seedlingCount(0), '0 mudas');
  });

  test('interestCountText', () {
    expect(interestCountText(0), 'Ninguém teve interesse ainda');
    expect(interestCountText(1), '1 pessoa teve interesse');
    expect(interestCountText(3), '3 pessoas tiveram interesse');
  });

  group('expiresInText', () {
    test('says "hoje" for later today', () {
      // 23:30 in São Paulo.
      expect(
        expiresInText(DateTime.utc(2026, 10, 31, 2, 30), now),
        'expira hoje',
      );
    });

    test('counts days in São Paulo, not 24 h periods', () {
      // 00:30 of tomorrow in São Paulo, only 12 h 30 min away.
      expect(
        expiresInText(DateTime.utc(2026, 10, 31, 3, 30), now),
        'expira em 1 dia',
      );
      expect(
        expiresInText(DateTime.utc(2026, 11, 29, 15), now),
        'expira em 30 dias',
      );
    });
  });

  test('postedAgoText', () {
    expect(postedAgoText(DateTime.utc(2026, 10, 30, 4), now), 'Anunciado hoje');
    expect(
      postedAgoText(DateTime.utc(2026, 10, 30, 2), now),
      'Anunciado há 1 dia',
    );
    expect(
      postedAgoText(DateTime.utc(2026, 10, 27, 15), now),
      'Anunciado há 3 dias',
    );
  });

  test('distanceText', () {
    expect(distanceText(0), 'menos de 1 km');
    expect(distanceText(2), 'a cerca de 2 km');
  });
}
