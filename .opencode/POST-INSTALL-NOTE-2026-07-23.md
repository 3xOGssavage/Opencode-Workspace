# Post-Install Note — 2026-07-23

## Skills Installed

12 new skills installed and repositioned to `C:\Users\user\.config\opencode\skills\`
(highest-priority path #8 in `opencode.json:skills.paths`).

### greensock/gsap-skills (8)

- `gsap-core` (15 KB)
- `gsap-timeline` (4.5 KB)
- `gsap-scrolltrigger` (18.6 KB)
- `gsap-plugins` (22 KB)
- `gsap-utils` (12.3 KB)
- `gsap-react` (6.7 KB)
- `gsap-performance` (4.2 KB)
- `gsap-frameworks` (10.8 KB)

### Leonxlnx/taste-skill (v2)

- `design-taste-frontend` (88.4 KB)

### Jakubantalik/transitions.dev (2)

- `transitions-dev` (23.4 KB)
- `transitions-polish` (12.8 KB)

### davila7/claude-code-templates

- `seo` (11.7 KB)

## ACTION REQUIRED: Restart opencode session

The 12 newly installed skills are **on disk** but will **not** appear in the
agent's available-skills list within the current opencode session. This is a
known opencode caching limitation (issue #8751: no hot-reload of skills).

**To activate:** exit the current opencode session and start a new one
(any project). On the next session start, the SKILL.md files in
`C:\Users\user\.config\opencode\skills\*/SKILL.md` will be discovered and
advertised to the model.

## Patches applied during install

1. `transitions-dev/SKILL.md` had a 1194-char `description:` frontmatter value,
   exceeding the opencode 1024-char limit, which blocked discovery entirely.
   **Patch applied:** trimmed description to 623 chars, preserving all trigger
   terms and reference to `transitions-polish`.

## Verification status

- All 12 SKILL.md files exist on disk: **OK**
- All `name:` fields match their directory: **OK**
- All `description:` fields <= 1024 chars (after patch): **OK**
- `verify-inheritance.ps1` returns 11/11 PASS: **OK**
- `opencode.json:skills.paths` correctly resolved: **OK** (121 SKILL.md across
  8 paths)
- Active session discovery: **REQUIRES RESTART** (opencode no-hot-reload)

## Backup refs

- `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-22.zip` (50.75 MB, full
  workspace pre-this-session)
- `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-23-b.zip` (31.2 KB,
  incremental of `~/.config/opencode/skills/` immediately before new installs)

## Phase 5c — 2026-07-24 (restoration of `transitions-dev/SKILL.md`)

After initial install + first restart, a follow-up audit revealed
`transitions-dev/SKILL.md` had been reduced to 670 B during the failed
Phase 5b description-trim attempt (only `name:` + `description:` were
preserved; the body was stripped). This phase restores the file bytes-perfect
from upstream.

### Actions

1. **Pre-restart backup:**
   `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-24-0304.zip` (11.6 MB)
2. **Upstream download (raw bytes, no encoding transformation):**
   `https://raw.githubusercontent.com/Jakubantalik/transitions.dev/main/skills/transitions-dev/SKILL.md`
   — 23,177 bytes raw.
3. **Body preservation:** 21,739 chars of upstream body kept intact.
4. **Description trimmed** to 542 chars (single-line, well under 1024 char
   opencode limit), preserving all 21 transition names and 4 command triggers
   (transitions reveal/review/apply/refine), with a "see transitions-polish"
   reference retained.
5. **Frontmatter repaired:** clean `--- / name: / description: / ---`
   opener/closer confirmed.
