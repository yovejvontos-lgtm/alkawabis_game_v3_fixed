import 'dart:ui';

/// مولّد أرقام عشوائية بسيط وثابت (نفس النتيجة على الجهازين).
class Lcg {
  Lcg(int seed) : _s = seed & 0x7fffffff;

  int _s;

  int _next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s;
  }

  double nextDouble() => (_next() >> 8) / 8388608.0;

  double range(double a, double b) => a + (b - a) * nextDouble();

  int rangeInt(int a, int b) {
    final int v = a + (nextDouble() * (b - a + 1)).floor();
    return v > b ? b : v;
  }
}

class EnemySpawn {
  const EnemySpawn(this.x, this.kind);
  final double x;
  final int kind;
}

class Level {
  Level({
    required this.index,
    required this.name,
    required this.width,
    required this.solids,
    required this.spikes,
    required this.spawns,
    required this.playerSpawnX,
    required this.hue,
    required this.boss,
    required this.isArena,
  });

  static const double groundY = 300;
  static const int campaignCount = 20;
  static const int arenaCount = 6;

  final int index;
  final String name;
  final double width;
  final List<Rect> solids;
  final List<Rect> spikes;
  final List<EnemySpawn> spawns;
  final List<double> playerSpawnX;
  final double hue;
  final bool boss;
  final bool isArena;

  static const List<String> _names = <String>[
    'الغابة المظلمة',
    'الزقاق المهجور',
    'المقبرة القديمة',
    'جسر الأشباح',
    'قلعة الظلال',
    'المستنقع الأسود',
    'الكهف الأحمر',
    'المصنع المهجور',
    'برج الصمت',
    'ساحة الغضب',
    'الصحراء الباردة',
    'الميناء الغارق',
    'المتاهة',
    'المعبد المنسي',
    'قمة العاصفة',
    'سجن الأرواح',
    'وادي الرماد',
    'أنفاق الظلام',
    'بوابة الكابوس',
    'ملك الكوابيس',
  ];

  /// يبحث عن مكان خالٍ من العقبات لظهور مقاتل.
  static double clearX(double x, List<Rect> solids, double width) {
    double px = x;
    for (int i = 0; i < 20; i++) {
      final Rect body = Rect.fromLTWH(px - 30, groundY - 90, 60, 88);
      bool hit = false;
      for (final Rect s in solids) {
        if (s.top >= groundY) {
          continue;
        }
        if (body.overlaps(s)) {
          hit = true;
          break;
        }
      }
      if (!hit) {
        break;
      }
      px += 50;
    }
    if (px > width - 60) {
      px = width - 60;
    }
    return px;
  }

  static Level campaign(int index) {
    final int i = index < 0 ? 0 : (index > campaignCount - 1 ? campaignCount - 1 : index);
    final Lcg r = Lcg(7000 + i * 7919);
    final double width = 1800.0 + i * 150.0;
    final List<Rect> solids = <Rect>[
      Rect.fromLTWH(-400, groundY, width + 800, 220),
    ];
    final List<Rect> spikes = <Rect>[];

    double x = 420;
    while (x < width - 450) {
      final int t = r.rangeInt(0, 5);
      if (t == 0) {
        solids.add(Rect.fromLTWH(x, groundY - 40, 40, 40));
      } else if (t == 1) {
        solids.add(Rect.fromLTWH(x, groundY - 40, 40, 40));
        solids.add(Rect.fromLTWH(x + 40, groundY - 80, 40, 80));
      } else if (t == 2) {
        solids.add(Rect.fromLTWH(x, groundY - 70, 26, 70));
      } else if (t == 3) {
        final double pw = r.range(120, 200);
        final double ph = r.range(102, 114);
        solids.add(Rect.fromLTWH(x, groundY - ph, pw, 16));
      } else if (t == 4 && i >= 2) {
        spikes.add(Rect.fromLTWH(x, groundY - 14, 64, 14));
      } else {
        solids.add(Rect.fromLTWH(x, groundY - 40, 40, 40));
        solids.add(Rect.fromLTWH(x + 90, groundY - 40, 40, 40));
      }
      x += r.range(240, 380);
    }

    final bool boss = i % 5 == 4;
    int count = 3 + (i * 0.55).floor();
    if (count > 13) {
      count = 13;
    }
    if (boss) {
      count -= 1;
    }
    final List<EnemySpawn> spawns = <EnemySpawn>[];
    final double span = width - 1000;
    for (int k = 0; k < count; k++) {
      double ex = 650 + k * (span / count) + r.range(-50, 50);
      ex = clearX(ex, solids, width);
      spawns.add(EnemySpawn(ex, 1));
    }
    if (boss) {
      spawns.add(EnemySpawn(clearX(width - 260, solids, width), 2));
    }

    return Level(
      index: i,
      name: _names[i],
      width: width,
      solids: solids,
      spikes: spikes,
      spawns: spawns,
      playerSpawnX: <double>[70, 115, 160, 205, 250, 295],
      hue: (i * 37.0) % 360.0,
      boss: boss,
      isArena: false,
    );
  }

  static Level arena(int index) {
    final int i = index < 0 ? 0 : (index > arenaCount - 1 ? arenaCount - 1 : index);
    final double width = 1200.0 + (i % 3) * 200.0;
    final List<Rect> solids = <Rect>[
      Rect.fromLTWH(-400, groundY, width + 800, 220),
    ];
    final List<Rect> spikes = <Rect>[];
    final double mid = width / 2;

    // منصتان متماثلتان
    solids.add(Rect.fromLTWH(width * 0.28 - 70, groundY - 108, 140, 16));
    solids.add(Rect.fromLTWH(width * 0.72 - 70, groundY - 108, 140, 16));
    // صندوقان في المنتصف
    solids.add(Rect.fromLTWH(mid - 20, groundY - 40, 40, 40));
    if (i % 2 == 1) {
      solids.add(Rect.fromLTWH(mid - 60, groundY - 40, 40, 40));
      solids.add(Rect.fromLTWH(mid + 20, groundY - 40, 40, 40));
    }
    if (i >= 3) {
      spikes.add(Rect.fromLTWH(mid - 150, groundY - 14, 60, 14));
      spikes.add(Rect.fromLTWH(mid + 90, groundY - 14, 60, 14));
    }

    return Level(
      index: i,
      name: 'الحلبة ${i + 1}',
      width: width,
      solids: solids,
      spikes: spikes,
      spawns: const <EnemySpawn>[],
      playerSpawnX: <double>[180, width - 180, 260, width - 260, 340, width - 340],
      hue: (200.0 + i * 55.0) % 360.0,
      boss: false,
      isArena: true,
    );
  }
}
