import 'package:flutter/foundation.dart';

import 'api/easel_api.dart';
import 'sidecar/paths.dart';
import 'sidecar/sidecar_launcher.dart';

class AppState extends ChangeNotifier {
  EaselPaths? paths;
  SidecarLauncher? launcher;
  EaselApi? api;
  String? bootError;
  bool booting = true;

  Future<void> boot() async {
    booting = true;
    bootError = null;
    notifyListeners();
    try {
      paths = await EaselPaths.resolve();
      launcher = SidecarLauncher(paths!);
      await launcher!.start();
      if (launcher!.state != SidecarState.ready) {
        bootError = launcher!.lastError ?? 'sidecar 启动失败';
      } else {
        api = EaselApi(launcher!.baseUrl);
      }
    } catch (e) {
      bootError = '$e';
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> shutdown() async {
    await launcher?.stop();
  }
}
