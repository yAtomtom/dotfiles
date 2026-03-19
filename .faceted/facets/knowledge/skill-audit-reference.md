## Prerequisites

- `pip install tiktoken` (optional — falls back to character-based estimation)
- No external API keys required. Analysis uses Claude sub-agents.

## Analysis Capabilities

### Routing Accuracy
Per-skill fire count, accuracy, false positives/negatives, specific incidents
with root cause analysis. See `~/.claude/skills/skill-auditor/agents/routing-analyst.md` for the rubric.

### Attention Budget
Total description tokens across all skills. Per-skill token cost and efficiency
rating. Identifies bloated descriptions that waste attention budget.
See `~/.claude/skills/skill-auditor/agents/portfolio-analyst.md`.

### Competition Matrix
Classifies skill-pair relationships: orthogonal / adjacent / overlapping / nested.
Based on real transcript evidence, not just keyword overlap.

### Portfolio-Aware Optimization
Patches consider the full skill set. Cascade checking is mandatory — each patch
states what it fixes, what it might break, and the token budget impact.
See `~/.claude/skills/skill-auditor/agents/improvement-planner.md`.

## Workspace Structure

    <base_dir>/                          # e.g. ~/.claude/skill-report/
    ├── health-history.json              # shared across runs (append-only)
    ├── 2026-03-04T18-45-23/             # run 1
    │   ├── transcripts.json
    │   ├── skill-manifest.json
    │   ├── batch-audit-*.json
    │   ├── audit-report.json
    │   ├── portfolio-analysis.json
    │   ├── improvement-proposals.json
    │   ├── patches/*.patch.json
    │   ├── skill-audit-report.html
    │   └── changelog.md
    └── 2026-03-04T20-12-07/             # run 2
        └── ...

## Troubleshooting

- **"No project found"**: Run with `--cwd` pointing to the project root, or
  use `--list` to see available projects.
- **tiktoken not installed**: Token counts will use character-based approximation.
  Install with `pip install tiktoken` for accuracy.
- **Large project (100+ sessions)**: Sessions are batched automatically. Multiple
  sub-agents run in parallel.
- **Sub-agent produces invalid JSON**: Re-run the specific sub-agent step. The
  rubric in agents/ includes exact schema specifications.
