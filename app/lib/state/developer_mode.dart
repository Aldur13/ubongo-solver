import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _developerModeKey = 'developer_mode_enabled';

/// Whether developer-only affordances (currently: the corrected-scan
/// share/export button on the piece-selection screen) are shown.
///
/// A persisted Settings toggle rather than a `kDebugMode` gate so that
/// release builds — the ones users actually test scanning with — can
/// still export what the native scanner produced; those exports are the
/// raw material for diagnosing detection failures (see
/// `packages/ubongo_vision/tool/inspect_card.dart`).
class DeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadPersisted();
    return false;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_developerModeKey);
    if (stored != null) state = stored;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_developerModeKey, enabled);
  }
}

final developerModeProvider = NotifierProvider<DeveloperModeNotifier, bool>(
  DeveloperModeNotifier.new,
);
