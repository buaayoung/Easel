import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../api/easel_api.dart';
import '../theme/easel_theme.dart';
import '../widgets/page_scaffold.dart';

enum _PreviewKind { text, image, video, other }

const _imageExts = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'};
const _videoExts = {'.mp4', '.mov', '.webm', '.m4v'};

_PreviewKind _kindFor(String path, [String? apiKind]) {
  final k = (apiKind ?? '').toLowerCase();
  if (k == 'image' || k == 'video' || k == 'text') {
    return switch (k) {
      'image' => _PreviewKind.image,
      'video' => _PreviewKind.video,
      _ => _PreviewKind.text,
    };
  }
  final ext = p.extension(path).toLowerCase();
  if (_imageExts.contains(ext)) return _PreviewKind.image;
  if (_videoExts.contains(ext)) return _PreviewKind.video;
  if ({'.md', '.txt', '.json', '.csv', '.html', '.htm', '.srt', '.vtt'}.contains(ext)) {
    return _PreviewKind.text;
  }
  return _PreviewKind.other;
}

IconData _fileIcon(_PreviewKind kind, {required bool isDir}) {
  if (isDir) return Icons.folder_outlined;
  return switch (kind) {
    _PreviewKind.image => Icons.image_outlined,
    _PreviewKind.video => Icons.videocam_outlined,
    _PreviewKind.text => Icons.description_outlined,
    _PreviewKind.other => Icons.insert_drive_file_outlined,
  };
}

class OutputsPage extends StatefulWidget {
  const OutputsPage({super.key, required this.api, this.jumpPath});

  final EaselApi api;
  final String? jumpPath;

  @override
  State<OutputsPage> createState() => _OutputsPageState();
}

