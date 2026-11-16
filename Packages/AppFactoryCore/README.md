# AppFactoryCore

应用工厂内核装配层：把 KernelCore 内核与各 Factory 组合根装配成可运行的 App（AppKernelAssembler / AppKernelReference / PluginFactory）。

## 包信息

| 项 | 值 |
| --- | --- |
| Swift 工具链 | 6.0 |
| 支持平台 | macOS 14+、iOS 17+ |
| 产品 | `AppFactoryCore` |

## 目标

| 目标 | 类型 | 依赖包 |
| --- | --- | --- |
| `AppFactoryCore` | target | KernelCore |
| `AppFactoryCoreTests` | testTarget | AppFactoryCore |

## 依赖

| 包 | 来源 |
| --- | --- |
| KernelCore | 本地路径 `../KernelCore` |

## 目录结构

```
Sources/AppFactoryCore/
├── AppAssemblyConfiguration.swift
├── AppKernelAssembler.swift
├── AppKernelReference.swift
├── PluginFactory.swift
├── ProviderFactory.swift
├── ViewFactory.swift
```

