import 'package:flutter/material.dart';

/// زر يُضغط ويُترك، يدعم اللمس المتعدد (كل زر يستمع بشكل مستقل).
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onChanged,
    this.size = 62,
  });

  final String emoji;
  final String label;
  final Color color;
  final double size;
  final ValueChanged<bool> onChanged;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) {
      return;
    }
    setState(() {
      _down = v;
    });
    widget.onChanged(v);
  }

  @override
  void dispose() {
    if (_down) {
      widget.onChanged(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent e) => _set(true),
      onPointerUp: (PointerUpEvent e) => _set(false),
      onPointerCancel: (PointerCancelEvent e) => _set(false),
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: <Color>[widget.color.withOpacity(_down ? 1 : 0.85), Colors.black.withOpacity(0.82)]),
          boxShadow: <BoxShadow>[BoxShadow(color: widget.color.withOpacity(_down ? 0.85 : 0.45), blurRadius: _down ? 20 : 11, spreadRadius: 1)],
          border: Border.all(
            color: Colors.white.withOpacity(_down ? 0.9 : 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(widget.emoji, style: TextStyle(fontSize: s * 0.36)),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: s * 0.18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// سهما اليمين واليسار في لوحة واحدة: يمكن تحريك الإصبع بينهما.
class ArrowPad extends StatefulWidget {
  const ArrowPad({
    super.key,
    required this.onChanged,
    this.width = 170,
    this.height = 76,
  });

  final void Function(bool left, bool right) onChanged;
  final double width;
  final double height;

  @override
  State<ArrowPad> createState() => _ArrowPadState();
}

class _ArrowPadState extends State<ArrowPad> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  bool _left = false;
  bool _right = false;

  void _recalc() {
    bool l = false;
    bool r = false;
    final double half = widget.width / 2;
    for (final Offset o in _pointers.values) {
      if (o.dx < half) {
        l = true;
      } else {
        r = true;
      }
    }
    if (l != _left || r != _right) {
      setState(() {
        _left = l;
        _right = r;
      });
      widget.onChanged(l, r);
    }
  }

  @override
  void dispose() {
    if (_left || _right) {
      widget.onChanged(false, false);
    }
    super.dispose();
  }

  Widget _arrow(bool active, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(active ? 0.55 : 0.2),
          border: Border.all(
            color: Colors.white.withOpacity(active ? 0.9 : 0.5),
            width: 2,
          ),
        ),
        child: Icon(icon, size: 44, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (PointerDownEvent e) {
        _pointers[e.pointer] = e.localPosition;
        _recalc();
      },
      onPointerMove: (PointerMoveEvent e) {
        _pointers[e.pointer] = e.localPosition;
        _recalc();
      },
      onPointerUp: (PointerUpEvent e) {
        _pointers.remove(e.pointer);
        _recalc();
      },
      onPointerCancel: (PointerCancelEvent e) {
        _pointers.remove(e.pointer);
        _recalc();
      },
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: <Widget>[
              _arrow(_left, Icons.chevron_left),
              _arrow(_right, Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
