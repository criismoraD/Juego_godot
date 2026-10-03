@tool
class_name SueloColision
extends StaticBody3D

## Rectángulo de colisión de suelo posicionable y redimensionable.
## Uso: instanciar la escena en el nivel, mover el nodo raíz con el gizmo
## y ajustar `tamano` en el inspector (X = largo, Y = grosor, Z = ancho).
## La cara superior queda en `position.y + tamano.y / 2`.

const TAMANO_MINIMO: Vector3 = Vector3(0.1, 0.1, 0.1)

@export var tamano: Vector3 = Vector3(36.0, 1.0, 4.0):
	set(value):
		tamano = Vector3(
			max(TAMANO_MINIMO.x, value.x),
			max(TAMANO_MINIMO.y, value.y),
			max(TAMANO_MINIMO.z, value.z)
		)
		if is_node_ready():
			_sincronizar()
@export var mostrar_visual_en_juego: bool = false:
	set(value):
		mostrar_visual_en_juego = value
		if is_node_ready():
			_actualizar_visibilidad()

@onready var _colision: CollisionShape3D = $CollisionShape3D
@onready var _visual: MeshInstance3D = $Visual


func _ready() -> void:
	_hacer_recursos_unicos()
	_sincronizar()
	_actualizar_visibilidad()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sincronizar()


func obtener_y_superior() -> float:
	return global_position.y + (tamano.y * 0.5)


func _hacer_recursos_unicos() -> void:
	if not is_instance_valid(_colision):
		return
	if _colision.shape is BoxShape3D:
		_colision.shape = (_colision.shape as BoxShape3D).duplicate()
	if not is_instance_valid(_visual):
		return
	if _visual.mesh is BoxMesh:
		_visual.mesh = (_visual.mesh as BoxMesh).duplicate()


func _sincronizar() -> void:
	var forma: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if forma and forma.shape is BoxShape3D:
		(forma.shape as BoxShape3D).size = tamano
	var malla: MeshInstance3D = get_node_or_null("Visual") as MeshInstance3D
	if malla and malla.mesh is BoxMesh:
		(malla.mesh as BoxMesh).size = tamano


func _actualizar_visibilidad() -> void:
	var malla: MeshInstance3D = get_node_or_null("Visual") as MeshInstance3D
	if malla == null:
		return
	if Engine.is_editor_hint():
		malla.visible = true
		return
	malla.visible = mostrar_visual_en_juego
