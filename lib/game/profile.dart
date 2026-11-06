/// أسماء الأزياء المتاحة وألوان اللوحة.
class Outfits {
  static const List<String> tops = <String>[
    'قميص عادي',
    'جاكيت جلد',
    'سترة بقلنسوة',
    'درع فارس',
    'رداء نينجا',
    'قميص كاراتيه',
    'سترة تكتيكية',
    'معطف طويل',
    'قميص رياضي',
    'رداء ساحر',
  ];

  static const List<String> bottoms = <String>[
    'بنطال عادي',
    'شورت',
    'بنطال جلد',
    'سروال نينجا',
    'سروال كاراتيه',
    'بنطال تكتيكي',
    'تنورة قتال',
    'بنطال بحزام',
    'سروال رياضي',
    'بنطال بأحذية عالية',
  ];

  /// أزياء كاملة مستوحاة (بدون شعارات أو أسماء الشخصيات).
  static const List<String> fulls = <String>[
    'زي الاستطلاع',
    'زي اللعنة',
    'زي القرصان',
    'زي الصياد',
    'زي المحارب',
  ];

  static const List<int> palette = <int>[
    0xFFE53935,
    0xFFFB8C00,
    0xFFFDD835,
    0xFF43A047,
    0xFF00ACC1,
    0xFF1E88E5,
    0xFF5E35B1,
    0xFFD81B60,
    0xFFFFFFFF,
    0xFF9E9E9E,
    0xFF6D4C41,
    0xFF263238,
  ];
}

/// بيانات لاعب: الاسم والزي والألوان.
class PlayerProfile {
  PlayerProfile({
    this.name = 'لاعب',
    this.top = 0,
    this.bottom = 0,
    this.full = -1,
    this.topColor = 0xFF1E88E5,
    this.bottomColor = 0xFF263238,
    this.hair = 0,
    this.headwear = -1,
  });

  String name;
  int top;
  int bottom;

  /// -1 يعني بدون زي كامل.
  int full;
  int topColor;
  int bottomColor;
  int hair; // تسريحة الشعر
  int headwear; // -1 بدون قبعة، 0 قبعة قش

  PlayerProfile copy() {
    return PlayerProfile(
      name: name,
      top: top,
      bottom: bottom,
      full: full,
      topColor: topColor,
      bottomColor: bottomColor,
      hair: hair,
      headwear: headwear,
    );
  }

  static String cleanName(String n) {
    final String s = n.replaceAll(RegExp(r'[~|\r\n]'), ' ').trim();
    if (s.isEmpty) {
      return 'لاعب';
    }
    return String.fromCharCodes(s.runes.take(12));
  }

  String encode() {
    return '${cleanName(name)}~$top~$bottom~$full~$topColor~$bottomColor~$hair~$headwear';
  }

  static PlayerProfile decode(String s) {
    try {
      final List<String> p = s.split('~');
      if (p.length < 6) {
        return PlayerProfile();
      }
      int pick(String v, int lo, int hi, int def) {
        final int? x = int.tryParse(v);
        if (x == null || x < lo || x > hi) {
          return def;
        }
        return x;
      }

      return PlayerProfile(
        name: cleanName(p[0]),
        top: pick(p[1], 0, Outfits.tops.length - 1, 0),
        bottom: pick(p[2], 0, Outfits.bottoms.length - 1, 0),
        full: pick(p[3], -1, Outfits.fulls.length - 1, -1),
        topColor: int.tryParse(p[4]) ?? 0xFF1E88E5,
        bottomColor: int.tryParse(p[5]) ?? 0xFF263238,
        hair: p.length > 6 ? pick(p[6], 0, 5, 0) : 0,
        headwear: p.length > 7 ? pick(p[7], -1, 0, -1) : -1,
      );
    } catch (_) {
      return PlayerProfile();
    }
  }

  String outfitSummary() {
    if (full >= 0 && full < Outfits.fulls.length) {
      return Outfits.fulls[full];
    }
    return '${Outfits.tops[top]} + ${Outfits.bottoms[bottom]}';
  }
}

/// لاعب داخل الغرفة: بياناته وفريقه (0 أو 1).
class RosterEntry {
  RosterEntry(this.profile, this.team);

  final PlayerProfile profile;
  int team;

  static List<List<Object>> toJson(List<RosterEntry> list) {
    return list
        .map((RosterEntry e) => <Object>[e.profile.encode(), e.team])
        .toList();
  }

  static List<RosterEntry> fromJson(List<dynamic> l) {
    final List<RosterEntry> out = <RosterEntry>[];
    for (final dynamic item in l) {
      if (item is List && item.length >= 2) {
        final int t = (item[1] as num).toInt();
        out.add(
          RosterEntry(PlayerProfile.decode(item[0] as String), t == 1 ? 1 : 0),
        );
      }
    }
    return out;
  }
}
