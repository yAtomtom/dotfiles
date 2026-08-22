# Output Volume

- One step has a bounded stdout budget; exceeding it discards the whole step
- Never re-quote an artifact in the response; summarize the change only
- When editing is allowed, edit existing files; full Write only for creation or repair
- Do not iteratively trim-and-recount; estimate once, edit once, verify once
- Read large files by range; narrow with Grep first
- Never stream the raw output of a large command
