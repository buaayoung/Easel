import 'package:flutter/material.dart';

import 'shell/app_controller.dart';
import 'shell/app_shell.dart';
import 'theme/easel_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EaselApp());
}

class EaselApp extends StatefulWidget {
  const EaselApp({super.key});

  @override
  State<EaselApp> createState() => _EaselAppState();
}

class _EaselAppState extends State<EaselApp> {
  final AppController _controller = AppController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.boot();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easel',
      debugShowCheckedModeBanner: false,
      theme: buildEaselTheme(),
      home: Scaffold(
        // 让主区纸感径向背景透出来，避免 Scaffold 纯白盖住氛围层
        backgroundColor: EaselColors.bg,
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_controller.booting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在启动本地 FastAPI sidecar…', style: TextStyle(color: EaselColors.textSecondary)),
          ],
        ),
      );
    }
    if (_controller.bootError != null || _controller.api == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: EaselColors.red),
                const SizedBox(height: 12),
                Text(
                  _controller.bootError ?? '未知错误',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: EaselColors.text),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请先运行 scripts/bundle_sidecar.sh，或设置 EASEL_VENDOR_ROOT。',
                  style: TextStyle(color: EaselColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _controller.boot,
                  child: const Text('重试'),
                ),
                if (_controller.launcher != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: SingleChildScrollView(
                      child: Text(
                        _controller.launcher!.logText,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: EaselColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return AppShell(controller: _controller);
  }
}
