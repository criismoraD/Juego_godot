class_name HuesoLimoProjectile
extends "res://System/Core/EnemyProjectileBase.gd"

## Hueso escupido por el Limo Cuadrado: vuela en parábola como el tridente
## del Imp, pero gira sobre su eje mientras se desplaza.

const VELOCIDAD_GIRO_X: float = 9.0  ## rad/s de giro frontal (tumbo)
const HUESO_MAT_PATH: String = "res://Entities/Proyectil_Hueso_Limo/HUESO_MAT.tres"

@export_category("Movimiento")
@export var velocidad: float = 8.0
@export var gravedad: float = 1.0

var _velocidad_base: float = 8.0
var _velocidad_base_capturada: bool = false
var _modelo_hueso: Node3D = null
var _mat_hueso: Material = null


func _init() -> void:
	color_proyectil = Color(0.95, 0.92, 0.8)
	offscreen_margin_x = 400.0
	offscreen_margin_top = 2000.0
	offscreen_margin_bottom = 300.0


func _ready() -> void:
	_capturar_velocidad_base_si_necesario()
	_modelo_hueso = find_child("HuesoModel", true, false) as Node3D
	_mat_hueso = load(HUESO_MAT_PATH) as Material
	super._ready()


func initialize(shoot_direction: Vector3, potencia: float = 1.0) -> void:
	_capturar_velocidad_base_si_necesario()
	_inicializar_direccion(shoot_direction)
	velocidad = _velocidad_base * max(0.0, potencia)


func _actualizar_movimiento(delta: float) -> void:
	_aplicar_movimiento_parabolico(delta, velocidad, gravedad)
	# Giro frontal continuo: el hueso rueda mientras vuela
	if _modelo_hueso and is_instance_valid(_modelo_hueso) and not is_stuck:
		_modelo_hueso.rotate_x(VELOCIDAD_GIRO_X * delta)


## El hueso conserva SIEMPRE su material con textura propia (HUESO_MAT).
func _preparar_visuales() -> void:
	_aplicar_material_hueso()


func _aplicar_visuales_cacheados() -> void:
	for mesh in _cached_mesh_instances:
		if not is_instance_valid(mesh):
			continue
		if mesh is MeshInstance3D:
			mesh.visible = true
			mesh.add_to_group("outline_meshes")
	_aplicar_material_hueso()


func _restaurar_visuales_desde_pool() -> void:
	_aplicar_material_hueso()


func _aplicar_material_hueso() -> void:
	if not _mat_hueso:
		_mat_hueso = load(HUESO_MAT_PATH) as Material
	if not _mat_hueso:
		return
	for mesh in _cached_mesh_instances:
		if is_instance_valid(mesh) and mesh is MeshInstance3D:
			(mesh as MeshInstance3D).material_override = _mat_hueso


func _capturar_velocidad_base_si_necesario() -> void:
	if _velocidad_base_capturada:
		return
	_velocidad_base = velocidad
	_velocidad_base_capturada = true
