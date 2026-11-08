# Unisyn Flutter host

桌面 UI：启动时拉起本地 FastAPI sidecar（`web/app.py`），界面布局与 Web 前端对齐（侧栏 + 工作台/对话/技能库/内容库/账号/画像 + 设置浮层），通过 `/api/*` 调用能力。

- 应用名：`Unisyn`
- Bundle ID：`com.jyyc.unisyn`

## 调试 vs 打包

| 场景 | Python / 依赖 |
|------|----------------|
| `flutter run -d macos` | 工程 **`.venv`**（uv）；模型 → 工程 **`models/`**。 |
| `PACKAGE_MODE=full`（默认） | 可重定位 CPython + 依赖打进 `.app`；模型按需下到 Application Support。 |
| `PACKAGE_MODE=host` | **轻量包**：只打源码。启动时用宿主机 `uv`/`python3`，缺 venv 则自动装到 Application Support；缺 node/ffmpeg 等会打开设置页安装。 |

```bash
./scripts/ensure_dev_venv.sh
cd flutter && flutter pub get && flutter run -d macos
```

## 打进 .app / .dmg

```bash
# 完整内置（体积大，离线可用）
./scripts/package_macos.sh
# → dist/Unisyn-<ver>-macos.dmg

# 宿主机环境（体积小，首次启动安装 Python 依赖）
PACKAGE_MODE=host ./scripts/package_macos.sh
# → dist/Unisyn-<ver>-macos-host.dmg

SKIP_BUNDLE=1 SKIP_FLUTTER_BUILD=1 PACKAGE_MODE=host ./scripts/package_macos.sh
```

## 页面（对齐 Web）

| 页 | 能力 |
|----|------|
| 工作台 | 快捷入口 + 热点/选题/排期/产物/账号统计 |
| 对话 | 多会话、空态建议卡、Composer、SSE 流式 |
| 技能库 | 分层浏览 + 右侧抽屉执行 |
| 内容库 | 目录浏览与预览 |
| 账号 | 平台登录 / 退出 / whoami |
| 画像 | 画像列表与维度文件编辑 |
| SubNav | 热点雷达 / 选题库 / 内容日历 / 发布中心 / 爆款拆解 |
| 设置 | 底栏齿轮打开浮层（模型 · 环境 · 更多） |
