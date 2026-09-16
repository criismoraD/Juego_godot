@tool
class_name AzulinaPosando
extends Node3D

## Azulina decorativa ("AzulinaPosando1") para el nivel del río.
## Solo posa: reproduce "Pose sexy" y al terminar la invierte (vuelta),
## ida y vuelta continuos sin agregar ni retocar cuadros.
## No tiene lógica de enemiga (sin emergencia, sin ataques, sin colisión).
## Es @tool para ver textura y pose directamente en el editor.

const NOMBRE_BASE_POSE: String = "Pose sexy"
const MATERIAL_AZULINA: Material = preload("res://Entities/Enemigo_Azulina/Azulina_MAT.tres")

# === EXPORTS ===
@export_category("Pose")
@export var animacion_pose: String = NOMBRE_BASE_POSE  ## Animación a loopear (contiene)
@export_range(0.1, 2.0, 0.05) var velocidad: float = 1.15:  ## Con ritmo de baile
	set(v):
		velocidad = v
		if is_node_ready() and _player:
			_player.speed_scale = v


# === ESTADO PRIVADO ===
var _player: AnimationPlayer = null
var _hacia_atras: bool = false
var _nombre_loop: String = "PoseSexyLoop"
const MARGEN_GIRO: float = 0.05  ## Ventana (s) para invertir antes del extremo


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_aplicar_material()
	_iniciar_pose_en_loop()


func _process(_delta: float) -> void:
	if _player == null or _player.current_animation != _nombre_loop:
		return
	if not _player.is_playing():
		return
	var anim := _player.get_animation(_nombre_loop)
	if anim == null or anim.length <= 0.0:
		return
	var pos: float = _player.current_animation_position
	if not _hacia_atras and pos >= anim.length - MARGEN_GIRO:
		_hacia_atras = true
		_player.play_backwards(_nombre_loop)
	elif _hacia_atras and pos <= MARGEN_GIRO:
		_hacia_atras = false
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


func _iniciar_pose_en_loop() -> void:
	_player = _buscar_player()
	if _player == null:
		push_warning("[AzulinaPosando] sin AnimationPlayer: no se puede posar")
		return
	var original: String = ""
	for nombre: String in _player.get_animation_list():
		if nombre.contains(animacion_pose):
			original = nombre
			break
	if original.is_empty():
		push_warning("[AzulinaPosando] animación no encontrada: " + animacion_pose)
		return
	_nombre_loop = original.replace(" ", "").replace("|", "") + "Loop"
	if not _player.has_animation(_nombre_loop):
		var loop := _player.get_animation(original).duplicate() as Animation
		loop.loop_mode = Animation.LOOP_NONE
		_agregar_animacion(_player, _nombre_loop, loop)
	_hacia_atras = false
	_player.speed_scale = velocidad
	_player.play(_nombre_loop)


## En Godot 4 las animaciones viven en AnimationLibrary (add_animation directo es de Godot 3).
func _agregar_animacion(player: AnimationPlayer, nombre: String, anim: Animation) -> void:
	var listas: PackedStringArray = player.get_animation_library_list()
	var libreria: String = ""
	if listas.has(""):
		libreria = ""
	elif listas.size() > 0:
		libreria = listas[0]
	player.get_animation_library(libreria).add_animation(nombre, anim)


func _aplicar_material() -> void:
	if MATERIAL_AZULINA == null:
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi:
			mi.material_override = MATERIAL_AZULINA
