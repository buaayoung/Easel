import 'package:flutter/material.dart';

import '../api/easel_api.dart';

/// P2 surface: video production entry — checks remotion/ffmpeg readiness then
/// points users at skill invocation via chat / future dedicated APIs.
class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.api});

  final EaselApi api;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  bool _loading = true;
  String? _error;
  Map<String, String> _status = {};

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.envTools(refresh: true);
      final tools = (data['tools'] as List? ?? []).whereType<Map>();
      final want = {'ffmpeg', 'node', 'rmdeps', 'shell', 'fw', 'model'};
      final map = <String, String>{};
      for (final t in tools) {
        final id = '${t['id']}';
        if (want.contains(id)) {
          map[id] = '${t['state']}${t['version'] != null ? ' · ${t['version']}' : ''}';
        }
      }
      setState(() {
        _status = map;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _check, child: const Text('重试')),
          ],
        ),
      );
    }

    final ready = (_status['ffmpeg'] ?? '').startsWith('ok') &&
        (_status['node'] ?? '').startsWith('ok');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('视频生产', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          ready
              ? '核心运行时已就绪。可在「对话」中调用 video-production 技能，或继续完善专用流水线页。'
              : '缺少 ffmpeg/node 等内置工具，请先确认 sidecar vendor 已正确打包。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        ..._status.entries.map(
          (e) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              e.value.startsWith('ok') ? Icons.check_circle : Icons.warning_amber,
              color: e.value.startsWith('ok') ? Colors.green : Colors.orange,
            ),
            title: Text(e.key),
            subtitle: Text(e.value),
          ),
        ),
        const SizedBox(height: 16),
        if ((_status['model'] ?? '').startsWith('ok') != true)
          FilledButton.tonal(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请到「环境」页下载 Whisper 模型（约 3GB）')),
              );
            },
            child: const Text('需要本地转录？去下载 Whisper 模型'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _check, child: const Text('重新检测')),
      ],
    );
  }
}
