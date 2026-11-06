import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../game/profile.dart';
import '../game/world.dart';

/// المنفذ الذي تستخدمه اللعبة على الشبكة المحلية.
const int kGamePort = 45678;

/// قناة اتصال نصية بين جهازين (كل رسالة سطر واحد).
abstract class NetLink {
  void Function(String line)? _onLine;
  void Function()? onClosed;
  final List<String> _pending = <String>[];
  bool closed = false;

  Socket? _socket;
  StreamSubscription<String>? _sub;

  /// عند تعيين المستقبِل تُسلَّم إليه الرسائل التي وصلت قبل تعيينه.
  set onLine(void Function(String line)? cb) {
    _onLine = cb;
    if (cb != null && _pending.isNotEmpty) {
      final List<String> list = List<String>.from(_pending);
      _pending.clear();
      for (final String l in list) {
        cb(l);
      }
    }
  }

  void _deliver(String line) {
    final void Function(String line)? cb = _onLine;
    if (cb == null) {
      _pending.add(line);
      if (_pending.length > 50) {
        _pending.removeAt(0);
      }
    } else {
      cb(line);
    }
  }

  void attach(Socket socket) {
    closed = false;
    _socket = socket;
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    _sub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      _deliver,
      onDone: _handleDone,
      onError: (Object e) {
        _handleDone();
      },
      cancelOnError: true,
    );
  }

  void _handleDone() {
    if (closed) {
      return;
    }
    closed = true;
    final void Function()? cb = onClosed;
    _cleanup();
    if (cb != null) {
      cb();
    }
  }

  void send(String line) {
    final Socket? s = _socket;
    if (s == null || closed) {
      return;
    }
    try {
      s.write('$line\n');
    } catch (_) {}
  }

  bool get connected => _socket != null && !closed;

  void _cleanup() {
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
  }

  void close() {
    closed = true;
    onClosed = null;
    _onLine = null;
    _cleanup();
  }
}

/// اتصال ضيف بالمضيف.
class ClientLink extends NetLink {
  Future<void> connect(String ip, PlayerProfile profile) async {
    final Socket s = await Socket.connect(
      ip,
      kGamePort,
      timeout: const Duration(seconds: 6),
    );
    attach(s);
    send('H|${profile.encode()}');
  }
}

/// اتصال المضيف بضيف واحد.
class PeerLink extends NetLink {
  PlayerProfile profile = PlayerProfile();
}

/// المضيف: يستقبل حتى 5 ضيوف (ليصبح المجموع 6 لاعبين).
class HostHub {
  static const int maxPeers = 5;

  ServerSocket? _server;
  final List<PeerLink> peers = <PeerLink>[];
  PlayerProfile hostProfile = PlayerProfile();

  /// فريق كل لاعب حسب رقمه (0 أو 1).
  final List<int> teams = <int>[0, 1, 0, 1, 0, 1];
  bool inGame = false;

  /// تغيّرت قائمة اللاعبين (للغرفة).
  void Function()? onChanged;

  /// وصلت رسالة من لاعب أثناء اللعب.
  void Function(int index, String line)? onGameLine;

  /// انقطع لاعب أثناء اللعب.
  void Function(int index)? onPeerLeft;

  int get playerCount => peers.length + 1;

  List<RosterEntry> roster() {
    final List<RosterEntry> out = <RosterEntry>[
      RosterEntry(hostProfile, teams[0]),
    ];
    for (int i = 0; i < peers.length; i++) {
      out.add(RosterEntry(peers[i].profile, teams[i + 1]));
    }
    return out;
  }

  Future<void> start() async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      kGamePort,
      shared: true,
    );
    _server = server;
    server.listen(
      (Socket s) {
        if (peers.length >= maxPeers || inGame) {
          try {
            s.write('F\n');
            s.flush().whenComplete(() {
              s.destroy();
            });
          } catch (_) {
            s.destroy();
          }
          return;
        }
        final PeerLink p = PeerLink();
        p.attach(s);
        peers.add(p);
        p.onLine = (String line) => _onLine(p, line);
        p.onClosed = () => _onClosed(p);
        sendRoster();
        final void Function()? cb = onChanged;
        if (cb != null) {
          cb();
        }
      },
      onError: (Object e) {},
    );
  }

  /// عناوين هذا الجهاز على الشبكة (تظهر للاعبين ليكتبوها).
  static Future<List<String>> localAddresses() async {
    final List<String> out = <String>[];
    try {
      final List<NetworkInterface> list = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final NetworkInterface ni in list) {
        for (final InternetAddress a in ni.addresses) {
          out.add(a.address);
        }
      }
    } catch (_) {}
    return out;
  }

  void broadcast(String line) {
    for (final PeerLink p in peers) {
      p.send(line);
    }
  }

  /// يرسل لكل ضيف رقمه، ثم يبث قائمة اللاعبين للجميع.
  void sendRoster() {
    for (int i = 0; i < peers.length; i++) {
      peers[i].send('A|${i + 1}');
    }
    final String json = jsonEncode(<String, dynamic>{
      'r': RosterEntry.toJson(roster()),
    });
    broadcast('R|$json');
  }

  /// يبدأ مرحلة (أو يعيدها) ويبلغ الجميع.
  void sendLevel(GameMode mode, int level) {
    inGame = true;
    final String json = jsonEncode(<String, dynamic>{
      'm': mode.index,
      'l': level,
      'r': RosterEntry.toJson(roster()),
    });
    broadcast('L|$json');
  }

  void _onLine(PeerLink p, String line) {
    final int i = line.indexOf('|');
    final String cmd = i < 0 ? line : line.substring(0, i);
    final String arg = i < 0 ? '' : line.substring(i + 1);
    if (cmd == 'H') {
      p.profile = PlayerProfile.decode(arg);
      sendRoster();
      final void Function()? cb = onChanged;
      if (cb != null) {
        cb();
      }
    } else if (cmd == 'Q') {
      _onClosed(p);
      p.close();
    } else if (inGame) {
      final int idx = peers.indexOf(p) + 1;
      if (idx > 0) {
        final void Function(int index, String line)? cb = onGameLine;
        if (cb != null) {
          cb(idx, line);
        }
      }
    }
  }

  void _onClosed(PeerLink p) {
    final int idx = peers.indexOf(p) + 1;
    if (idx <= 0) {
      return;
    }
    if (inGame) {
      final void Function(int index)? cb = onPeerLeft;
      if (cb != null) {
        cb(idx);
      }
    } else {
      peers.remove(p);
      sendRoster();
      final void Function()? cb = onChanged;
      if (cb != null) {
        cb();
      }
    }
  }

  void close() {
    for (final PeerLink p in peers) {
      p.send('Q');
      p.close();
    }
    peers.clear();
    onChanged = null;
    onGameLine = null;
    onPeerLeft = null;
    try {
      _server?.close();
    } catch (_) {}
    _server = null;
  }
}
