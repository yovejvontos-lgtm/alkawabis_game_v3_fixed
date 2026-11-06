import 'dart:math';

import 'package:flutter/material.dart';

import 'fighter.dart';
import 'level.dart';
import 'profile.dart';
import 'stickman.dart';
import 'world.dart';

class Spark {
  Spark(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color)
      : maxLife = life;

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
}

class _Anim {
  _Anim(this.pose);

  Pose pose;
  double phase = 0;
}

/// حالة العرض المحلية: الكاميرا والشرارات وتنعيم الوضعيات (مؤثرات بصرية فقط).
class RenderState extends ChangeNotifier {
  double camX = 0;
  bool camInit = false;
  double viewW = 640;
  int lastHitSeq = 0;
  double shake = 0;
  final List<Spark> sparks = <Spark>[];
  final Map<int, _Anim> anims = <int, _Anim>{};
  final Random _r = Random();

  void reset() {
    camX = 0;
    camInit = false;
    lastHitSeq = 0;
    shake = 0;
    sparks.clear();
    anims.clear();
  }

  void update(GameWorld w, double dt, int focusIndex) {
    for (final List<double> h in w.recentHits) {
      final int seq = h[0].toInt();
      if (seq > lastHitSeq) {
        lastHitSeq = seq;
        _burst(h[1], h[2], h[3].toInt());
      }
    }
    for (int i = sparks.length - 1; i >= 0; i--) {
      final Spark s = sparks[i];
      s.life -= dt;
      if (s.life <= 0) {
        sparks.removeAt(i);
        continue;
      }
      s.vy += 700 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    if (shake > 0) {
      shake -= dt * 20;
      if (shake < 0) {
        shake = 0;
      }
    }

    // تنعيم الوضعيات: انتقال ناعم بين الحركات
    final double k = 1 - exp(-dt * 30);
    for (final Fighter f in w.players) {
      _animate(f, w.time, dt, k);
    }
    for (final Fighter f in w.enemies) {
      _animate(f, w.time, dt, k);
    }

    // الكاميرا تتبع اللاعب المحلي بنعومة
    double target = 0;
    if (focusIndex >= 0 && focusIndex < w.players.length) {
      target = w.players[focusIndex].drawX(w.alpha) - viewW / 2;
    }
    final double maxCam = max(0.0, w.level.width - viewW);
    if (target < 0) {
      target = 0;
    }
    if (target > maxCam) {
      target = maxCam;
    }
    if (!camInit) {
      camX = target;
      camInit = true;
    } else {
      camX += (target - camX) * (1 - exp(-dt * 9));
    }
  }

  void _animate(Fighter f, double worldTime, double dt, double k) {
    _Anim? a = anims[f.id];
    if (a == null) {
      a = _Anim(poseFor(f, worldTime, 0));
      anims[f.id] = a;
    }
    if (f.state == FState.run) {
      double sp = f.speed > 0 ? f.vx.abs() / f.speed : 1.0;
      if (sp > 1.3) {
        sp = 1.3;
      }
      a.phase += dt * 14 * sp;
    }
    final Pose target = poseFor(f, worldTime, a.phase);
    final double spin = target.spin;
    final Pose blended = Pose.lerp(a.pose, target, k);
    blended.spin = spin;
    a.pose = blended;
  }

  void _burst(double x, double y, int big) {
    final int n = big == 2 ? 24 : (big == 1 ? 16 : 11);
    for (int i = 0; i < n; i++) {
      final double a = _r.nextDouble() * 2 * pi;
      final double sp = 80 + _r.nextDouble() * (big == 2 ? 320 : 220);
      // رذاذ دم أحمر مع شرارات الضربات، أوضح عند الضربات القوية.
      final Color c = _r.nextInt(100) < 58
          ? const Color(0xFFE60026)
          : (_r.nextBool() ? const Color(0xFFFFEB3B) : const Color(0xFFFFFFFF));
      sparks.add(
        Spark(
          x,
          y,
          cos(a) * sp,
          sin(a) * sp - 60,
          0.25 + _r.nextDouble() * 0.25,
          2.0 + _r.nextDouble() * 2.0,
          c,
        ),
      );
    }
    if (big >= 1) {
      final double s = big == 2 ? 7.0 : 3.5;
      if (s > shake) {
        shake = s;
      }
    }
  }

  void repaintNow() {
    notifyListeners();
  }
}

class GamePainter extends CustomPainter {
  GamePainter({
    required this.world,
    required this.rs,
    required this.focusIndex,
  }) : super(repaint: rs);

