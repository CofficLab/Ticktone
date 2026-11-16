# Ticktone

Ticktone is a precise metronome for macOS and iOS. It runs entirely on-device: no account, no network, no analytics.

📖 [中文版](README_zh.md) | English

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://developer.apple.com/macos/)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

## Features

- **Sample-accurate engine**: a dedicated audio render path keeps the click steady under UI load.
- **Tempo 30–300 BPM** with Italian tempo markings, tap tempo, and tempo lock.
- **Time signatures and subdivisions**: beats per measure, beat unit, duple/triple/quadruple subdivisions.
- **Accent patterns**: cycle weak / normal / accent / mute per beat.
- **Practice tools**: count-in measures, tempo training with target BPM and step size, visual flash, haptics.
- **Presets**: save and recall complete configurations.
- **Pendulum and beat indicators** that follow the configured pattern.
- **Click sound sets** built from synthesized samples; volume is adjustable.
- **Native multiplatform shell**: SwiftUI on macOS and iOS from one app target.

## Requirements

- macOS 14.0+ / iOS 17.0+
- Xcode 16.0+
- Swift 6.0+
- XcodeGen (the `.xcodeproj` is generated from `project.yml`)

## Development

```sh
xcodegen generate
open Metronome.xcodeproj
```

Select the `Metronome` scheme and run. The target builds for macOS and iOS; use a simulator or device destination for iOS.

### Project layout

- `MetronomeApp/` — app entry, Info.plist, entitlements, assets, localizations
- `Packages/PluginMetronome/` — `MetronomeCore` (pure domain logic) and `PluginMetronome` (audio engine, views, plugin)
- `Packages/FactoryMetronome/` — macOS and iOS assembly roots built on the Lumi Kernel/Provider/Plugin architecture
- `Packages/AppFactoryCore/`, `ProviderSettingsHost/`, `PluginRootView/`, `PluginSettingGeneral/`, `PluginSettingToolbar/`, `PluginActivityBar/` — host shell packages used by the assembly
- `scripts/` — package test runner

## Tests

Run every package suite:

```sh
./scripts/test-all-packages.sh
```

Build both platforms:

```sh
xcodebuild -project Metronome.xcodeproj -scheme Metronome -destination 'platform=macOS' build
xcodebuild -project Metronome.xcodeproj -scheme Metronome -destination 'generic/platform=iOS Simulator' build
```

## License

GPLv3. See [LICENSE](LICENSE).
