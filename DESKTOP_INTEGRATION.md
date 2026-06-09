# Engram × OpenCode Desktop 集成指南

> 给 **opencode desktop 项目**的 AI / 开发者。本 bundle 让 opencode desktop **内置 Engram 长期记忆系统**（会话开始注入记忆、会话空闲自动复盘巩固、提供 `/engram-*` 命令），无需用户用 npm 安装插件。
>
> 本目录由 engram 仓库的 `export-desktop-bundle.{sh,ps1}` 抽离生成，可整体拷入你的 desktop 项目。

---

## 1. 这是什么

Engram 是仿人脑分层长期记忆系统：**可移植内核**（一个 Rust 单二进制 `engram` + redb 存储 + 复盘提示词 + skill）零改动跨 CLI 共享，每个 CLI 一份**适配器**。本 bundle 是 **opencode 适配器**，形态是一个 opencode 插件（`engram.ts`）+ 它运行时要用的资产。

CLI 用户走 `opencode plugin engram-opencode`（npm）。**desktop 走本 bundle**：把文件随 app 打包、让内置的 opencode core 加载它。

## 2. Bundle 内容与布局

```
plugin/
  engram.ts                      opencode 插件入口（导出 EngramPlugin）
engram-data/
  bin/
    engram-windows-x86_64.exe    引擎二进制（Windows）
    engram-macos-aarch64         引擎二进制（macOS Apple Silicon）
    engram-macos-x86_64          引擎二进制（macOS Intel）
    engram-linux-x86_64          引擎二进制（Linux）
  scripts/
    reviewer-prompt.md           复盘者提示词（内核资产，勿改）
  skills/
    engram/SKILL.md              engram agent 接口 + 判定 rubric（内核资产，勿改）
```

**这个相对布局很重要**（见第 4 节资产解析）：`engram.ts` 在 `<X>/plugin/`，资产在 `<X>/engram-data/`，二者父目录 `<X>` 相同。

## 3. OpenCode 插件加载契约（务必先理解）

1. **自动加载目录**：opencode core 启动时会自动加载配置目录下 `plugin/` 里的 `*.ts` / `*.js`（**实测单数 `plugin/` 有效**；core 也会扫 `plugins/`，用单数最稳）。配置目录默认 `~/.config/opencode`（含 Windows，走 `USERPROFILE/.config/opencode`）。
2. **`config.plugin` 数组只认 npm 包名**，**不要**用它指向本地文件路径——本地插件必须放进上面的 auto-load 目录。
3. **插件模块形态**：导出一个 named async 函数，签名 `({ client, project, directory, worktree, $ }) => Promise<Hooks>`。core 会遍历模块所有导出、把每个**函数值**当插件调用——所以 `engram.ts` 只 `export const EngramPlugin`（仅此一个导出函数），**切勿再加第二个导出函数**，否则会被重复注册（双重注入）。
4. **资产解析**：`engram.ts` 用 `import.meta.dir`（Bun）定位自身目录 `here`，再按顺序在这三处找 `bin/` `scripts/` `skills/`：
   - `here/`（入口与资产同级）
   - `here/../`（入口在子目录、资产在父目录）
   - `here/../engram-data/`（**本 bundle 采用的布局**）

   只要保持「`<X>/plugin/engram.ts` + `<X>/engram-data/...`」，资产即可被解析。也可用环境变量 `ENGRAM_BIN` 显式指定二进制绝对路径，绕过自动查找。

## 4. 部署方式（按你的 desktop 架构三选一）

opencode desktop 内部会跑一个 opencode core（CLI 二进制 `serve` 子进程，或嵌入式）。让 core 加载本 bundle，核心就是**把 `plugin/` 与 `engram-data/` 放进 core 启动时使用的「配置目录」**。

### 方式 A：core 用 app 专属配置目录（最贴合「打包进 exe」，推荐）
1. 把本 bundle 作为只读 app 资源随安装包分发（Electron 的 `resources/`、Tauri 的 resource、或任意打包目录）。
2. app 首次运行时，把 `plugin/` 和 `engram-data/` **部署到一个 app 管理的可写配置目录 `D`**（例如 `<userData>/opencode/`），得到 `D/plugin/engram.ts` 和 `D/engram-data/...`。
3. 启动 core 时让它把 `D` 当配置目录。opencode 配置目录默认 `~/.config/opencode`；若你的 core 尊重 `XDG_CONFIG_HOME`，可设它指向 `D`（**请在你侧验证 opencode 当前版本是否读 `XDG_CONFIG_HOME`，Windows 尤其要验**；若不读，则用方式 B，或把 `D` 设为 `~/.config/opencode`）。
> 资源目录通常只读、core 只需「读」插件文件即可；但仍建议部署到**可写**目录，因为 opencode 会在配置目录内写状态。Engram 自己的记忆库写在 `~/.engram`（走 `os.homedir()`，与配置目录无关），不受影响。

