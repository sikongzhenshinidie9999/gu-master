# AGENTS.md

本文件是 Codex 在本项目中开发时必须遵守的开发规则。请先完整阅读本文件，再开始任何任务。

## 项目定位

- 当前项目根目录：`D:\project\gu-master`（Flutter 应用）。
- 本项目是基于 **Sidequest**（巫师风 RPG 待办/习惯应用）逐步改造而成的 **“蛊师修炼系统”**。
- 当前阶段目标**不是**立即开发完整功能，而是通过**小步迭代**，逐步把 Sidequest 改造成蛊师修炼系统。
- **禁止一次性设计和实现整个蛊师系统**；每次只做一个小而完整的功能增量，理解清楚后再动手。

## 技术栈

- Flutter / Dart
- 状态管理：Riverpod 2.x（`flutter_riverpod`，当前使用 `StateNotifier` + `StateNotifierProvider`）
- 本地持久化：Hive（`hive` + `hive_flutter`，NoSQL，离线优先）
- 本地通知：`flutter_local_notifications` + `timezone`
- 其他现有依赖：`google_fonts`、`intl`、`uuid`、`flutter_staggered_animations`、`cupertino_icons`

## 目录结构与架构（Feature-first）

```
lib/
├── main.dart                          # 应用入口（Hive 初始化、ProviderScope、主题）
└── src/
    ├── core/                          # 跨功能核心服务
    │   └── services/                  # 如 notification_service.dart
    ├── features/                      # 按功能模块划分（Feature-first）
    │   └── <feature>/
    │       ├── data/                  # 数据模型（Hive model + 生成的 .g.dart 适配器）
    │       ├── logic/                 # Provider / Notifier / 业务状态
    │       └── presentation/
    │           └── screens/           # 页面
    └── shared/                        # 跨功能共享
        └── widgets/                   # 共享组件（GlassCard、BackgroundGradient 等）
```

- 现有 feature：`quests`（任务/公告板）、`settings`（设置）、`stats`（统计）。
- 数据流惯例：UI → `ref.read(provider.notifier).方法()` → Notifier 更新 Hive 并修改 state → `ref.watch` 重建 UI。
- 持久化惯例：Hive Box —— `quests`（`QuestModel`，typeId=0）、`stats`、`settings`（动态值）。

## 开发规则（硬性约束）

1. **优先复用现有架构**，不无理由重构；不要为了“优化”而主动改动现有代码结构。
2. **不主动升级 Flutter、Dart 或任何依赖版本**；**禁止执行 `flutter pub upgrade`**。
3. **不删除现有功能**，除非用户明确要求。
4. **不修改与当前任务无关的文件**；保持小范围修改，避免一次改动大量无关文件。
5. 每次修改前，**先理解相关代码和数据流**（Provider → Notifier → Hive → UI），再动手。
6. 采用**小步迭代**：一次只做一个小的功能增量，不一次性铺开整个蛊师系统。
7. 修改 Dart 代码后**必须运行 `flutter analyze`**，并确认无新增问题。
8. 涉及功能行为变化时，**尽可能增加或修改对应测试**（`test/`）。
9. **不允许为了消除 warning 而进行无关重构**。
10. **不擅自改变 Hive 数据模型的 `typeId`**；修改数据模型必须考虑已有用户数据的兼容性（新增字段给默认值、必要时提供迁移逻辑）。
11. **不擅自改变现有 Git 分支结构**；**禁止执行 `git reset --hard`、`git clean -fd` 等可能导致数据丢失的命令**；**不擅自 commit 或 push**，除非用户明确要求。

## 数据与兼容性注意事项

- `QuestModel` 使用 `@HiveType(typeId: 0)`，适配器由 `hive_generator` + `build_runner` 生成（`quest_model.g.dart`）。
- 修改模型字段后需要重新生成适配器，并保证旧数据可正常读取。
- `quests` / `stats` / `settings` 三个 Hive Box 由 `main.dart` 在启动时打开，`questBoxProvider` 通过 `ProviderScope` 注入。
- 已知问题（后续涉及相关功能时注意）：`NotificationService.init()` 目前未在 `main()` 中调用；任务过期只在启动时检查。涉及通知、过期逻辑前先确认现状。

## 任务完成汇报模板

每完成一个任务，必须向用户报告：

- 修改了哪些文件
- 每个文件为什么修改
- 实现了什么
- 是否运行了 `flutter analyze`
- 是否运行了测试
- 是否存在已知问题
