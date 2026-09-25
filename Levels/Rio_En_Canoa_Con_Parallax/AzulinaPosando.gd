@tool
class_name AzulinaPosando
extends Node3D

## Azulina decorativa ("AzulinaPosando1") para el nivel del río.
## Posa o baila en bucle continuo y suave.
## No tiene lógica de enemiga (sin emergencia, sin ataques, sin colisión).
## Es @tool para ver textura y pose directamente en el editor.
## Se remueve la línea de contorno para que luzca limpia como adorno.

const NOMBRE_BASE_POSE: String = "Pose sexy"
const MATERIAL_AZULINA: StandardMaterial3D = preload("res://Entities/Enemigo_Azulina/Azulina_MAT.tres")

# === EXPORTS ===
@export_category("Pose")
@export var animacion_pose: String = NOMBRE_BASE_POSE:  ## Animación a loopear (contiene o exacta)
	set(v):
		animacion_pose = v
		_pose_iniciada = false
		if is_node_ready() and _player:
			_iniciar_pose_en_loop()

@export_range(0.1, 2.0, 0.05) var velocidad: float = 1.15:  ## Con ritmo de baile
	set(v):
		velocidad = v
		if is_node_ready() and _player:
			_player.speed_scale = v


# === ESTADO PRIVADO ===
var _player: AnimationPlayer = null
var _nombre_loop: String = "PoseSexyLoop"
var _pose_iniciada: bool = false
var _reintentos_pose: int = 0
var _material_sin_outline: StandardMaterial3D = null

const MAX_REINTENTOS_POSE: int = 240  ## ~4 s a 60 fps reintentando el arranque
const VARIANTES_PREFIJO: Array[String] = ["", "Armature|", "Armature|Armature|"]  ## Nombres según importación del GLB


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_aplicar_material()
	if _iniciar_pose_en_loop():
		_pose_iniciada = true


func _process(_delta: float) -> void:
	if not _pose_iniciada:
		_reintentar_arranque_pose()
		return
	if _player == null:
		return
	# Si por alguna razón la animación se detuvo o fue reseteada, reanudar inmediatamente
	if not _player.is_playing() or _player.current_animation != _nombre_loop:
		_player.play(_nombre_loop)


# === FUNCIONES PRIVADAS ===
func _buscar_player() -> AnimationPlayer:
	var por_nombre := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if por_nombre:
		return por_nombre
	var por_tipo := find_children("*", "AnimationPlayer", true, false)
	if por_tipo.size() > 0:
		return por_tipo[0] as AnimationPlayer
	return null


func _iniciar_pose_en_loop() -> bool:
	_player = _buscar_player()
	if _player == null:
		return false
	var original: String = _resolver_animacion(_player, animacion_pose)
	if original.is_empty():
		return false
	_nombre_loop = original.replace(" ", "").replace("|", "") + "Loop"

	var es_baile: bool = animacion_pose.to_lower().contains("baile")
	var modo_loop := Animation.LOOP_LINEAR if es_baile else Animation.LOOP_PINGPONG

	if not _player.has_animation(_nombre_loop):
		var loop := _player.get_animation(original).duplicate() as Animation
		loop.loop_mode = modo_loop
		_agregar_animacion(_player, _nombre_loop, loop)
	else:
		var anim_existente := _player.get_animation(_nombre_loop)
		if anim_existente:
			anim_existente.loop_mode = modo_loop

	_player.speed_scale = velocidad
	_player.play(_nombre_loop)

	if not _player.animation_finished.is_connected(_al_terminar_animacion):
		_player.animation_finished.connect(_al_terminar_animacion)

	return true


func _al_terminar_animacion(anim_nombre: StringName) -> void:
	if not is_instance_valid(_player):
		return
	if anim_nombre == _nombre_loop or String(anim_nombre).contains(_nombre_loop):
		_player.play(_nombre_loop)


## Si el arranque falló en _ready (player o animación aún no disponibles),
## reintenta unos segundos; si agota los intentos lo reporta con la lista real.
func _reintentar_arranque_pose() -> void:
	_reintentos_pose += 1
	if _iniciar_pose_en_loop():
		_pose_iniciada = true
		return
	if _reintentos_pose < MAX_REINTENTOS_POSE:
		return
	set_process(false)
	var disponibles: String = "sin player"
	if _player != null:
		disponibles = str(_player.get_animation_list())
	push_error("[AzulinaPosando] no se pudo iniciar '" + animacion_pose + "'. Disponibles: " + disponibles)


## Resuelve el nombre real en el player (exacto con variantes de prefijo,
## luego insensible a mayúsculas y finalmente por contenido).
func _resolver_animacion(player: AnimationPlayer, base: String) -> String:
	var base_limpia: String = base.strip_edges()
	var base_lower: String = base_limpia.to_lower()

	# 1. Búsqueda exacta y con variantes de prefijo
	for prefijo: String in VARIANTES_PREFIJO:
		var candidato: String = prefijo + base_limpia
		if player.has_animation(candidato):
			return candidato
		for nombre: String in player.get_animation_list():
			if nombre.to_lower() == candidato.to_lower():
				return nombre

	# 2. Coincidencia exacta por nombre base sin prefijo (insensible a mayúsculas)
	for nombre: String in player.get_animation_list():
		var sin_prefijo: String = nombre.split("|")[-1].strip_edges().to_lower()
		if sin_prefijo == base_lower:
			return nombre

	# 3. Coincidencia por subcadena
	for nombre: String in player.get_animation_list():
		if nombre.to_lower().contains(base_lower):
			return nombre

	return ""


## En Godot 4 las animaciones viven en AnimationLibrary (add_animation directo es de Godot 3).
func _agregar_animacion(player: AnimationPlayer, nombre: String, anim: Animation) -> void:
	var listas: PackedStringArray = player.get_animation_library_list()
	var libreria: String = ""
	if listas.has(""):
		libreria = ""
	elif listas.size() > 0:
		libreria = listas[0]
	player.get_animation_library(libreria).add_animation(nombre, anim)


func _obtener_material_sin_outline() -> Material:
	if is_instance_valid(_material_sin_outline):
		return _material_sin_outline
	_material_sin_outline = MATERIAL_AZULINA.duplicate() as StandardMaterial3D
	_material_sin_outline.next_pass = null
	return _material_sin_outline


func _aplicar_material() -> void:
	var mat := _obtener_material_sin_outline()
	if mat == null:
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi:
			if mi.is_in_group("outline_meshes"):
				mi.remove_from_group("outline_meshes")
			mi.material_override = mat
			if mi.mesh != null:
				for s in range(mi.mesh.get_surface_count()):
					var surf_mat := mi.get_surface_override_material(s)
					if surf_mat is StandardMaterial3D and surf_mat.next_pass != null:
						var dupe := (surf_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
						dupe.next_pass = null
						mi.set_surface_override_material(s, dupe)
