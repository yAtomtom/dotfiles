# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations)

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics
rtk gain --history    # Show command usage history with savings
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (for debugging)
```

## Installation Verification

```bash
rtk --version         # Should show: rtk X.Y.Z
rtk gain              # Should work (not "command not found")
which rtk             # Verify correct binary
```

⚠️ **Name collision**: If `rtk gain` fails, you may have reachingforthejack/rtk (Rust Type Kit) installed instead.

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code hook.
Example: `git status` → `rtk git status` (transparent, 0 tokens overhead)

Refer to CLAUDE.md for full command reference.

## Exclude Policy (rtk-guard.sh)

A guard hook (`.claude/hooks/rtk-guard.sh`) runs in front of `rtk-rewrite.sh` and
passes the following commands through **unchanged** (no rtk rewrite), because rtk's
output either misleads Claude or breaks command semantics:

| Command | Reason for exclusion |
|---------|----------------------|
| `find` | rtk find drops compound predicates (`-delete`/`-exec`/`-not`) → silent failure |
| `ls` | non-standard timestamp-first format; file sizes shown as `0B` (broken) |
| `git diff` | non-unified diff format; misleads line/context reads (`git status`/`log` keep rtk) |
| `grep` / `cat` | truncation / intelligent filtering → Claude re-runs raw (net token loss) |

`cargo`/`npm`/`test`/`log`/`docker`/`tree`/`deps` etc. keep rtk savings.

**Why a separate guard hook** (not rtk's own `[hooks] exclude_commands`):
`exclude_commands` has no effect on the `rtk rewrite` path used by the hook
(upstream bug rtk-ai/rtk#1335). Editing `rtk-rewrite.sh` directly would also break
`rtk verify` (SHA-256 integrity) and be clobbered on `rtk init`/upgrade.
