import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plantai/data/services/photo_picker/image_picker_photo_picker.dart';
import 'package:plantai/data/services/photo_picker/photo_picker.dart';

import '../../../testing/fake_photo_picker.dart';

/// Stands in for the plugin: answers [answer] and records the arguments.
class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker(this.answer);

  Future<XFile?> Function() answer;
  final calls = <Map<String, Object?>>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    calls.add({
      'source': source,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'imageQuality': imageQuality,
    });
    return answer();
  }
}

void main() {
  test('asks the plugin for one reduced photo and reads it', () async {
    final plugin = _FakeImagePicker(
      () async => XFile.fromData(
        onePixelPng,
        path: '/data/cache/IMG_0042.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    final result = await ImagePickerPhotoPicker(plugin)
        .pick(PhotoSource.camera);

    expect(plugin.calls.single, {
      'source': ImageSource.camera,
      'maxWidth': 1600.0,
      'maxHeight': 1600.0,
      'imageQuality': 85,
    });
    final photo = (result as Picked).photo;
    expect(photo.bytes, onePixelPng);
    expect(photo.filename, 'IMG_0042.jpg');
    expect(photo.contentType, 'image/jpeg');
  });

  test('the gallery is the gallery', () async {
    final plugin = _FakeImagePicker(() async => null);

    await ImagePickerPhotoPicker(plugin).pick(PhotoSource.gallery);

    expect(plugin.calls.single['source'], ImageSource.gallery);
  });

  test('no file is a cancel', () async {
    final picker = ImagePickerPhotoPicker(_FakeImagePicker(() async => null));

    expect(await picker.pick(PhotoSource.camera), isA<PickCancelled>());
  });

  test('a refused camera permission is CameraDenied', () async {
    final picker = ImagePickerPhotoPicker(
      _FakeImagePicker(
        () async => throw PlatformException(code: 'camera_access_denied'),
      ),
    );

    expect(await picker.pick(PhotoSource.camera), isA<CameraDenied>());
  });

  test('any other plugin error is PickFailed', () async {
    final picker = ImagePickerPhotoPicker(
      _FakeImagePicker(
        () async => throw PlatformException(code: 'no_available_camera'),
      ),
    );

    expect(await picker.pick(PhotoSource.camera), isA<PickFailed>());
  });
}
