import 'dart:math';

import 'package:flutter/material.dart';

import 'fighter.dart';
import 'profile.dart';

double _c01(double v) {
  if (v < 0) {
    return 0;
  }
  if (v > 1) {
    return 1;
  }
  return v;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// وضعية الهيكل: زوايا المفاصل (من الأسفل، والموجب للأمام).
class Pose {
  double lean = 0.1;
  double fa1 = 0.5;
  double fa2 = 2.1;
  double ba1 = 0.1;
  double ba2 = 2.0;
  double ft1 = 0.35;
  double ft2 = 0.05;
  double bt1 = -0.3;
  double bt2 = -0.05;
  double spin = 0;
  double lift = 0;

  static Pose lerp(Pose a, Pose b, double t) {
    final Pose p = Pose();
    p.lean = _lerp(a.lean, b.lean, t);
    p.fa1 = _lerp(a.fa1, b.fa1, t);
    p.fa2 = _lerp(a.fa2, b.fa2, t);
    p.ba1 = _lerp(a.ba1, b.ba1, t);
    p.ba2 = _lerp(a.ba2, b.ba2, t);
    p.ft1 = _lerp(a.ft1, b.ft1, t);
    p.ft2 = _lerp(a.ft2, b.ft2, t);
    p.bt1 = _lerp(a.bt1, b.bt1, t);
    p.bt2 = _lerp(a.bt2, b.bt2, t);
    p.spin = _lerp(a.spin, b.spin, t);
    p.lift = _lerp(a.lift, b.lift, t);
    return p;
  }
}

/// يحسب الوضعية المستهدفة حسب حالة المقاتل (والتنعيم يتم خارجياً).
Pose poseFor(Fighter f, double worldTime, double runPhase) {
  final Pose p = Pose();
  final double t = f.stateTime;
  switch (f.state) {
    case FState.idle:
      {
        final double b = 0.5 + 0.5 * sin(worldTime * 4 + f.id);
        p.lean = 0.10 + 0.03 * b;
        p.fa1 = 0.5;
        p.fa2 = 2.15 + 0.1 * b;
        p.ba1 = 0.1;
        p.ba2 = 2.0;
        p.ft1 = 0.35;
        p.ft2 = 0.05;
        p.bt1 = -0.3;
        p.bt2 = -0.05;
        return p;
      }
    case FState.run:
      {
        final double ph = runPhase;
        final double s1 = sin(ph);
        final double s2 = sin(ph + pi);
        p.lean = 0.28;
        p.ft1 = 0.95 * s1;
        p.ft2 = p.ft1 - (0.25 + 0.75 * (0.5 + 0.5 * cos(ph)));
        p.bt1 = 0.95 * s2;
        p.bt2 = p.bt1 - (0.25 + 0.75 * (0.5 + 0.5 * cos(ph + pi)));
        p.fa1 = -0.9 * s1 + 0.2;
        p.fa2 = p.fa1 + 1.4;
        p.ba1 = -0.9 * s2 + 0.2;
        p.ba2 = p.ba1 + 1.4;
        return p;
      }
    case FState.jump:
      {
        if (f.vy < 0) {
          p.lean = 0.1;
          p.ft1 = 1.0;
          p.ft2 = 0.1;
          p.bt1 = 0.2;
          p.bt2 = -0.7;
          p.fa1 = 2.3;
          p.fa2 = 2.6;
          p.ba1 = 1.9;
          p.ba2 = 2.2;
        } else {
          p.lean = 0.05;
          p.ft1 = 0.5;
          p.ft2 = 0.3;
          p.bt1 = -0.4;
          p.bt2 = -0.5;
          p.fa1 = 1.4;
          p.fa2 = 1.6;
          p.ba1 = -1.2;
          p.ba2 = -1.4;
        }
        return p;
      }
    case FState.punch:
      {
        final int step = f.comboStep;
        if (step == 0) {
          // لكمة مستقيمة
          final double ext = sin(pi * _c01((t / 0.28 - 0.1) / 0.7));
          p.lean = 0.12 + 0.25 * ext;
          p.fa1 = _lerp(0.2, 1.5, ext);
          p.fa2 = _lerp(2.4, 1.57, ext);
          p.ba1 = 0.1;
          p.ba2 = 2.3;
          p.ft1 = 0.6;
          p.ft2 = 0.15;
          p.bt1 = -0.5;
          p.bt2 = -0.1;
          return p;
        }
        if (step == 1) {
          // لكمة بالذراع الخلفية
          final double ext = sin(pi * _c01((t / 0.30 - 0.1) / 0.7));
          p.lean = 0.15 + 0.3 * ext;
          p.ba1 = _lerp(0.1, 1.5, ext);
          p.ba2 = _lerp(2.3, 1.55, ext);
          p.fa1 = 0.6;
          p.fa2 = 2.2;
          p.ft1 = 0.7;
          p.ft2 = 0.2;
          p.bt1 = -0.6;
          p.bt2 = -0.2;
          return p;
        }
        // أبركت: لكمة صاعدة
        final double ext = sin(pi * _c01((t / 0.42 - 0.12) / 0.65));
        p.lean = 0.35 - 0.4 * ext;
        p.fa1 = _lerp(0.4, 2.3, ext);
        p.fa2 = _lerp(0.9, 2.7, ext);
        p.ba1 = 0.1;
        p.ba2 = 2.2;
        p.lift = 5 * ext;
        p.ft1 = 0.5;
        p.ft2 = 0.1;
        p.bt1 = -0.4;
        p.bt2 = -0.05;
        return p;
      }
    case FState.kick:
      {
        final int step = f.comboStep;
        if (step == 0) {
          // ركلة أمامية
          final double ext = sin(pi * _c01((t / 0.40 - 0.1) / 0.7));
          p.lean = -0.1 - 0.2 * ext;
          p.ft1 = _lerp(0.3, 1.45, ext);
          p.ft2 = _lerp(-0.1, 1.45, ext);
          p.bt1 = -0.1;
          p.bt2 = -0.05;
          p.fa1 = 0.6;
          p.fa2 = 2.2;
          p.ba1 = -0.8;
          p.ba2 = -0.4;
          return p;
        }
        if (step == 1) {
          // ركلة دائرية عالية
          final double ext = sin(pi * _c01((t / 0.45 - 0.1) / 0.7));
          p.lean = -0.25 * ext;
          p.ft1 = _lerp(0.2, 1.75, ext);
          p.ft2 = _lerp(-0.2, 2.0, ext);
          p.bt1 = -0.1;
          p.bt2 = -0.05;
          p.fa1 = 0.9;
          p.fa2 = 1.4;
          p.ba1 = -1.0;
          p.ba2 = -0.8;
          return p;
        }
        // ركلة طائرة
        final double ext = sin(pi * _c01((t / 0.58 - 0.1) / 0.75));
        p.lean = -0.5 * ext;
        p.lift = 14 * ext;
        p.ft1 = _lerp(0.4, 1.5, ext);
        p.ft2 = _lerp(0.3, 1.5, ext);
        p.bt1 = _lerp(-0.1, 0.4, ext);
        p.bt2 = _lerp(-0.05, -0.9, ext);
        p.fa1 = -0.9;
        p.fa2 = -0.6;
        p.ba1 = -1.3;
        p.ba2 = -1.0;
        return p;
      }
    case FState.special:
      {
        final Pose idle = Pose();
        idle.lean = 0.1;
        final Pose sp = Pose();
        sp.lean = 0;
        sp.fa1 = 1.3;
        sp.fa2 = 1.3;
        sp.ba1 = -1.3;
        sp.ba2 = -1.3;
        sp.ft1 = 1.5;
        sp.ft2 = 1.5;
        sp.bt1 = -1.5;
        sp.bt2 = -1.5;
        sp.lift = 44;
        sp.spin = 2 * pi * _c01((t - 0.08) / 0.5);
        final double w = min(_c01(t / 0.1), _c01((0.7 - t) / 0.1));
        return Pose.lerp(idle, sp, w);
      }
    case FState.hurt:
      {
        p.lean = -0.45;
        p.fa1 = 0.9;
        p.fa2 = 1.0;
        p.ba1 = -0.7;
        p.ba2 = -0.5;
        p.ft1 = 0.5;
        p.ft2 = 0.2;
        p.bt1 = -0.5;
        p.bt2 = -0.3;
        return p;
      }
    case FState.dead:
      {
        p.lean = 0;
        p.fa1 = 0.3;
        p.fa2 = 0.3;
        p.ba1 = -0.3;
        p.ba2 = -0.3;
        p.ft1 = 0.12;
        p.ft2 = 0.12;
        p.bt1 = -0.12;
        p.bt2 = -0.12;
        return p;
      }
  }
}

// ----------------------------------------------------------------------
//  الرسم
// ----------------------------------------------------------------------

final Paint _glow = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeWidth = 10;
final Paint _body = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeWidth = 6
  ..color = const Color(0xFF000000);
final Paint _fillP = Paint()..style = PaintingStyle.fill;
final Paint _tubeP = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;
final Paint _ringP = Paint()..style = PaintingStyle.stroke;

class _J {
  _J({
    required this.neck,
    required this.head,
    required this.sh,
    required this.fe,
    required this.fh,
    required this.be,
    required this.bh,
    required this.fk,
    required this.fa,
    required this.ff,
    required this.bk,
    required this.ba,
    required this.bf,
    required this.perp,
  });

  final Offset neck;
  final Offset head;
  final Offset sh;
  final Offset fe;
  final Offset fh;
  final Offset be;
  final Offset bh;
  final Offset fk;
  final Offset fa;
  final Offset ff;
  final Offset bk;
  final Offset ba;
  final Offset bf;
  final Offset perp;
}

int _b(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

Color _shade(Color c, double f) {
  return Color.fromARGB(255, _b(c.red * f), _b(c.green * f), _b(c.blue * f));
}

Color _light(Color c, double t) {
  return Color.lerp(c, const Color(0xFFFFFFFF), t)!;
}

Offset _mid(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

void _tube(Canvas c, Offset a, Offset b, Color col, double w) {
  _tubeP
    ..color = col
    ..strokeWidth = w;
  c.drawLine(a, b, _tubeP);
}

void _dot(Canvas c, Offset o, double r, Color col) {
  _fillP.color = col;
  c.drawCircle(o, r, _fillP);
}

void _poly(Canvas c, List<Offset> pts, Color col) {
  final Path path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (int i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx, pts[i].dy);
  }
  path.close();
  _fillP.color = col;
  c.drawPath(path, _fillP);
}

void _legs(Canvas c, _J j, Color col, double w) {
  _tube(c, Offset.zero, j.bk, col, w);
  _tube(c, j.bk, j.ba, col, w);
  _tube(c, Offset.zero, j.fk, col, w);
  _tube(c, j.fk, j.fa, col, w);
}

void _fullArms(Canvas c, _J j, Color col, double w) {
  _tube(c, j.sh, j.be, col, w);
  _tube(c, j.be, j.bh, col, w);
  _tube(c, j.sh, j.fe, col, w);
  _tube(c, j.fe, j.fh, col, w);
}

// ---------------- أزياء علوية ----------------

void _topBack(Canvas c, _J j, int style, Color col) {
  if (style == 4) {
    // وشاح ينفلت خلف الرقبة
    _tube(c, j.neck, j.neck + const Offset(-13, 6), col, 4);
    _tube(c, j.neck + const Offset(-13, 6), j.neck + const Offset(-21, 2), col, 3.4);
  }
}

void _topFront(Canvas c, _J j, int style, Color col) {
  final Color d = _shade(col, 0.55);
  final Color l = _light(col, 0.5);
  const Offset o = Offset.zero;
  switch (style) {
    case 0:
      _tube(c, o, j.sh, col, 9);
      _tube(c, j.sh, j.fe, col, 8);
      _tube(c, j.sh, j.be, col, 8);
      break;
    case 1:
      _tube(c, o, j.sh, d, 9.5);
      _fullArms(c, j, d, 8);
      _tube(c, o, j.sh, l, 1.6);
      break;
    case 2:
      _tube(c, o, j.sh, col, 9.5);
      _fullArms(c, j, col, 8);
      _ringP
        ..color = col
        ..strokeWidth = 3.5;
      c.drawCircle(j.neck, 5.5, _ringP);
      final Offset pk = _mid(o, j.sh, 0.25);
      _tube(c, pk - j.perp * 3.5, pk + j.perp * 3.5, d, 2.4);
      break;
    case 3:
      const Color metal = Color(0xFFB0BEC5);
      _tube(c, o, j.sh, metal, 11);
      _tube(c, j.sh, j.fe, metal, 8);
      _tube(c, j.sh, j.be, metal, 8);
      _dot(c, j.sh, 5.2, col);
      _tube(c, _mid(o, j.sh, 0.2), _mid(o, j.sh, 0.8), col, 2.5);
      break;
    case 4:
      _tube(c, o, j.sh, d, 9.5);
      _fullArms(c, j, d, 8);
      final Offset wp = _mid(o, j.sh, 0.15);
      _tube(c, wp - j.perp * 5, wp + j.perp * 5, col, 3);
      break;
    case 5:
      _tube(c, o, j.sh, col, 9.5);
      _fullArms(c, j, col, 8.5);
      final Offset vm = _mid(o, j.sh, 0.45);
      _tube(c, j.neck + j.perp * 3, vm, d, 1.6);
      _tube(c, j.neck - j.perp * 3, vm, d, 1.6);
      final Offset bp = _mid(o, j.sh, 0.12);
      _tube(c, bp - j.perp * 5.5, bp + j.perp * 5.5, const Color(0xFF212121), 3.5);
      break;
    case 6:
      _tube(c, o, j.sh, col, 10);
      _tube(c, j.sh, j.fe, d, 8);
      _tube(c, j.sh, j.be, d, 8);
      final Offset pc = _mid(o, j.sh, 0.55);
      _tube(c, pc - j.perp * 3.5, pc - j.perp * 3.5 + const Offset(0, 3), d, 3);
      _tube(c, pc + j.perp * 3.5, pc + j.perp * 3.5 + const Offset(0, 3), d, 3);
      _tube(
        c,
        _mid(o, j.sh, 0.9) + j.perp * 3.5,
        _mid(o, j.sh, 0.1) - j.perp * 3.5,
        d,
        2,
      );
      break;
    case 7:
      _tube(c, o, j.sh, d, 10);
      _tube(c, const Offset(0, -2), const Offset(0, 15), d, 14);
      _fullArms(c, j, d, 8.5);
      break;
    case 8:
      _tube(c, o, j.sh, col, 9);
      _tube(c, _mid(o, j.sh, 0.2), _mid(o, j.sh, 0.8), _light(col, 0.7), 2);
      break;
    case 9:
      _poly(
        c,
        <Offset>[
          j.sh + const Offset(-6, 0),
          j.sh + const Offset(6, 0),
          const Offset(10, 22),
          const Offset(-10, 22),
        ],
        col,
      );
      _fullArms(c, j, d, 9.5);
      _dot(c, _mid(o, j.sh, 0.6), 2, _light(col, 0.8));
      break;
    default:
      break;
  }
}

// ---------------- أزياء سفلية ----------------

void _botFront(Canvas c, _J j, int style, Color col) {
  final Color d = _shade(col, 0.55);
  final Color l = _light(col, 0.5);
  const Offset o = Offset.zero;
  switch (style) {
    case 0:
      _legs(c, j, col, 8);
      break;
    case 1:
      _tube(c, o, _mid(o, j.fk, 0.85), col, 8.5);
      _tube(c, o, _mid(o, j.bk, 0.85), col, 8.5);
      break;
    case 2:
      _legs(c, j, d, 8);
      _dot(c, j.fk, 2, l);
      _dot(c, j.bk, 2, l);
      break;
    case 3:
      _legs(c, j, col, 7.5);
      _tube(c, _mid(j.fk, j.fa, 0.7), j.fa, l, 9);
      _tube(c, _mid(j.bk, j.ba, 0.7), j.ba, l, 9);
      break;
    case 4:
      _legs(c, j, col, 11);
      break;
    case 5:
      _legs(c, j, col, 8.5);
      _dot(c, j.fk, 4.2, d);
      _dot(c, j.bk, 4.2, d);
      _tube(c, _mid(o, j.fk, 0.35), _mid(o, j.fk, 0.6), d, 5);
      break;
    case 6:
      _poly(
        c,
        const <Offset>[
          Offset(-6, -1),
          Offset(6, -1),
          Offset(13, 15),
          Offset(-13, 15),
        ],
        col,
      );
      break;
    case 7:
      _legs(c, j, col, 8);
      _tube(c, const Offset(-6.5, -2), const Offset(6.5, -2), l, 3.2);
      break;
    case 8:
      _legs(c, j, col, 7.5);
      _tube(
        c,
        _mid(o, j.fk, 0.1) + const Offset(3.5, 0),
        _mid(o, j.fk, 0.95) + const Offset(3.5, 0),
        l,
        1.8,
      );
      _tube(
        c,
        _mid(o, j.bk, 0.1) + const Offset(3.5, 0),
        _mid(o, j.bk, 0.95) + const Offset(3.5, 0),
        l,
        1.8,
      );
      break;
    case 9:
      _tube(c, o, j.fk, col, 8);
      _tube(c, o, j.bk, col, 8);
      _tube(c, j.fk, j.fa, d, 9.5);
      _tube(c, j.bk, j.ba, d, 9.5);
      _tube(c, j.fa, j.ff, d, 8);
      _tube(c, j.ba, j.bf, d, 8);
      break;
    default:
      break;
  }
}

// ---------------- أزياء كاملة (مستوحاة، بلا شعارات) ----------------

void _fullBack(Canvas c, _J j, int style) {
  if (style == 0) {
    // عباءة خضراء خلف الظهر
    _poly(
      c,
      <Offset>[
        j.sh + const Offset(-1.5, -1),
        j.sh + const Offset(-17, 12),
        const Offset(-15, 24),
        const Offset(-3, 4),
      ],
      const Color(0xFF2E7D32),
    );
  } else if (style == 3) {
    // أذيال المعطف الداكن
    _poly(
      c,
      <Offset>[
        j.sh + const Offset(-2, 0),
        j.sh + const Offset(-10, 10),
        const Offset(-13, 24),
        const Offset(-2, 6),
      ],
      const Color(0xFF1A237E),
    );
  }
}

void _fullFront(Canvas c, _J j, int style) {
  const Offset o = Offset.zero;
  switch (style) {
    case 0:
      {
        const Color jacket = Color(0xFF795548);
        const Color strap = Color(0xFF4E342E);
        _legs(c, j, const Color(0xFFEEEEEE), 8);
        _tube(c, _mid(j.fk, j.fa, 0.55), j.fa, jacket, 8.5);
        _tube(c, _mid(j.bk, j.ba, 0.55), j.ba, jacket, 8.5);
        _tube(c, o, j.sh, jacket, 9.5);
        _fullArms(c, j, jacket, 8);
        final Offset a1 = _mid(o, j.sh, 0.2);
        final Offset a2 = _mid(o, j.sh, 0.85);
        _tube(c, a1 - j.perp * 4.5, a2 + j.perp * 4.5, strap, 1.8);
        _tube(c, a1 + j.perp * 4.5, a2 - j.perp * 4.5, strap, 1.8);
        final Offset t1 = _mid(o, j.fk, 0.5);
        _tube(c, t1 - j.perp * 4, t1 + j.perp * 4, strap, 2);
        final Offset t2 = _mid(o, j.bk, 0.5);
        _tube(c, t2 - j.perp * 4, t2 + j.perp * 4, strap, 2);
        break;
      }
    case 1:
      {
        const Color robe = Color(0xFFF5F5F5);
        _legs(c, j, const Color(0xFF37474F), 10.5);
        _tube(c, o, j.sh, robe, 10.5);
        _fullArms(c, j, robe, 9.5);
        _tube(
          c,
          j.neck,
          _mid(o, j.sh, 0.5) + j.perp * 2.5,
          const Color(0xFFE91E63),
          2.2,
        );
        final Offset s = _mid(o, j.sh, 0.1);
        _tube(c, s - j.perp * 6, s + j.perp * 6, const Color(0xFF212121), 4.5);
        break;
      }
    case 2:
      {
        _tube(c, o, _mid(o, j.fk, 0.85), const Color(0xFF1565C0), 9);
        _tube(c, o, _mid(o, j.bk, 0.85), const Color(0xFF1565C0), 9);
        _tube(c, j.fa, j.ff, const Color(0xFF8D6E63), 7);
        _tube(c, j.ba, j.bf, const Color(0xFF8D6E63), 7);
        _tube(c, o, j.sh, const Color(0xFFD32F2F), 9.5);
        final Offset s = _mid(o, j.sh, 0.1);
        _tube(c, s - j.perp * 5.5, s + j.perp * 5.5, const Color(0xFFFFD600), 3.5);
        break;
      }
    case 3:
      {
        const Color navy = Color(0xFF1A237E);
        const Color violet = Color(0xFF7C4DFF);
        _legs(c, j, const Color(0xFF0D1330), 8);
        _tube(c, o, j.sh, navy, 10);
        _tube(c, const Offset(0, -2), const Offset(0, 15), navy, 13);
        _fullArms(c, j, navy, 8.5);
        _tube(c, o, j.sh, violet, 1.6);
        _tube(c, _mid(j.fe, j.fh, 0.7), j.fh, violet, 9);
        _tube(c, _mid(j.be, j.bh, 0.7), j.bh, violet, 9);
        _dot(c, j.sh, 4.2, violet);
        break;
      }
    case 4:
      {
        const Color orange = Color(0xFFFB8C00);
        const Color blue = Color(0xFF1565C0);
        _legs(c, j, orange, 9);
        _tube(c, _mid(j.fk, j.fa, 0.5), j.fa, blue, 9);
        _tube(c, _mid(j.bk, j.ba, 0.5), j.ba, blue, 9);
        _tube(c, j.fa, j.ff, blue, 7.5);
        _tube(c, j.ba, j.bf, blue, 7.5);
        _tube(c, o, j.sh, orange, 10);
        _fullArms(c, j, orange, 8.5);
        _tube(c, _mid(j.fe, j.fh, 0.6), j.fh, blue, 9);
        _tube(c, _mid(j.be, j.bh, 0.6), j.bh, blue, 9);
        final Offset s = _mid(o, j.sh, 0.1);
        _tube(c, s - j.perp * 5.5, s + j.perp * 5.5, blue, 4);
        break;
      }
    default:
      break;
  }
}

/// يرسم الشخصية: رأس دائري أسود بالكامل، جسم، ذراعان، ساقان وقدمان.
/// اللون الأسود واحد، والهالة الملونة تميّز اللاعب، والزي يُرسم فوق الجسم.
void drawStickman(Canvas canvas, Pose p, Color accent, PlayerProfile? prof) {
  const double seg = 17.5;
  const double arm = 13.0;
  const double torso = 24.0;
  const double headR = 10.5;

  final double footF = seg * (cos(p.ft1) + cos(p.ft2));
  final double footB = seg * (cos(p.bt1) + cos(p.bt2));
  final double hipY = -max(footF, footB) - p.lift;

  canvas.save();
  canvas.translate(0, hipY);
  if (p.spin != 0) {
    canvas.rotate(p.spin);
  }

  Offset pt(Offset o, double a, double len) {
    return Offset(o.dx + sin(a) * len, o.dy + cos(a) * len);
  }

  final double sl = sin(p.lean);
  final double cl = cos(p.lean);
  final Offset neck = Offset(sl * torso, -cl * torso);
  final Offset head = Offset(sl * (torso + headR), -cl * (torso + headR));
  final Offset sh = Offset(sl * (torso - 3), -cl * (torso - 3));

  final Offset fe = pt(sh, p.fa1, arm);
  final Offset fh = pt(fe, p.fa2, arm);
  final Offset be = pt(sh, p.ba1, arm);
  final Offset bh = pt(be, p.ba2, arm);

  final Offset fk = pt(Offset.zero, p.ft1, seg);
  final Offset fa = pt(fk, p.ft2, seg);
  final Offset ff = pt(fa, p.ft2 + pi / 2, 6);
  final Offset bk = pt(Offset.zero, p.bt1, seg);
  final Offset ba = pt(bk, p.bt2, seg);
  final Offset bf = pt(ba, p.bt2 + pi / 2, 6);

  final _J j = _J(
    neck: neck,
    head: head,
    sh: sh,
    fe: fe,
    fh: fh,
    be: be,
    bh: bh,
    fk: fk,
    fa: fa,
    ff: ff,
    bk: bk,
    ba: ba,
    bf: bf,
    perp: Offset(cl, sl),
  );

  // الهالة الملونة
  _glow.color = accent;
  canvas.drawLine(sh, be, _glow);
  canvas.drawLine(be, bh, _glow);
  canvas.drawLine(Offset.zero, bk, _glow);
  canvas.drawLine(bk, ba, _glow);
  canvas.drawLine(ba, bf, _glow);
  canvas.drawLine(Offset.zero, neck, _glow);
  canvas.drawLine(Offset.zero, fk, _glow);
  canvas.drawLine(fk, fa, _glow);
  canvas.drawLine(fa, ff, _glow);
  canvas.drawLine(sh, fe, _glow);
  canvas.drawLine(fe, fh, _glow);
  _fillP.color = accent;
  canvas.drawCircle(head, headR + 2.2, _fillP);

  // عناصر خلف الجسم (عباءة، وشاح)
  if (prof != null) {
    if (prof.full >= 0) {
      _fullBack(canvas, j, prof.full);
    } else {
      _topBack(canvas, j, prof.top, Color(prof.topColor));
    }
  }

  // الجسم الأسود
  canvas.drawLine(sh, be, _body);
  canvas.drawLine(be, bh, _body);
  canvas.drawLine(Offset.zero, bk, _body);
  canvas.drawLine(bk, ba, _body);
  canvas.drawLine(ba, bf, _body);
  canvas.drawLine(Offset.zero, neck, _body);
  canvas.drawLine(Offset.zero, fk, _body);
  canvas.drawLine(fk, fa, _body);
  canvas.drawLine(fa, ff, _body);
  canvas.drawLine(sh, fe, _body);
  canvas.drawLine(fe, fh, _body);

  // الزي فوق الجسم
  if (prof != null) {
    if (prof.full >= 0) {
      _fullFront(canvas, j, prof.full);
    } else {
      _botFront(canvas, j, prof.bottom, Color(prof.bottomColor));
      _topFront(canvas, j, prof.top, Color(prof.topColor));
    }
  }

  // الرأس يبقى أسود بالكامل ويُرسم أخيراً
  _fillP.color = const Color(0xFF000000);
  canvas.drawCircle(head, headR, _fillP);
  if (prof != null) {
    final Paint hairPaint = Paint()..color = const Color(0xFF17120F)..style = PaintingStyle.fill;
    final double hr = headR;
    switch (prof.hair) {
      case 1:
        final Path spikes = Path()..moveTo(head.dx-hr, head.dy-2)..lineTo(head.dx-hr*0.75, head.dy-hr*1.6)..lineTo(head.dx-hr*0.25, head.dy-hr*0.9)..lineTo(head.dx+hr*0.1, head.dy-hr*1.8)..lineTo(head.dx+hr*0.45, head.dy-hr*0.8)..lineTo(head.dx+hr, head.dy-hr*1.25)..lineTo(head.dx+hr, head.dy+2)..close();
        canvas.drawPath(spikes, hairPaint); break;
      case 2: canvas.drawOval(Rect.fromCenter(center: Offset(head.dx,head.dy-hr*0.25), width: hr*2.1,height:hr*2.0),hairPaint); canvas.drawRect(Rect.fromLTWH(head.dx-hr*1.05,head.dy,hr*0.4,hr*1.2),hairPaint); canvas.drawRect(Rect.fromLTWH(head.dx+hr*0.65,head.dy,hr*0.4,hr*1.2),hairPaint); break;
      case 3: final Path tall = Path()..moveTo(head.dx-hr,head.dy)..lineTo(head.dx-hr*0.7,head.dy-hr*1.3)..lineTo(head.dx+hr*0.2,head.dy-hr*1.8)..lineTo(head.dx+hr,head.dy-hr*0.9)..lineTo(head.dx+hr,head.dy+2)..close(); canvas.drawPath(tall,hairPaint); break;
      case 4: canvas.drawOval(Rect.fromCenter(center: Offset(head.dx,head.dy-hr*0.3),width:hr*2.2,height:hr*1.7),hairPaint); break;
      case 5: canvas.drawArc(Rect.fromCenter(center: Offset(head.dx,head.dy-hr*0.15),width:hr*2.0,height:hr*1.3),pi,pi, false, hairPaint..style=PaintingStyle.stroke..strokeWidth=hr*0.45); break;
    }
    if (prof.headwear == 0) {
      final Paint straw = Paint()..color = const Color(0xFFFFD54F);
      canvas.drawOval(Rect.fromCenter(center: Offset(head.dx,head.dy-hr*0.85),width:hr*3.0,height:hr*0.65),straw);
      canvas.drawOval(Rect.fromCenter(center: Offset(head.dx,head.dy-hr*1.05),width:hr*1.7,height:hr*0.75),straw);
      canvas.drawRect(Rect.fromLTWH(head.dx-hr*0.85,head.dy-hr*1.05,hr*1.7,hr*0.25),Paint()..color=const Color(0xFFD32F2F));
    }
  }

  canvas.restore();
}
