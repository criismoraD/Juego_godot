class_name GoblinGirlArrowProjectile
extends "res://Scripts/Projectiles/EnemyProjectileBase.gd"

const GOBLIN_GIRL_ARROW_MAGENTA: Color = Color(1.0, 0.0, 0.85)

@export_category("Movimiento")
@export var velocidad: float = 10.0
@export var gravedad: float = 1.0

var _velocidad_base: float = 10.0
var _velocidad_base_capturada: bool = false


func _init() -> void:
	color_proyectil = GOBLIN_GIRL_ARROW_MAGENTA


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
	_remove_glb_model()
	_create_material()
	_create_procedural_arrow()
	_create_trail_particles()


func _capturar_velocidad_base_si_necesario() -> void:
	if _velocidad_base_capturada:
		return

	_velocidad_base = velocidad
	_velocidad_base_capturada = true
