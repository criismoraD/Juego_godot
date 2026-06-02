
## 2024-05-18 - Caching Player Reference to Prevent N+1 Node Group Lookups
**Learning:** Calling `get_tree().get_nodes_in_group("player")` within functions that are called frequently or repetitively causes O(N) scene tree traversals and array allocations. In `Scripts/Levels/NIVEL01.gd`, this was occurring every time `_set_movimiento_jugador_bloqueado` was called.
**Action:** Implemented caching for the `player` group lookup by adding a class variable `_cached_players: Array[Node] = []` and a helper method `_get_players_cached()`. This method retrieves the nodes once and then iterates backward to validate instances on subsequent calls, converting the lookup to an O(1) operation without allocating new arrays.
