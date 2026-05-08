extends Node

## Controlador principal para el modo Level Designer (Mario Maker style).

@onready var item_list: ItemList = $"../HSplitContainer/Sidebar/LibraryPanel/ItemList"
@onready var btn_play: Button = $"../HSplitContainer/Sidebar/ButtonPlay"
@onready var btn_save: Button = $"../HSplitContainer/Sidebar/ButtonSave"
@onready var viewport: SubViewport = $"../HSplitContainer/MainCanvas/ViewportContainer/SubViewport"

var current_level_data: Resource
var selected_prefab_path: String = ""
var ghost_instance: Node3D = null
var current_snap_size: float = 1.0

func _ready() -> void:
	if item_list:
		item_list.item_selected.connect(_on_item_selected)

	if btn_save:
		btn_save.pressed.connect(_on_save_pressed)

	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)

	_load_prefab_library()

	# Load or create level data
	current_level_data = load("res://addons/level_designer/level_data.gd").new()

func _on_save_pressed() -> void:
	if current_level_data:
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("Levels"):
			dir.make_dir("Levels")

		var save_path = "res://Levels/CustomLevel.tres"
		var err = ResourceSaver.save(current_level_data, save_path)
		if err == OK:
			print("Saved custom level to: ", save_path)
		else:
			push_error("Failed to save level data!")

func _on_play_pressed() -> void:
	if current_level_data:
		# Save first to ensure the most recent is loaded
		_on_save_pressed()
		# Global singleton or persistent node would typically pass this over,
		# but passing via file is also clean. We will configure the global WaveSpawner
		# inside GAMEPLAY.tscn to check for this custom level on ready, or we transition.
		# For simplicity, we can load the scene and then inject the data

		# Alternatively, use an Autoload if it existed, but we'll try injecting after load
		var packed_gameplay = load("res://Scenes/Levels/GAMEPLAY.tscn")
		if packed_gameplay:
			var gameplay_instance = packed_gameplay.instantiate()

			# Find spawner and inject
			var spawners = gameplay_instance.find_children("*", "Node3D", true, false)
			for s in spawners:
				if s.has_method("iniciar_desde_data"):
					s.iniciar_desde_data(current_level_data)

			# Set the scene
			get_tree().root.add_child(gameplay_instance)
			get_tree().current_scene.queue_free()
			get_tree().current_scene = gameplay_instance
		else:
			push_error("Could not load GAMEPLAY.tscn for testing.")

func _load_prefab_library() -> void:
	if not item_list:
		return
	item_list.clear()
	# Hardcoded for now, could be dynamic scanning
	var items = [
		{"name": "Goblin", "path": "res://Scenes/Characters/Goblin.tscn"},
		{"name": "Goblin Girl", "path": "res://Scenes/Characters/GoblinGirl.tscn"},
		{"name": "Imp Shield", "path": "res://Scenes/Characters/ImpShieldGirl.tscn"},
		{"name": "Tower", "path": "res://Scenes/Environment/TORRE.tscn"}
	]
	for item in items:
		var idx = item_list.add_item(item["name"])
		item_list.set_item_metadata(idx, item["path"])

func _on_item_selected(index: int) -> void:
	selected_prefab_path = item_list.get_item_metadata(index)
	print("Selected Prefab: ", selected_prefab_path)
	_update_ghost_instance()

func _update_ghost_instance() -> void:
	if ghost_instance:
		ghost_instance.queue_free()
		ghost_instance = null

	if selected_prefab_path != "":
		var scene = load(selected_prefab_path)
		if scene:
			ghost_instance = scene.instantiate() as Node3D
			if ghost_instance:
				viewport.add_child(ghost_instance)
				# Make it look like a ghost (optional: traverse and set transparent material)

func _process(delta: float) -> void:
	if not ghost_instance or not viewport:
		return

	var mouse_pos = viewport.get_mouse_position()
	var camera = viewport.get_camera_3d()
	if not camera:
		return

	# Simple 2.5D mapping (Z = 0)
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)

	# Intersect with Z=0 plane (Y is up, X is right, we want object moving along X and Y, or X and Z if top-down. Assuming 2.5D side scroller where Z=0)
	# For side scroller: X and Y move, Z = 0
	if ray_dir.z != 0:
		var distance = (0 - ray_origin.z) / ray_dir.z
		var intersection = ray_origin + ray_dir * distance

		# Snapping
		intersection.x = round(intersection.x / current_snap_size) * current_snap_size
		intersection.y = round(intersection.y / current_snap_size) * current_snap_size
		intersection.z = 0

		ghost_instance.global_position = intersection

func _input(event: InputEvent) -> void:
	if not ghost_instance or not viewport:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var rect = viewport.get_parent_control().get_global_rect()
		if rect.has_point(get_viewport().get_mouse_position()):
			_place_object()

func _place_object() -> void:
	if not ghost_instance or not current_level_data:
		return

	var pos = ghost_instance.global_position

	# Determinar si es enemigo o elemento
	if selected_prefab_path.contains("Characters"):
		# Es un enemigo, agregar a la oleada 1 por defecto (crearla si no existe)
		if current_level_data.oleadas.size() == 0:
			current_level_data.agregar_oleada()

		# Calcular tiempo basado en pos.x (como ejemplo simple, X=10 -> t=10s)
		var spawn_time = pos.x
		if spawn_time < 0: spawn_time = 0

		current_level_data.agregar_enemigo_a_oleada(0, selected_prefab_path, spawn_time, pos)
		print("Placed enemy at ", pos, " time: ", spawn_time)
	else:
		# Es un elemento estático
		current_level_data.agregar_elemento(selected_prefab_path, pos, Vector3.ZERO, Vector3.ONE)
		print("Placed element at ", pos)

	# Leave a permanent copy in the viewport so the designer can see it
	var permanent_instance = load(selected_prefab_path).instantiate() as Node3D
	viewport.add_child(permanent_instance)
	permanent_instance.global_position = pos
