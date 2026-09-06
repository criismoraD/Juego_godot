class_name SombraPersonaje
extends Node3D
## Componente de sombra procedural para personajes.
## Proyecta una elipse oscura debajo del personaje usando RayCast3D y maneja el recorte en bordes.


const SHADER_SOMBRA: Shader = preload("res://System/Shaders/sombra_personaje.gdshader")

# === CONFIGURACIÓN - APARIENCIA ===
@export_category("Sombra Apariencia")
@export var opacidad: float = 1.0
@export var tamano: Vector2 = Vector2(0.6, 0.6)
@export var suavizado: float = 0.8
@export var offset_y: float = 0.015
@export var offset_x: float = 0.0
@export var offset_z: float = 0.0

# === CONFIGURACIÓN - COMPORTAMIENTO ===
@export_category("Sombra Comportamiento")
@export var escala_por_altura: bool = true
@export var altura_max_desvanecimiento: float = 0.2
@export var escala_minima: float = 0.5
@export var mascara_colision: int = 65 ## Capa 1 (Mundo) y Capa 7 (Plataformas Permanente)
@export var heredar_escala_padre: bool = false
@export var prioridad_render: int = 0  ## Orden en el pase transparente (menor = se dibuja antes, queda debajo)

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _ray: RayCast3D
var _ray_izq: RayCast3D
var _ray_der: RayCast3D


func _ready() -> void:
	_crear_mesh()
	_crear_raycasts()


func _crear_mesh() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "SombraMesh"
	_mesh.top_level = true
	_mesh.visible = false
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var quad := QuadMesh.new()
	quad.size = tamano
	_mesh.mesh = quad

	_material = ShaderMaterial.new()
	_material.shader = SHADER_SOMBRA
	_material.render_priority = prioridad_render
	_material.set_shader_parameter("opacidad", opacidad)
	_material.set_shader_parameter("suavizado", suavizado)
	_material.set_shader_parameter("corte_izq", 0.0)
	_material.set_shader_parameter("corte_der", 0.0)

	_mesh.material_override = _material
	add_child(_mesh)


func _crear_raycasts() -> void:
	_ray = RayCast3D.new()
	_ray.name = "RaycastSuelo"
	_ray.top_level = true
	_ray.target_position = Vector3(0, -15, 0)
	_ray.enabled = true
	_ray.collision_mask = mascara_colision
	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true
	add_child(_ray)

	_ray_izq = RayCast3D.new()
	_ray_izq.name = "RaycastSueloIzq"
	_ray_izq.top_level = true
	_ray_izq.target_position = Vector3(0, -15, 0)
	_ray_izq.enabled = true
	_ray_izq.collision_mask = mascara_colision
	_ray_izq.collide_with_areas = false
	_ray_izq.collide_with_bodies = true
	add_child(_ray_izq)

	_ray_der = RayCast3D.new()
	_ray_der.name = "RaycastSueloDer"
	_ray_der.top_level = true
	_ray_der.target_position = Vector3(0, -15, 0)
	_ray_der.enabled = true
	_ray_der.collision_mask = mascara_colision
	_ray_der.collide_with_areas = false
	_ray_der.collide_with_bodies = true
	add_child(_ray_der)


var _excepciones_configuradas: bool = false


func _actualizar_excepciones_raycasts(padre: Node3D) -> void:
	if _excepciones_configuradas:
		return
	_excepciones_configuradas = true

	var nodo: Node = padre
	while nodo:
		if nodo is CollisionObject3D:
			if _ray:
				_ray.add_exception(nodo)
			if _ray_izq:
				_ray_izq.add_exception(nodo)
			if _ray_der:
				_ray_der.add_exception(nodo)
		nodo = nodo.get_parent()

	for col_child in padre.find_children("*", "CollisionObject3D", true, false):
		if col_child is CollisionObject3D:
			if _ray:
				_ray.add_exception(col_child)
			if _ray_izq:
				_ray_izq.add_exception(col_child)
			if _ray_der:
				_ray_der.add_exception(col_child)


