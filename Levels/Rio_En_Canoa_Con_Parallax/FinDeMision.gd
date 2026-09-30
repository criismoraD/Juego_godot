@tool
class_name FinDeMision
extends Node3D

## Bloque de fin de misión del nivel río: rojo sólido en el editor e
## invisible en juego. ÚNICA forma de completar el nivel: cuando la canoa
## aliada toca el bloque sale la cortinilla y el nivel termina.
## Posiciónalo y dimensiona `tamano` a gusto desde el inspector.

signal mision_cumplida

@export var tamano: Vector3 = Vector3(6.0, 8.0, 14.0):
	set(v):
		tamano = Vector3(maxf(v.x, 0.5), maxf(v.y, 0.5), maxf(v.z, 0.5))
		_actualizar_visual()
@export var color_editor: Color = Color(1.0, 0.05, 0.05, 1.0):
	set(v):
		color_editor = v
		_actualizar_visual()

var _mision_cumplida: bool = false
var _visual: MeshInstance3D = null


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	add_to_group("fin_de_mision")
	if Engine.is_editor_hint():
		_construir_visual()
	else:
		_ocultar_visual()


# === FUNCIONES PÚBLICAS ===
## Retorna true el frame en que la canoa entra al bloque (solo una vez) y
## emite mision_cumplida. El nivel conecta esa señal para terminar.
func comprobar_canoa(canoa: Node3D) -> bool:
	if _mision_cumplida:
		return false
	if not is_instance_valid(canoa):
		return false
	var p: Vector3 = canoa.global_position
	var c: Vector3 = global_position
	if absf(p.x - c.x) > tamano.x * 0.5:
		return false
	if absf(p.y - c.y) > tamano.y * 0.5:
		return false
	if absf(p.z - c.z) > tamano.z * 0.5:
		return false
	_mision_cumplida = true
	mision_cumplida.emit()
	return true


## Indica si el bloque ya se cumplió.
func esta_cumplida() -> bool:
	return _mision_cumplida


## Permite reutilizar el bloque sin recargar la escena (testeo).
func reiniciar() -> void:
	_mision_cumplida = false


# === FUNCIONES PRIVADAS ===
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
	_visual.material_override = mat
	_visual.position = Vector3.ZERO
	_visual.visible = true


func _ocultar_visual() -> void:
	if is_instance_valid(_visual):
		_visual.visible = false
		_visual.queue_free()
	_visual = null
