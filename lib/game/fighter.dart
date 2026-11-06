import 'input.dart';
import 'profile.dart';

enum FState { idle, run, jump, punch, kick, special, hurt, dead }

double round1(double v) => (v * 10).roundToDouble() / 10;
double round2(double v) => (v * 100).roundToDouble() / 100;

/// مقاتل: لاعب أو عدو. الإحداثيات: x منتصف الجسم، y مستوى القدمين.
class Fighter {
  Fighter({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.maxHp,
    this.w = 28,
    this.h = 80,
    this.speed = 190,
    this.dmgMul = 1,
    this.aggr = 1,
    this.team = 0,
  }) : hp = maxHp {
    netX = x;
    netY = y;
    px = x;
    py = y;
  }

  /// من 0 إلى 5 للاعبين، و100 فما فوق للأعداء.
  final int id;

  /// 0 لاعب، 1 عدو عادي، 2 زعيم.
  final int kind;

  double x;
  double y;
  double vx = 0;
  double vy = 0;
  int facing = 1;

  double hp;
  final double maxHp;

  final double w;
  final double h;
  final double speed;
  final double dmgMul;
  final double aggr;

  int team;
  PlayerProfile? profile;

  FState state = FState.idle;
  double stateTime = 0;
  bool onGround = true;
  bool blockedX = false;
  double invul = 0;
  double specialCd = 0;
  double hurtTime = 0.32;

  // الكومبو: رقم الضربة الحالية (0 إلى 2)
  int comboStep = 0;
  int comboKind = 0;
  double sinceAtk = 99;
  double bufPunch = 0;
  double bufKick = 0;

  final PlayerInput input = PlayerInput();
  final List<int> hitIds = <int>[];

  // ذكاء العدو
  double aiCooldown = 1.0;
  double aiJumpCd = 0;

  // الموضع في الخطوة السابقة (لتنعيم العرض)
  double px = 0;
  double py = 0;

  // أهداف التنعيم عند اللاعب الضيف
  double netX = 0;
  double netY = 0;
  double sinceSnap = 0;

  bool get isDead => state == FState.dead;
  bool get isPlayer => kind == 0;
  double get scale => h / 80.0;

  double drawX(double a) => px + (x - px) * a;
  double drawY(double a) => py + (y - py) * a;

  List<num> toList() {
    return <num>[
      round1(x),
      round1(y),
      round1(vx),
      round1(vy),
      facing,
      round1(hp),
      state.index,
      round2(stateTime),
      onGround ? 1 : 0,
      round1(specialCd),
      comboStep,
    ];
  }

  void applyList(List<dynamic> l) {
    if (l.length < 11) {
      return;
    }
    netX = (l[0] as num).toDouble();
    netY = (l[1] as num).toDouble();
    vx = (l[2] as num).toDouble();
    vy = (l[3] as num).toDouble();
    facing = (l[4] as num).toInt() >= 0 ? 1 : -1;
    hp = (l[5] as num).toDouble();
    final int si = (l[6] as num).toInt();
    if (si >= 0 && si < FState.values.length) {
      state = FState.values[si];
    }
    stateTime = (l[7] as num).toDouble();
    onGround = (l[8] as num).toInt() == 1;
    specialCd = (l[9] as num).toDouble();
    comboStep = (l[10] as num).toInt();
    sinceSnap = 0;
  }

  /// تنعيم الحركة عند الضيف: توقّع بسرعة اللاعب ثم تقريب سلس.
  void smoothGuest(double dt) {
    sinceSnap += dt;
    final double ext = sinceSnap < 0.12 ? sinceSnap : 0.12;
    final double tx = netX + vx * ext;
    final double ty = onGround ? netY : netY + vy * ext;
    final double dx = tx - x;
    final double dy = ty - y;
    if (dx.abs() > 150 || dy.abs() > 150) {
      x = tx;
      y = ty;
    } else {
      double k = dt * 14;
      if (k > 1) {
        k = 1;
      }
      x += dx * k;
      y += dy * k;
    }
    px = x;
    py = y;
  }
}