class _OutputsPageState extends State<OutputsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _roots = [];
  final List<Map<String, dynamic>> _stack = [];
  String? _previewPath;
  _PreviewKind _previewKind = _PreviewKind.text;
  String _preview = '';
  bool _previewLoading = false;
  VideoPlayerController? _video;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Future<void> _disposeVideo() async {
    final c = _video;
    _video = null;
    _videoReady = false;
    await c?.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roots = await widget.api.outputs();
      setState(() {
        _roots = roots;
        _stack.clear();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _current {
    if (_stack.isEmpty) return _roots;
    final last = _stack.last;
    final children = last['children'];
    if (children is List) {
      return children.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Future<void> _closePreview() async {
    await _disposeVideo();
    if (!mounted) return;
    setState(() {
      _previewPath = null;
      _preview = '';
      _previewKind = _PreviewKind.text;
      _previewLoading = false;
    });
  }

  Future<void> _open(Map<String, dynamic> node) async {
    final isDir = node['type'] == 'dir' || node['children'] is List;
    if (isDir) {
      setState(() => _stack.add(node));
      return;
    }
    final path = '${node['path'] ?? node['name'] ?? ''}';
    final kind = _kindFor(path, '${node['kind'] ?? ''}');
    await _disposeVideo();
    if (!mounted) return;

    if (kind == _PreviewKind.image) {
      setState(() {
        _previewPath = path;
        _previewKind = kind;
        _preview = '';
        _previewLoading = false;
      });
      return;
    }

    if (kind == _PreviewKind.video) {
      setState(() {
        _previewPath = path;
        _previewKind = kind;
        _preview = '';
        _previewLoading = true;
        _videoReady = false;
      });
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.api.mediaUrl(path)),
        );
        await controller.initialize();
        await controller.setLooping(true);
        if (!mounted || _previewPath != path) {
          await controller.dispose();
          return;
        }
        setState(() {
          _video = controller;
          _videoReady = true;
          _previewLoading = false;
        });
        await controller.play();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _previewLoading = false;
          _preview = '无法预览视频：$e';
        });
      }
      return;
    }

    if (kind == _PreviewKind.other) {
      setState(() {
        _previewPath = path;
        _previewKind = kind;
        _preview = '此文件类型暂不支持内嵌预览，可在文件目录中打开。';
        _previewLoading = false;
      });
      return;
    }

    setState(() {
      _previewPath = path;
      _previewKind = kind;
      _preview = '';
      _previewLoading = true;
    });
    try {
      final content = await widget.api.outputContent(path);
      if (!mounted || _previewPath != path) return;
      if (content['isBinary'] == true) {
        setState(() {
          _previewLoading = false;
          _previewKind = _PreviewKind.other;
          _preview = '二进制文件，可在文件目录中打开。';
        });
        return;
      }
      setState(() {
        _previewLoading = false;
        _preview = '${content['content'] ?? content['text'] ?? content}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _preview = '无法预览：$e';
      });
    }
  }

  Future<void> _delete(String path) async {
    if (_previewPath == path) await _closePreview();
    await widget.api.deleteOutput(path);
    await _load();
  }

  String get _currentRelPath {
    if (_stack.isEmpty) return '';
    final last = _stack.last;
    return '${last['path'] ?? last['name'] ?? ''}';
  }

  Future<void> _reveal([String? path]) async {
    final target = path ?? _currentRelPath;
    try {
      await widget.api.revealOutput(target);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开文件目录：$e')),
      );
    }
  }

  Widget _buildPreviewBody() {
    if (_previewLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_previewKind) {
      case _PreviewKind.image:
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.network(
              widget.api.mediaUrl(_previewPath!),
              fit: BoxFit.contain,
              errorBuilder: (_, err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('图片加载失败：$err', style: const TextStyle(fontSize: 12.5)),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        );
      case _PreviewKind.video:
        if (_preview.isNotEmpty) {
          return Center(child: Text(_preview, style: const TextStyle(fontSize: 12.5)));
        }
        if (!_videoReady || _video == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final c = _video!;
        return Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _VideoControls(controller: c),
          ],
        );
      case _PreviewKind.text:
      case _PreviewKind.other:
        return SingleChildScrollView(
          child: SelectableText(
            _preview,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '内容库',
      subtitle: '浏览与管理生成产物',
      actions: [
        IconButton(
          tooltip: '在文件目录打开',
          onPressed: _loading ? null : () => _reveal(),
          icon: const Icon(Icons.folder_open_outlined),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _stack.isEmpty
                              ? null
                              : () => setState(() {
                                    _stack.clear();
                                  }),
                          child: const Text('根目录'),
                        ),
                        for (var i = 0; i < _stack.length; i++)
                          TextButton(
                            onPressed: () => setState(() {
                              _stack.removeRange(i + 1, _stack.length);
                            }),
                            child: Text('${_stack[i]['name'] ?? _stack[i]['path'] ?? ''}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: _current.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (_, i) {
                                final n = _current[i];
                                final name = '${n['name'] ?? n['path'] ?? ''}';
                                final rel = '${n['path'] ?? name}';
                                final isDir = n['type'] == 'dir' || n['children'] is List;
                                final kind = isDir
                                    ? _PreviewKind.other
                                    : _kindFor(rel, '${n['kind'] ?? ''}');
                                return EaselCard(
                                  onTap: () => _open(n),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _fileIcon(kind, isDir: isDir),
                                        size: 18,
                                        color: EaselColors.accentStart,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(name)),
                                      IconButton(
                                        tooltip: '在文件目录打开',
                                        onPressed: () => _reveal(rel),
                                        icon: const Icon(Icons.folder_open_outlined, size: 16),
                                      ),
                                      IconButton(
                                        onPressed: () => _delete(rel),
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_previewPath != null) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              width: (_previewKind == _PreviewKind.image ||
                                      _previewKind == _PreviewKind.video)
                                  ? 480
                                  : 360,
                              child: EaselCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _previewPath!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: '在文件目录打开',
                                          onPressed: () => _reveal(_previewPath),
                                          icon: const Icon(Icons.folder_open_outlined, size: 16),
                                        ),
                                        IconButton(
                                          onPressed: _closePreview,
                                          icon: const Icon(Icons.close, size: 16),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Expanded(child: _buildPreviewBody()),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant _VideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final value = c.value;
    final pos = value.position;
    final dur = value.duration;
    final maxMs = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
    return Column(
      children: [
        Slider(
          value: pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble(),
          max: maxMs,
          onChanged: (v) => c.seekTo(Duration(milliseconds: v.round())),
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => value.isPlaying ? c.pause() : c.play(),
              icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Text(
              '${_fmt(pos)} / ${_fmt(dur)}',
              style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const Spacer(),
            IconButton(
              tooltip: value.volume == 0 ? '取消静音' : '静音',
              onPressed: () => c.setVolume(value.volume == 0 ? 1 : 0),
              icon: Icon(value.volume == 0 ? Icons.volume_off : Icons.volume_up, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
