import 'dart:convert';

import 'package:flutter/material.dart';

import '../game/level.dart';
import '../game/profile.dart';
import '../game/save.dart';
import '../game/world.dart';
import '../net/net_link.dart';
import 'game_screen.dart';

enum _Stage { choose, hosting, joining }

/// غرفة الانتظار: إنشاء حفلة (مضيف) أو الانضمام إليها (ضيف)، حتى 6 لاعبين.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  _Stage _stage = _Stage.choose;
  HostHub? _hub;
  ClientLink? _client;
  List<String> _ips = <String>[];
  bool _busy = false;
  String? _error;
  GameMode _mode = GameMode.coop;
  int _level = 0;

  // الضيف
  List<RosterEntry> _guestRoster = <RosterEntry>[];
  int _myIndex = 0;

  final TextEditingController _ipCtrl =
      TextEditingController(text: '192.168.43.1');

  @override
  void dispose() {
    _hub?.close();
    _client?.close();
    _ipCtrl.dispose();
    super.dispose();
  }

  String _modeName(GameMode m) {
    switch (m) {
      case GameMode.coop:
        return 'تعاون ضد الأعداء';
      case GameMode.ffa:
        return 'مواجهة حرة';
      case GameMode.teams:
        return 'فرق (3 ضد 3)';
    }
  }

  int get _maxLevel =>
      _mode == GameMode.coop ? Save.instance.unlocked : Level.arenaCount - 1;

  // ---------------- المضيف ----------------

  Future<void> _startHost() async {
    setState(() {
      _stage = _Stage.hosting;
      _busy = true;
      _error = null;
    });
    final HostHub hub = HostHub();
    hub.hostProfile = Save.instance.profile.copy();
    try {
      await hub.start();
      final List<String> ips = await HostHub.localAddresses();
      hub.onChanged = () {
        if (mounted) {
          setState(() {});
        }
      };
      if (!mounted) {
        hub.close();
        return;
      }
      setState(() {
        _hub = hub;
        _ips = ips;
        _busy = false;
      });
    } catch (e) {
      hub.close();
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = _Stage.choose;
          _error = 'تعذر إنشاء الحفلة. تأكد أن الواي فاي أو نقطة الاتصال تعمل.';
        });
      }
    }
  }

  bool get _canStart {
    final HostHub? hub = _hub;
    if (hub == null || hub.peers.isEmpty) {
      return false;
    }
    if (_mode == GameMode.teams) {
      int a = 0;
      int b = 0;
      for (int i = 0; i < hub.playerCount; i++) {
        if (hub.teams[i] == 0) {
          a++;
        } else {
          b++;
        }
      }
      return a > 0 && b > 0;
    }
    return true;
  }

  void _startGame() {
    final HostHub? hub = _hub;
    if (hub == null || !_canStart) {
      return;
    }
    final List<RosterEntry> roster = hub.roster();
    hub.sendLevel(_mode, _level);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => GameScreen(
          role: GameRole.host,
          mode: _mode,
          levelIndex: _level,
          roster: roster,
          hub: hub,
        ),
      ),
    );
  }

  // ---------------- الضيف ----------------

  Future<void> _connect() async {
    final String ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _error = 'اكتب عنوان المضيف';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ClientLink link = ClientLink();
    try {
      await link.connect(ip, Save.instance.profile);
    } catch (e) {
      link.close();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'تعذر الاتصال. تأكد من العنوان ومن أنكما على الشبكة نفسها.';
        });
      }
      return;
    }
    if (!mounted) {
      link.close();
      return;
    }
    link.onClosed = () {
      if (mounted) {
        setState(() {
          _client = null;
          _guestRoster = <RosterEntry>[];
          _error = 'انقطع الاتصال بالمضيف';
        });
      }
    };
    link.onLine = (String line) => _onGuestLine(link, line);
    setState(() {
      _client = link;
      _busy = false;
    });
  }

  void _onGuestLine(ClientLink link, String line) {
    if (!mounted) {
      return;
    }
    final int i = line.indexOf('|');
    final String cmd = i < 0 ? line : line.substring(0, i);
    final String arg = i < 0 ? '' : line.substring(i + 1);

    if (cmd == 'A') {
      final int? idx = int.tryParse(arg);
      if (idx != null) {
        setState(() {
          _myIndex = idx;
        });
      }
    } else if (cmd == 'R') {
      try {
        final dynamic m = jsonDecode(arg);
        if (m is Map<String, dynamic>) {
          final List<RosterEntry> r =
              RosterEntry.fromJson(m['r'] as List<dynamic>);
          setState(() {
            _guestRoster = r;
          });
        }
      } catch (_) {}
    } else if (cmd == 'F') {
      link.close();
      setState(() {
        _client = null;
        _error = 'الحفلة ممتلئة أو بدأت اللعب بالفعل';
      });
    } else if (cmd == 'Q') {
      link.close();
      setState(() {
        _client = null;
        _guestRoster = <RosterEntry>[];
        _error = 'أغلق المضيف الحفلة';
      });
    } else if (cmd == 'L') {
      try {
        final dynamic m = jsonDecode(arg);
        if (m is Map<String, dynamic>) {
          final int mi = (m['m'] as num).toInt();
          final int lv = (m['l'] as num).toInt();
          final List<RosterEntry> r =
              RosterEntry.fromJson(m['r'] as List<dynamic>);
          if (mi >= 0 && mi < GameMode.values.length && r.isNotEmpty) {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext ctx) => GameScreen(
                  role: GameRole.guest,
                  mode: GameMode.values[mi],
                  levelIndex: lv,
                  roster: r,
                  myIndex: _myIndex,
                  link: link,
                ),
              ),
            );
          }
        }
      } catch (_) {}
    }
  }

  // ---------------- الواجهة ----------------

  Widget _bigButton(String text, VoidCallback? onTap, {bool main = true}) {
    return SizedBox(
      width: 260,
      height: 48,
      child: main
          ? FilledButton(onPressed: onTap, child: Text(text))
          : FilledButton.tonal(onPressed: onTap, child: Text(text)),
    );
  }

  Widget _chooseView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'اللعب الجماعي عبر الواي فاي',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'حتى 6 لاعبين • لاعب يفتح نقطة اتصال والبقية يتصلون بها',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _bigButton('إنشاء حفلة', _startHost),
            const SizedBox(height: 10),
            _bigButton(
              'الانضمام لحفلة',
              () => setState(() {
                _stage = _Stage.joining;
                _error = null;
              }),
              main: false,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF8A80)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rosterTile(int i, RosterEntry e, {bool hostControls = false}) {
    final HostHub? hub = _hub;
    Widget? trailing;
    if (_mode == GameMode.teams && hub != null) {
      final bool blue = e.team == 0;
      trailing = hostControls
          ? TextButton(
              onPressed: () {
                setState(() {
                  hub.teams[i] = blue ? 1 : 0;
                  hub.sendRoster();
                });
              },
              child: Text(
                blue ? '🔵 الأزرق' : '🔴 الأحمر',
              ),
            )
          : Text(blue ? '🔵 الأزرق' : '🔴 الأحمر');
    }
    return ListTile(
      dense: true,
      leading: Text(i == 0 ? '👑' : '🎮', style: const TextStyle(fontSize: 20)),
      title: Text(e.profile.name),
      subtitle: Text(e.profile.outfitSummary()),
      trailing: trailing,
    );
  }

  Widget _hostView() {
    final HostHub? hub = _hub;
    final List<RosterEntry> roster =
        hub == null ? <RosterEntry>[] : hub.roster();
    if (_level > _maxLevel) {
      _level = _maxLevel;
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                const Text(
                  'حفلتك جاهزة 🎉',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_busy)
                  const CircularProgressIndicator()
                else ...<Widget>[
                  const Text('اطلب من اللاعبين كتابة هذا العنوان عند الانضمام:'),
                  const SizedBox(height: 6),
                  if (_ips.isEmpty)
                    const Text(
                      'لم يتم العثور على عنوان. فعّل نقطة الاتصال أو الواي فاي.',
                      style: TextStyle(color: Color(0xFFFF8A80)),
                    )
                  else
                    for (final String ip in _ips)
                      SelectableText(
                        ip,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFEB3B),
                        ),
                      ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final GameMode m in GameMode.values)
                        ChoiceChip(
                          label: Text(_modeName(m)),
                          selected: _mode == m,
                          onSelected: (bool v) => setState(() {
                            _mode = m;
                            if (_level > _maxLevel) {
                              _level = _maxLevel;
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      IconButton(
                        onPressed: _level > 0
                            ? () => setState(() {
                                  _level--;
                                })
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        _mode == GameMode.coop
                            ? 'المرحلة ${_level + 1}'
                            : 'الحلبة ${_level + 1}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        onPressed: _level < _maxLevel
                            ? () => setState(() {
                                  _level++;
                                })
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  _bigButton('ابدأ اللعبة', _canStart ? _startGame : null),
                  if (hub != null && hub.peers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'بانتظار انضمام لاعب واحد على الأقل...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  if (_mode == GameMode.teams && !_canStart && hub != null && hub.peers.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'يجب أن يكون في كل فريق لاعب واحد على الأقل',
                        style: TextStyle(color: Color(0xFFFF8A80)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          width: 250,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  'اللاعبون (${roster.length}/6)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    for (int i = 0; i < roster.length; i++)
                      _rosterTile(i, roster[i], hostControls: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _joinView() {
    final ClientLink? c = _client;
    final bool connected = c != null && c.connected;
    return Row(
      children: <Widget>[
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'الانضمام لحفلة',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اتصل بالواي فاي أو نقطة اتصال المضيف، ثم اكتب العنوان الذي يظهر عنده.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipCtrl,
                      enabled: !connected,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(fontSize: 22),
                      decoration: InputDecoration(
                        labelText: 'عنوان المضيف',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_busy)
                      const CircularProgressIndicator()
                    else if (connected)
                      const Text(
                        '✅ تم الاتصال. بانتظار المضيف ليبدأ اللعبة...',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF69F0AE), fontSize: 16),
                      )
                    else
                      _bigButton('اتصال', _connect),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFF8A80)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (connected)
          SizedBox(
            width: 250,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(
                    'اللاعبون (${_guestRoster.length}/6)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      for (int i = 0; i < _guestRoster.length; i++)
                        _rosterTile(i, _guestRoster[i]),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_stage) {
      case _Stage.choose:
        body = _chooseView();
        break;
      case _Stage.hosting:
        body = _hostView();
        break;
      case _Stage.joining:
        body = _joinView();
        break;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الكوابيس')),
      body: SafeArea(child: body),
    );
  }
}
