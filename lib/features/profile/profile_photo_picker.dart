import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Gallery access is kept separate so widget tests can inject a picker.
Future<Uint8List?> pickProfilePhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    // 512 px is plenty for a 72 dp avatar and keeps even a PNG far below the
    // store's 2 MiB limit.
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );
  return file?.readAsBytes();
}
