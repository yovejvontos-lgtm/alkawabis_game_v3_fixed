import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/fighter.dart';
import '../game/input.dart';
import '../game/level.dart';
import '../game/painter.dart';
import '../game/profile.dart';
import '../game/save.dart';
import '../game/world.dart';
import '../net/net_link.dart';
import '../widgets/controls.dart';

enum GameRole { solo, host, guest }

/// شاشة اللعب: فردي، أو مضيف (يشغّل المحاكاة)، أو ضيف (يعرض ويرسل أزراره).
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.role,
    required this.mode,
    required this.levelIndex,
    required this.roster,
    this.myIndex = 0,
    this.hub,
    this.link,
  });

  final GameRole role;
  final GameMode mode;
  final int levelIndex;
  final List<RosterEntry> roster;
  final int myIndex;
  final HostHub? hub;
  final ClientLink? link;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const double _step = 1 / 60;

  late GameWorld _world;
  final RenderState _rs = RenderState();
  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _acc = 0;
  int _steps = 0;
  int _mask = 0;
  final Map<int, int> _remoteMasks = <int, int>{};
  late int _levelIndex;
  late GameMode _mode;
  late List<RosterEntry> _roster;
  WorldStatus _shown = WorldStatus.playing;
  bool _leaving = false;
  bool _disconnectShown = false;
  int _martialStep = 0;
  int _uiRefresh = 0;

  bool get _isGuest => widget.role == GameRole.guest;
  bool get _isHost => widget.role == GameRole.host;
  int get _focus => _isGuest ? widget.myIndex : 0;

  @override
  void initState() {
    super.initState();
    _levelIndex = widget.levelIndex;
    _mode = widget.mode;
    _roster = widget.roster;
    _world = _makeWorld();

    final HostHub? hub = widget.hub;
    if (_isHost && hub != null) {
      hub.onGameLine = _onHostLine;
      hub.onPeerLeft = _onPeerLeft;
    }
    final ClientLink? link = widget.link;
    if (_isGuest && link != null) {
      link.onClosed = _onLinkClosed;
      link.onLine = _onGuestLine;
    }
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    widget.hub?.close();
    widget.link?.close();
    super.dispose();
  }

  GameWorld _makeWorld() {
    final Level lv = _mode == GameMode.coop
        ? Level.campaign(_levelIndex)
        : Level.arena(_levelIndex);
    return GameWorld(level: lv, mode: _mode, roster: _roster);
  }

  // ------------------------------------------------------------------
  //  الحلقة الرئيسية
  // ------------------------------------------------------------------

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt < 0) {
      dt = 0;
    }
    if (dt > 0.05) {
      dt = 0.05;
    }

    if (_isGuest) {
      _world.alpha = 1;
      _world.smoothAll(dt);
    } else {
      _acc += dt;
      while (_acc >= _step) {
        _world.step(_step);
        _acc -= _step;
        _steps++;
        if (_isHost && _steps % 2 == 0) {
          _sendSnapshot();
        }
      }
      _world.alpha = _acc / _step;
    }

    _rs.update(_world, dt, _focus);
    _rs.repaintNow();
    if (++_uiRefresh % 6 == 0 && mounted) setState(() {});

    if (_world.status != _shown) {
      final WorldStatus s = _world.status;
      if (s == WorldStatus.won && _mode == GameMode.coop) {
        Save.instance.unlock(_levelIndex + 1);
      }
      setState(() {
        _shown = s;
      });
    }
  }

  void _sendSnapshot() {
    final HostHub? hub = widget.hub;
    if (hub == null || hub.peers.isEmpty) {
      return;
    }
    hub.broadcast('S|${jsonEncode(_world.snapshot())}');
  }

  // ------------------------------------------------------------------
  //  الشبكة
  // ------------------------------------------------------------------

  void _onHostLine(int index, String line) {
    final int i = line.indexOf('|');
    final String cmd = i < 0 ? line : line.substring(0, i);
    final String arg = i < 0 ? '' : line.substring(i + 1);
    if (cmd == 'I') {
      final int? m = int.tryParse(arg);
      if (m != null && index >= 0 && index < _world.players.length) {
        _remoteMasks[index] = m;
        _world.players[index].input.setMask(m);
      }
    }
  }

  void _onPeerLeft(int index) {
    if (!mounted) {
      return;
    }
    _world.killPlayer(index);
    final String name = index < _roster.length
        ? _roster[index].profile.name
        : 'لاعب';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('غادر $name اللعبة')),
    );
  }

  void _onGuestLine(String line) {
    final int i = line.indexOf('|');
    final String cmd = i < 0 ? line : line.substring(0, i);
    final String arg = i < 0 ? '' : line.substring(i + 1);

    if (cmd == 'S') {
      try {
        final dynamic m = jsonDecode(arg);
        if (m is Map<String, dynamic>) {
          _world.applySnapshot(m);
        }
      } catch (_) {}
    } else if (cmd == 'L') {
      try {
        final dynamic m = jsonDecode(arg);
        if (m is Map<String, dynamic> && mounted) {
          final int mi = (m['m'] as num).toInt();
          final int lv = (m['l'] as num).toInt();
          final List<RosterEntry> r =
              RosterEntry.fromJson(m['r'] as List<dynamic>);
          if (mi >= 0 && mi < GameMode.values.length && r.isNotEmpty) {
            setState(() {
              _mode = GameMode.values[mi];
              _levelIndex = lv;
              _roster = r;
              _world = _makeWorld();
              _rs.reset();
              _shown = WorldStatus.playing;
            });
          }
        }
      } catch (_) {}
    } else if (cmd == 'Q') {
      _onLinkClosed();
    }
  }

  void _onLinkClosed() {
    if (_leaving || !mounted || _disconnectShown) {
      return;
    }
    _disconnectShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('انقطع الاتصال'),
          content: const Text('غادر المضيف أو انقطعت الشبكة.'),
          actions: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _exitToMenu();
              },
              child: const Text('القائمة الرئيسية'),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------
  //  التحكم
  // ------------------------------------------------------------------

  void _applyLocalMask() {
    if (_isGuest) {
      widget.link?.send('I|$_mask');
    } else if (_world.players.isNotEmpty) {
      _world.players[0].input.setMask(_mask);
    }
  }

  void _setBit(int bit, bool down) {
    final int old = _mask;
    if (down) {
      _mask |= bit;
    } else {
      _mask &= ~bit;
    }
    if (_mask != old) {
      _applyLocalMask();
    }
  }

  void _setArrows(bool left, bool right) {
    final int old = _mask;
    _mask &= ~(PlayerInput.left | PlayerInput.right);
    if (left) {
      _mask |= PlayerInput.left;
    }
    if (right) {
      _mask |= PlayerInput.right;
    }
    if (_mask != old) {
      _applyLocalMask();
    }
  }

  // ------------------------------------------------------------------
  //  المراحل والخروج
  // ------------------------------------------------------------------

  bool get _hasNext =>
      _mode == GameMode.coop && _levelIndex + 1 < Level.campaignCount;

  void _loadLevel(int idx) {
    setState(() {
      _levelIndex = idx;
      _world = _makeWorld();
      _rs.reset();
      _shown = WorldStatus.playing;
      _acc = 0;
    });
    if (_world.players.isNotEmpty) {
      _world.players[0].input.setMask(_mask);
    }
    if (_isHost) {
      _remoteMasks.forEach((int index, int m) {
        if (index >= 0 && index < _world.players.length) {
          _world.players[index].input.setMask(m);
        }
      });
      widget.hub?.sendLevel(_mode, _levelIndex);
    }
  }

  void _next() {
    if (_hasNext) {
      _loadLevel(_levelIndex + 1);
    }
  }

  void _retry() {
    _loadLevel(_levelIndex);
  }

  void _exitToMenu() {
    _leaving = true;
    widget.hub?.broadcast('Q');
    widget.hub?.close();
    widget.link?.send('Q');
    widget.link?.close();
    if (mounted) {
      Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    }
  }

  Future<void> _confirmExit() async {
    final bool online = widget.hub != null || widget.link != null;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('الخروج من اللعبة؟'),
          content: Text(
            online
                ? 'ستنتهي مشاركتك في هذه الحفلة.'
                : 'سيضيع تقدمك في هذه المرحلة.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('متابعة اللعب'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('خروج'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      _exitToMenu();
    }
  }

  // ------------------------------------------------------------------
  //  الواجهة
  // ------------------------------------------------------------------

  Widget _actionButtons() {
    final double cd = _world.players.isEmpty ? 0 : _world.players[_focus < _world.players.length ? _focus : 0].specialCd;
    final String ultimateLabel = cd > 0 ? '${cd.ceil()} ث' : 'الضربة القاضية';
    return SizedBox(
      width: 310, height: 310,
      child: Stack(clipBehavior: Clip.none, children: <Widget>[
        Positioned(left: 0, top: 78, child: HoldButton(emoji: '🦵', label: 'ركل', color: const Color(0xFFFFD600), size: 86, onChanged: (bool d) => _setBit(PlayerInput.kick, d))),
        Positioned(left: 0, top: 174, child: HoldButton(emoji: '👊', label: 'لكم', color: const Color(0xFF39E75F), size: 86, onChanged: (bool d) => _setBit(PlayerInput.punch, d))),
        Positioned(left: 112, top: 0, child: HoldButton(emoji: '💥', label: ultimateLabel, color: const Color(0xFFFF1744), size: 82, onChanged: (bool d) => _setBit(PlayerInput.special, d))),
        Positioned(left: 112, top: 91, child: HoldButton(emoji: '🥋', label: 'فنون قتالية', color: const Color(0xFFB620FF), size: 88, onChanged: (bool down) {
          if (!down) return;
          // كل ضغطة تنفذ حركة من سلسلة متغيرة: لكمتان ثم ركلتان علويتان.
          final int bit = (_martialStep % 4 < 2) ? PlayerInput.punch : PlayerInput.kick;
          _martialStep++;
          _setBit(bit, true);
          _setBit(bit, false);
        })),
        Positioned(left: 112, top: 190, child: HoldButton(emoji: '⬆️', label: 'قفز', color: const Color(0xFF03A9F4), size: 118, onChanged: (bool d) => _setBit(PlayerInput.jump, d))),
      ]),
    );
  }

  Widget _overlayButton(String text, VoidCallback onTap, {bool main = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: 230,
        child: main
            ? FilledButton(onPressed: onTap, child: Text(text))
            : OutlinedButton(onPressed: onTap, child: Text(text)),
      ),
    );
  }

  String _winnerTitle() {
    final int w = _world.winner;
    if (w < 0) {
      return 'تعادل 🤝';
    }
    if (_mode == GameMode.teams) {
      return w == 0 ? 'فاز الفريق الأزرق 🏆' : 'فاز الفريق الأحمر 🏆';
    }
    final Fighter f = _world.players[w < _world.players.length ? w : 0];
    final String name = f.profile?.name ?? 'لاعب';
    return 'فاز $name 🏆';
  }

  Widget _resultOverlay() {
    String title;
    String subtitle = '';
    final bool won = _shown == WorldStatus.won;
    if (won) {
      title = _hasNext ? 'نجحت المرحلة ✅' : 'أنهيت كل الكوابيس 🎉';
      subtitle = _hasNext ? 'فُتحت المرحلة التالية' : 'أحسنت!';
    } else if (_shown == WorldStatus.lost) {
      title = 'خسرت 💀';
      subtitle = 'حاول مرة أخرى';
    } else {
      title = _winnerTitle();
    }

    final List<Widget> buttons = <Widget>[];
    if (_isGuest) {
      buttons.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('بانتظار المضيف...'),
        ),
      );
    } else {
      if (won && _hasNext) {
        buttons.add(_overlayButton('المرحلة التالية', _next, main: true));
        buttons.add(_overlayButton('إعادة المرحلة', _retry));
      } else if (_shown == WorldStatus.pvpOver) {
        buttons.add(_overlayButton('جولة جديدة', _retry, main: true));
      } else if (!won) {
        buttons.add(_overlayButton('إعادة المحاولة', _retry, main: true));
      }
    }
    buttons.add(_overlayButton('القائمة الرئيسية', _exitToMenu));

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.65),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 10),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFFFCC80),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ...buttons,
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _confirmExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: GamePainter(
                  world: _world,
                  rs: _rs,
                  focusIndex: _focus,
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 16,
              child: ArrowPad(onChanged: _setArrows),
            ),
            Positioned(
              right: 18,
              bottom: 16,
              child: _actionButtons(),
            ),
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _confirmExit,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.45),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (_shown != WorldStatus.playing) _resultOverlay(),
          ],
        ),
      ),
    );
  }
}
