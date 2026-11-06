import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/fighter.dart';
import '../game/profile.dart';
import '../game/save.dart';
import '../game/stickman.dart';

/// شاشة «شخصيتي»: الاسم، الأزياء العلوية والسفلية والكاملة، والألوان.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late PlayerProfile _p;
  final TextEditingController _name = TextEditingController();
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  late final Fighter _dummy;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  FState _preview = FState.idle;

  @override
  void initState() {
    super.initState();
    _p = Save.instance.profile.copy();
    _name.text = _p.name;
    _dummy = Fighter(id: 0, kind: 0, x: 0, y: 0, maxHp: 1);
    _ticker = createTicker((Duration e) {
      final double dt = (e - _last).inMicroseconds / 1000000.0;
      _last = e;
      _time.value += dt > 0.05 ? 0.05 : dt;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    _name.dispose();
    _persist();
    super.dispose();
  }

  void _persist() {
    final PlayerProfile out = _p.copy();
    out.name = PlayerProfile.cleanName(_name.text);
    Save.instance.saveProfile(out);
  }

  void _change(void Function() fn) {
    setState(fn);
    _persist();
  }

  Widget _palette(int current, void Function(int) onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int c in Outfits.palette)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: current == c ? Colors.white : Colors.white24,
                  width: current == c ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chips(
    List<String> names,
    int selected,
    void Function(int) onPick, {
    bool withNone = false,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        if (withNone)
          ChoiceChip(
            label: const Text('بدون'),
            selected: selected < 0,
            onSelected: (bool v) => onPick(-1),
          ),
        for (int i = 0; i < names.length; i++)
          ChoiceChip(
            label: Text(names[i]),
            selected: selected == i,
            onSelected: (bool v) => onPick(i),
          ),
      ],
    );
  }

  Widget _topTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _chips(
            Outfits.tops,
            _p.full >= 0 ? -2 : _p.top,
            (int i) => _change(() {
              _p.top = i;
              _p.full = -1;
            }),
          ),
          const SizedBox(height: 10),
          const Text('اللون'),
          const SizedBox(height: 6),
          _palette(
            _p.topColor,
            (int c) => _change(() {
              _p.topColor = c;
              _p.full = -1;
            }),
          ),
        ],
      ),
    );
  }

  Widget _bottomTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _chips(
            Outfits.bottoms,
            _p.full >= 0 ? -2 : _p.bottom,
            (int i) => _change(() {
              _p.bottom = i;
              _p.full = -1;
            }),
          ),
          const SizedBox(height: 10),
          const Text('اللون'),
          const SizedBox(height: 6),
          _palette(
            _p.bottomColor,
            (int c) => _change(() {
              _p.bottomColor = c;
              _p.full = -1;
            }),
          ),
        ],
      ),
    );
  }


  Widget _headTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('تسريحة الشعر'),
        const SizedBox(height: 8),
        _chips(const <String>['أصلع','شعر شوكي','شعر طويل','شعر مدبب','شعر فوضوي','شعر ناعم'], _p.hair, (int i) => _change(() => _p.hair = i)),
        const SizedBox(height: 16),
        const Text('القبعات'),
        const SizedBox(height: 8),
        _chips(const <String>['قبعة قش مثل قبعة لوفي'], _p.headwear, (int i) => _change(() => _p.headwear = i), withNone: true),
      ]),
    );
  }

  Widget _fullTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'الزي الكامل يغطي الجسم كله ويحل محل العلوي والسفلي.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _chips(
            Outfits.fulls,
            _p.full,
            (int i) => _change(() {
              _p.full = i;
            }),
            withNone: true,
          ),
        ],
      ),
    );
  }

  Widget _previewButtons() {
    const List<FState> states = <FState>[
      FState.idle,
      FState.run,
      FState.punch,
      FState.kick,
    ];
    const List<String> labels = <String>['وقوف', 'جري', 'لكم', 'ركل'];
    return Wrap(
      spacing: 4,
      children: <Widget>[
        for (int i = 0; i < states.length; i++)
          ChoiceChip(
            label: Text(labels[i], style: const TextStyle(fontSize: 11)),
            selected: _preview == states[i],
            visualDensity: VisualDensity.compact,
            onSelected: (bool v) => setState(() {
              _preview = states[i];
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('شخصيتي')),
      body: SafeArea(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 210,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: TextField(
                      controller: _name,
                      maxLength: 12,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'اسم الشخصية',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String v) => _persist(),
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _PreviewPainter(
                        profile: _p,
                        dummy: _dummy,
                        time: _time,
                        state: _preview,
                      ),
                    ),
                  ),
                  _previewButtons(),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            Expanded(
              child: DefaultTabController(
                length: 4,
                child: Column(
                  children: <Widget>[
                    const TabBar(
                      tabs: <Widget>[
                        Tab(text: 'علوي'),
                        Tab(text: 'سفلي'),
                        Tab(text: 'كامل'),
                        Tab(text: 'الرأس والشعر'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: <Widget>[
                          _topTab(),
                          _bottomTab(),
                          _fullTab(),
                          _headTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.profile,
    required this.dummy,
    required this.time,
    required this.state,
  }) : super(repaint: time);

  final PlayerProfile profile;
  final Fighter dummy;
  final ValueNotifier<double> time;
  final FState state;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = time.value;
    dummy.state = state;
    dummy.comboStep = 0;
    dummy.vy = 0;
    switch (state) {
      case FState.punch:
        dummy.stateTime = (t % 0.9) / 0.9 * 0.28;
        break;
      case FState.kick:
        dummy.stateTime = (t % 1.1) / 1.1 * 0.4;
        break;
      default:
        dummy.stateTime = t;
        break;
    }
    final Pose pose = poseFor(dummy, t, t * 14);
    final double sc = size.height / 120;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.88);
    canvas.scale(sc, sc);
    drawStickman(canvas, pose, const Color(0xFF40C4FF), profile);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) => true;
}
