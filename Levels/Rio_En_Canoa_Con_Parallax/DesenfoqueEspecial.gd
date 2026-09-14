@tool
class_name DesenfoqueEspecial
extends MeshInstance3D

## Plano de desenfoque INDEPENDIENTE para el nivel del rio.
## A diferencia de PlanoDesenfoqueFondo, cada instancia clona su material
## y su malla al cargarse: editar opacidad, tinte o tamaño aquí
## no altera al resto de capas de desenfoque copiadas.

# === CONSTANTES ===
const SHADER_DESENFOQUE: Shader = preload("res://System/Shaders/desenfoque_fondo_plano.gdshader")

# === EXPORTS ===
@export_category("Control de Desenfoque")
## Grado o intensidad de desenfoque aplicado a todo lo que esté detrás de este plano (0.0 = nítido, 10.0 = máximo difuminado).
@export_range(0.0, 10.0, 0.1) var grado_desenfoque: float = 3.5:
	set(valor):
		grado_desenfoque = valor
		_actualizar_parametros_shader()

## Opacidad general del efecto (1.0 = desenfoque completo, 0.0 = transparente/inactivo).
@export_range(0.0, 1.0, 0.05) var opacidad: float = 1.0:
	set(valor):
		opacidad = valor
		_actualizar_parametros_shader()

## Tinte de color atmosférico opcional (Blanco = sin teñir).
@export var tinte: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(valor):
		tinte = valor
		_actualizar_parametros_shader()

## Suavizado en el borde inferior para fundirse de forma natural con el agua o el horizonte.
@export_range(0.0, 1.0, 0.05) var desvanecer_borde_inferior: float = 0.08:
	set(valor):
		desvanecer_borde_inferior = valor
		_actualizar_parametros_shader()

@export_category("Dimensiones del Plano")
## Ancho y alto de la capa plana en metros.
@export var tamano: Vector2 = Vector2(260.0, 90.0):
	set(valor):
		tamano = valor
		_actualizar_malla()

@export_category("Seguimiento de Cámara")
## Si está activo, el plano acompaña automáticamente a la cámara en el eje X durante la navegación.
@export var seguir_camara_x: bool = true

# === VARIABLES PRIVADAS ===
var _material_desenfoque: ShaderMaterial = null
var _camara_referencia: Camera3D = null
var _offset_x_camara: float = 0.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_inicializar_malla()
	_inicializar_material()
	_actualizar_parametros_shader()
	_detectar_camara()


func _process(_delta: float) -> void:
	if not seguir_camara_x:
		return

	if not is_instance_valid(_camara_referencia):
		_detectar_camara()

	if is_instance_valid(_camara_referencia):
		global_position.x = _camara_referencia.global_position.x + _offset_x_camara


# === FUNCIONES PÚBLICAS ===
## Asigna dinámicamente el grado de desenfoque.
func fijar_grado_desenfoque(nuevo_grado: float) -> void:
	grado_desenfoque = clampf(nuevo_grado, 0.0, 10.0)


## Retorna el material de shader de desenfoque activo (propio de esta instancia).
func obtener_material_desenfoque() -> ShaderMaterial:
	if _material_desenfoque == null:
		_inicializar_material()
	return _material_desenfoque


## Fija la cámara de referencia para el seguimiento horizontal.
func fijar_camara(cam: Camera3D) -> void:
	_camara_referencia = cam
	if is_instance_valid(_camara_referencia):
		_offset_x_camara = global_position.x - _camara_referencia.global_position.x


# === FUNCIONES PRIVADAS ===
func _inicializar_malla() -> void:
	var qmesh: QuadMesh = mesh as QuadMesh
	if qmesh != null:
		# Clonar para no redimensionar las demás copias que comparten la malla.
		qmesh = qmesh.duplicate() as QuadMesh
		mesh = qmesh
	else:
		qmesh = QuadMesh.new()
		mesh = qmesh
	qmesh.size = tamano


func _actualizar_malla() -> void:
	var qmesh: QuadMesh = mesh as QuadMesh
	if qmesh:
		qmesh.size = tamano
	elif is_inside_tree():
		_inicializar_malla()


func _inicializar_material() -> void:
	if material_override is ShaderMaterial and (material_override as ShaderMaterial).shader == SHADER_DESENFOQUE:
		# Clonar para no teñir las demás copias que comparten el material.
		_material_desenfoque = (material_override as ShaderMaterial).duplicate() as ShaderMaterial
	else:
		_material_desenfoque = ShaderMaterial.new()
		_material_desenfoque.shader = SHADER_DESENFOQUE
		_material_desenfoque.render_priority = 0
	material_override = _material_desenfoque


func _actualizar_parametros_shader() -> void:
	if _material_desenfoque == null:
		_inicializar_material()

	if _material_desenfoque:
		_material_desenfoque.set_shader_parameter("desenfoque", grado_desenfoque)
		_material_desenfoque.set_shader_parameter("opacidad", opacidad)
		_material_desenfoque.set_shader_parameter("tinte", tinte)
		_material_desenfoque.set_shader_parameter("desvanecer_borde_inferior", desvanecer_borde_inferior)


func _detectar_camara() -> void:
	if is_instance_valid(_camara_referencia):
		return

	var vp := get_viewport()
	if vp:
		_camara_referencia = vp.get_camera_3d()

	if not is_instance_valid(_camara_referencia) and is_inside_tree():
		var raiz := get_tree().root if get_tree() else null
		if raiz:
			_camara_referencia = raiz.find_child("CamaraPrincipal", true, false) as Camera3D

	if is_instance_valid(_camara_referencia):
		_offset_x_camara = global_position.x - _camara_referencia.global_position.x
