import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class NativeVibration {
  static const MethodChannel _channel = MethodChannel('native_vibration');

  static Future<void> vibrate(int durationMs) async {
    try {
      await _channel.invokeMethod('vibrate', {'duration': durationMs});
    } on PlatformException catch (e) {
      debugPrint("Erro na vibração: ${e.message}");
    }
  }
}