  final GameWorld world;
  final RenderState rs;
  final int focusIndex;

  static const List<Color> playerColors = <Color>[
    Color(0xFF40C4FF),
    Color(0xFFFF9100),
    Color(0xFF69F0AE),
    Color(0xFFFF4081),
    Color(0xFFFFEB3B),
    Color(0xFFB388FF),
  ];
  static const List<Color> teamColors = <Color>[
    Color(0xFF40C4FF),
    Color(0xFFFF5252),
  ];
  static const Color enemyColor = Color(0xFFFF1744);
  static const Color bossColor = Color(0xFFD500F9);

  static final Map<String, TextPainter> _cache = <String, TextPainter>{};

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  Color _accent(Fighter f) {
    if (f.kind == 2) {
      return bossColor;
    }
    if (f.kind == 1) {
      return enemyColor;
    }
    if (world.mode == GameMode.teams) {
      return teamColors[f.team == 1 ? 1 : 0];
    }
    return playerColors[f.id % playerColors.length];
  }

  TextPainter _tp(String text, double size, Color color, FontWeight weight) {
    final String key = '$text|$size|${color.value}|${weight.index}';
    final TextPainter? hit = _cache[key];
    if (hit != null) {
      return hit;
    }
    if (_cache.length > 120) {
      _cache.clear();
    }
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    _cache[key] = tp;
    return tp;
  }

  void _text(
    Canvas c,
    String text,
    double x,
    double y,
    double size,
    Color color, {
    FontWeight weight = FontWeight.normal,
    bool center = false,
  }) {
    final TextPainter tp = _tp(text, size, color, weight);
    c.save();
    c.translate(center ? x - tp.width / 2 : x, y);
    tp.paint(c, Offset.zero);
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.height / 360.0;
    final double viewW = size.width / scale;
    final Level lv = world.level;
    rs.viewW = viewW;
    final double cam = rs.camX;

    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(Rect.fromLTWH(0, 0, viewW, 360));

    _drawBackground(canvas, viewW, cam, lv);

    canvas.save();
    double sx = 0;
    double sy = 0;
    if (rs.shake > 0) {
      sx = sin(world.time * 80) * rs.shake * 0.5;
      sy = cos(world.time * 90) * rs.shake * 0.5;
    }
    canvas.translate(-cam + sx, sy);

    for (final Rect s in lv.solids) {
      if (s.right < cam - 20 || s.left > cam + viewW + 20) {
        continue;
      }
      _drawSolid(canvas, s, lv);
    }
    for (final Rect s in lv.spikes) {
      if (s.right < cam - 20 || s.left > cam + viewW + 20) {
        continue;
      }
      _drawSpikes(canvas, s);
    }

    for (final Fighter e in world.enemies) {
      if (e.isDead) {
        _drawFighter(canvas, e);
      }
    }
    for (final Fighter e in world.enemies) {
      if (!e.isDead) {
        _drawFighter(canvas, e);
      }
    }
    for (final Fighter p in world.players) {
      if (p.isDead) {
        _drawFighter(canvas, p);
      }
    }
    for (final Fighter p in world.players) {
      if (!p.isDead && p.id != focusIndex) {
        _drawFighter(canvas, p);
      }
    }
    for (final Fighter p in world.players) {
      if (!p.isDead && p.id == focusIndex) {
        _drawFighter(canvas, p);
      }
    }

    // علامة اللاعب المحلي
    if (focusIndex >= 0 && focusIndex < world.players.length) {
      final Fighter me = world.players[focusIndex];
      if (!me.isDead) {
        final double mx = me.drawX(world.alpha);
        final double my = me.drawY(world.alpha);
        final Path tri = Path()
          ..moveTo(mx - 6, my - me.h - 22)
          ..lineTo(mx + 6, my - me.h - 22)
          ..lineTo(mx, my - me.h - 13)
          ..close();
        _fill.color = _accent(me);
        canvas.drawPath(tri, _fill);
      }
    }

    // الشرارات
    for (final Spark s in rs.sparks) {
      final double a = s.life / s.maxLife;
      _stroke
        ..color = s.color.withOpacity(a < 0 ? 0 : (a > 1 ? 1 : a))
        ..strokeWidth = s.size
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(s.x, s.y),
        Offset(s.x - s.vx * 0.03, s.y - s.vy * 0.03),
        _stroke,
      );
    }

