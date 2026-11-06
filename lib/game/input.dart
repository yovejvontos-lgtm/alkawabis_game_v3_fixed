/// حالة أزرار لاعب واحد. تُخزَّن الأزرار المضغوطة كأقنعة بتّات
/// حتى يسهل إرسالها عبر الشبكة.
class PlayerInput {
  static const int left = 1;
  static const int right = 2;
  static const int jump = 4;
  static const int punch = 8;
  static const int kick = 16;
  static const int special = 32;

  int held = 0;
  int just = 0;

  /// يضبط الأزرار المضغوطة حالياً، ويسجّل الأزرار التي ضُغطت للتو.
  void setMask(int mask) {
    just |= mask & ~held;
    held = mask;
  }

  bool isHeld(int bit) => (held & bit) != 0;

  /// يرجع true مرة واحدة فقط لكل ضغطة جديدة.
  bool consume(int bit) {
    final bool r = (just & bit) != 0;
    just &= ~bit;
    return r;
  }

  void clearJust() {
    just = 0;
  }

  void reset() {
    held = 0;
    just = 0;
  }
}
