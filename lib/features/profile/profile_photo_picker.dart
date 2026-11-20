import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Gallery access is kept separate so widget tests can inject a picker.
Future<Uint8List?> pickProfilePhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 80,
  );
  return file?.readAsBytes();
}
