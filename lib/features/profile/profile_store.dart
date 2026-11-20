import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../ledger/data/local_ledger.dart';

/// A detached snapshot of the local profile, with no account information.
final class LocalProfile {
  LocalProfile({this.name = '', Uint8List? avatarBytes})
    : avatarBytes = avatarBytes == null
          ? null
          : Uint8List.fromList(avatarBytes).asUnmodifiableView();

  final String name;
  final Uint8List? avatarBytes;
}

/// Device-only profile storage, intentionally outside ledger JSON backups.
final class ProfileStore {
  ProfileStore(this._ledger);

  final LocalLedger _ledger;

  static const int maxAvatarBytes = 2 * 1024 * 1024;
  static const int maxNameRunes = 60;

  Future<void> _ensureTable() => _ledger.customStatement('''
    CREATE TABLE IF NOT EXISTS local_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL,
      avatar BLOB
    )
  ''');

  Future<LocalProfile> load() async {
    await _ensureTable();
    final row = await _ledger.customSelect('''
      SELECT name, CASE WHEN length(avatar) <= $maxAvatarBytes THEN avatar END
        AS avatar, length(avatar) AS avatar_size
      FROM local_profile WHERE id = 1
    ''').getSingleOrNull();
    if (row == null) return LocalProfile();
    final avatar = row.readNullable<Uint8List>('avatar');
    if ((row.readNullable<int>('avatar_size') ?? 0) > maxAvatarBytes ||
        (avatar != null && !isSupportedAvatar(avatar))) {
      throw const FormatException('Invalid stored profile photo.');
    }
    return LocalProfile(name: row.read<String>('name'), avatarBytes: avatar);
  }

  Future<void> save(LocalProfile profile) async {
    final name = profile.name.trim();
    if (name.runes.length > maxNameRunes) {
      throw const FormatException('Use at most 60 characters for the name.');
    }
    final avatar = profile.avatarBytes;
    if (avatar != null && !isSupportedAvatar(avatar)) {
      throw const FormatException('Choose a PNG or JPEG up to 2 MiB.');
    }
    await _ensureTable();
    await _ledger.customStatement(
      '''
      INSERT INTO local_profile (id, name, avatar) VALUES (1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET name = excluded.name, avatar = excluded.avatar
    ''',
      <Object?>[name, avatar],
    );
  }

  static bool isSupportedAvatar(Uint8List bytes) {
    if (bytes.length > maxAvatarBytes) return false;
    const png = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    return (bytes.length >= png.length &&
            Iterable<int>.generate(png.length)
                .every((i) => bytes[i] == png[i])) ||
        (bytes.length >= 4 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff);
  }
}
