import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'thorvg_method_channel.dart';

abstract class ThorvgPlatform extends PlatformInterface {
  /// Constructs a ThorvgPlatform.
  ThorvgPlatform() : super(token: _token);

  static final Object _token = Object();

  static ThorvgPlatform _instance = MethodChannelThorvg();

  /// The default instance of [ThorvgPlatform] to use.
  ///
  /// Defaults to [MethodChannelThorvg].
  static ThorvgPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ThorvgPlatform] when
  /// they register themselves.
  static set instance(ThorvgPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
