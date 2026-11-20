import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Gallery access is kept separate so widget tests can inject a picker.
///
/// The picker is intentionally quiet: no camera, no multi-select, no cropping
/// UI of its own. A profile photo is decoration, so the constraints below keep
/// it small and the resulting bytes well inside the store's 2 MiB limit.
///
/// A user who cancels gets `null` back - never an exception - and so does a
/// platform that cannot open a picker at all (no gallery app, access denied):
/// the screen then says "Photo selection cancelled." or shows its own error
/// copy instead of surfacing a raw platform failure.
Future<Uint8List?> pickProfilePhoto() async {
  XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // 512 px is plenty for an 84 dp avatar and keeps even a PNG far below
      // the store's 2 MiB limit.
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
      requestFullMetadata: false,
    );
  } on Exception {
    return null;
  }
  if (file == null) return null;
  return file.readAsBytes();
}
