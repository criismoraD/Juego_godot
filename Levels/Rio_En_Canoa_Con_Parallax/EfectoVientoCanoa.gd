class_name EfectoVientoCanoa
extends Node3D

## Controlador visual del efecto de viento / estelas cinemáticas (Wind Strip Shader)
## para la canoa en el nivel del río al acelerar con la tecla Z.
##
## Gestiona múltiples MeshInstance3D con TubeTrailMesh y ShaderMaterial compartido,
## aplicando instance shader parameters para lograr estelas desfasadas, únicas y fluidas.

# === CONSTANTES ===
const SHADER_VIENTO: Shader = preload("res://System/Shaders/wind_strip.gdshader")
const DURACION_TRANSICION_DEFECTO: float = 0.25
const OPACIDAD_MAXIMA_DEFECTO: float = 0.75
const COLOR_VIENTO_DEFECTO: Color = Color(0.92, 0.96, 1.0, 0.75)
const CUSTOM_AABB_DEFECTO: AABB = AABB(Vector3(-15.0, -10.0, -10.0), Vector3(30.0, 20.0, 20.0))

# === EXPORTS ===
@export_category("Control de Activación")
@export var activo: bool = false:
	set(v):
		activo = v
		if is_inside_tree():
			_actualizar_estado_activo(v)

@export_range(0.05, 1.5, 0.05) var duracion_transicion: float = DURACION_TRANSICION_DEFECTO  ## Tiempo de fade-in / fade-out (segundos)
@export_range(0.0, 1.0, 0.05) var opacidad_maxima: float = OPACIDAD_MAXIMA_DEFECTO  ## Opacidad al alcanzar el impulso máximo
@export var color_base_viento: Color = COLOR_VIENTO_DEFECTO  ## Tinte del viento / agua vaporizada

# === VARIABLES PRIVADAS ===
var _material_viento: ShaderMaterial = null
var _tween_opacidad: Tween = null
var _opacidad_actual: float = 0.0
var _estelas: Array[MeshInstance3D] = []


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_inicializar_material()
	_recopilar_y_configurar_estelas()
	# Iniciar en estado inactivo sin renderizar si no está marcado como activo
	if not activo:
		visible = false
		_aplicar_opacidad(0.0)
	else:
		visible = true
		_aplicar_opacidad(opacidad_maxima)


# === FUNCIONES PÚBLICAS ===
## Activa o desactiva suavemente el efecto de estelas de viento con fade progresivo.
func set_activo(nuevo_activo: bool) -> void:
	if activo == nuevo_activo and is_inside_tree():
		return
	activo = nuevo_activo
	if is_inside_tree():
		_actualizar_estado_activo(nuevo_activo)


## Retorna si el efecto de estelas está activo en este momento.
func esta_activo() -> bool:
	return activo


## Retorna la opacidad actual entre 0.0 y opacidad_maxima.
func obtener_opacidad_actual() -> float:
	return _opacidad_actual


## Retorna el arreglo de mallas de estela registradas.
func obtener_estelas() -> Array[MeshInstance3D]:
	return _estelas


## Retorna el material de sombreador compartido de las estelas.
func obtener_material() -> ShaderMaterial:
	if not is_instance_valid(_material_viento):
		_inicializar_material()
	return _material_viento


# === FUNCIONES PRIVADAS ===
func _actualizar_estado_activo(nuevo_activo: bool) -> void:
	if is_instance_valid(_tween_opacidad) and _tween_opacidad.is_running():
		_tween_opacidad.kill()

	_tween_opacidad = create_tween()
	if nuevo_activo:
		visible = true
		_tween_opacidad.tween_method(_aplicar_opacidad, _opacidad_actual, opacidad_maxima, duracion_transicion)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_tween_opacidad.tween_method(_aplicar_opacidad, _opacidad_actual, 0.0, duracion_transicion)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween_opacidad.tween_callback(func() -> void:
			if not activo:
				visible = false
		)


