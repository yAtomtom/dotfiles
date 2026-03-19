## Error Taxonomy

| Verdict | Description |
|---------|-------------|
| correct | Right skill loaded for the intent |
| false_negative | Skill should have loaded but didn't. High bar: task must be meaningfully worse without it |
| false_positive | Skill loaded but was irrelevant |
| confused | Wrong skill loaded instead of the correct one |
| no_skill_needed | No skill was needed for this turn (most common) |
| explicit_invocation | User explicitly called `/skill-name` — not a routing event, skip from accuracy calc |
| coverage_gap | User intent not covered by any existing skill |

**Note on `disable-model-invocation: true`**: Skills with this flag never
auto-fire by design. They are excluded from false_negative analysis and
listed separately in the report as "explicit-only" skills.
