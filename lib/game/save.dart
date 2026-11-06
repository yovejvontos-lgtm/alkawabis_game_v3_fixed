import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'level.dart';
import 'profile.dart';

/// الحفظ المحلي: المراحل المفتوحة وبيانات الشخصية.
class Save extends ChangeNotifier {
  Save._();

  static final Save instance = Save._();

  /// أعلى رقم مرحلة مفتوحة (يبدأ من 0).
  int unlocked = 0;
  PlayerProfile profile = PlayerProfile();

  Future<void> load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final int u = p.getInt('unlocked_v2') ?? 0;
      unlocked = u < 0 ? 0 : (u > Level.campaignCount - 1 ? Level.campaignCount - 1 : u);
      final String? s = p.getString('profile_v2');
      if (s != null) {
        profile = PlayerProfile.decode(s);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> unlock(int index) async {
    if (index <= unlocked || index >= Level.campaignCount) {
      return;
    }
    unlocked = index;
    notifyListeners();
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setInt('unlocked_v2', unlocked);
    } catch (_) {}
  }

  Future<void> saveProfile(PlayerProfile p) async {
    profile = p.copy();
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_v2', profile.encode());
    } catch (_) {}
  }
}