6. **Broken-state copy:** `transitions-dev/SKILL.md.broken-pre-5c` retained at
   `C:\Users\user\.config\opencode\skills\transitions-dev\` for forensic
   reference.

### Verification (post Phase 5c)

- `transitions-dev/SKILL.md`: 22,526 bytes, all 8 B-3 validation checks PASS:
  - size in 15–25 KB range ✅
  - first three bytes = `--` ✅
  - starts with frontmatter ✅
  - `name:` field present ✅
  - `name: transitions-dev` matches directory ✅
  - `description:` present ✅
  - `description:` is single-line ✅
  - `description:` length = 542 chars ≤ 1024 ✅
- Other 11 SKILL.md files: all PASS (sizes 4–88 KB, all frontmatter valid).
- `verify-inheritance.ps1`: 11/11 PASS.
- Cross-path name-collision scan: 120 unique names discovered.
  Pre-existing collisions found: `setup`, `deploy`, `logs`, `vercel-cli`
  duplicated across path #6 and path #7 (path #7 wins per precedence rule).
  **Zero collisions involving the 12 newly installed skills.**

## Final Status

All 12 skills installed at `C:\Users\user\.config\opencode\skills/`
(highest priority, path #8). After session restart, opencode will discover
and load all 12 + transitions-dev fully restored.

## Backup refs

- `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-22.zip` (50.75 MB, full
  workspace pre-this-session)
- `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-23-b.zip` (31.2 KB,
  incremental of `~/.config/opencode/skills/` immediately before new installs)
- `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-23.zip` (12 MB, mid-session
  staging snapshot)
- `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-24-0304.zip` (11.6 MB,
  pre-Phase-5c snapshot)

## To roll back

```powershell
# Brute-force rollback for the 12 new skills
$toRemove = @("gsap-core","gsap-timeline","gsap-scrolltrigger","gsap-plugins",
"gsap-utils","gsap-react","gsap-performance","gsap-frameworks",
"design-taste-frontend","transitions-dev","transitions-polish","seo")
foreach ($s in $toRemove) {
  $p = "C:\Users\user\.config\opencode\skills\$s"
  if (Test-Path $p) { Remove-Item $p -Recurse -Force -Confirm:$false }
}
```

## Ponytail — 2026-07-24

### What it is

[DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) (v4.8.4,
MIT) installs a behavior-injection plugin for opencode that channels a "lazy
senior dev" ruleset into every chat's system prompt. Adds a 7-rung ladder
(YAGNI → reuse → stdlib → native → existing dep → one-liner → minimum), ships
6 slash commands (`/ponytail`, `/ponytail-review`, `/ponytail-audit`,
`/ponytail-debt`, `/ponytail-gain`, `/ponytail-help`), and registers 6 skills
(ponytail, ponytail-review, ponytail-audit, ponytail-debt, ponytail-gain,
ponytail-help) in `node_modules\@dietrichgebert\ponytail\skills\`.

### Actions

1. **Pre-install backup:** `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-24-1159-ponytail-pre.zip`
   (26.96 MB, snyc of `.opencode/`, `~/.config/opencode/`, `%APPDATA%/opencode/`,
   `~/.agents/`, plus top-level files)
2. **Sandbox-then-promote**: built `opencode.json` copy at
   `C:\Users\user\AppData\Local\Temp\ponytail-sandbox\`, injected plugin entry,
   npm-installed package, ran bypass-style probes that confirmed all 3 plugin
   hooks fired correctly.
3. **npm-global install:** `npm install -g @dietrichgebert/ponytail` — added 1
   package in 2s, lands at `C:\Users\user\AppData\Roaming\npm\node_modules\@dietrichgebert\ponytail`.
4. **Plugin main resolves:** `Default export: [AsyncFunction]` — opencode can
   load it directly via `"@dietrichgebert/ponytail"` plugin spec.
5. **System-prompt transform verified:** `getPonytailInstructions("full")`
   returns 5,299 chars of valid Ponytail rules content with the ladder,
   persistence warning, when-NOT-to-be-lazy clauses, and hardware-calibration
   carve-outs.
6. **Promotion to real config:** appended `"@dietrichgebert/ponytail"` as the
   4th entry in `F:\CD\Opencode\opencode.json:plugin[]` (after superpowers,
   opencode-notify, envsitter-guard).

### Sandbox → production promotion

- **Default mode:** `full` (matches ponytail README default, balanced ladder)
- **Sandbox JSON present at:** `C:\Users\user\AppData\Local\Temp\ponytail-sandbox\opencode.json`
- **Real JSON promoted at:** `F:\CD\Opencode\opencode.json` (lines 531-536)
- **verify-inheritance.ps1:** 11/11 PASS

### Plugin hooks (3) verified

| Hook                                 | Verified                                                                                  |
| ------------------------------------ | ----------------------------------------------------------------------------------------- |
| `config`                             | Mutates `config.skills.paths` to add ponytail skills dir; registers `ponytail-*` commands |
| `experimental.chat.system.transform` | Appends Ponytail ruleset to system prompt on every chat turn (5299 chars)                 |
| `command.execute.before`             | Captures `/ponytail` argument, persists mode to `~/.config/opencode/.ponytail-active`     |

### Commands added (after restart)

| Command                                             | Purpose                                        |
| --------------------------------------------------- | ---------------------------------------------- |
| `/ponytail [lite\|full\|ultra]`                     | Switch intensity level. Default `full`.        |
| `/ponytail off` or `stop ponytail` or `normal mode` | Disable                                        |
| `/ponytail-review`                                  | Review git diff for over-engineering only      |
| `/ponytail-audit`                                   | Whole-repo over-engineering audit              |
| `/ponytail-debt`                                    | Collect `ponytail:` markers into a debt ledger |
| `/ponytail-gain`                                    | Render the measured-impact scoreboard          |
| `/ponytail-help`                                    | Quick reference card                           |

### State file format

Location: `C:\Users\user\.config\opencode\.ponytail-active`
Format: one of `off`, `lite`, `full`, `ultra` (raw bytes, no BOM).
**Note:** when written via Windows PowerShell `Set-Content -Encoding utf8`, a UTF-8 BOM
(`\ufeff`) is automatically prepended, which breaks `normalizePersistedMode`'s matching.
**Always write state via `[System.IO.File]::WriteAllBytes` or `[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]($false))` to avoid the BOM.**

Default if state file is missing: `full` (from `DEFAULT_MODE` in
`hooks/ponytail-config.js`).

### Env-var overrides (optional)

| Env var                    | Effect                                                        |
| -------------------------- | ------------------------------------------------------------- |
| `PONYTAIL_DEFAULT_MODE`    | One of `off\|lite\|full\|ultra` — preferred over file default |
| `PONYTAIL_QUIET_STARTUP=1` | Silence pi-style "Ponytail loaded" startup toast              |
| `PONYTAIL_HIDE_STATUS=1`   | Hide the status-bar indicator                                 |

### Marketing-claim caveat

The original 80–94% LOC-reduction benchmark was revised to 54% mean after a
critic pointed out the comparison arm padded answers with prose. See Scott
Logic 2026-06-16 "Ponytail? YAGNI!" critique for the methodology argument.
The runtime behavior of the plugin is unchanged regardless of which number
is correct; the ruleset is well-defined and useful.

### Coexistence notes

- **superpowers plugin:** loads first, injects content into its own skills.
  Ponytail's `system.transform` runs on every turn and is independent of
  superpowers' skill-loading order. Expected to coexist cleanly; if visible
  conflict, disable one via plugin[] removal.
- **add-y-test-engineer skill:** when user explicitly asks for tests, fires
  via skill-name resolution and may compete with ponytail's "non-trivial
  logic leaves ONE runnable check behind" rule. The two converge toward the
  same outcome; no functional conflict.

### Action required (user)

**Perform a full opencode process restart** (start menu, then re-run
`opencode`). Skill discovery in the current session is cached at startup;
the plugin was added in mid-session and won't activate until the next opencode
launch.

### Verification

- `npm-global install`: ✅ added 1 package in 2s
- Plugin main resolves: ✅ `[AsyncFunction]`
- System transform injects: ✅ 5299-chars Ponytail ruleset
- 6 skills (`ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help`): ✅ all with valid SKILL.md
- 6 commands registered: ✅ via `command/ponytail*.md`
- 1 plugins registered: ✅ via `plugins/ponytail.mjs`
- `verify-inheritance.ps1`: ✅ 11/11 PASS

### Rollback (ponytail-only)

```powershell
# Edit F:\CD\Opencode\opencode.json: remove "@dietrichgebert/ponytail" from plugin[]
# Then uninstall the npm package:
npm uninstall -g @dietrichgebert/ponytail
# Clear state file:
Remove-Item "$env:USERPROFILE\.config\opencode\.ponytail-active" -ErrorAction SilentlyContinue
# Restore backup zip if needed:
# Expand F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-24-1159-ponytail-pre.zip and overwrite opencode.json
```
