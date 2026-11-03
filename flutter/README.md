# Easel Flutter host

桌面 UI：启动时拉起本地 FastAPI sidecar（`web/app.py`），功能页通过 `/api/*` 调工具。

## 前置

```bash
# 在仓库根目录组装 vendor（体积大；开发可用 SKIP_DOWNLOAD=1 链系统 node/ffmpeg）
./scripts/bundle_sidecar.sh
# 或
SKIP_DOWNLOAD=1 ./scripts/bundle_sidecar.sh
```

可选：`export EASEL_VENDOR_ROOT=/绝对路径/dist/sidecar`

## 运行（macOS）

```bash
cd flutter
flutter pub get
flutter run -d macos
```

## 打进 .app

```bash
./scripts/bundle_sidecar.sh
./scripts/embed_sidecar_macos.sh
cd flutter && flutter build macos
```

`embed_sidecar_macos.sh` 把 `dist/sidecar` 拷到 `macos/Runner/Resources/sidecar`，构建后位于 `Contents/Resources/sidecar`。

## 页面

| 页 | 能力 |
|----|------|
| 对话 | `POST /api/chat` |
| 视频 | 体检 ffmpeg/node/remotion；模型引导去环境页 |
| 环境 | `GET /api/env/tools`；打包态仅允许按需装（如 Whisper `model`） |
