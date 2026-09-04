class_name PlayerInterior
extends CharacterBody3D

@export_category("Movimiento")
@export var velocidad_caminar: float = 0.20  ## +10% de velocidad al caminar en el interior
@export var velocidad_rotacion: float = 10.0

const ANIM_IDLE := "IDLE_INTERIOR"
const ANIM_CAMINAR := "CAMINAR_INTERIOR"

var _arquera_modelo: Node3D
var _anim_tree: AnimationTree
var _anim_player: AnimationPlayer

var _yaw_base: float = 0.0
var _yaw_objetivo: float = 0.0
var _esta_caminando: bool = false
var puede_moverse: bool = true


func _ready() -> void:
	add_to_group("player_interior")

	_ajustar_linea_negra_minima()

	_arquera_modelo = find_child("ArqueraModel", true, false) as Node3D
	if _arquera_modelo:
		_yaw_base = _arquera_modelo.rotation.y
		_yaw_objetivo = _yaw_base

	_anim_tree = find_child("AnimationTree", true, false) as AnimationTree
	if _anim_tree:
		if _anim_tree.anim_player and has_node(_anim_tree.anim_player):
			_anim_player = _anim_tree.get_node(_anim_tree.anim_player) as AnimationPlayer
		if not _anim_player:
			_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

		if _anim_player:
			var anim_caminar_real := _obtener_anim_nombre(ANIM_CAMINAR)
			var anim_idle_real := _obtener_anim_nombre(ANIM_IDLE)
			for anim_name in [anim_idle_real, anim_caminar_real, "Armature|Armature|CAMINAR_ADELANTE", "Armature|Armature|IDLE", "IDLE_INTERIOR", "CAMINAR_INTERIOR"]:
				if _anim_player.has_animation(anim_name):
					_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

		_configurar_arbol_anim_dinamico()
		_anim_tree.active = true
		_anim_tree.set("parameters/Locomocion/transition_request", "idle")


func _ajustar_linea_negra_minima() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance:
			continue

		var count: int = mesh_instance.get_surface_override_material_count()
		if count == 0 and mesh_instance.mesh:
			count = mesh_instance.mesh.get_surface_count()

		for i in range(maxi(count, 1)):
			var mat: Material = mesh_instance.get_active_material(i)
			if mat and mat is StandardMaterial3D:
				var dup_mat: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
				if dup_mat.next_pass and dup_mat.next_pass is ShaderMaterial:
					var next_p: ShaderMaterial = dup_mat.next_pass.duplicate() as ShaderMaterial
					next_p.set_shader_parameter("outline_width", 2.0)
					dup_mat.next_pass = next_p
				mesh_instance.set_surface_override_material(i, dup_mat)

		if mesh_instance.material_override and mesh_instance.material_override is StandardMaterial3D:
			var dup_mat: StandardMaterial3D = mesh_instance.material_override.duplicate() as StandardMaterial3D
			if dup_mat.next_pass and dup_mat.next_pass is ShaderMaterial:
				var next_p: ShaderMaterial = dup_mat.next_pass.duplicate() as ShaderMaterial
				next_p.set_shader_parameter("outline_width", 2.0)
				dup_mat.next_pass = next_p
			mesh_instance.material_override = dup_mat


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if not puede_moverse:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_esta_caminando = false
		_actualizar_animacion()
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir_mundo := Vector3(input.x, 0.0, input.y)

	if dir_mundo.length_squared() > 1.0:
		dir_mundo = dir_mundo.normalized()

	velocity.x = dir_mundo.x * velocidad_caminar
	velocity.z = dir_mundo.z * velocidad_caminar

	move_and_slide()

	_esta_caminando = dir_mundo.length_squared() > 0.01

	if _esta_caminando:
		var delta_yaw := _calcular_delta_yaw_cardinal(dir_mundo)
		_yaw_objetivo = _yaw_base + delta_yaw

	if _arquera_modelo:
		var actual := _arquera_modelo.rotation.y
		var factor := clampf(velocidad_rotacion * delta, 0.0, 1.0)
		_arquera_modelo.rotation.y = lerp_angle(actual, _yaw_objetivo, factor)

	_actualizar_animacion()


func _calcular_delta_yaw_cardinal(d: Vector3) -> float:
	if absf(d.x) >= absf(d.z):
		return 0.0 if d.x > 0.0 else PI
	return PI / 2.0 if d.z < 0.0 else -PI / 2.0


func _actualizar_animacion() -> void:
	if not _anim_tree:
		return
	var estado := "caminar" if _esta_caminando else "idle"
	_anim_tree.set("parameters/Locomocion/transition_request", estado)


func _obtener_anim_nombre(preferido: String) -> String:
	if not _anim_player:
		return preferido
	if _anim_player.has_animation(preferido):
		return preferido
	var pref_lower := preferido.to_lower()
	for anim in _anim_player.get_animation_list():
		var a_lower := anim.to_lower()
		if a_lower == pref_lower or a_lower.ends_with("/" + pref_lower) or pref_lower in a_lower:
			return anim
	if preferido == ANIM_IDLE:
		for fallback in ["Armature|Armature|IDLE", "Armature|IDLE", "IDLE"]:
			if _anim_player.has_animation(fallback):
				return fallback
	elif preferido == ANIM_CAMINAR:
		for fallback in ["Armature|Armature|CAMINAR_ADELANTE", "Armature|CAMINAR_ADELANTE", "CAMINAR"]:
			if _anim_player.has_animation(fallback):
				return fallback
	return preferido


func _configurar_arbol_anim_dinamico() -> void:
	var root := AnimationNodeBlendTree.new()

	var anim_idle_real := _obtener_anim_nombre(ANIM_IDLE)
	var anim_caminar_real := _obtener_anim_nombre(ANIM_CAMINAR)

	var nodo_idle := AnimationNodeAnimation.new()
	nodo_idle.animation = anim_idle_real

	var nodo_caminar := AnimationNodeAnimation.new()
	nodo_caminar.animation = anim_caminar_real

	var timescale_caminar := AnimationNodeTimeScale.new()

	var trans_loco := AnimationNodeTransition.new()
	trans_loco.input_count = 2
	trans_loco.set_input_name(0, "idle")
	trans_loco.set_input_name(1, "caminar")
	trans_loco.xfade_time = 0.2

	root.add_node("Idle", nodo_idle)
	root.add_node("CaminarAnim", nodo_caminar)
	root.add_node("TimeScaleCaminar", timescale_caminar)
	root.add_node("Locomocion", trans_loco)

	root.connect_node("TimeScaleCaminar", 0, "CaminarAnim")
	root.connect_node("Locomocion", 0, "Idle")
	root.connect_node("Locomocion", 1, "TimeScaleCaminar")
	root.connect_node("output", 0, "Locomocion")

	_anim_tree.tree_root = root
	_anim_tree.set("parameters/TimeScaleCaminar/scale", 1.1)