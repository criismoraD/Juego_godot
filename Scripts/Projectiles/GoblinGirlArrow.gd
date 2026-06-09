class_name GoblinGirlArrowProjectile
extends "res://Scripts/Projectiles/EnemyProjectileBase.gd"

@export_category("Movimiento")
@export var velocidad: float = 10.0
@export var gravedad: float = 1.0


func _init() -> void:
	color_proyectil = Color(0.8, 0.2, 0.8)


func initialize(shoot_direction: Vector3, potencia: float = 1.0) -> void:
	_inicializar_direccion(shoot_direction)
	velocidad *= potencia


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_parabolico(delta, velocidad, gravedad)


func _preparar_visuales() -> void:
	_remove_glb_model()
	_create_material()
	_create_procedural_arrow()
	_create_trail_particles()
