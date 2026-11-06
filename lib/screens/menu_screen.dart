import 'package:flutter/material.dart';

import 'level_select_screen.dart';
import 'lobby_screen.dart';
import 'profile_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  void _help(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('طريقة اللعب'),
          content: const SingleChildScrollView(
            child: Text(
              'التحكم:\n'
              '• السهمان في اليسار: الحركة يميناً ويساراً.\n'
              '• قفز: للقفز فوق العقبات.\n'
              '• لكم وركل: اضغط عدة مرات متتالية لتنفيذ 3 حركات مختلفة (كومبو).\n'
              '• فنون: ركلة دوّارة قوية تضرب من الجهتين (تحتاج انتظاراً بين كل مرة).\n\n'
              'الهدف: اهزم كل الأعداء في المرحلة، وتجنّب المسامير. '
              'كل 5 مراحل يظهر زعيم. وكل فوز يفتح المرحلة التالية.\n\n'
              'اللعب الجماعي عبر الواي فاي:\n'
              '1) أحد اللاعبين يفتح نقطة اتصال (Hotspot) في هاتفه.\n'
              '2) اللاعب الثاني يتصل بها من إعدادات الواي فاي.\n'
              '3) المضيف يضغط «إنشاء حفلة» فيظهر له عنوان IP.\n'
              '4) الضيف يضغط «الانضمام لحفلة» ويكتب العنوان.\n'
              '5) المضيف يختار تعاون أو مواجهة حرة أو فرق (3 ضد 3) ثم يبدأ اللعبة.\n'
              '6) يمكن أن يشارك حتى 6 لاعبين.\n\n'
              'ملاحظة: اللاعبان يجب أن يكونا على الشبكة نفسها.',
              style: TextStyle(height: 1.6),
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('حسناً'),
            ),
          ],
        );
      },
    );
  }

  Widget _btn(String text, VoidCallback onTap, {bool main = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        width: 260,
        height: 46,
        child: main
            ? FilledButton(onPressed: onTap, child: Text(text))
            : FilledButton.tonal(onPressed: onTap, child: Text(text)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset('assets/cover.png', fit: BoxFit.cover),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: <Color>[Color(0xEE000000), Color(0x33000000)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'الكوابيس',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: <Shadow>[
                          Shadow(color: Color(0xFFFF1744), blurRadius: 18),
                          Shadow(color: Colors.black, blurRadius: 6),
                        ],
                      ),
                    ),
                    const Text(
                      'لعبة قتال 2D - حتى 6 لاعبين عبر الواي فاي',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    _btn(
                      'لعب فردي',
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) =>
                              const LevelSelectScreen(),
                        ),
                      ),
                      main: true,
                    ),
                    _btn(
                      'لعب جماعي (واي فاي)',
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) => const LobbyScreen(),
                        ),
                      ),
                    ),
                    _btn(
                      'شخصيتي (الاسم والأزياء)',
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) => const ProfileScreen(),
                        ),
                      ),
                    ),
                    _btn('طريقة اللعب', () => _help(context)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