func _process(_delta: float) -> void:
	if not _mesh or not _ray or not _ray_izq or not _ray_der:
		return

	if not is_inside_tree() or is_queued_for_deletion():
		return

	if not _mesh.is_inside_tree() or not _ray.is_inside_tree() or not _ray_izq.is_inside_tree() or not _ray_der.is_inside_tree():
		return

	var padre := get_parent() as Node3D
	if not padre or not is_instance_valid(padre) or not padre.is_inside_tree():
		return

	_actualizar_excepciones_raycasts(padre)

	var padre_pos: Vector3 = padre.global_position

	# Actualizar raycast central
	_ray.global_position = padre_pos + Vector3(0, 0.5, 0)
	_ray.global_rotation = Vector3.ZERO
	_ray.force_raycast_update()

	if not _ray.is_colliding():
		_mesh.visible = false
		return

	var collider = _ray.get_collider()
	if collider == padre or (collider and (collider.get_parent() == padre or padre.is_ancestor_of(collider))):
		_ray.add_exception(collider)
		_ray.force_raycast_update()
		if not _ray.is_colliding():
			_mesh.visible = false
			return

	var punto_suelo: Vector3 = _ray.get_collision_point()
	var y_centro: float = punto_suelo.y
	
	_mesh.global_position = Vector3(padre_pos.x + offset_x, y_centro + offset_y, padre_pos.z + offset_z)
	_mesh.global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	_mesh.visible = true

	# Calcular escala e influencia de altura
	var altura: float = padre_pos.y - y_centro
	var factor: float = clampf(1.0 - (altura / altura_max_desvanecimiento), 0.0, 1.0)
	var escala: float = lerpf(escala_minima, 1.0, factor) if escala_por_altura else 1.0
	
	var escala_global_padre := Vector2(1.0, 1.0)
	if heredar_escala_padre:
		var ps: Vector3 = padre.global_basis.get_scale()
		escala_global_padre = Vector2(ps.x, ps.z)

	_mesh.scale = Vector3(escala * escala_global_padre.x, 1.0, escala * escala_global_padre.y)
	_material.set_shader_parameter("opacidad", opacidad * factor)

	# Actualizar raycasts laterales para control de bordes
	var radio: float = tamano.x * 0.5 * escala * escala_global_padre.x
	
	_ray_izq.global_position = padre_pos + Vector3(-radio, 0.5, 0)
	_ray_izq.global_rotation = Vector3.ZERO
	_ray_izq.force_raycast_update()

	var col_izq = _ray_izq.get_collider()
	if col_izq == padre or (col_izq and (col_izq.get_parent() == padre or padre.is_ancestor_of(col_izq))):
		_ray_izq.add_exception(col_izq)
		_ray_izq.force_raycast_update()

	_ray_der.global_position = padre_pos + Vector3(radio, 0.5, 0)
	_ray_der.global_rotation = Vector3.ZERO
	_ray_der.force_raycast_update()

	var col_der = _ray_der.get_collider()
	if col_der == padre or (col_der and (col_der.get_parent() == padre or padre.is_ancestor_of(col_der))):
		_ray_der.add_exception(col_der)
		_ray_der.force_raycast_update()

	# Lógica de desvanecimiento en bordes
	var corte_izq: float = 0.0
	if not _ray_izq.is_colliding():
		corte_izq = 1.0
	elif _ray_izq.get_collider() != _ray.get_collider():
		var y_diff: float = absf(y_centro - _ray_izq.get_collision_point().y)
		if y_diff > 0.35:
			corte_izq = 1.0

	var corte_der: float = 0.0
	if not _ray_der.is_colliding():
		corte_der = 1.0
	elif _ray_der.get_collider() != _ray.get_collider():
		var y_diff: float = absf(y_centro - _ray_der.get_collision_point().y)
		if y_diff > 0.35:
			corte_der = 1.0

	_material.set_shader_parameter("corte_izq", corte_izq)
	_material.set_shader_parameter("corte_der", corte_der)


func set_tamano(nuevo: Vector2) -> void:
	tamano = nuevo
	if _mesh and _mesh.mesh is QuadMesh:
		(_mesh.mesh as QuadMesh).size = tamano


func set_opacidad(nueva: float) -> void:
	opacidad = nueva
	if _material:
		_material.set_shader_parameter("opacidad", opacidad)
