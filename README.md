# engram-opencode

> [Engram](https://github.com/jimhy/engram) — brain-inspired long-term memory — for **opencode**. Injects relevant memory at session start, consolidates when a session goes idle, adds `/engram-*` commands, and recalls on demand via a skill. One Rust binary, zero deps, **memory store shared with the Claude Code & Codex versions**.

**English** | [中文](./README.zh-CN.md)

---

## Install

```bash
opencode plugin engram-opencode
```

That's it — opencode installs the npm package and adds it to your config. On first run the plugin **self-provisions** everything via its `config` hook: the pre-permissioned reviewer/query agents and the `/engram-*` commands. No files to drop by hand.

Update: `opencode plugin engram-opencode -f`. Uninstall: remove `engram-opencode` from the `plugin` array in your opencode config.

<details>
<summary>Local / offline install (development, or before the package is published)</summary>

```bash
./install.sh        # macOS / Linux
.\install.ps1       # Windows (PowerShell)
```

Copies `plugin/engram.ts` into opencode's auto-loaded plugin dir and the bundled assets next to it (`<config>/engram-data/`). The agents + commands are still self-provisioned by the `config` hook. `<config>` defaults to `~/.config/opencode` (override: `OPENCODE_CONFIG_DIR=...` / `-ConfigDir`).
</details>

## What you get

| opencode mechanism | what it does |
|---|---|
| `experimental.chat.system.transform` hook | Injects the **hot index** (relevant memory) onto the system prompt each turn (cached per directory). Survives compaction for free, since the system prompt is rebuilt after it. |
| `session.idle` event | On each idle, rebuilds a stable JSONL transcript from the SDK, asks `engram review-prepare` for the **increment since the last watermark**, and — once it's big enough — spins up an independent reviewer that consolidates (writes, promotes/demotes, supersedes, merges). Also **catches up** any unfinished review on startup. |
| `config` hook | **Self-provisions** the `engram-reviewer` + `engram` agents (pre-permissioned) and the `/engram-*` commands — so the npm install is truly one command. |
| `/engram-*` commands | `recall` / `status` / `list` / `render` — query memory straight from the TUI (see below). |
| engram **skill** | recall-first: when asked "have we handled X / what's the project / what's left", the agent recalls from memory before scanning code. |

The store is **shared with the Claude Code & Codex versions** (`~/.engram/general.redb` + per-project `<project>/.engram/engram.redb`). Only the consolidation **ledger** (watermark / pending / transcripts) is per-CLI under `~/.engram/opencode/`, so the adapters never fight over progress.

## Commands

| command | what it does |
|---|---|
| `/engram-recall <query>` | Search the memory store (cold + hot) and list the hits. |
| `/engram-status` | Memory-system overview: per-tier counts, projects, cold store, tombstones. |
| `/engram-list [filters]` | List memories (pass `--level L4.2 --status active` etc. as args). |
| `/engram-render` | Preview the **hot index** that gets injected into this session. |

These run as the injected, pre-permissioned **`engram`** query agent, which runs the bundled `engram` binary and shows the output verbatim.

## How it works

Same engine as [engram](https://github.com/jimhy/engram) — tiered, ACT-R-style activation, self-forgetting (forgetting = demotion, not deletion).

| Tier | Role |
|---|---|
| **L1** | "subconscious" — core identity / global preferences (almost never forgotten) |
| **L2** | important, cross-project |
| **L3** | ordinary general notes |
| **L4** | per-project, in `<project>/.engram/engram.redb`, located via the `.engram/` anchor |

## The reviewer

Runs as an **isolated opencode session** (created in-process via the SDK client, fired with `promptAsync`), so its context is independent and the user's session is untouched. Live reviewer sessions are attached under the source session when possible, marked with `metadata.engram=true`, `metadata.engramRole="reviewer"`, `metadata.background=true`, and `metadata.hidden=true`, then archived immediately so opencode desktop does not show the temporary reviewer in normal session lists. It runs as the self-provisioned **`engram-reviewer`** agent, pre-permissioned for `external_directory` + `bash` (it reads the transcript slice / `SKILL.md` outside the cwd and runs the `engram` binary) while `edit`/`webfetch` stay denied — so the background session never stalls on a permission prompt. It ends with `engram consolidate-done` (advances the watermark, clears the pending). If it never finishes (crash / restart), catch-up replays the pending on the next startup — nothing lost, nothing redone.

## Structure (npm package)

```
opencode-plugin/                   the npm package (name: engram-opencode)
  package.json                     main -> plugin/engram.ts
  plugin/engram.ts                 the adapter: injection + idle review + config-hook self-provision
  scripts/reviewer-prompt.md       reviewer prompt (kernel asset, identical across adapters)
  skills/engram/SKILL.md           engram agent interface + judgment rubric (kernel asset)
  bin/                             four-platform engine binaries
install.{ps1,sh}                   local/offline installer (auto-load layout)
```

The reviewer/query **agents and commands are not files** — they are injected at runtime by the `config` hook, so they travel with the package automatically.

## Differences from the Claude Code adapter

- **Plugin, not shell hooks**: a single `engram.ts` loaded into opencode's (Bun) runtime.
- **`session.idle` instead of `SessionEnd`**: review runs only when the increment ≥ `ENGRAM_REVIEW_MIN_LINES` (default **10** — lower than the others' 40 because this adapter normalizes one-**message**-per-line, not one-event-per-line).
- **Transcript via the SDK**: `client.session.messages(...)` normalized to a stable JSONL fed to the same `review-prepare` (kernel unchanged).
- **Reviewer via the in-process SDK** (an isolated session as the `engram-reviewer` agent) rather than a headless `claude -p` / `codex exec` subprocess.
- **Self-provisioning**: agents + commands injected via the `config` hook instead of shipped as files.

## Configuration

- `ENGRAM_REVIEW_MIN_LINES` — increment (in normalized transcript lines) needed to trigger a review (default `10`).
- `ENGRAM_REVIEWER_MODEL` — `providerID/modelID` override for the reviewer session (default: opencode's default model).
- `ENGRAM_BIN` — absolute path to an `engram` binary, overriding the bundled one.
- `ENGRAM_REVIEWER=1` — makes the plugin inert (used by the reviewer subprocess / for debugging).

## Verifying interactively

1. Install and open `opencode` in a project; send a message.
2. **Injection**: ask `what do you remember about me?` — the answer should reflect your hot-index memories.
3. **Commands**: run `/engram-status` — you should see the memory overview.
4. **Review**: after a substantive exchange (≥ `ENGRAM_REVIEW_MIN_LINES` lines), the background reviewer is marked and archived by default; verify it by `~/.engram/opencode/watermark.json` advancing and pending clearing. For debugging, search archived sessions by `metadata.engramRole="reviewer"` or title `engram-review`.

## License

MIT
