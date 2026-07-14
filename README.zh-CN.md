# engram-opencode

> [Engram](https://github.com/jimhy/engram) —— 仿人脑分层长期记忆 —— 的 **opencode** 插件。会话开始注入相关记忆、会话空闲时自动巩固、提供 `/engram-*` 命令、并按需通过 skill 回溯。单 Rust 二进制、零依赖，**记忆库与 Claude Code / Codex 版本共用**。

[English](./README.md) | **中文**

---

## 安装

```bash
opencode plugin engram-opencode
```

就这一条 —— opencode 会装 npm 包并写进配置。首次运行时插件通过 `config` hook **自动注册**一切：预放行权限的复盘/查询 agent、以及 `/engram-*` 命令。**无需手动放任何文件**。

更新：`opencode plugin engram-opencode -f`。卸载：从 opencode 配置的 `plugin` 数组里移除 `engram-opencode`。

<details>
<summary>本地 / 离线安装（开发，或包还没发布时）</summary>

```bash
./install.sh        # macOS / Linux
.\install.ps1       # Windows (PowerShell)
```

把 `plugin/engram.ts` 拷进 opencode 的自动加载插件目录、把随附资产放在 `<config>/engram-data/`。agent 与命令仍由 `config` hook 自动注册。`<config>` 默认 `~/.config/opencode`（覆盖：`OPENCODE_CONFIG_DIR=...` / `-ConfigDir`）。
</details>

## 你得到什么

| opencode 机制 | 作用 |
|---|---|
| `experimental.chat.system.transform` hook | 每回合把**热索引**（相关记忆）追加进系统提示（按目录缓存）。压缩后系统提示重建，故天然扛 compaction。 |
| `session.idle` 事件 | 每次空闲时用 SDK 规整成稳定 JSONL，交给 `engram review-prepare` 算**自上次水位线以来的增量**，够大时起独立复盘者巩固（写新、升降级、supersede、合并）。启动时还会**补跑**没收尾的复盘。 |
| `config` hook | **自动注册** `engram-reviewer` + `engram` 两个（预放行权限的）agent 和 `/engram-*` 命令 —— 这就是 npm 真·一键装的关键。 |
| `/engram-*` 命令 | `recall` / `status` / `list` / `render` —— 在 TUI 里直接查记忆（见下）。 |
| engram **skill** | recall-first：被问「以前处理过 X 吗 / 项目是啥 / 还剩什么」时，先查记忆再翻代码。 |

记忆库与 **Claude Code / Codex 版本共用**（`~/.engram/general.redb` + 各项目 `<项目>/.engram/engram.redb`）。仅巩固**进度账本**（水位线 / pending / 转录切片）按 CLI 隔离在 `~/.engram/opencode/`，三端互不抢进度。

## 命令

| 命令 | 作用 |
|---|---|
| `/engram-recall <关键词>` | 检索记忆库（冷库、热库都搜）并列出命中。 |
| `/engram-status` | 记忆系统概况：各层条数、项目、冷库、墓碑。 |
| `/engram-list [过滤]` | 列出记忆（可把 `--level L4.2 --status active` 等当参数传）。 |
| `/engram-render` | 预览本会话将注入的**热索引**。 |

这些命令以注入的、预放行的 **`engram`** 查询 agent 运行：它跑随附的 `engram` 二进制并把输出原样展示。

## 工作原理

与 [engram](https://github.com/jimhy/engram) 同一引擎 —— 分层、ACT-R 式活跃度、自遗忘（遗忘=降级，不是删除）。

| 层级 | 角色 |
|---|---|
| **L1** | 「潜意识」—— 核心身份 / 全局偏好（几乎不遗忘） |
| **L2** | 重要、跨项目 |
| **L3** | 普通通用笔记 |
| **L4** | 项目级，存 `<项目>/.engram/engram.redb`，靠 `.engram/` 锚点定位 |

## 复盘者

以一个**独立的 opencode 会话**运行（in-process SDK client 新建、`promptAsync` 发起），上下文独立、不污染用户会话。实时复盘会话会尽量挂到被复盘会话下面作为子会话，并带 `metadata.engram=true`、`metadata.engramRole="reviewer"`、`metadata.background=true`、`metadata.hidden=true` 标记；插件创建后会立即归档它，所以 opencode desktop 的普通会话列表默认不显示这个临时会话。它以自动注册的 **`engram-reviewer`** agent 运行，预放行 `external_directory` + `bash`（要读工作目录外的转录切片 / `SKILL.md`、要跑 `engram` 二进制），同时 `edit`/`webfetch` 保持禁用 —— 所以后台会话**不会卡在权限询问**。它以 `engram consolidate-done` 收尾（推进水位线、清 pending）。若没跑完（崩溃/重启），下次启动 catch-up 补跑 pending —— 不丢不重。

## 目录结构（npm 包）

```
opencode-plugin/                   npm 包（name: engram-opencode）
  package.json                     main -> plugin/engram.ts
  plugin/engram.ts                 适配器：注入 + 空闲复盘 + config hook 自注册
  scripts/reviewer-prompt.md       复盘者提示词（内核资产，跨适配器一致）
  skills/engram/SKILL.md           engram agent 接口 + 判定 rubric（内核资产）
  bin/                             四平台引擎二进制
install.{ps1,sh}                   本地/离线安装（auto-load 布局）
```

复盘/查询 **agent 与命令不是文件** —— 由 `config` hook 运行时注入，随包自动携带。

## 与 Claude Code 适配器的差异

- **插件而非 shell hook**：单个 `engram.ts`，装进 opencode 的（Bun）运行时。
- **`session.idle` 替 `SessionEnd`**：仅当增量 ≥ `ENGRAM_REVIEW_MIN_LINES`（默认 **10** —— 低于其它两者的 40，因为本适配器规整成「一条消息一行」而非「一个事件一行」）才复盘。
- **转录走 SDK**：`client.session.messages(...)` 规整成稳定 JSONL，喂同一个 `review-prepare`（内核不动）。
- **复盘走 in-process SDK**（一个以 `engram-reviewer` agent 运行的独立会话），而非无头 `claude -p` / `codex exec` 子进程。
- **自注册**：agent + 命令由 `config` hook 注入，而不是作为文件分发。

## 配置

- `ENGRAM_REVIEW_MIN_LINES` —— 触发复盘所需的（规整后转录）增量行数（默认 `10`）。
- `ENGRAM_REVIEWER_MODEL` —— 复盘会话的模型覆盖，格式 `providerID/modelID`（默认走 opencode 默认模型）。
- `ENGRAM_BIN` —— `engram` 二进制的绝对路径，覆盖随附的二进制。
- `ENGRAM_REVIEWER=1` —— 让插件完全失活（复盘子进程 / 调试用）。

## 交互式验证

1. 安装后在项目里打开 `opencode`，发一条消息。
2. **注入**：问「你还记得关于我的什么？」—— 回答应体现你的热索引记忆。
3. **命令**：跑 `/engram-status` —— 应看到记忆库概况。
4. **复盘**：进行一段实质对话（≥ `ENGRAM_REVIEW_MIN_LINES` 行）后，后台复盘会话默认被标记并归档隐藏；验证以 `~/.engram/opencode/watermark.json` 推进、pending 清空为准。调试时可在归档会话里按 `metadata.engramRole="reviewer"` 或标题 `engram-review` 查找。

## 许可

Apache License 2.0 —— 见 [LICENSE](./LICENSE)。
