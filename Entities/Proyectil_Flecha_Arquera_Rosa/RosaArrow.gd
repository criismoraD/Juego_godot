class_name RosaArrowProjectile
extends "res://System/Core/EnemyProjectileBase.gd"

const ROSA_ARROW_PINK: Color = Color(1.0, 0.25, 0.75)

@export_category("Movimiento")
@export var velocidad: float = 10.0
@export var gravedad: float = 1.0

var _velocidad_base: float = 10.0
var _velocidad_base_capturada: bool = false


func _init() -> void:
	color_proyectil = ROSA_ARROW_PINK
	outline_width = 20.0


func _ready() -> void:
	_capturar_velocidad_base_si_necesario()
	super._ready()


func initialize(shoot_direction: Vector3, potencia: float = 1.0) -> void:
	_capturar_velocidad_base_si_necesario()
	_inicializar_direccion(shoot_direction)
	velocidad = _velocidad_base * max(0.0, potencia)


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_parabolico(delta, velocidad, gravedad)


func _preparar_visuales() -> void:
	# Conservar la malla 3D idéntica a la flecha de la protagonista (FLECHA.fbx)
	_create_material()
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := child as MeshInstance3D
		if mesh_inst and projectile_material:
			mesh_inst.material_override = projectile_material
	_create_trail_particles()


func _capturar_velocidad_base_si_necesario() -> void:
	if _velocidad_base_capturada:
		return
	_velocidad_base = velocidad
	_velocidad_base_capturada = true
