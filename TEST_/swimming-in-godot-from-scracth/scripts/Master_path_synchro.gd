@tool
extends Path3D

@export var master_path: Path3D
# Notice the brackets! This makes a dynamic list in the Inspector.
@export var shadow_paths: Array[Path3D] = []

var _is_updating: bool = false
var master_memory: Array = []

func _process(delta):
	if master_path and master_path.curve:
		if not master_path.curve.changed.is_connected(_sync_paths):
			master_path.curve.changed.connect(_sync_paths)

	# Setup initial memory if you just opened the project or added a new path
	if master_path and master_path.curve:
		if master_memory.size() == 0 and master_path.curve.get_point_count() > 0:
			_take_snapshot()
			# Make sure all newly added shadow paths have the baseline dots!
			for shadow in shadow_paths:
				if shadow and shadow.curve:
					if shadow.curve.get_point_count() != master_path.curve.get_point_count():
						_force_rebuild_shadow(shadow)

func _sync_paths():
	if _is_updating: return
	if master_path == null or master_path.curve == null: return

	var m_count = master_path.curve.get_point_count()

	# --- EVENT 1: A point was ADDED or DELETED ---
	if m_count != master_memory.size():
		_handle_point_add_remove(m_count)
		return

	_is_updating = true

	# --- EVENT 2: A point (or its curve handles) was MOVED ---
	var points_moved = false
	
	# Mute all shadows
	for shadow in shadow_paths:
		if shadow and shadow.curve:
			shadow.curve.set_block_signals(true)

	for i in range(m_count):
		var current_m_pos = master_path.curve.get_point_position(i)
		var current_m_in = master_path.curve.get_point_in(i)
		var current_m_out = master_path.curve.get_point_out(i)
		var old_m = master_memory[i]

		var pos_changed = current_m_pos.distance_squared_to(old_m.pos) > 0.0001
		var in_changed = current_m_in.distance_squared_to(old_m.in_vec) > 0.0001
		var out_changed = current_m_out.distance_squared_to(old_m.out_vec) > 0.0001

		if pos_changed or in_changed or out_changed:
			
			if pos_changed:
				var distance_moved = current_m_pos - old_m.pos
				# Push EVERY shadow path by the distance moved!
				for shadow in shadow_paths:
					if shadow and shadow.curve and shadow.curve.get_point_count() == m_count:
						var current_s_pos = shadow.curve.get_point_position(i)
						shadow.curve.set_point_position(i, current_s_pos + distance_moved)

			if in_changed or out_changed:
				# Copy handles to EVERY shadow path
				for shadow in shadow_paths:
					if shadow and shadow.curve and shadow.curve.get_point_count() == m_count:
						shadow.curve.set_point_in(i, current_m_in)
						shadow.curve.set_point_out(i, current_m_out)

			master_memory[i] = { "pos": current_m_pos, "in_vec": current_m_in, "out_vec": current_m_out }
			points_moved = true

	# Unmute and update all shadows
	for shadow in shadow_paths:
		if shadow and shadow.curve:
			shadow.curve.set_block_signals(false)
			if points_moved:
				shadow.curve.changed.emit()

	_is_updating = false


# --- THE DIFFING ENGINE (Finds where you added/deleted dots) ---
func _handle_point_add_remove(m_count):
	_is_updating = true
	
	for shadow in shadow_paths:
		if shadow and shadow.curve:
			shadow.curve.set_block_signals(true)

	if m_count > master_memory.size(): # POINT ADDED
		var inserted_idx = m_count - 1 
		
		for i in range(master_memory.size()):
			if master_path.curve.get_point_position(i).distance_squared_to(master_memory[i].pos) > 0.0001:
				inserted_idx = i
				break
		
		var new_pos = master_path.curve.get_point_position(inserted_idx)
		var new_in = master_path.curve.get_point_in(inserted_idx)
		var new_out = master_path.curve.get_point_out(inserted_idx)
		
		# Insert dot on EVERY shadow path, maintaining their unique widths
		for shadow in shadow_paths:
			if shadow and shadow.curve:
				var s_count = shadow.curve.get_point_count()
				var ref_offset = Vector3.ZERO
				
				if inserted_idx > 0 and inserted_idx - 1 < s_count:
					ref_offset = shadow.curve.get_point_position(inserted_idx - 1) - master_memory[inserted_idx - 1].pos
				elif s_count > 0:
					ref_offset = shadow.curve.get_point_position(0) - master_memory[0].pos
					
				shadow.curve.add_point(new_pos + ref_offset, new_in, new_out, inserted_idx)

	elif m_count < master_memory.size(): # POINT DELETED
		var deleted_idx = master_memory.size() - 1 
		
		for i in range(m_count):
			if master_path.curve.get_point_position(i).distance_squared_to(master_memory[i].pos) > 0.0001:
				deleted_idx = i
				break
		
		# Remove dot on EVERY shadow path
		for shadow in shadow_paths:
			if shadow and shadow.curve and deleted_idx < shadow.curve.get_point_count():
				shadow.curve.remove_point(deleted_idx)

	for shadow in shadow_paths:
		if shadow and shadow.curve:
			shadow.curve.set_block_signals(false)
			shadow.curve.changed.emit()

	_take_snapshot()
	_is_updating = false

func _force_rebuild_shadow(shadow_path: Path3D):
	shadow_path.curve.clear_points()
	for i in range(master_path.curve.get_point_count()):
		shadow_path.curve.add_point(
			master_path.curve.get_point_position(i),
			master_path.curve.get_point_in(i),
			master_path.curve.get_point_out(i)
		)

func _take_snapshot():
	if master_path == null or master_path.curve == null: return
	master_memory.clear()
	for i in range(master_path.curve.get_point_count()):
		master_memory.append({
			"pos": master_path.curve.get_point_position(i),
			"in_vec": master_path.curve.get_point_in(i),
			"out_vec": master_path.curve.get_point_out(i)
		})