### 方式 B：部署到用户全局 `~/.config/opencode`（最简单）
app 首启把 `plugin/engram.ts` 拷到 `~/.config/opencode/plugin/engram.ts`，把 `engram-data/` 拷到 `~/.config/opencode/engram-data/`。core 用默认配置目录即可加载，且与 CLI 版本共存。
> 注意去重：若用户已用 `opencode plugin engram-opencode`（npm）装过，会出现两份插件被同时加载（双重注入）。部署前检测：若 `~/.config/opencode` 的 config 里 `plugin` 数组已含 `engram-opencode`，则跳过本部署。

### 方式 C：fork core 作为内置插件（最彻底的「进 exe」）
若你的 desktop 自行编译 opencode core，可把 `engram.ts` 作为 core 的 internal/bundled 插件编译进去（参考 core 现有 internal plugins 的注册方式），资产随 core 二进制打包，路径用 `ENGRAM_BIN` 等指定。改动量最大，但完全不落盘到用户配置目录。

## 5. 平台二进制与权限

- **按目标平台裁剪**：每个平台的安装包只需保留对应的一个二进制即可减体积——
  Windows→`engram-windows-x86_64.exe`，macOS→`engram-macos-aarch64`（Apple Silicon）/`engram-macos-x86_64`（Intel），Linux→`engram-linux-x86_64`。其余可删。
- **可执行权限**：macOS / Linux 上部署后必须给二进制加可执行位（`chmod +x engram-data/bin/engram-*`）。打包/解包流程要保留或重设执行位。
- **macOS 签名/公证**：把第三方二进制打进 .app 时，注意 Gatekeeper——按你 app 的签名流程对 `engram-*` 一并签名/公证，否则会被拦。
- 也可用 `ENGRAM_BIN=<绝对路径>` 让插件用你指定位置的二进制（例如你把它放在 app 的 bin 目录而非 `engram-data/bin`）。

## 6. 自动就绪的部分（你无需额外处理）

插件加载后会**自动**完成下列事，desktop 端不用写任何额外代码：
- **注入热索引**：每回合通过 `experimental.chat.system.transform` 把相关记忆加到系统提示（压缩后自动重注）。
- **自动注册 agent + 命令**：插件的 `config` hook 会注入两个**已预放行权限**的 agent（`engram-reviewer` 复盘者、`engram` 查询助手）和四个命令 `/engram-recall` `/engram-status` `/engram-list` `/engram-render`。**无需放任何 agent/command 文件。**
- **会话空闲自动复盘**：`session.idle` 时按增量阈值起一个独立复盘会话（用 `engram-reviewer` agent，已放行 `external_directory`+`bash`，后台不会卡权限弹窗），巩固记忆并 `consolidate-done` 收尾；崩溃/重启用启动 catch-up 补跑。
- **记忆库位置**：`~/.engram/general.redb`（L1-3）+ 各项目 `<项目>/.engram/engram.redb`（L4）；复盘进度账本在 `~/.engram/opencode/`。**与 CLI / Claude Code / Codex 版本共用同一记忆库**，三端互通。

## 7. 权限注意

复盘者后台会话要读工作目录外的文件（切片 / `SKILL.md`）并用 bash 跑 `engram` 二进制——这些已由注入的 `engram-reviewer` agent 预放行（`external_directory: allow` + `bash: allow`，同时 `edit`/`webfetch` 禁用）。**若你的 desktop 有自己的权限门控 / 沙箱**，请确保不要拦截：①该 agent 执行 `engram-data/bin/` 下的二进制；②对 `~/.engram` 和配置目录的读写。

## 8. 验证（部署后）

1. **加载**：core 日志（`~/.local/share/opencode/log/<时间>.log` 或你指定的 log 路径）应出现 `loading plugin .../engram.ts`，且无报错。
2. **注册**：跑 `opencode debug config`（或等价的 resolved-config dump）应能看到 agent `engram-reviewer` / `engram` 与 command `engram-recall/status/list/render`。
3. **注入**：发一条消息问「你记得我什么」，回答应体现已有记忆（首次空库则无内容，属正常）。
4. **命令**：触发 `/engram-status`，应输出记忆库概况（各层条数）。
5. **复盘**：进行一段实质对话（增量 ≥ `ENGRAM_REVIEW_MIN_LINES`，默认 10），随后 `~/.engram/opencode/watermark.json` 应推进、`~/.engram/opencode/pending/` 清空，记忆库可能新增条目。

## 9. 环境变量

| 变量 | 作用 |
|---|---|
| `ENGRAM_BIN` | engram 二进制的绝对路径，覆盖自动查找（适合把二进制放在非 `engram-data/bin` 处） |
| `ENGRAM_REVIEW_MIN_LINES` | 触发复盘所需的（规整后转录）增量行数，默认 `10` |
| `ENGRAM_REVIEWER_MODEL` | 复盘会话模型覆盖，格式 `providerID/modelID`，默认走 opencode 默认模型 |
| `ENGRAM_REVIEWER=1` | 让插件完全失活（不注入 / 不复盘 / 不注册），用于复盘子进程或调试 |

## 10. 禁用 / 卸载

删除部署出去的 `plugin/engram.ts`（及 `engram-data/`）即可。记忆库 `~/.engram/` 不会被删（用户数据，按需另行清理）。
