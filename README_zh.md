# Ticktone

Ticktone 是一款面向 macOS 与 iOS 的精准节拍器。全部能力在本地运行：不需要账号，不联网，不做分析统计。

📖 中文版 | [English](README.md)

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://developer.apple.com/macos/)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

## 功能

- **采样级精准引擎**：独立音频渲染路径，界面负载下节拍依然稳定。
- **30–300 BPM**：意大利速度术语、Tap Tempo、速度锁定。
- **拍号与细分**：每小节拍数、拍值、二/三/四连音细分。
- **重音模式**：逐拍循环切换弱拍 / 普通 / 重音 / 静音。
- **练习工具**：预备拍、变速训练（目标 BPM 与每档增量）、视觉闪烁、触感反馈。
- **预设**：保存并恢复完整配置。
- **摆锤与拍点指示**：跟随当前重音模式显示。
- **音色组**：合成采样，音量可调。
- **原生多平台**：一个 target 同时产出 macOS 与 iOS App。

## 环境要求

- macOS 14.0+ / iOS 17.0+
- Xcode 16.0+
- Swift 6.0+
- XcodeGen（`.xcodeproj` 由 `project.yml` 生成）

## 开发

```sh
xcodegen generate
open Metronome.xcodeproj
```

选择 `Metronome` scheme 运行。target 同时支持 macOS 与 iOS；iOS 请选择模拟器或真机 destination。

### 目录结构

- `MetronomeApp/` — App 入口与宿主清单（`MetronomeManifest.swift`）、Info.plist、entitlements、资源与本地化
- `Packages/PluginMetronome/` — `MetronomeCore`（纯领域逻辑）与 `PluginMetronome`（音频引擎、视图、插件）
- `Packages/PluginSettingGeneral/`、`PluginSettingToolbar/`、`PluginActivityBar/` — 宿主壳插件
- 装配由远程 `LumiFactory` 包提供（内核流水线、macOS/iOS 窗口壳）；App 只声明清单
- `scripts/` — 包测试脚本

## 测试

运行全部包的测试：

```sh
./scripts/test-all-packages.sh
```

构建两个平台：

```sh
xcodebuild -project Metronome.xcodeproj -scheme Metronome -destination 'platform=macOS' build
xcodebuild -project Metronome.xcodeproj -scheme Metronome -destination 'generic/platform=iOS Simulator' build
```

## 许可证

GPLv3，见 [LICENSE](LICENSE)。
