@tool
class_name PosicionJefeSubmarino
extends Node3D

## Bloque verde para posicionar al Jefe Submarino en el editor del nivel río.
## Muestra una caja verde tridimensional en el editor que el desarrollador puede
## mover libremente por el mapa. En tiempo de ejecución es invisible y sitúa al
## JefeSubmarino exactamente en su coordenada (conservando por defecto su cota Y de
## sumersión y profundidad Z).

# === CONSTANTES ===
const TAMANO_DEFECTO: Vector3 = Vector3(9.0, 3.0, 2.5)
const COLOR_VERDE_EDITOR: Color = Color(0.15, 0.95, 0.25, 0.75)
const NOMBRE_JEFE_DEFECTO: String = "JefeSubmarino"
const GRUPO_POSICION: String = "posicion_jefe_submarino"
const GRUPO_JEFE: String = "jefe_submarino"

# === EXPORTS ===
@export_category("Visualización Editor")
@export var tamano: Vector3 = TAMANO_DEFECTO:
	set(v):
		tamano = Vector3(maxf(v.x, 0.5), maxf(v.y, 0.5), maxf(v.z, 0.5))
		_actualizar_visual()

@export var color_editor: Color = COLOR_VERDE_EDITOR:
	set(v):
		color_editor = v
		_actualizar_visual()

@export_category("Sincronización Jefe")
## Si true, sincroniza la posición del nodo JefeSubmarino con este bloque tanto
## en el editor como al arrancar la partida.
@export var sincronizar_con_jefe: bool = true

## Si true, solo sincroniza la posición horizontal X, respetando la cota Y
## del agua y el plano Z del río del jefe.
@export var solo_eje_x: bool = true

# === VARIABLES PRIVADAS ===
var _visual: MeshInstance3D = null


# === FUNCIONES BUILT-IN ===
func _enter_tree() -> void:
	add_to_group(GRUPO_POSICION)
	set_notify_transform(true)


func _ready() -> void:
	add_to_group(GRUPO_POSICION)
	if Engine.is_editor_hint():
		set_notify_transform(true)
		set_process(true)
		_construir_visual()
		_sincronizar_posicion_jefe()
	else:
		_sincronizar_posicion_jefe()
		_ocultar_visual()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if Engine.is_editor_hint():
			_sincronizar_posicion_jefe()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sincronizar_posicion_jefe()


# === FUNCIONES PÚBLICAS ===
## Fuerza la sincronización de la posición del Jefe Submarino con este bloque.
func aplicar_posicion_al_jefe(jefe: Node3D = null) -> void:
	var objetivo: Node3D = jefe if is_instance_valid(jefe) else _obtener_jefe()
	if not is_instance_valid(objetivo):
		return

	if solo_eje_x:
		if not is_equal_approx(objetivo.global_position.x, global_position.x):
			objetivo.global_position.x = global_position.x
	else:
		if not objetivo.global_position.is_equal_approx(global_position):
			objetivo.global_position = global_position


## Retorna la referencia al JefeSubmarino si existe en la escena.
func obtener_jefe_submarino() -> Node3D:
	return _obtener_jefe()


# === FUNCIONES PRIVADAS ===
func _obtener_jefe() -> Node3D:
	if not is_inside_tree():
		return null
	var tree: SceneTree = get_tree()
	if tree != null:
		var nodo_grupo: Node = tree.get_first_node_in_group(GRUPO_JEFE)
		if is_instance_valid(nodo_grupo) and nodo_grupo is Node3D:
			return nodo_grupo as Node3D
	var padre: Node = get_parent()
	if is_instance_valid(padre):
		var hijo: Node = padre.find_child(NOMBRE_JEFE_DEFECTO, true, false)
		if is_instance_valid(hijo) and hijo is Node3D:
			return hijo as Node3D
	return null


func _sincronizar_posicion_jefe() -> void:
	if not sincronizar_con_jefe:
		return
	aplicar_posicion_al_jefe()


func _actualizar_visual() -> void:
	if not Engine.is_editor_hint():
		return
	if not is_node_ready():
		return
	_construir_visual()


func _construir_visual() -> void:
	if not is_instance_valid(_visual):
		_visual = MeshInstance3D.new()
		_visual.name = "VisualEditor"
		_visual.mesh = BoxMesh.new()
		add_child(_visual)
	var caja := _visual.mesh as BoxMesh
	if is_instance_valid(caja):
		caja.size = tamano
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color_editor
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_visual.material_override = mat
	_visual.position = Vector3.ZERO
	_visual.visible = true


func _ocultar_visual() -> void:
	if is_instance_valid(_visual):
		_visual.visible = false
		_visual.queue_free()
	_visual = null
