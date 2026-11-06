# Unisyn Flutter host

桌面 UI：启动时拉起本地 FastAPI sidecar（`web/app.py`），界面布局与 Web 前端对齐（侧栏 + 工作台/对话/技能库/内容库/账号/画像 + 设置浮层），通过 `/api/*` 调用能力。

- 应用名：`Unisyn`
- Bundle ID：`com.jyyc.unisyn`

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

## 打进 .app / .dmg

```bash
# 一键：组装 sidecar → flutter build → 嵌入 .app → 打 DMG
./scripts/package_macos.sh
# 输出：flutter/.../Unisyn.app 与 dist/Unisyn-<version>-macos.dmg

# 已有 sidecar / Release .app 时可跳过耗时步骤：
SKIP_BUNDLE=1 SKIP_FLUTTER_BUILD=1 ./scripts/package_macos.sh
```

开发态也可先嵌入再手动 build：

```bash
./scripts/bundle_sidecar.sh
./scripts/embed_sidecar_macos.sh
cd flutter && flutter build macos
```

`embed_sidecar_macos.sh` 把 `dist/sidecar` 拷到 `macos/Runner/Resources/sidecar`，构建后位于 `Contents/Resources/sidecar`。

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
