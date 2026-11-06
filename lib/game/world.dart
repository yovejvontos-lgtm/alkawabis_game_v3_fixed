import 'dart:math';
import 'dart:ui';

import 'fighter.dart';
import 'input.dart';
import 'level.dart';
import 'profile.dart';

enum WorldStatus { playing, won, lost, pvpOver }

/// أوضاع اللعب: تعاون ضد الأعداء، مواجهة حرة، فرق (3 ضد 3).
enum GameMode { coop, ffa, teams }

class _Atk {
  const _Atk(
    this.duration,
    this.hitStart,
    this.hitEnd,
    this.damage,
    this.reach,
    this.knock,
    this.big, {
    this.lunge = 0,
    this.pop = -140,
  });

  final double duration;
  final double hitStart;
  final double hitEnd;
  final double damage;
  final double reach;
  final double knock;
  final int big;
  final double lunge;
  final double pop;
}

/// ثلاث لكمات متتالية: جاب، هوك، أبركت.
const List<_Atk> _punches = <_Atk>[
  _Atk(0.28, 0.07, 0.17, 7, 40, 120, 0, lunge: 260),
  _Atk(0.30, 0.08, 0.19, 9, 44, 170, 0, lunge: 300),
  _Atk(0.42, 0.10, 0.26, 15, 42, 260, 1, lunge: 240, pop: -380),
];

/// ثلاث ركلات متتالية: أمامية، دائرية عالية، طائرة.
const List<_Atk> _kicks = <_Atk>[
  _Atk(0.40, 0.10, 0.24, 10, 54, 200, 0, lunge: 280),
  _Atk(0.45, 0.10, 0.30, 15, 68, 290, 1, lunge: 320, pop: -280),
  _Atk(0.58, 0.14, 0.38, 20, 68, 360, 2, lunge: 460),
];

const _Atk _specialAtk = _Atk(0.90, 0.12, 0.68, 32, 78, 760, 2, lunge: 340, pop: -460);

/// عالم اللعبة: الفيزياء والقتال والذكاء الاصطناعي.
/// يعمل كاملاً عند اللاعب الفردي أو المضيف، أما الضيوف فيستقبلون لقطات فقط.
class GameWorld {
  GameWorld({
    required this.level,
    required this.mode,
    required List<RosterEntry> roster,
  }) {
    final int n = roster.length;
    for (int i = 0; i < n; i++) {
      double sx;
      if (level.isArena) {
        if (mode == GameMode.teams) {
          final int team = roster[i].team;
          int k = 0;
          for (int j = 0; j < i; j++) {
            if (roster[j].team == team) {
              k++;
            }
          }
          sx = team == 0 ? 150.0 + k * 55 : level.width - 150.0 - k * 55;
        } else {
          sx = 150.0 + (n <= 1 ? 0.0 : i * (level.width - 300.0) / (n - 1));
        }
        sx = Level.clearX(sx, level.solids, level.width);
      } else {
        final int si = i < level.playerSpawnX.length
            ? i
            : level.playerSpawnX.length - 1;
        sx = level.playerSpawnX[si];
      }
      final Fighter p = Fighter(
        id: i,
        kind: 0,
        x: sx,
        y: Level.groundY,
        maxHp: 200,
        team: roster[i].team,
      );
      p.profile = roster[i].profile;
      if (level.isArena) {
        p.facing = sx < level.width / 2 ? 1 : -1;
      }
      players.add(p);
    }

    final double idx = level.index.toDouble();
    final double hpMul = 1.0 + 0.3 * (n - 1);
    int c = 0;
    for (final EnemySpawn s in level.spawns) {
      Fighter e;
      if (s.kind == 2) {
        e = Fighter(
          id: 100 + c,
          kind: 2,
          x: s.x,
          y: Level.groundY,
          maxHp: (260 + idx * 14) * hpMul,
          w: 40,
          h: 108,
          speed: 105,
          dmgMul: 1.3 + idx * 0.03,
          aggr: 1.1,
        );
      } else {
        e = Fighter(
          id: 100 + c,
          kind: 1,
          x: s.x,
          y: Level.groundY,
          maxHp: (36 + idx * 3.2) * hpMul,
          speed: min(150.0, 85.0 + idx * 3.5),
          dmgMul: 0.8 + idx * 0.05,
          aggr: 1 + idx * 0.03,
        );
      }
      e.facing = -1;
      e.aiCooldown = 0.8 + _rnd.nextDouble();
      enemies.add(e);
      c++;
    }
  }

