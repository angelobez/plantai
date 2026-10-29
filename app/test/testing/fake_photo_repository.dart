import 'dart:async';

import 'package:plantai/data/repositories/photo/photo_repository.dart';
import 'package:plantai/data/services/api/models/photo.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';
import 'package:plantai/domain/models/photo_failure.dart';

/// A [PhotoRepository] the test drives: it answers with [failure] (when set)
/// or a new [Photo], and records what was sent in [uploads].
///
/// Set [gate] to hold every upload until the test completes it.
class FakePhotoRepository implements PhotoRepository {
  /// Thrown by the next uploads, until set back to null.
  PhotoFailure? failure;

  /// When set, uploads wait for it before answering.
  Completer<void>? gate;

  /// The file name of every photo sent, in order.
  final uploads = <String>[];

  @override
  Future<Photo> upload(PickedPhoto photo) async {
    uploads.add(photo.filename);
    final gate = this.gate;
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return Photo(
      id: 'photo-${uploads.length}',
      url: 'https://photo-storage.fake/photos/${uploads.length}.jpg',
      expiresAt: DateTime.utc(2026, 11, 3, 15),
    );
  }
}
