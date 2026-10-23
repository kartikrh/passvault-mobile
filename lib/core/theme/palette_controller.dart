import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_theme.dart';

/// The chosen palette, remembered on the device (same three as the web app;
/// the two apps don't sync the choice -- it's a per-device preference).
class PaletteController extends StateNotifier<PvPalette> {
  PaletteController(this._storage) : super(PvPalette.amethyst) {
    _load();
  }

  final FlutterSecureStorage _storage;
  static const _key = 'passvault.palette';

  Future<void> _load() async {
    try {
      final saved = await _storage.read(key: _key);
      final match = PvPalette.values.where((p) => p.name == saved);
      if (match.isNotEmpty) state = match.first;
    } catch (_) {
      // Storage unavailable -- keep the default.
    }
  }

  Future<void> select(PvPalette palette) async {
    state = palette;
    try {
      await _storage.write(key: _key, value: palette.name);
    } catch (_) {}
  }
}
