import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class Env {
  Env._();

  /// Base URL del backend Django.
  /// - Web: 127.0.0.1 (mismo host)
  /// - Android emulador: 10.0.2.2 (loopback del host)
  /// - Resto: 127.0.0.1
  static String get apiBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }
}
