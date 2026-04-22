## 2023-10-27 - [Optimization Strategy for Godot Group Queries]
**Learning:** [Iterating over groups using `get_tree().get_nodes_in_group(group_name)` inside a loop over an array of group names creates an O(G*N) anti-pattern, frequently leading to redundant node processing if nodes belong to multiple groups.]
**Action:** [Use a Dictionary keyed by `node.get_instance_id()` to collect unique nodes across groups before iterating to apply state changes. During state restoration, iterate directly over the saved instance ID dictionary using `instance_from_id()` instead of requerying groups to eliminate tree searches entirely.]

## 2023-10-27 - [Headless GDScript Validation]
**Learning:** [Since the standard Godot executable is missing in the sandbox, syntax and logic cannot be verified using standard `godot --headless` commands.]
**Action:** [Install `gdtoolkit` via pip (`pip install gdtoolkit`) and use `gdlint` to catch syntax errors, spacing issues, and missing definitions.]

## 2026-04-17 - [Static Caching for Recursive Node Searches]
**Learning:** [Recursive searches like `find_child(..., true)` are O(N) and extremely costly when called every frame in `_process` or `_physics_process`. Static utility methods that perform these searches should implement caching.]
**Action:** [Implement static variables in utility classes to cache results. Include logic to invalidate the cache when the scene changes (e.g., comparing `get_tree().current_scene`) and use `is_instance_valid()` to ensure cached node references are still safe to use.]
## 2024-05-18 - Optimizing Tree Search Operations
**Learning:** `get_tree().root.find_child(...)` iterates over the entire tree, including Global Autoloads. This can be extremely slow and cause bugs, notably when searching for objects initialized during transitions.
**Action:** Always prefer `get_tree().get_nodes_in_group(...)` if available. If a traversal is necessary, scope it using `get_tree().current_scene.find_child(...)` or fallback correctly by resolving the scene root manually using `get_tree().root.get_child(get_tree().root.get_child_count() - 1)` to avoid null references when `current_scene` hasn't fully attached.

## 2024-06-25 - [Array Allocation and GC Pressure]
**Learning:** [Using `Array.filter()` or allocating new arrays inside `_process` loops creates severe Garbage Collection (GC) pressure in GDScript, leading to stuttering.]
**Action:** [Avoid allocating new arrays or filtering every frame. Instead, iterate over existing arrays using simple loops to count matching items, or maintain cleanly updated lists asynchronously.]

## 2024-06-25 - [Centralized Data Caching to Avoid Group Lookups]
**Learning:** [Repeatedly calling `get_tree().get_nodes_in_group()` inside physics or process ticks for multiple entities (like `ImpShieldGirl` seeking an enemy) causes O(N) performance drops.]
**Action:** [Utilize central managers (like `WaveSpawner`) to maintain authoritative arrays of active entities. Have individual actors cache a reference to the manager (using a `static var` strategy) and fetch the arrays directly instead of querying the scene tree.]
## 2024-05-17 - Array.filter() allocations in _process loops
**Learning:** In GDScript, using `Array.filter(func(x): ...)` allocates a new Array on the heap and creates overhead from lambda execution. When used in `_process` loops (e.g. tracking valid enemies in `WaveSpawner.gd`), this creates rapid Garbage Collection (GC) pressure causing micro-stuttering.
**Action:** Replace `Array.filter` checks in frequent update loops with backward iteration: `for i in range(arr.size() - 1, -1, -1): if condition: arr.remove_at(i)`. This modifies the array in-place and completely eliminates the allocation and lambda overhead.

## 2025-01-24 - [Performance] Node Group Caching in GDScript
**Learning:** Calling `get_tree().get_nodes_in_group()` in Godot 4 triggers a SceneTree traversal and returns a fresh copy of the array on every call. In UI toggles or performance-sensitive loops, this leads to redundant allocations and CPU overhead.
**Action:** Implement a local cache (e.g., `_escudos_cache`) to store group references. Use a helper method (e.g., `_get_valid_escudos`) to prune the cache using backward iteration and `is_instance_valid()` before accessing the nodes.

## 2026-04-22 - [In-Place Array Iteration over Creation in Hot Paths]
**Learning:** [Allocating arrays (like `lista_limpia`) during `_process` to track active nodes creates unnecessary Garbage Collection (GC) overhead every single frame.]
**Action:** [Use an in-place reverse iteration over existing arrays (`for i in range(arr.size() - 1, -1, -1):`) and remove invalid entries directly using `remove_at(i)`. This modifies the array without requiring new allocations, effectively eliminating GC stutters in tight loops.]
