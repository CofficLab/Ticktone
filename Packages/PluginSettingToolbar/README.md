# PluginSettingToolbar

## 重要规则

- 插件仅实现功能和外部集成；共享能力放在 Provider，装配放在 Factory；禁止依赖 App target、跨 Factory 依赖或创建第二套 Kernel。
- 所有 Provider、工具、命令、视图和设置贡献都必须通过 Kernel 生命周期注册，并保留可撤销句柄；禁用、注销、关闭时完整清理，生命周期操作应可重复执行。
- 异步任务必须可取消并绑定当前 kernel/project/context；发布结果前校验 generation 和当前上下文，防止旧任务覆盖新状态。
- 涉及 UI 时优先使用 [LumiUI](../LumiUI/README.md) 组件和 `DesignTokens`（按钮、列表行、卡片、设置行、空/错误/加载状态等）；不要复制通用控件或设计令牌。LumiUI 缺少能力时优先补充共享组件，并说明原因。
- 自定义 UI 仅用于领域交互或品牌视觉；保持深浅色、平台适配、本地化和无障碍。插件自己管理内部滚动，宿主只负责契约要求的外层组合。
- 包级改动使用对应包的 `swift test --package-path Packages/<PackageName>`（无测试则 `swift build`），并单独报告静态检查、构建/测试和真实运行时/视觉验证；提交前执行 `git diff --check`。



设置工具栏插件：提供设置场景的工具栏贡献。

## 包信息

| 项 | 值 |
| --- | --- |
| Swift 工具链 | 6.0 |
| 支持平台 | macOS 14+ |
| 产品 | `PluginSettingToolbar` |

## 目标

| 目标 | 类型 | 依赖包 |
| --- | --- | --- |
| `PluginSettingToolbar` | target | KernelCore, LumiUI, ProviderToolbar |

## 依赖

| 包 | 来源 |
| --- | --- |
| KernelCore | 本地路径 `../KernelCore` |
| ProviderToolbar | 本地路径 `../ProviderToolbar` |
| LumiUI | 远程 `https://github.com/lumi-softworks/LumiUI.git`（1.5.1） |

## 目录结构

```
Sources/PluginSettingToolbar/
├── SettingsToolbarPlugin.swift
```
