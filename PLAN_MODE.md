# Plan Mode Ecosystem Analysis for `pi`

_Date: 2026-02-22 (UTC)_

This document compares the official `pi` plan-mode example with relevant third-party packages.

> Popularity is based on npm monthly downloads (snapshot from npm search metadata).
> Ordering: **official example first**, then third-party packages by popularity.

---

## 0) Official Example (Baseline)

**Source:** `examples/extensions/plan-mode` in `@mariozechner/pi-coding-agent`

### Functionality
- `/plan`, `/todos`, `Ctrl+Alt+P`, `--plan`
- Read-only planning toolset
- Bash allowlist/blocklist safety checks
- Plan extraction from `Plan:` sections
- Execution tracking via `[DONE:n]`
- Status + widget progress UI
- Session persistence and resume recovery

### Strong parts
- Most complete reference implementation
- Good end-to-end workflow: plan → choose execute/refine → track completion
- Solid state restoration logic

### Weak parts
- Opinionated workflow (heavier than a minimal toggle)

---

## 1) `@ferologics/pi-extensions` (contains `plan-mode`)

**Popularity:** ~529/mo  
**Package type:** extension bundle

### Specifics / Functionality
- Includes `plan-mode/index.ts` plus other extensions
- Plan mode behavior closely mirrors official example:
  - `/plan`, `/todos`, shortcut, `--plan`
  - tool restriction + bash filtering
  - todo extraction + `[DONE:n]`
  - progress UI + persistence

### Strong parts
- Closest package equivalent to official full-feature plan mode
- Useful if you want a curated extension bundle

### Weak parts
- Not single-purpose; includes extra extensions you may not need

---

## 2) `@juanibiapina/pi-plan`

**Popularity:** ~273/mo  
**Package type:** focused plan-mode extension

### Specifics / Functionality
- `/plan`, `--plan`
- Optional configurable shortcut via `@juanibiapina/pi-extension-settings`
- Status indicator + `pi-powerbar` event integration
- State restored from session custom messages (`plan-mode-enter` / `plan-mode-exit`)

### Strong parts
- Lightweight and clean UX
- Good integration with adjacent ecosystem packages
- Clear session-visible mode messaging strategy

### Weak parts
- Simpler than official example:
  - no plan todo extraction UI
  - no `[DONE:n]` execution-tracking workflow
- Safety posture relies more on prompt/tool-mode constraints than deep bash command blocking logic

---

## 3) `@plannotator/pi-extension`

**Popularity:** ~0/mo (new)  
**Package type:** advanced plan-review workflow

### Specifics / Functionality
- `/plannotator`, `/plannotator-status`, `/plannotator-review`, `/plannotator-annotate`
- `--plan`, `--plan-file`
- File-based plan in `PLAN.md`
- Browser review/approval UI via `exit_plan_mode` tool
- Deny/annotate/approve loop with feedback to agent
- Checklist + `[DONE:n]` progress tracking in execution phase

### Strong parts
- Most advanced human-in-the-loop review experience
- File-backed plans are explicit, inspectable, git-friendly
- Strong for team workflows requiring approval gates

### Weak parts
- Heavier operational footprint (browser UI + local server interactions)
- More complex than baseline plan-mode extension

---

## 4) `@devkade/pi-plan`

**Popularity:** ~0/mo (new)  
**Package type:** plan mode + approval loop (YOLO by default)

### Specifics / Functionality
- `/plan`, `/plan on|off|status`, `/plan <task>`
- Read-only mode blocks mutating tools (`edit`, `write`, `ast_rewrite`)
- Bash filtered through read-only checks
- Approval loop at `agent_end`: execute now / keep planning / exit plan mode
- Dynamic read-only toolset based on available tools

### Strong parts
- Strong command ergonomics
- Explicit approval workflow without major complexity
- Adaptive tool selection is practical in mixed setups

### Weak parts
- Less comprehensive progress UX vs official example (no equivalent todo extraction/widget flow)
- Persistence/state handling is simpler than baseline

---

## 5) `pi-plan-modus`

**Popularity:** ~0/mo (new)  
**Package type:** security-focused plan mode (RepoPrompt-aware)

### Specifics / Functionality
- `/plan`, `Ctrl+Alt+P`, `--plan`
- Restricts native tools (`edit`, `write`)
- Strong bash gating:
  - AST-based analysis via `just-bash`
  - regex fallback
  - redirect/write/editor command blocking
- Explicit RepoPrompt protection:
  - blocks write-capable MCP calls (`apply_edits`, `file_actions`)
  - blocks risky `rp-cli` / `rp_exec` write patterns
- Restores state across session start/switch/tree/fork

### Strong parts
- Strongest security hardening among compared options
- Unique, explicit handling of RepoPrompt write surfaces
- Very defensive state reapplication model

### Weak parts
- Less planning UX richness (no baseline-style extracted todo workflow)
- More focused on enforcement than collaborative planning flow

---

## Packages with “coding plan” naming but not plan-mode workflow

These are related to external providers/tools, not read-only planning mode extensions:
- `@imsus/pi-extension-minimax-coding-plan-mcp` (web/image tools)
- `pi-kimi-coder` (provider integration)
- `pi-planning-with-files` (skill package, file-based planning method)

---

## Quick Recommendation Matrix

- **Closest to official example:** `@ferologics/pi-extensions` (its `plan-mode`)
- **Lightweight/simple:** `@juanibiapina/pi-plan`
- **Strongest safety enforcement:** `pi-plan-modus`
- **Best visual review/approval workflow:** `@plannotator/pi-extension`
- **Balanced approval loop + simple controls:** `@devkade/pi-plan`
