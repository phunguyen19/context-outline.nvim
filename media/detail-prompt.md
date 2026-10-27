Add more detail to one node of this project's Context Outline map, `.context-outline/root.json`.

The node: {{PATH}}
{{WHERE}}

1. Find that node in root.json (follow the titles from the top) and read the code it points at, plus the code it calls.
2. Add child nodes under it for the steps inside, in the order they happen. Nest when a step has its own sub-steps, at most 2 levels below this node.
3. If it already has children, keep them. Add the missing steps in the right place, or add children under the existing ones.

Match the style of the rest of the map: short plain-English titles that say what happens (not function names), important rules and edge cases in the title, `lines` pointing at the smallest range that shows the step, leaf nodes on one line, 2-space indentation. Don't change any other node or `basedOn`. Don't invent anything. If you're not sure, leave it out.

Before you finish: check that the JSON is valid, every new `file` exists, and every `lines` range is inside its file. Reply with a short list of what you added.
