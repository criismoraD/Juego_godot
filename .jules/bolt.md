## 2023-10-27 - [Optimization Strategy for Godot Group Queries]
**Learning:** [Iterating over groups using `get_tree().get_nodes_in_group(group_name)` inside a loop over an array of group names creates an O(G*N) anti-pattern, frequently leading to redundant node processing if nodes belong to multiple groups.]
**Action:** [Use a Dictionary keyed by `node.get_instance_id()` to collect unique nodes across groups before iterating to apply state changes. During state restoration, iterate directly over the saved instance ID dictionary using `instance_from_id()` instead of requerying groups to eliminate tree searches entirely.]

## 2023-10-27 - [Headless GDScript Validation]
**Learning:** [Since the standard Godot executable is missing in the sandbox, syntax and logic cannot be verified using standard `godot --headless` commands.]
**Action:** [Install `gdtoolkit` via pip (`pip install gdtoolkit`) and use `gdlint` to catch syntax errors, spacing issues, and missing definitions.]