  static const double gravity = 1800;
  static const double jumpVel = -680;

  final Level level;
  final GameMode mode;
  final List<Fighter> players = <Fighter>[];
  final List<Fighter> enemies = <Fighter>[];

  WorldStatus status = WorldStatus.playing;

  /// في المواجهة الحرة: رقم اللاعب الفائز. في الفرق: رقم الفريق الفائز. -1 تعادل.
  int winner = -1;
  double time = 0;

  /// نسبة التنعيم بين الخطوتين (للعرض فقط).
  double alpha = 1;

  int hitSeq = 0;
  final List<List<double>> recentHits = <List<double>>[];

  final Random _rnd = Random();
  double _endTimer = 0;

  bool get pvp => mode != GameMode.coop;

  int get enemiesAlive {
    int c = 0;
    for (final Fighter e in enemies) {
      if (!e.isDead) {
        c++;
      }
    }
    return c;
  }

  /// يقتل لاعباً انقطع اتصاله.
  void killPlayer(int i) {
    if (i < 0 || i >= players.length) {
      return;
    }
    final Fighter p = players[i];
    p.hp = 0;
    p.state = FState.dead;
    p.stateTime = 0;
    p.input.reset();
  }

  // ------------------------------------------------------------------
  //  الخطوة الرئيسية
  // ------------------------------------------------------------------

  void step(double dt) {
    time += dt;
    for (final Fighter p in players) {
      p.px = p.x;
      p.py = p.y;
    }
    for (final Fighter e in enemies) {
      e.px = e.x;
      e.py = e.y;
    }

    if (status == WorldStatus.playing) {
      for (final Fighter p in players) {
        _updatePlayer(p, dt);
      }
      for (final Fighter e in enemies) {
        _updateEnemy(e, dt);
      }
      _checkSpikes();
      _checkEnd(dt);
    } else {
      for (final Fighter p in players) {
        _idleStep(p, dt);
      }
      for (final Fighter e in enemies) {
        _idleStep(e, dt);
      }
    }
  }

  void _idleStep(Fighter f, double dt) {
    f.stateTime += dt;
    if (!f.isDead && _isFree(f.state)) {
      f.vx = 0;
    }
    _applyPhysics(f, dt);
    _updateMoveState(f);
    f.input.clearJust();
  }

  // ------------------------------------------------------------------
  //  الحالات
  // ------------------------------------------------------------------

  bool _isFree(FState s) {
    return s == FState.idle || s == FState.run || s == FState.jump;
  }

  bool _isAttack(FState s) {
    return s == FState.punch || s == FState.kick || s == FState.special;
  }

  _Atk? _atkOf(Fighter f) {
    final int step = f.comboStep < 0 ? 0 : (f.comboStep > 2 ? 2 : f.comboStep);
    switch (f.state) {
      case FState.punch:
        return _punches[step];
      case FState.kick:
        return _kicks[step];
      case FState.special:
        return _specialAtk;
      default:
        return null;
    }
  }

  void _setState(Fighter f, FState s) {
    if (f.state != s) {
      f.state = s;
      f.stateTime = 0;
    }
  }

  void _endAction(Fighter f) {
    f.state = f.onGround ? FState.idle : FState.jump;
    f.stateTime = 0;
  }

  void _tickStateTimers(Fighter f) {
    final _Atk? atk = _atkOf(f);
    if (atk != null && f.stateTime >= atk.duration) {
      _endAction(f);
      return;
    }
    if (f.state == FState.hurt && f.stateTime >= f.hurtTime) {
      _endAction(f);
    }
  }

