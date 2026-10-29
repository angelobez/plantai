import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/ui/core/widgets/photo_image.dart';

void main() {
  testWidgets('caches the photo by its id, not by the presigned URL', (
    tester,
  ) async {
    final photo = Photo(
      id: '0190e0d4-0000-7000-8000-0000000000aa',
      url: 'http://localhost:9000/plantai-photos/photos/aa.jpg?X-Amz-Date=1',
      expiresAt: DateTime.utc(2026, 11, 3, 15),
    );
    late Widget built;

    // Built, not pumped: the real cache needs the platform's file system.
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          built = PhotoImage(photo: photo).build(context);
          return const SizedBox();
        },
      ),
    );

    final image = built as CachedNetworkImage;
    expect(image.cacheKey, photo.id);
    expect(image.imageUrl, photo.url);
  });
}
