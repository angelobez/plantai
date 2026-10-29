import 'dart:async';
import 'dart:typed_data';

import 'package:plantai/data/services/photo_picker/photo_picker.dart';

/// A 1×1 transparent PNG, so a preview of a fake photo decodes.
final onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// A photo as the picker hands it out; [name] tells two of them apart.
PickedPhoto pickedPhoto([String name = 'IMG_0001.jpg']) =>
    PickedPhoto(bytes: onePixelPng, filename: name);

/// A [PhotoPicker] the test drives: [next] answers every pick until changed,
/// and [asked] records the sources asked for.
///
/// Set [gate] to hold the picks until the test completes it, as if the
/// camera were still open.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({PickResult? next}) : next = next ?? Picked(pickedPhoto());

  PickResult next;

  /// When set, picks wait for it before answering.
  Completer<void>? gate;

  final asked = <PhotoSource>[];

  @override
  Future<PickResult> pick(PhotoSource source) async {
    asked.add(source);
    await gate?.future;
    return next;
  }
}