func _inicializar_material() -> void:
	if is_instance_valid(_material_viento):
		return
	_material_viento = ShaderMaterial.new()
	_material_viento.shader = SHADER_VIENTO
	var col: Color = color_base_viento
	col.a = 0.0
	_material_viento.set_shader_parameter("color", col)


func _recopilar_y_configurar_estelas() -> void:
	_estelas.clear()
	for child in get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			_configurar_malla_estela(mi)
			_estelas.append(mi)

	# Si la escena no tenía nodos hijos configurados, generamos el juego de estelas por defecto
	if _estelas.is_empty():
		_generar_estelas_por_defecto()


func _configurar_malla_estela(mi: MeshInstance3D) -> void:
	mi.custom_aabb = CUSTOM_AABB_DEFECTO
	mi.material_override = obtener_material()
	if mi.mesh == null or not (mi.mesh is TubeTrailMesh):
		mi.mesh = _crear_tubetrail_mesh_por_defecto()


func _crear_tubetrail_mesh_por_defecto(radio: float = 0.035, secciones: int = 40) -> TubeTrailMesh:
	var mesh: TubeTrailMesh = TubeTrailMesh.new()
	mesh.radius = radio
	mesh.sections = secciones
	mesh.section_length = 1.0 / float(secciones)  # Longitud unitaria = 1.0 m
	mesh.section_rings = 4

	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0.0, 0.0))
	curva.add_point(Vector2(0.5, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	mesh.curve = curva
	return mesh


func _generar_estelas_por_defecto() -> void:
	# Configuración de estelas aerodinámicas alrededor de la canoa:
	# Local +Y apunta hacia -X (hacia atrás) con rotación Z = 90 grados
	var configs: Array[Dictionary] = [
		{"pos": Vector3(0.65, 0.35, 0.22), "rot": Vector3(0.0, 0.0, 90.0), "offset": 0.0, "wave": 0.2, "loop": 0.15},
		{"pos": Vector3(-0.15, 0.55, -0.18), "rot": Vector3(4.0, -3.0, 92.0), "offset": 2.7, "wave": -0.15, "loop": -0.08},
		{"pos": Vector3(0.40, 0.12, 0.32), "rot": Vector3(-3.0, 4.0, 88.0), "offset": 5.4, "wave": 0.4, "loop": 0.22},
		{"pos": Vector3(-0.55, 0.15, -0.28), "rot": Vector3(2.0, 2.0, 90.0), "offset": 8.1, "wave": -0.25, "loop": -0.12},
		{"pos": Vector3(0.50, 0.22, -0.32), "rot": Vector3(-4.0, -2.0, 93.0), "offset": 10.8, "wave": 0.3, "loop": 0.18},
		{"pos": Vector3(0.05, 0.65, 0.15), "rot": Vector3(3.0, -1.0, 87.0), "offset": 13.5, "wave": 0.1, "loop": 0.25},
		{"pos": Vector3(-0.35, 0.38, 0.35), "rot": Vector3(0.0, 3.0, 91.0), "offset": 16.2, "wave": -0.3, "loop": -0.05}
	]

	for i in range(configs.size()):
		var cfg: Dictionary = configs[i]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "EstelaViento_%d" % (i + 1)
		mi.position = cfg["pos"]
		mi.rotation_degrees = cfg["rot"]
		_configurar_malla_estela(mi)
		mi.set_instance_shader_parameter("extra_offset_time", cfg["offset"])
		mi.set_instance_shader_parameter("extra_wave_length", cfg["wave"])
		mi.set_instance_shader_parameter("extra_loop_radius", cfg["loop"])
		add_child(mi)
		_estelas.append(mi)


func _aplicar_opacidad(valor: float) -> void:
	_opacidad_actual = valor
	var mat: ShaderMaterial = obtener_material()
	if is_instance_valid(mat):
		var col: Color = color_base_viento
		col.a = valor
		mat.set_shader_parameter("color", col)
