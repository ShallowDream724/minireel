# 开发与构建

本文描述当前 Flutter 工程的实际构建方式。使用介绍见 [README](../README.md)，人工验收见 [Android 验收清单](04_Android首版验收清单.md)。

## 环境

建议固定使用 Flutter **3.41.9 stable**，对应 Dart **3.11.5**。`pubspec.yaml` 要求 Dart 3.11 或更高的兼容版本，提交的 `pubspec.lock` 用于锁定应用依赖。

| 工具 | 当前配置 |
| --- | --- |
| Java | JDK 17 |
| Android compile / target SDK | 36，由 Flutter SDK 提供默认值 |
| Android 最低版本 | API 24 / Android 7.0 |
| Android NDK | 28.2.13676358，由 Flutter SDK 提供默认值 |
| Android Gradle Plugin | 8.11.1 |
| Kotlin | 2.2.20 |
| Gradle | 8.14，使用仓库内的 wrapper |

需要接受 Android SDK licenses，并允许构建期间下载 Dart/Maven 依赖、Gradle 和 `media_kit` 使用的原生媒体库。应用无需 Go、Node.js 或外部 FFmpeg 可执行文件。

## 获取与运行

```sh
git clone https://github.com/WEP-56/minireel.git
cd minireel
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <设备ID>
```

Android debug 构建禁用 Impeller，使用 Skia/OpenGL，以避开部分模拟器的 MESA/Vulkan `VkFence` 问题。该配置不影响 release 构建。修改原生 Manifest 后需要停止应用并重新运行，热重载不能切换渲染后端。

## 检查与打包

```sh
flutter analyze --no-pub
flutter test test --no-pub
flutter build apk --release --split-per-abi
```

Flutter 3.41.9 的 Release 打包命令需要保留默认的 Pub 步骤，以按发布模式重新生成插件注册文件、排除仅用于开发的 `integration_test` 插件。这里不要添加 `--no-pub`，否则前面的依赖获取或测试可能留下包含测试插件的注册文件，导致 Java 编译报 `IntegrationTestPlugin` 找不到。静态检查和单元测试可以继续使用 `--no-pub`。

安装包位于 `build/app/outputs/flutter-apk/`，分别面向 `arm64-v8a`、`armeabi-v7a` 和 `x86_64`。不加 `--split-per-abi` 可生成单个通用 APK。

**当前 release 构建使用开发签名，供本地验证。** 正式发布前需要在 `android/app/build.gradle.kts` 配置稳定的发布签名。仅创建 `key.properties` 并不会自动改变当前签名配置。不要把签名私钥或密码提交到仓库。

应用版本由 `pubspec.yaml` 的 `version` 控制，也可通过 Flutter 的 `--build-name` / `--build-number` 覆盖。

## 后续 GitHub Actions 打包

当前仓库尚未添加 Actions workflow。未来工作流可以直接使用上述检查和打包命令，不需要重新创建 Flutter 工程、生成图标、生成测试样本或另外拷贝数据源文件。

建议执行顺序：

1. 检出代码，设置 JDK 17、Flutter 3.41.9 和 Android SDK。
2. 安装需要的 SDK / NDK，并接受 licenses。
3. 执行 `flutter pub get --enforce-lockfile`。
4. 执行静态检查和 `flutter test test --no-pub`。
5. 执行 `flutter build apk --release --split-per-abi`（保留默认 Pub 步骤），将 `build/app/outputs/flutter-apk/*.apk` 上传为构建产物。
6. 确定正式发布流程后，再从 GitHub Secrets 注入稳定的发布签名。

`integration_test/` 中的测试需要 Android 设备和真实网络/片源。它们应作为单独的人工或设备验收步骤，不宜作为每次打包的固定前置条件。

## 仓库完整性

以下文件是工程的一部分，必须保留在版本控制中：

- `lib/`、`pubspec.yaml`、`pubspec.lock`、`.metadata` 和 `analysis_options.yaml`。
- `assets/logo.png` 与 **`assets/config/sources.json`**。
- `android/` 的 Manifest、Kotlin 入口、Gradle 配置、图标和启动页资源。
- `android/gradlew`、`android/gradlew.bat`、`android/gradle/wrapper/gradle-wrapper.jar` 和对应 `.properties`。
- `test/`，包括 `test/fixtures/playback_codec.json`；以及 `integration_test/`、`tool/`。

`.gitattributes` 保证 Unix wrapper 的 LF 换行，Git 中的 `android/gradlew` 保留可执行权限，便于 Linux runner 使用。

`android/local.properties`、SDK 路径、构建缓存和插件注册文件由本机 Flutter 工具生成，不应提交。`build/`、`.tmp/`、`output/` 和签名材料同样忽略。

本地的 `api-example/`、`ui.ux-example/` 以及最初的三份迁移规划资料属于参考材料，已在 `.gitignore` 中排除。当前应用运行和打包不读取这些目录。后续维护以现有代码、本文和当前验收清单为准。

## 数据源配置

`assets/config/sources.json` 已包含当前使用的数据源默认配置，并由 `pubspec.yaml` 声明为必需资源。它必须随代码提交；正常构建和运行不需要额外的私有配置文件。

可选编译覆盖项：

| 参数 | 作用 |
| --- | --- |
| `MINIREEL_BASE_URL` | 覆盖剧库网页地址，同时调整网页 Referer |
| `MINIREEL_PLAYBACK_ENDPOINT` | 覆盖备用播放接口 |

这些地址不等于账号凭据；未来若接入需要 token 的服务，应另外设计凭据管理。现有临时视频 URL 和每集内容密钥只在运行时内存中使用，不写入应用数据库。

数据流为 `SourceAdapter → DramaRepository → PlaybackSession → media_kit`。网页直链优先，备用取流负责兜底；原生加载失败时最多自动恢复两次，并保留进度。上游没有提供有效视频地址时，会明确报告片源不可用。

## 辅助工具

```sh
# 只读检查剧库、详情和前两集播放解析
dart run tool/probe_source.dart
dart run tool/probe_source.dart --fallback

# 替换 logo 后重新生成 Android 图标
dart run tool/generate_icons.dart

# 修改协议解码测试样本时使用；常规构建无需 Node.js
node tool/generate_codec_vectors.cjs
```

协议测试样本为合成数据，不包含真实播放密钥。图标和测试样本的现有输出已提交，无需在 CI 中重新生成。

## 平台范围

当前仅有 Android runner。Windows 是后续方向，可复用数据源、播放会话与界面，届时需补充 runner、对应媒体原生库和 SQLite backend。当前不提供 macOS / iOS 工程。
