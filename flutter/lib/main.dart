import 'package:flutter/material.dart';

import 'app_state.dart';
import 'pages/chat_page.dart';
import 'pages/env_page.dart';
import 'pages/video_page.dart';

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
  final AppState _state = AppState();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onState);
    _state.boot();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_onState);
    _state.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6F5B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.chat_bubble_outline),
                  selectedIcon: Icon(Icons.chat_bubble),
                  label: Text('对话'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: Text('视频'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.dns_outlined),
                  selectedIcon: Icon(Icons.dns),
                  label: Text('环境'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_state.booting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在启动本地 FastAPI sidecar…'),
          ],
        ),
      );
    }
    if (_state.bootError != null || _state.api == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  _state.bootError ?? '未知错误',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '请先运行 scripts/bundle_sidecar.sh，或设置 EASEL_VENDOR_ROOT。',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _state.boot(),
                  child: const Text('重试'),
                ),
                if (_state.launcher != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: SingleChildScrollView(
                      child: Text(
                        _state.launcher!.logText,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
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

    final api = _state.api!;
    return IndexedStack(
      index: _index,
      children: [
        ChatPage(api: api),
        VideoPage(api: api),
        EnvPage(api: api),
      ],
    );
  }
}
