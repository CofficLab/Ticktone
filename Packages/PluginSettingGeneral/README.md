# PluginSettingGeneral

## 重要规则

- 插件仅实现功能和外部集成；共享能力放在 Provider，装配放在 Factory；禁止依赖 App target、跨 Factory 依赖或创建第二套 Kernel。
- 所有 Provider、工具、命令、视图和设置贡献都必须通过 Kernel 生命周期注册，并保留可撤销句柄；禁用、注销、关闭时完整清理，生命周期操作应可重复执行。
- 异步任务必须可取消并绑定当前 kernel/project/context；发布结果前校验 generation 和当前上下文，防止旧任务覆盖新状态。
- 涉及 UI 时优先使用 [LumiUI](../LumiUI/README.md) 组件和 `DesignTokens`（按钮、列表行、卡片、设置行、空/错误/加载状态等）；不要复制通用控件或设计令牌。LumiUI 缺少能力时优先补充共享组件，并说明原因。
- 自定义 UI 仅用于领域交互或品牌视觉；保持深浅色、平台适配、本地化和无障碍。插件自己管理内部滚动，宿主只负责契约要求的外层组合。
- 包级改动使用对应包的 `swift test --package-path Packages/<PackageName>`（无测试则 `swift build`），并单独报告静态检查、构建/测试和真实运行时/视觉验证；提交前执行 `git diff --check`。



通用设置插件：通过共享内核的 `SettingViewProviding` 注册「通用」入口。
应用名称、隐私说明、网站及可选操作由宿主配置；版本信息和说明书来自宿主 Bundle 与共享 Provider。

宿主通过插件工厂装配：

```swift
SettingGeneralPlugin(configuration: .init(
    privacyDescription: "Documents stay on this device."
))
```

其他共享 `KernelCore` 与 `ProviderSettingView` 的应用可以复用同一个插件，
并只注入自己支持的能力。
BookletMaker 通过 `FactoryBookletMakerMac` 装配该插件，iOS Factory 继续使用自己的插件目录。

## 包信息

| 项 | 值 |
| --- | --- |
| Swift 工具链 | 6.0 |
| 支持平台 | macOS 14+、iOS 17+ |
| 产品 | `PluginSettingGeneral` |

## 目标

| 目标 | 类型 | 依赖包 |
| --- | --- | --- |
| `PluginSettingGeneral` | target | KernelCore, LumiLocalizationKit, LumiLoggingKit, LumiUI, ProviderCommand, ProviderDocsView, ProviderSettingView |
| `PluginSettingGeneralTests` | testTarget | PluginSettingGeneral |

## 依赖

| 包 | 来源 |
| --- | --- |
| LumiLogging | `https://github.com/lumi-softworks/LumiLogging.git` |
| KernelCore | 本地路径 `../KernelCore` |
| ProviderDocsView | 本地路径 `../ProviderDocsView` |
| ProviderCommand | 本地路径 `../ProviderCommand` |
| ProviderSettingView | 本地路径 `../ProviderSettingView` |
| LumiLocalizationKit | 远程包 `https://github.com/lumi-softworks/LumiLocalization.git` |
| LumiUI | 远程 `https://github.com/lumi-softworks/LumiUI.git`（1.5.1） |

## 目录结构

```
Sources/PluginSettingGeneral/
├── AppVersion.swift
├── GeneralSettingsConfiguration.swift
├── SettingGeneralPlugin.swift
├── Support/
│   ├── SettingGeneralLocalization.swift
├── Views/
│   ├── GeneralSettingsDetailView.swift
│   ├── ManualsBrowserView.swift
```
