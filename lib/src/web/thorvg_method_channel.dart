import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'thorvg_platform_interface.dart';

/// An implementation of [ThorvgPlatform] that uses method channels.
class MethodChannelThorvg extends ThorvgPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('thorvg');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
