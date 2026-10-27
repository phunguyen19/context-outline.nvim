Bring this project's Context Outline map, `.context-outline/root.json`, up to date with the current code. Update the existing map; don't rebuild it from scratch.

## Find what changed

1. Read `basedOn` in `.context-outline/root.json` (like "main @ 12ef58a").
2. Run `git diff <that commit>..HEAD --stat`, then read the diffs of the changed files. If the commit can't be found, check every node against the current code instead.

## Update the map

- Fix `lines` for every node whose code moved, so the range covers the same code as before.
- Fix `file` for code that moved to another file.
- Add nodes for new behaviour, in the section and position where it happens. Match the style of nearby nodes: short plain-English titles that say what happens, with important rules and edge cases in the title.
- Change a title only when the behaviour it describes changed.
- Remove nodes whose code is gone.
- Keep everything else as it is: section order, titles, notes, nesting, and formatting (2-space indentation, leaf nodes on one line). Someone may have edited the map by hand.
- Set `basedOn` to "<current branch> @ <current short commit hash>".
- Don't invent anything. If you're not sure, leave it out.

## Before you finish

- Check that the JSON is valid, every `file` exists, and every `lines` range is inside its file and still points at the code its title describes.
- Reply with a short list of what you added, removed, renamed, and moved.