  void _startAttack(Fighter f, FState s, {bool allowChain = true}) {
    final int kind = s == FState.punch ? 1 : (s == FState.kick ? 2 : 0);
    if (kind != 0) {
      if (allowChain &&
          f.comboKind == kind &&
          f.sinceAtk < 0.5 &&
          f.comboStep < 2) {
        f.comboStep++;
      } else {
        f.comboStep = 0;
      }
      f.comboKind = kind;
    } else {
      f.comboStep = 0;
      f.comboKind = 0;
    }
    f.state = s;
    f.stateTime = 0;
    f.hitIds.clear();
    f.sinceAtk = 0;

    if (s == FState.special) {
      f.specialCd = 10.0;
      f.vx = f.facing * 220.0;
      if (f.onGround) {
        f.vy = -260;
        f.onGround = false;
      }
      return;
    }
    final _Atk? atk = _atkOf(f);
    // الاندفاع للأمام: اللاعب أقوى من الأعداء قليلاً
    final double lungeMul = f.kind == 0 ? 1.0 : 0.6;
    f.vx = f.facing * (atk == null ? 0.0 : atk.lunge * lungeMul);
    if (s == FState.kick && f.comboStep == 2 && f.onGround) {
      f.vy = -200;
      f.onGround = false;
    }
  }

  // ------------------------------------------------------------------
  //  اللاعبون
  // ------------------------------------------------------------------

  void _updatePlayer(Fighter f, double dt) {
    f.stateTime += dt;
    if (f.invul > 0) {
      f.invul -= dt;
    }
    if (f.specialCd > 0) {
      f.specialCd -= dt;
    }
    final PlayerInput inp = f.input;

    if (inp.consume(PlayerInput.punch)) {
      f.bufPunch = 0.28;
    }
    if (inp.consume(PlayerInput.kick)) {
      f.bufKick = 0.28;
    }
    final bool wantSpecial = inp.consume(PlayerInput.special);
    final bool wantJump = inp.consume(PlayerInput.jump);
    if (f.bufPunch > 0) {
      f.bufPunch -= dt;
    }
    if (f.bufKick > 0) {
      f.bufKick -= dt;
    }

    if (f.isDead) {
      _applyPhysics(f, dt);
      inp.clearJust();
      return;
    }

    _tickStateTimers(f);

    if (_isAttack(f.state)) {
      f.sinceAtk = 0;
    } else {
      f.sinceAtk += dt;
    }

    if (_isFree(f.state)) {
      int dir = 0;
      if (inp.isHeld(PlayerInput.left)) {
        dir -= 1;
      }
      if (inp.isHeld(PlayerInput.right)) {
        dir += 1;
      }
      f.vx = dir * f.speed;
      if (dir != 0) {
        f.facing = dir;
      }
      if (wantJump && f.onGround) {
        f.vy = jumpVel;
        f.onGround = false;
      }
      if (wantSpecial && f.specialCd <= 0) {
        _startAttack(f, FState.special);
      } else if (f.bufKick > 0) {
        f.bufKick = 0;
        f.bufPunch = 0;
        _startAttack(f, FState.kick);
      } else if (f.bufPunch > 0) {
        f.bufPunch = 0;
        f.bufKick = 0;
        _startAttack(f, FState.punch);
      }
    } else if (f.state == FState.punch || f.state == FState.kick) {
      // نافذة الإلغاء: الضغطة التالية تكمل الكومبو دون انتظار انتهاء الحركة
      final _Atk? atk = _atkOf(f);
      if (atk != null && f.stateTime >= atk.duration * 0.6) {
        if (f.bufKick > 0 && (f.state == FState.punch || f.comboStep < 2)) {
          f.bufKick = 0;
          f.bufPunch = 0;
          _startAttack(f, FState.kick);
        } else if (f.bufPunch > 0 &&
            (f.state == FState.kick || f.comboStep < 2)) {
          f.bufPunch = 0;
          f.bufKick = 0;
          _startAttack(f, FState.punch);
        }
      }
    }

    _applyPhysics(f, dt);
    _updateAttackHits(f);
    _updateMoveState(f);
    inp.clearJust();
  }

