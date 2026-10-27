Build a plain-English map of this codebase for the Context Outline VS Code extension and save it as `.context-outline/root.json` at the repo root (create the folder).

Read the code before writing. Every file path and line range in the map must be real.

## Format

{
  "name": "<repo name>",
  "summary": "<2-3 sentences: what the project does, in plain English>",
  "basedOn": "<branch> @ <short commit hash>",
  "children": [ <node>, ... ]
}

Each node:

{
  "title": "<plain-English step>",
  "note": "<optional: extra detail shown on hover>",
  "file": "<optional: path from the repo root>",
  "lines": "<optional: 1-based, like \"12-40\" or \"12\">",
  "children": [ <optional child nodes> ]
}

Only `title` is required.

## How to organise it

- Top level: numbered sections that follow how the program runs, for example "1. When the service starts up", "2. Customer API", "3. Background jobs". Common sections: startup, entry points (API, CLI, UI), background work (queues, jobs, timers), core logic, what's stored, other services it calls, helper tools, key domain types.
- Inside a section, list steps in the order they happen. Nest when a step has its own sub-steps. Keep it to about 4 levels deep.
- Titles are short, plain English, and say what happens, not function names. Good: "Skip if the asset isn't in the filter". Bad: "filterAssets()".
- Put important rules and edge cases in the title, for example "Deleting something already gone counts as success".
- Point `lines` at the smallest range that shows the step. A parent can point at the whole function.
- A grouping node with no file is fine, for example "Database writes".
- Use 2-space indentation. Write leaf nodes on one line: { "title": "...", "file": "...", "lines": "..." }
- Don't invent anything. If you're not sure, leave it out.

## Before you finish

Check that the JSON is valid, every `file` exists, and every `lines` range is inside its file.
