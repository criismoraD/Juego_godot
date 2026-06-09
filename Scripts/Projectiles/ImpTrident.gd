class_name ImpTridentProjectile
extends "res://Scripts/Projectiles/EnemyProjectileBase.gd"

const TRIDENT_EMISSION_ENERGY: float = 4.0

@export_category("Movimiento")
@export var velocidad: float = 8.0
@export var gravedad: float = 1.2


func _init() -> void:
	color_proyectil = Color(1.0, 0.15, 0.05)
	offscreen_margin_x = 400.0
	offscreen_margin_top = 2000.0
	offscreen_margin_bottom = 300.0


func initialize(shoot_direction: Vector3, potencia: float = 1.0) -> void:
	_inicializar_direccion(shoot_direction)
	velocidad *= potencia


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_parabolico(delta, velocidad, gravedad)


func _preparar_visuales() -> void:
	_create_material(TRIDENT_EMISSION_ENERGY)


func _aplicar_visuales_cacheados() -> void:
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue

		if mesh is MeshInstance3D:
			mesh.visible = true
			mesh.add_to_group("outline_meshes")
			mesh.material_override = projectile_material


func _restaurar_visuales_desde_pool() -> void:
	_create_material(TRIDENT_EMISSION_ENERGY)
	_aplicar_visuales_cacheados()
