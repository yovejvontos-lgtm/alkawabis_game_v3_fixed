import 'package:flutter/material.dart';

import '../game/level.dart';
import '../game/profile.dart';
import '../game/save.dart';
import '../game/world.dart';
import 'game_screen.dart';

/// اختيار المرحلة: المراحل مقفلة وتُفتح الواحدة تلو الأخرى بالفوز.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  void _play(BuildContext context, int i) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => GameScreen(
          role: GameRole.solo,
          mode: GameMode.coop,
          levelIndex: i,
          roster: <RosterEntry>[
            RosterEntry(Save.instance.profile.copy(), 0),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختر المرحلة')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Save.instance,
          builder: (BuildContext context, Widget? child) {
            final int unlocked = Save.instance.unlocked;
            return GridView.count(
              padding: const EdgeInsets.all(14),
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: <Widget>[
                for (int i = 0; i < Level.campaignCount; i++)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: i > unlocked
                          ? const Color(0xFF263238)
                          : (i % 5 == 4
                              ? const Color(0xFF8E24AA)
                              : const Color(0xFF37474F)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      if (i > unlocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('أكمل المرحلة السابقة أولاً لتفتح هذه'),
                          ),
                        );
                        return;
                      }
                      _play(context, i);
                    },
                    child: Text(
                      i > unlocked
                          ? '🔒'
                          : (i % 5 == 4 ? '${i + 1} 👑' : '${i + 1}'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
