class_name GargolaProjectile
extends "res://Entities/Projectiles/EnemyProjectileBase.gd"

const GARGOLA_EMISSION_ENERGY: float = 4.0
const GARGOLA_RED: Color = Color(1.0, 0.1, 0.05)

@export_category("Movimiento")
@export var speed: float = 9.0


func _init() -> void:
	color_proyectil = GARGOLA_RED
	offscreen_margin_x = 400.0
	offscreen_margin_top = 2000.0
	offscreen_margin_bottom = 300.0


func initialize(shoot_direction: Vector3, power: float = 1.0) -> void:
	_inicializar_direccion(shoot_direction)
	speed = lerp(10.0, 30.0, clamp(power, 0.0, 1.0))


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_recto(delta, speed)


func _preparar_visuales() -> void:
	_remove_glb_model()
	_create_material(GARGOLA_EMISSION_ENERGY)
	_create_procedural_sphere()


func _create_procedural_sphere() -> void:
	var sphere_mesh := MeshInstance3D.new()
	sphere_mesh.name = "SphereVisual"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.material = projectile_material
	sphere_mesh.mesh = sphere
	sphere_mesh.material_override = projectile_material
	sphere_mesh.add_to_group("outline_meshes")
	add_child(sphere_mesh)

	var trail_container := Node3D.new()
	trail_container.name = "TrailContainer"
	trail_container.position = Vector3(0.0, 0.0, 0.0)
	add_child(trail_container)
	_create_trail_particles()