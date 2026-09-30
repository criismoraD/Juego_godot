class_name CienagaParallax
extends Node3D

## Controlador de parallax + seguimiento de cámara para el Nivel Ciénaga.
## REGLA DEL NIVEL CIENAGA:
## - La cámara del frente (CamaraFrente) sigue al personaje en X con clamp y suavizado.
## - La cámara del fondo (CamaraFondoDOF, capa 2 con DOF) acompaña con factor sutil (parallax).
## - El fondo 2D (FONDO estatico) queda 100% estático en el encuadre de su cámara.
## - Todo objeto decorativo distante (Z < umbral) se mueve a la capa 2 para
##   difuminarse con la distancia vía el DOF de CamaraFondoDOF.

# === CONSTANTES ===
const CAPA_FONDO_DOF: int = 2
const CAPA_FRENTE_NITIDO: int = 1
const GRUPO_PLAYER: String = "player"
const NOMBRE_NODO_PLAYER: String = "Player"

# Prefijos (en minúsculas, sin espacios) de decorado que SIEMPRE va al fondo.
const PREFIJOS_FONDO_SIEMPRE: Array[String] = [
	"chozaazulina",
	"chochaverde",
	"carretacomercio",
	"carreta",
	"campamento",
	"bote",
	"trono",
	"roca",
	"cordillera",
	"reflejo",
]

# Prefijos que solo van al fondo si además están detrás del plano de juego (Z < umbral).
const PREFIJOS_FONDO_CONDICIONAL: Array[String] = [
	"plataformamaderos",
	"palomusgo",
	"palo",
]

# Nombres exactos (minúsculas) que NUNCA se tocan aunque estén lejos:
# gameplay, NPCs, UI, suelo, luces, cámaras, efectos del plano de juego.
const NOMBRES_EXCLUIDOS: Array[String] = [
	"player", "arquera", "prota", "wave", "spawn", "gameui", "game",
	"suelo", "piso", "pisopueblo", "limitzone", "barrera",
	"enredadera", "cuerda", "zapayo", "jarrones", "pozo", "gateta",
	"fukencia", "veera", "pirata", "azulina", "ratona", "perrena",
	"gema", "fuego", "bracero", "mandoble", "pechera", "dummy",
	"waterplane", "luciernagas", "capa001", "capa002", "humo",
	"lighting", "light", "worldenvironment", "subviewport", "compositor",
	"fondo3drect", "frente3drect", "texturerect", "prespectiva", "camara",
	"fondo", "capav",
]

# === EXPORTS ===
@export_category("Seguimiento de Cámara")
@export var seguimiento_activo: bool = true
@export var limite_camara_min_x: float = -12.0
@export var limite_camara_max_x: float = 16.0
@export var suavizado_camara: float = 8.0

@export_category("Parallax de Fondo")
@export_range(0.0, 1.0, 0.01) var factor_parallax_fondo: float = 0.15
@export var fondo_estatico_fijo: bool = true
@export var luz_agua_sigue_camara: bool = true

@export_category("Capa 2 - Fondo Distante")
@export var aplicar_capa_fondo_auto: bool = true
@export var umbral_z_distante: float = 0.5
@export_flags_3d_render var capa_fondo: int = 2

# === VARIABLES PRIVADAS ===
var _camara_frente: Camera3D = null
var _camara_fondo: Camera3D = null
var _camara_editor: Camera3D = null
var _fondo_estatico: Node3D = null
var _luz_agua: OmniLight3D = null
var _iniciado: bool = false
var _x_origen_frente: float = 0.0
var _x_origen_fondo: float = 0.0
var _offset_x_fondo_estatico: float = 0.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_detectar_nodos()
	_guardar_origenes()
	_desactivar_oleadas()
	if aplicar_capa_fondo_auto and not Engine.is_editor_hint():
		_mover_distantes_a_capa_fondo()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not seguimiento_activo:
		return
	if delta <= 0.0:
		return
	_actualizar_seguimiento_camara(delta)


# === FUNCIONES PÚBLICAS ===
## Reaplica la clasificación a capa 2 (útil tras spawns dinámicos).
func reaplicar_capa_fondo() -> void:
	_mover_distantes_a_capa_fondo()


## Retorna la cámara de gameplay (frente).
func obtener_camara_frente() -> Camera3D:
	if not is_instance_valid(_camara_frente):
		_detectar_nodos()
	return _camara_frente


## Fija manualmente la cámara de referencia (tests / transiciones).
func fijar_camaras(frente: Camera3D, fondo: Camera3D) -> void:
	_camara_frente = frente
	_camara_fondo = fondo
	_guardar_origenes()


# === FUNCIONES PRIVADAS ===
func _desactivar_oleadas() -> void:
	if Engine.is_editor_hint():
		return
	var raiz: Node = get_parent() if is_instance_valid(get_parent()) else self
	var spawner: Node = raiz.find_child("WaveSpawner", true, false)
	if not is_instance_valid(spawner):
		return
	if spawner.has_method("detener_spawning"):
		spawner.call("detener_spawning")
	spawner.set_process(false)
	spawner.set_physics_process(false)
	if "cola_spawn" in spawner:
		(spawner.get("cola_spawn") as Array).clear()
	if "active_goblins" in spawner:
		(spawner.get("active_goblins") as Array).clear()
	if "enemigos_por_oleada" in spawner:
		spawner.set("enemigos_por_oleada", 0)
	if "is_wave_active" in spawner:
		spawner.set("is_wave_active", false)


