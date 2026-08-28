class_name GoblinGirlArrowProjectile
extends "res://System/Core/EnemyProjectileBase.gd"

## Flecha de Arquera Goblin: Color rosado brillante con línea de contorno toon negra.

const GOBLIN_GIRL_ARROW_MAGENTA: Color = Color(1.0, 0.38, 0.72, 1.0)  ## Rosado brillante
const GOBLIN_GIRL_ARROW_PINK: Color = GOBLIN_GIRL_ARROW_MAGENTA

@export_category("Movimiento")
@export var velocidad: float = 10.0
@export var gravedad: float = 1.0

var _velocidad_base: float = 10.0
var _velocidad_base_capturada: bool = false


func _init() -> void:
	color_proyectil = GOBLIN_GIRL_ARROW_PINK
	outline_width = 25.0


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
	_create_material()
	_create_trail_particles()


func _aplicar_visuales_cacheados() -> void:
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			mesh.material_override = projectile_material


func _restaurar_visuales_desde_pool() -> void:
	_aplicar_visuales_cacheados()
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			mesh.visible = true
	if trail_particles:
		trail_particles.process_material = _get_shared_trail_process_material(color_proyectil)
		trail_particles.draw_pass_1 = _get_shared_trail_mesh(color_proyectil)
		trail_particles.emitting = true


func _capturar_velocidad_base_si_necesario() -> void:
	if _velocidad_base_capturada:
		return

	_velocidad_base = velocidad
	_velocidad_base_capturada = true
