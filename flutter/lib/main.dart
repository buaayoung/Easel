import 'package:flutter/material.dart';

import 'shell/app_controller.dart';
import 'shell/app_shell.dart';
import 'theme/easel_theme.dart';
import 'theme/theme_controller.dart';

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
  final ThemeController _theme = ThemeController();

  /// Stable ThemeData — never rebuild (avoids mutating global palette mid-frame).
  static final ThemeData _light = buildEaselTheme(Brightness.light);
  static final ThemeData _dark = buildEaselTheme(Brightness.dark);

  @override
  void initState() {
    super.initState();
    _controller.boot();
    _theme.load();
  }

  @override
  void dispose() {
    _controller.shutdown();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme changes rebuild MaterialApp only; controller changes stay under home.
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) {
        return MaterialApp(
          title: 'Unisyn',
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          themeMode: _theme.themeMode,
          themeAnimationDuration: Duration.zero,
          builder: (context, child) {
            final palette = EaselPalette.of(context);
            EaselColors.bind(palette);
            return KeyedSubtree(
              key: ValueKey<bool>(palette.isDark),
              child: ColoredBox(
                color: palette.bg,
                child: DefaultTextStyle(
                  style: TextStyle(color: palette.text, fontSize: 14, height: 1.6),
                  child: IconTheme(
                    data: IconThemeData(color: palette.textSecondary),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          home: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Scaffold(
                backgroundColor: Colors.transparent,
                body: _body(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _body() {
    if (_controller.booting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
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
                Icon(Icons.error_outline, size: 48, color: EaselColors.red),
                const SizedBox(height: 12),
                Text(
                  _controller.bootError ?? '未知错误',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: EaselColors.text),
                ),
                const SizedBox(height: 8),
                Text(
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
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: EaselColors.textSecondary),
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

    return AppShell(controller: _controller, theme: _theme);
  }
}