func _detectar_nodos() -> void:
	var raiz: Node = get_parent() if is_instance_valid(get_parent()) else self
	_camara_frente = raiz.find_child("CamaraFrente", true, false) as Camera3D
	_camara_fondo = raiz.find_child("CamaraFondoDOF", true, false) as Camera3D
	_camara_editor = raiz.find_child("PRESPECTIVA", true, false) as Camera3D
	_fondo_estatico = raiz.find_child("FONDO estatico", true, false) as Node3D
	_luz_agua = raiz.find_child("LuzAguaPueblo", true, false) as OmniLight3D


func _guardar_origenes() -> void:
	_iniciado = false
	if is_instance_valid(_camara_frente):
		_x_origen_frente = _camara_frente.global_position.x
	if is_instance_valid(_camara_fondo):
		_x_origen_fondo = _camara_fondo.global_position.x
	if is_instance_valid(_fondo_estatico) and is_instance_valid(_camara_fondo):
		_offset_x_fondo_estatico = _fondo_estatico.global_position.x - _camara_fondo.global_position.x


func _buscar_player() -> Node3D:
	var tree: SceneTree = get_tree()
	if tree != null:
		var por_grupo: Node = tree.get_first_node_in_group(GRUPO_PLAYER)
		if por_grupo is Node3D:
			return por_grupo as Node3D
	var raiz: Node = get_parent() if is_instance_valid(get_parent()) else self
	return raiz.find_child(NOMBRE_NODO_PLAYER, true, false) as Node3D


func _actualizar_seguimiento_camara(delta: float) -> void:
	if not is_instance_valid(_camara_frente):
		_detectar_nodos()
		if not is_instance_valid(_camara_frente):
			return
	var prota: Node3D = _buscar_player()
	if not is_instance_valid(prota):
		return
	var objetivo_x: float = clampf(prota.global_position.x, limite_camara_min_x, limite_camara_max_x)
	if not _iniciado:
		_iniciado = true
		_x_origen_frente = _camara_frente.global_position.x
		if is_instance_valid(_camara_fondo):
			_x_origen_fondo = _camara_fondo.global_position.x
		if is_instance_valid(_fondo_estatico) and is_instance_valid(_camara_fondo):
			_offset_x_fondo_estatico = _fondo_estatico.global_position.x - _camara_fondo.global_position.x
		_camara_frente.global_position.x = objetivo_x
		if is_instance_valid(_camara_editor):
			_camara_editor.global_position.x = objetivo_x
		if is_instance_valid(_luz_agua) and luz_agua_sigue_camara:
			_luz_agua.global_position.x = objetivo_x
		_aplicar_parallax_fondo()
		return
	var peso: float = clampf(delta * suavizado_camara, 0.0, 1.0)
	_camara_frente.global_position.x = lerpf(_camara_frente.global_position.x, objetivo_x, peso)
	if is_instance_valid(_camara_editor):
		_camara_editor.global_position.x = _camara_frente.global_position.x
	if is_instance_valid(_luz_agua) and luz_agua_sigue_camara:
		_luz_agua.global_position.x = _camara_frente.global_position.x
	_aplicar_parallax_fondo()


func _aplicar_parallax_fondo() -> void:
	if not is_instance_valid(_camara_frente) or not is_instance_valid(_camara_fondo):
		return
	var delta_frente: float = _camara_frente.global_position.x - _x_origen_frente
	_camara_fondo.global_position.x = _x_origen_fondo + (delta_frente * factor_parallax_fondo)
	if fondo_estatico_fijo and is_instance_valid(_fondo_estatico):
		_fondo_estatico.global_position.x = _camara_fondo.global_position.x + _offset_x_fondo_estatico


func _mover_distantes_a_capa_fondo() -> void:
	var raiz: Node = get_parent() if is_instance_valid(get_parent()) else self
	for hijo in raiz.get_children():
		_clasificar_recursivo(hijo)


func _clasificar_recursivo(nodo: Node) -> void:
	if nodo == self:
		return
	if nodo is Light3D or nodo is Camera3D or nodo is SubViewport or nodo is CanvasLayer or nodo is Control:
		return
	if nodo is Node3D and _es_distante(nodo as Node3D):
		_fijar_capa_recursiva(nodo, capa_fondo)
		return
	for hijo in nodo.get_children():
		_clasificar_recursivo(hijo)


func _es_distante(nodo: Node3D) -> bool:
	var nombre_llano: String = nodo.name.to_lower().replace(" ", "").replace("_", "")
	for excluido in NOMBRES_EXCLUIDOS:
		if nombre_llano.begins_with(excluido):
			return false
	for prefijo in PREFIJOS_FONDO_SIEMPRE:
		if nombre_llano.begins_with(prefijo):
			return true
	for prefijo in PREFIJOS_FONDO_CONDICIONAL:
		if nombre_llano.begins_with(prefijo) and nodo.global_position.z < umbral_z_distante:
			return true
	# Heurística por profundidad: decorado genérico muy por detrás del plano de juego.
	if nodo.global_position.z < -2.0:
		if nombre_llano.begins_with("tronco") or nombre_llano.begins_with("bote"):
			return true
	return false


func _fijar_capa_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D and not (nodo is Light3D or nodo is Camera3D):
		if Engine.is_editor_hint():
			(nodo as VisualInstance3D).layers = capa | CAPA_FRENTE_NITIDO
		else:
			(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_fijar_capa_recursiva(hijo, capa)
