class_name GoblinArrowProjectile
extends "res://Entities/Projectiles/EnemyProjectileBase.gd"

const MIN_ARROW_SPEED: float = 10.0
const MAX_ARROW_SPEED: float = 30.0
const GOBLIN_ARROW_ORANGE: Color = Color(1.0, 0.28, 0.0)

@export_category("Movimiento")
@export var speed: float = 8.0


func _init() -> void:
	color_proyectil = GOBLIN_ARROW_ORANGE


func initialize(shoot_direction: Vector3, power: float = 1.0) -> void:
	_inicializar_direccion(shoot_direction)
	speed = lerp(MIN_ARROW_SPEED, MAX_ARROW_SPEED, clamp(power, 0.0, 1.0))


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_recto(delta, speed)


func _preparar_visuales() -> void:
	_remove_glb_model()
	_create_material()
	_create_procedural_arrow()
	_create_trail_particles()


func _on_impacto_con_dano(_body: Node) -> void:
	AudioManager.play_goblin_laugh()


func _on_impacto_con_escudo(_body: Node) -> void:
	AudioManager.play_goblin_laugh()
