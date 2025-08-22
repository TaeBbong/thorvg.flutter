
import 'thorvg_platform_interface.dart';

class Thorvg {
  Future<String?> getPlatformVersion() {
    return ThorvgPlatform.instance.getPlatformVersion();
  }
}