  void _updateMoveState(Fighter f) {
    if (_isFree(f.state)) {
      FState s;
      if (!f.onGround) {
        s = FState.jump;
      } else if (f.vx.abs() > 20) {
        s = FState.run;
      } else {
        s = FState.idle;
      }
      _setState(f, s);
    }
  }

  // ------------------------------------------------------------------
  //  الأعداء
  // ------------------------------------------------------------------

  Fighter? _nearestAlivePlayer(Fighter e) {
    Fighter? best;
    double bestD = 1e9;
    for (final Fighter p in players) {
      if (p.isDead) {
        continue;
      }
      final double d = (p.x - e.x).abs();
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  void _updateEnemy(Fighter e, double dt) {
    e.stateTime += dt;
    if (e.invul > 0) {
      e.invul -= dt;
    }
    if (e.aiCooldown > 0) {
      e.aiCooldown -= dt;
    }
    if (e.aiJumpCd > 0) {
      e.aiJumpCd -= dt;
    }

    if (e.isDead) {
      _applyPhysics(e, dt);
      return;
    }

    _tickStateTimers(e);

    if (_isFree(e.state)) {
      final Fighter? target = _nearestAlivePlayer(e);
      e.vx = 0;
      if (target != null) {
        final double dx = target.x - e.x;
        final double ad = dx.abs();
        if (ad < 720) {
          e.facing = dx >= 0 ? 1 : -1;
          final double reach = 34 * e.scale + e.w * 0.5 + 10;
          if (ad > reach) {
            e.vx = e.facing * e.speed;
            if (e.blockedX && e.onGround && e.aiJumpCd <= 0) {
              e.vy = jumpVel;
              e.onGround = false;
              e.aiJumpCd = 0.7;
            } else if (target.y < e.y - 70 &&
                ad < 160 &&
                e.onGround &&
                e.aiJumpCd <= 0) {
              e.vy = jumpVel;
              e.onGround = false;
              e.aiJumpCd = 1.0;
            }
          } else {
            if (e.aiCooldown <= 0 && (target.y - e.y).abs() < 70) {
              final bool punch = _rnd.nextDouble() < 0.6;
              _startAttack(
                e,
                punch ? FState.punch : FState.kick,
                allowChain: false,
              );
              e.aiCooldown = (0.8 + _rnd.nextDouble() * 1.0) / e.aggr;
            }
          }
        }
      }
    }

    _applyPhysics(e, dt);
    _updateAttackHits(e);
    _updateMoveState(e);
  }

  // ------------------------------------------------------------------
  //  الفيزياء
  // ------------------------------------------------------------------

  bool _overlap(Fighter f, Rect s) {
    return f.x + f.w / 2 > s.left + 0.001 &&
        f.x - f.w / 2 < s.right - 0.001 &&
        f.y > s.top + 0.001 &&
        f.y - f.h < s.bottom - 0.001;
  }

  void _applyPhysics(Fighter f, double dt) {
    f.blockedX = false;

    if (f.onGround && !_isFree(f.state)) {
      f.vx *= 0.88;
    }

    f.vy += gravity * dt;
    if (f.vy > 1400) {
      f.vy = 1400;
    }

    f.x += f.vx * dt;
    for (final Rect s in level.solids) {
      if (_overlap(f, s)) {
        if (f.vx > 0) {
          f.x = s.left - f.w / 2 - 0.01;
        } else if (f.vx < 0) {
          f.x = s.right + f.w / 2 + 0.01;
        }
        f.blockedX = true;
      }
    }

    f.y += f.vy * dt;
    f.onGround = false;
    for (final Rect s in level.solids) {
      if (_overlap(f, s)) {
        if (f.vy > 0) {
          f.y = s.top;
          f.vy = 0;
          f.onGround = true;
        } else if (f.vy < 0) {
          f.y = s.bottom + f.h + 0.01;
          f.vy = 0;
        }
      }
    }

    final double minX = f.w / 2;
    final double maxX = level.width - f.w / 2;
    if (f.x < minX) {
      f.x = minX;
    } else if (f.x > maxX) {
      f.x = maxX;
    }
  }

  // ------------------------------------------------------------------
  //  القتال
  // ------------------------------------------------------------------

  Rect _hitBox(Fighter a, _Atk atk) {
    final double reach = atk.reach * a.scale;
    final double top = a.y - a.h * 0.92;
    final double bottom = a.y - a.h * 0.08;
    if (a.state == FState.special) {
      return Rect.fromLTRB(
        a.x - reach - a.w / 2,
        top,
        a.x + reach + a.w / 2,
        bottom,
      );
    }
    if (a.facing > 0) {
      return Rect.fromLTRB(a.x, top, a.x + a.w / 2 + reach, bottom);
    }
    return Rect.fromLTRB(a.x - a.w / 2 - reach, top, a.x, bottom);
  }

  bool _canHit(Fighter a, Fighter t) {
    if (a.id == t.id || t.isDead) {
      return false;
    }
    if (a.kind == 0) {
      if (t.kind != 0) {
        return true;
      }
      if (mode == GameMode.coop) {
        return false;
      }
      if (mode == GameMode.teams) {
        return a.team != t.team;
      }
      return true;
    }
    return t.kind == 0;
  }

  void _updateAttackHits(Fighter a) {
    final _Atk? atk = _atkOf(a);
    if (atk == null) {
      return;
    }
    if (a.stateTime < atk.hitStart || a.stateTime > atk.hitEnd) {
      return;
    }
    final Rect box = _hitBox(a, atk);
    for (final Fighter t in players) {
      _tryHit(a, t, atk, box);
    }
    for (final Fighter t in enemies) {
      _tryHit(a, t, atk, box);
    }
  }

  void _tryHit(Fighter a, Fighter t, _Atk atk, Rect box) {
    if (!_canHit(a, t) || t.invul > 0 || a.hitIds.contains(t.id)) {
      return;
    }
    final Rect body = Rect.fromLTRB(
      t.x - t.w / 2,
      t.y - t.h,
      t.x + t.w / 2,
      t.y,
    );
    if (box.overlaps(body)) {
      _hit(a, t, atk);
    }
  }

  void _addHitEvent(double x, double y, int big) {
    hitSeq++;
    recentHits.add(<double>[hitSeq.toDouble(), x, y, big.toDouble()]);
    while (recentHits.length > 10) {
      recentHits.removeAt(0);
    }
  }

  void _hit(Fighter a, Fighter t, _Atk atk) {
    a.hitIds.add(t.id);
    final double dmg = atk.damage * a.dmgMul;
    t.hp -= dmg;
    t.invul = 0.22;
    _addHitEvent(t.x, t.y - t.h * 0.6, atk.big);

    int dir = a.facing;
    if (a.state == FState.special) {
      dir = t.x >= a.x ? 1 : -1;
    }

    if (t.hp <= 0) {
      t.hp = 0;
      t.state = FState.dead;
      t.stateTime = 0;
      t.vx = dir * min(atk.knock * 1.1, 360.0);
      t.vy = -260;
      t.onGround = false;
      return;
    }

    final bool stagger = t.kind != 2 || atk.damage >= 15;
    if (stagger) {
      t.state = FState.hurt;
      t.stateTime = 0;
      t.hurtTime = atk.big >= 1 ? 0.4 : 0.3;
      t.vx = dir * atk.knock;
      t.vy = atk.pop;
      t.onGround = false;
    } else {
      t.vx += dir * 60.0;
    }
  }

  void _checkSpikes() {
    if (level.spikes.isEmpty) {
      return;
    }
    for (final Fighter p in players) {
      if (p.isDead || p.invul > 0) {
        continue;
      }
      final Rect body = Rect.fromLTRB(
        p.x - p.w / 2,
        p.y - p.h,
        p.x + p.w / 2,
        p.y,
      );
      for (final Rect s in level.spikes) {
        if (body.overlaps(s)) {
          p.hp -= 12;
          p.invul = 0.9;
          p.vy = -420;
          p.onGround = false;
          _addHitEvent(p.x, p.y - 6, 0);
          if (p.hp <= 0) {
            p.hp = 0;
            p.state = FState.dead;
            p.stateTime = 0;
          } else {
            p.state = FState.hurt;
            p.stateTime = 0;
            p.hurtTime = 0.3;
          }
          break;
        }
      }
    }
  }

  void _checkEnd(double dt) {
    WorldStatus? result;
    int win = -1;

    if (mode == GameMode.coop) {
      bool allDead = true;
      for (final Fighter p in players) {
        if (!p.isDead) {
          allDead = false;
        }
      }
      if (allDead) {
        result = WorldStatus.lost;
      } else if (enemies.isNotEmpty && enemiesAlive == 0) {
        result = WorldStatus.won;
      }
    } else if (mode == GameMode.ffa) {
      int alive = 0;
      int last = -1;
      for (final Fighter p in players) {
        if (!p.isDead) {
          alive++;
          last = p.id;
        }
      }
      if (players.length >= 2 && alive <= 1) {
        result = WorldStatus.pvpOver;
        win = alive == 1 ? last : -1;
      }
    } else {
      int a0 = 0;
      int a1 = 0;
      for (final Fighter p in players) {
        if (!p.isDead) {
          if (p.team == 0) {
            a0++;
          } else {
            a1++;
          }
        }
      }
      if (players.length >= 2 && (a0 == 0 || a1 == 0)) {
        result = WorldStatus.pvpOver;
        if (a0 == 0 && a1 == 0) {
          win = -1;
        } else {
          win = a0 > 0 ? 0 : 1;
        }
      }
    }

    if (result == null) {
      _endTimer = 0;
      return;
    }
    _endTimer += dt;
    if (_endTimer >= 0.9) {
      status = result;
      winner = win;
    }
  }

  // ------------------------------------------------------------------
  //  الشبكة
  // ------------------------------------------------------------------

  Map<String, dynamic> snapshot() {
    return <String, dynamic>{
      't': round2(time),
      's': status.index,
      'w': winner,
      'p': players.map((Fighter f) => f.toList()).toList(),
      'e': enemies.map((Fighter f) => f.toList()).toList(),
      'h': recentHits
          .map(
            (List<double> h) => <num>[
              h[0].toInt(),
              round1(h[1]),
              round1(h[2]),
              h[3].toInt(),
            ],
          )
          .toList(),
    };
  }

  void applySnapshot(Map<String, dynamic> m) {
    time = (m['t'] as num).toDouble();
    final int si = (m['s'] as num).toInt();
    if (si >= 0 && si < WorldStatus.values.length) {
      status = WorldStatus.values[si];
    }
    winner = (m['w'] as num).toInt();

    final List<dynamic> p = m['p'] as List<dynamic>;
    for (int i = 0; i < p.length && i < players.length; i++) {
      players[i].applyList(p[i] as List<dynamic>);
    }
    final List<dynamic> e = m['e'] as List<dynamic>;
    for (int i = 0; i < e.length && i < enemies.length; i++) {
      enemies[i].applyList(e[i] as List<dynamic>);
    }

    recentHits.clear();
    final List<dynamic> h = m['h'] as List<dynamic>;
    for (final dynamic item in h) {
      final List<dynamic> l = item as List<dynamic>;
      if (l.length >= 4) {
        recentHits.add(<double>[
          (l[0] as num).toDouble(),
          (l[1] as num).toDouble(),
          (l[2] as num).toDouble(),
          (l[3] as num).toDouble(),
        ]);
      }
    }
  }

  /// تنعيم الحركة عند الضيف.
  void smoothAll(double dt) {
    for (final Fighter f in players) {
      f.smoothGuest(dt);
    }
    for (final Fighter f in enemies) {
      f.smoothGuest(dt);
    }
  }
}