    canvas.restore();

    _drawHud(canvas, viewW, cam);
    canvas.restore();
  }

  // ------------------------------------------------------------------
  //  الخلفية والعقبات
  // ------------------------------------------------------------------

  void _drawBackground(Canvas c, double viewW, double cam, Level lv) {
    final Color top = HSLColor.fromAHSL(1, lv.hue, 0.55, 0.12).toColor();
    final Color bot =
        HSLColor.fromAHSL(1, (lv.hue + 25) % 360, 0.5, 0.28).toColor();
    final Rect r = Rect.fromLTWH(0, 0, viewW, 360);
    final Paint bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[top, bot],
      ).createShader(r);
    c.drawRect(r, bg);

    _fill.color = const Color(0x33FFFFFF);
    c.drawCircle(Offset(viewW * 0.78 - cam * 0.02, 64), 26, _fill);

    for (int layer = 0; layer < 2; layer++) {
      final double par = layer == 0 ? 0.12 : 0.3;
      final double off = cam * par;
      final Path p = Path()..moveTo(0, 360);
      for (double x = 0; x <= viewW + 40; x += 40) {
        final double wx = x + off;
        final double hgt = (layer == 0 ? 130.0 : 85.0) +
            sin(wx * 0.012 + layer * 2 + lv.hue) * 35 +
            sin(wx * 0.031) * 14;
        p.lineTo(x, 300 - hgt);
      }
      p.lineTo(viewW + 40, 360);
      p.close();
      _fill.color = Color.fromRGBO(0, 0, 0, layer == 0 ? 0.28 : 0.42);
      c.drawPath(p, _fill);
    }
  }

  void _drawSolid(Canvas c, Rect s, Level lv) {
    if (s.top >= Level.groundY) {
      _fill.color = HSLColor.fromAHSL(1, lv.hue, 0.3, 0.09).toColor();
      c.drawRect(s, _fill);
      _stroke
        ..color = HSLColor.fromAHSL(1, lv.hue, 0.4, 0.28).toColor()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.butt;
      c.drawLine(Offset(s.left, s.top), Offset(s.right, s.top), _stroke);
      return;
    }
    if (s.height <= 20) {
      _fill.color = HSLColor.fromAHSL(1, lv.hue, 0.25, 0.20).toColor();
      c.drawRect(s, _fill);
      _stroke
        ..color = HSLColor.fromAHSL(1, lv.hue, 0.4, 0.38).toColor()
        ..strokeWidth = 2;
      c.drawLine(Offset(s.left, s.top), Offset(s.right, s.top), _stroke);
      return;
    }
    final bool wall = s.width < 30;
    _fill.color = wall ? const Color(0xFF3A3A4A) : const Color(0xFF4E342E);
    c.drawRect(s, _fill);
    _stroke
      ..color = wall ? const Color(0xFF6A6A80) : const Color(0xFF8D6E63)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;
    c.drawRect(s.deflate(1), _stroke);
    if (wall) {
      for (double y = s.top + 14; y < s.bottom; y += 14) {
        c.drawLine(Offset(s.left, y), Offset(s.right, y), _stroke);
      }
    } else {
      c.drawLine(s.topLeft, s.bottomRight, _stroke);
      c.drawLine(s.topRight, s.bottomLeft, _stroke);
    }
  }

  void _drawSpikes(Canvas c, Rect s) {
    final Path p = Path();
    double x = s.left;
    while (x < s.right - 1) {
      final double x2 = min(x + 16, s.right);
      p.moveTo(x, s.bottom);
      p.lineTo((x + x2) / 2, s.top);
      p.lineTo(x2, s.bottom);
      p.close();
      x += 16;
    }
    _fill.color = const Color(0xFFCFD8DC);
    c.drawPath(p, _fill);
    _stroke
      ..color = const Color(0xFFB71C1C)
      ..strokeWidth = 1.5;
    c.drawPath(p, _stroke);
  }

  // ------------------------------------------------------------------
  //  المقاتلون
  // ------------------------------------------------------------------

  void _drawFighter(Canvas canvas, Fighter f) {
    if (f.isDead && f.kind != 0 && f.stateTime > 4.0) {
      return;
    }
    final Color accent = _accent(f);
    final double s = f.h / 80.0;
    final double fx = f.drawX(world.alpha);
    final double fy = f.drawY(world.alpha);

    if (f.onGround && !f.isDead) {
      _fill.color = const Color(0x55000000);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(fx, fy + 1),
          width: 36 * s,
          height: 7 * s,
        ),
        _fill,
      );
    }

    final Pose pose = rs.anims[f.id]?.pose ?? poseFor(f, world.time, 0);

    canvas.save();
    canvas.translate(fx, fy);
    canvas.scale(f.facing * s, s);
    if (f.isDead) {
      final double fall = f.stateTime / 0.45 > 1 ? 1.0 : f.stateTime / 0.45;
      canvas.rotate(-pi / 2 * fall);
      canvas.translate(0, -3);
    }
    drawStickman(canvas, pose, accent, f.profile);
    canvas.restore();

    // اسم اللاعب فوق رأسه
    final PlayerProfile? prof = f.profile;
    if (prof != null && !f.isDead) {
      _text(canvas, prof.name, fx, fy - f.h - 36, 10, accent,
          weight: FontWeight.bold, center: true);
    }

    // شريط صحة العدو
    if (f.kind != 0 && !f.isDead && f.hp < f.maxHp) {
      final double bw = 36 * s;
      final double bx = fx - bw / 2;
      final double by = fy - f.h - 16 * s;
      _fill.color = const Color(0x88000000);
      canvas.drawRect(Rect.fromLTWH(bx, by, bw, 4), _fill);
      _fill.color = accent;
      canvas.drawRect(Rect.fromLTWH(bx, by, bw * (f.hp / f.maxHp), 4), _fill);
    }
  }

  // ------------------------------------------------------------------
  //  الواجهة العلوية
  // ------------------------------------------------------------------

  void _bar(
    Canvas c,
    double x,
    double y,
    double w,
    double frac,
    Color color,
    String label,
  ) {
    final double f = frac < 0 ? 0 : (frac > 1 ? 1 : frac);
    final RRect back = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, 14),
      const Radius.circular(7),
    );
    _fill.color = const Color(0x99000000);
    c.drawRRect(back, _fill);
    if (f > 0) {
      _fill.color = color;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w * f, 14),
          const Radius.circular(7),
        ),
        _fill,
      );
    }
    _stroke
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1;
    c.drawRRect(back, _stroke);
    _text(c, label, x + 8, y + 1, 10, Colors.white, weight: FontWeight.bold);
  }

  void _drawHud(Canvas c, double viewW, double cam) {
    final List<Fighter> ps = world.players;
    final List<Fighter> left = <Fighter>[];
    final List<Fighter> right = <Fighter>[];
    if (world.mode == GameMode.teams) {
      for (final Fighter p in ps) {
        if (p.team == 0) {
          left.add(p);
        } else {
          right.add(p);
        }
      }
    } else {
      final int half = (ps.length + 1) ~/ 2;
      for (int i = 0; i < ps.length; i++) {
        if (i < half) {
          left.add(ps[i]);
        } else {
          right.add(ps[i]);
        }
      }
    }
    for (int i = 0; i < left.length; i++) {
      final Fighter f = left[i];
      _bar(c, 14, 8.0 + i * 17, 120, f.hp / f.maxHp, _accent(f),
          f.profile?.name ?? 'لاعب');
    }
    for (int i = 0; i < right.length; i++) {
      final Fighter f = right[i];
      _bar(c, viewW - 134, 8.0 + i * 17, 120, f.hp / f.maxHp, _accent(f),
          f.profile?.name ?? 'لاعب');
    }

    final String title = world.level.isArena
        ? world.level.name
        : 'المرحلة ${world.level.index + 1}';
    _text(c, title, viewW / 2, 6, 12, Colors.white70,
        weight: FontWeight.bold, center: true);
    if (world.mode == GameMode.coop) {
      _text(c, 'الأعداء: ${world.enemiesAlive}', viewW / 2, 22, 12,
          const Color(0xFFFF8A80),
          weight: FontWeight.bold, center: true);
    }

    // سهم يدل على أقرب عدو خارج الشاشة
    if (world.mode == GameMode.coop &&
        focusIndex >= 0 &&
        focusIndex < ps.length) {
      final Fighter me = ps[focusIndex];
      Fighter? near;
      double bestD = 1e9;
      for (final Fighter e in world.enemies) {
        if (e.isDead) {
          continue;
        }
        final double d = (e.x - me.x).abs();
        if (d < bestD) {
          bestD = d;
          near = e;
        }
      }
      if (near != null) {
        final bool lf = near.x < cam - 10;
        final bool rt = near.x > cam + viewW + 10;
        if (lf || rt) {
          final Path tri = Path();
          if (lf) {
            tri
              ..moveTo(10, 180)
              ..lineTo(28, 168)
              ..lineTo(28, 192)
              ..close();
          } else {
            tri
              ..moveTo(viewW - 10, 180)
              ..lineTo(viewW - 28, 168)
              ..lineTo(viewW - 28, 192)
              ..close();
          }
          _fill.color = const Color(0xAAFFEB3B);
          c.drawPath(tri, _fill);
        }
      }
    }

    // عنوان المرحلة في البداية
    if (world.time < 2.4) {
      final double a = world.time < 1.8 ? 1.0 : (2.4 - world.time) / 0.6;
      final TextPainter big = TextPainter(
        text: TextSpan(
          text: world.level.name,
          style: TextStyle(
            color: Colors.white.withOpacity(a),
            fontSize: 34,
            fontWeight: FontWeight.bold,
            shadows: <Shadow>[
              Shadow(color: Colors.black.withOpacity(a), blurRadius: 8),
            ],
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      big.paint(c, Offset(viewW / 2 - big.width / 2, 110));
      String sub = 'اهزم كل الأعداء';
      if (world.level.isArena) {
        sub = world.mode == GameMode.teams ? 'فريق ضد فريق' : 'كل لاعب ضد الجميع';
      } else if (world.level.boss) {
        sub = 'زعيم المرحلة';
      }
      final TextPainter small = TextPainter(
        text: TextSpan(
          text: sub,
          style: TextStyle(
            color: const Color(0xFFFFCC80).withOpacity(a),
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      small.paint(c, Offset(viewW / 2 - small.width / 2, 156));
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.world != world || oldDelegate.focusIndex != focusIndex;
  }
}
