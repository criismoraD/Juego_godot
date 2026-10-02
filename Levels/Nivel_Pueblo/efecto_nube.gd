@tool
class_name EfectoNube
extends Node3D

## Recreación del efecto de nubes en perspectiva 3D estilo Castlevania: Symphony of the Night.
## Las nubes viajan hacia la cámara en un loop continuo sobre un plano inclinado en perspectiva,
## con textura PNG desplazable y medidores de velocidad y color configurables en el Inspector del Editor.

# === SEÑALES ===
signal velocidad_cambiada(nueva_velocidad: float)
signal color_cambiado(nuevo_tinte_luz: Color, nuevo_tinte_sombra: Color)

# === ENUMS Y CONSTANTES ===
enum PresetVelocidad {
	PERSONALIZADA,
	PAUSA,
	LENTO,
	NORMAL,
	RAPIDO,
}

enum PresetColorNube {
	PERSONALIZADO,
	NARANJA_TUTORIAL,
	ATARDECER_DORADO,
	NOCTURNO_VIOLETA,
	SANGRIENTO_ROJO,
	TORMENTA_GRIS,
	BLANCO_PURO,
}

const VELOCIDAD_MINIMA: float = -2.0
const VELOCIDAD_MAXIMA: float = 2.0
const VELOCIDAD_PRESET_PAUSA: float = 0.0
const VELOCIDAD_PRESET_LENTO: float = 0.15
const VELOCIDAD_PRESET_NORMAL: float = 0.35
const VELOCIDAD_PRESET_RAPIDO: float = 0.70

const COLOR_NARANJA_LUZ: Color = Color(1.0, 0.58, 0.18, 0.95)
const COLOR_NARANJA_SOMBRA: Color = Color(0.42, 0.16, 0.14, 0.95)
const COLOR_DORADO_LUZ: Color = Color(1.0, 0.76, 0.25, 0.95)
const COLOR_DORADO_SOMBRA: Color = Color(0.46, 0.20, 0.08, 0.95)
const COLOR_VIOLETA_LUZ: Color = Color(0.85, 0.78, 1.0, 0.90)
const COLOR_VIOLETA_SOMBRA: Color = Color(0.18, 0.12, 0.28, 0.90)
const COLOR_ROJO_LUZ: Color = Color(1.0, 0.22, 0.18, 0.95)
const COLOR_ROJO_SOMBRA: Color = Color(0.35, 0.05, 0.08, 0.95)
const COLOR_GRIS_LUZ: Color = Color(0.65, 0.68, 0.72, 0.90)
const COLOR_GRIS_SOMBRA: Color = Color(0.15, 0.16, 0.20, 0.90)
const COLOR_BLANCO_LUZ: Color = Color(1.0, 1.0, 1.0, 0.90)
const COLOR_BLANCO_SOMBRA: Color = Color(0.45, 0.45, 0.50, 0.90)

const TEXTURA_DEFAULT_RUTA: String = "res://Levels/Nivel_Pueblo/Texturas/nube_castlevania.png"
const SHADER_RUTA: String = "res://System/Shaders/efecto_nube_3d.gdshader"
const UMBRAL_OFFSET_LOOP: float = 1000.0

# === EXPORTS ===
@export_group("Velocidad de Nubes (Medidor en Editor)")
## Medidor y selector principal de velocidad de desplazamiento de las nubes (unidades/s).
## Valores positivos desplazan las nubes hacia la cámara (efecto 3D SotN).
@export_range(-2.0, 2.0, 0.01, "or_greater", "or_less") var velocidad: float = VELOCIDAD_PRESET_NORMAL:
	set = set_velocidad,
	get = get_velocidad

## Selector rápido de velocidades estándar desde el editor
@export var preset_velocidad: PresetVelocidad = PresetVelocidad.NORMAL:
	set = _set_preset_velocidad

## Invierte el sentido del viaje de las nubes
@export var invertir_direccion: bool = false:
	set = _set_invertir_direccion

## Activa o pausa la previsualización del movimiento continuo en el editor de Godot
@export var animar_en_editor: bool = true

@export_group("Color y Medidor de Tinte")
## Selector de presets cromáticos para ambientaciones (Atardecer naranja, noche, tormenta)
@export var preset_color: PresetColorNube = PresetColorNube.PERSONALIZADO:
	set = _set_preset_color

## Medidor de color de la luz / crestas iluminadas de las nubes
@export var tinte_luz: Color = COLOR_NARANJA_LUZ:
	set = _set_tinte_luz

## Medidor de color de las sombras / base y áreas densas de las nubes
@export var tinte_sombra: Color = COLOR_NARANJA_SOMBRA:
	set = _set_tinte_sombra

## Medidor de intensidad y brillo del color (multiplicador de luminosidad)
@export_range(0.0, 3.0, 0.05) var intensidad_color: float = 1.0:
	set = _set_intensidad_color

## Medidor de recoloreo de dos tonos (1.0 = gradiente completo sombra/luz, 0.0 = tinte simple)
@export_range(0.0, 1.0, 0.05) var modo_recoloreo: float = 1.0:
	set = _set_modo_recoloreo

## Contraste entre crestas iluminadas y valles de sombra
@export_range(0.5, 2.5, 0.05) var contraste: float = 1.0:
	set = _set_contraste

@export_group("Desplazamiento y Dirección")
## Dirección del scroll en coordenadas UV
@export var direccion_scroll: Vector2 = Vector2(0.0, 1.0):
	set = _set_direccion_scroll
## Repetición de la textura en el plano UV
@export var uv_scale: Vector2 = Vector2(2.5, 2.0):
	set = _set_uv_scale
## Si true, acompaña horizontalmente la cámara para que el cielo de nubes nunca termine al caminar
@export var seguir_camara_x: bool = true
## Factor de parallax horizontal respecto al movimiento de la cámara
@export_range(0.0, 1.0, 0.05) var factor_parallax_camara: float = 0.25

@export_group("Geometría y Perspectiva 3D")
## Ángulo de inclinación en grados respecto al eje X para proyectar profundidad 3D
@export_range(-90.0, 90.0, 0.5) var angulo_inclinacion_grados: float = -78.0:
	set = _set_angulo_inclinacion
## Tamaño del plano de las nubes en el espacio 3D (ancho X, profundidad Y)
@export var tamano_plano: Vector2 = Vector2(90.0, 60.0):
	set = _set_tamano_plano
## Capas de render donde se proyectará la malla (capa 2 para integrarse con SubViewportFondo3D)
@export_flags_3d_render var capas_render: int = 2:
	set = _set_capas_render

@export_group("Aspecto Visual")
## Textura PNG de las nubes. Si es nula, se carga automáticamente la textura por defecto de Castlevania
@export var textura_nube: Texture2D = null:
	set = set_textura_nube
## Aplica un suave difuminado en el horizonte lejano y cerca de la cámara
@export var desvanecer_bordes: bool = true:
	set = _set_desvanecer_bordes

# === VARIABLES PÚBLICAS Y PRIVADAS ===
var _acumulador_offset: float = 0.0
var _camara_referencia: Camera3D = null
var _posicion_base_x: float = 0.0
var _camara_origen_x: float = 0.0
var _camara_detectada: bool = false

# === ONREADY ===
@onready var malla_nubes: MeshInstance3D = %MallaNubes

# === BUILT-IN ===
func _ready() -> void:
	_posicion_base_x = global_position.x
	_inicializar_nodos_si_es_necesario()
	_inicializar_textura()
	_configurar_malla()
	_configurar_material()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if Engine.is_editor_hint() and not animar_en_editor:
		return
	_actualizar_desplazamiento(delta)
	if not Engine.is_editor_hint():
		_actualizar_posicion_camara()

# === FUNCIONES PÚBLICAS ===
## Modifica la velocidad de desplazamiento de las nubes
func set_velocidad(nuevo_valor: float) -> void:
	velocidad = nuevo_valor
	velocidad_cambiada.emit(velocidad)


## Retorna la velocidad actual de desplazamiento
func get_velocidad() -> float:
	return velocidad


## Configura el color de las nubes (luz y sombra)
func set_colores_nube(color_luz: Color, color_sombra: Color) -> void:
	tinte_luz = color_luz
	tinte_sombra = color_sombra
	color_cambiado.emit(tinte_luz, tinte_sombra)
	_aplicar_colores_material()


## Aplica la paleta naranja de atardecer ideal para el nivel tutorial
func aplicar_paleta_naranja_tutorial() -> void:
	preset_color = PresetColorNube.NARANJA_TUTORIAL


## Asigna una nueva textura PNG a las nubes
func set_textura_nube(nueva_textura: Texture2D) -> void:
	textura_nube = nueva_textura
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat) and is_instance_valid(textura_nube):
		mat.set_shader_parameter("textura_nubes", textura_nube)

# === FUNCIONES PRIVADAS ===
func _inicializar_nodos_si_es_necesario() -> void:
	if not is_instance_valid(malla_nubes):
		malla_nubes = get_node_or_null("%MallaNubes") as MeshInstance3D
	if not is_instance_valid(malla_nubes):
		malla_nubes = find_child("MallaNubes", true, false) as MeshInstance3D


func _inicializar_textura() -> void:
	if is_instance_valid(textura_nube):
		return
	if ResourceLoader.exists(TEXTURA_DEFAULT_RUTA):
		textura_nube = load(TEXTURA_DEFAULT_RUTA) as Texture2D


func _obtener_material() -> ShaderMaterial:
	_inicializar_nodos_si_es_necesario()
	if not is_instance_valid(malla_nubes):
		return null
	if malla_nubes.material_override is ShaderMaterial:
		return malla_nubes.material_override as ShaderMaterial
	return null


func _configurar_malla() -> void:
	_inicializar_nodos_si_es_necesario()
	if not is_instance_valid(malla_nubes):
		return
	
	var plano_mesh: PlaneMesh = malla_nubes.mesh as PlaneMesh
	if not is_instance_valid(plano_mesh):
		plano_mesh = PlaneMesh.new()
		malla_nubes.mesh = plano_mesh
	
	plano_mesh.size = tamano_plano
	malla_nubes.rotation_degrees.x = angulo_inclinacion_grados
	malla_nubes.layers = capas_render


func _configurar_material() -> void:
	_inicializar_nodos_si_es_necesario()
	if not is_instance_valid(malla_nubes):
		return
	
	var mat: ShaderMaterial = _obtener_material()
	if not is_instance_valid(mat):
		mat = ShaderMaterial.new()
		var shader_res: Shader = load(SHADER_RUTA) as Shader
		if is_instance_valid(shader_res):
			mat.shader = shader_res
		malla_nubes.material_override = mat
	
	_aplicar_parametros_material(mat)


func _aplicar_parametros_material(mat: ShaderMaterial) -> void:
	if not is_instance_valid(mat):
		return
	
	if is_instance_valid(textura_nube):
		mat.set_shader_parameter("textura_nubes", textura_nube)
	
	mat.set_shader_parameter("tinte_luz", tinte_luz)
	mat.set_shader_parameter("tinte_sombra", tinte_sombra)
	mat.set_shader_parameter("intensidad_color", intensidad_color)
	mat.set_shader_parameter("modo_recoloreo", modo_recoloreo)
	mat.set_shader_parameter("contraste", contraste)
	mat.set_shader_parameter("direccion_scroll", direccion_scroll)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("habilitar_fade_bordes", desvanecer_bordes)


func _aplicar_colores_material() -> void:
	var mat: ShaderMaterial = _obtener_material()
	if not is_instance_valid(mat):
		return
	mat.set_shader_parameter("tinte_luz", tinte_luz)
	mat.set_shader_parameter("tinte_sombra", tinte_sombra)
	mat.set_shader_parameter("intensidad_color", intensidad_color)
	mat.set_shader_parameter("modo_recoloreo", modo_recoloreo)
	mat.set_shader_parameter("contraste", contraste)


func _actualizar_desplazamiento(delta: float) -> void:
	if is_zero_approx(velocidad):
		return
	
	var signo: float = -1.0 if invertir_direccion else 1.0
	_acumulador_offset += (velocidad * signo) * delta
	if absf(_acumulador_offset) > UMBRAL_OFFSET_LOOP:
		_acumulador_offset = fmod(_acumulador_offset, 1.0)
	
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("uv_offset", _acumulador_offset)


func _actualizar_posicion_camara() -> void:
	if not seguir_camara_x:
		return
	
	if not is_instance_valid(_camara_referencia):
		_buscar_camara_referencia()
	
	if not is_instance_valid(_camara_referencia):
		return
	
	if not _camara_detectada:
		_camara_detectada = true
		_camara_origen_x = _camara_referencia.global_position.x
	
	var delta_camara_x: float = _camara_referencia.global_position.x - _camara_origen_x
	global_position.x = _posicion_base_x + (delta_camara_x * (1.0 - factor_parallax_camara))


func _buscar_camara_referencia() -> void:
	var viewport: Viewport = get_viewport()
	if is_instance_valid(viewport):
		_camara_referencia = viewport.get_camera_3d()
	
	if is_instance_valid(_camara_referencia):
		return
	
	var raiz: Node = get_tree().current_scene if get_tree() else null
	if not is_instance_valid(raiz):
		return
	
	var cam_frente: Node = raiz.find_child("CamaraFrente", true, false)
	if cam_frente is Camera3D:
		_camara_referencia = cam_frente as Camera3D
		return
	
	var cam_fondo: Node = raiz.find_child("CamaraFondoDOF", true, false)
	if cam_fondo is Camera3D:
		_camara_referencia = cam_fondo as Camera3D


# === SETTERS DE EDITOR ===
func _set_preset_velocidad(nuevo_preset: PresetVelocidad) -> void:
	preset_velocidad = nuevo_preset
	match nuevo_preset:
		PresetVelocidad.PAUSA:
			set_velocidad(VELOCIDAD_PRESET_PAUSA)
		PresetVelocidad.LENTO:
			set_velocidad(VELOCIDAD_PRESET_LENTO)
		PresetVelocidad.NORMAL:
			set_velocidad(VELOCIDAD_PRESET_NORMAL)
		PresetVelocidad.RAPIDO:
			set_velocidad(VELOCIDAD_PRESET_RAPIDO)


func _set_preset_color(nuevo_preset: PresetColorNube) -> void:
	preset_color = nuevo_preset
	match nuevo_preset:
		PresetColorNube.NARANJA_TUTORIAL:
			tinte_luz = COLOR_NARANJA_LUZ
			tinte_sombra = COLOR_NARANJA_SOMBRA
			intensidad_color = 1.15
			modo_recoloreo = 1.0
			contraste = 1.05
		PresetColorNube.ATARDECER_DORADO:
			tinte_luz = COLOR_DORADO_LUZ
			tinte_sombra = COLOR_DORADO_SOMBRA
			intensidad_color = 1.2
			modo_recoloreo = 1.0
			contraste = 1.0
		PresetColorNube.NOCTURNO_VIOLETA:
			tinte_luz = COLOR_VIOLETA_LUZ
			tinte_sombra = COLOR_VIOLETA_SOMBRA
			intensidad_color = 1.0
			modo_recoloreo = 1.0
			contraste = 1.0
		PresetColorNube.SANGRIENTO_ROJO:
			tinte_luz = COLOR_ROJO_LUZ
			tinte_sombra = COLOR_ROJO_SOMBRA
			intensidad_color = 1.15
			modo_recoloreo = 1.0
			contraste = 1.1
		PresetColorNube.TORMENTA_GRIS:
			tinte_luz = COLOR_GRIS_LUZ
			tinte_sombra = COLOR_GRIS_SOMBRA
			intensidad_color = 1.0
			modo_recoloreo = 1.0
			contraste = 1.0
		PresetColorNube.BLANCO_PURO:
			tinte_luz = COLOR_BLANCO_LUZ
			tinte_sombra = COLOR_BLANCO_SOMBRA
			intensidad_color = 1.0
			modo_recoloreo = 0.0
			contraste = 1.0
	_aplicar_colores_material()


func _set_tinte_luz(valor: Color) -> void:
	tinte_luz = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("tinte_luz", tinte_luz)


func _set_tinte_sombra(valor: Color) -> void:
	tinte_sombra = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("tinte_sombra", tinte_sombra)


func _set_intensidad_color(valor: float) -> void:
	intensidad_color = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("intensidad_color", intensidad_color)


func _set_modo_recoloreo(valor: float) -> void:
	modo_recoloreo = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("modo_recoloreo", modo_recoloreo)


func _set_contraste(valor: float) -> void:
	contraste = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("contraste", contraste)


func _set_invertir_direccion(valor: bool) -> void:
	invertir_direccion = valor


func _set_direccion_scroll(valor: Vector2) -> void:
	direccion_scroll = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("direccion_scroll", direccion_scroll)


func _set_uv_scale(valor: Vector2) -> void:
	uv_scale = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("uv_scale", uv_scale)


func _set_angulo_inclinacion(valor: float) -> void:
	angulo_inclinacion_grados = valor
	_inicializar_nodos_si_es_necesario()
	if is_instance_valid(malla_nubes):
		malla_nubes.rotation_degrees.x = angulo_inclinacion_grados


func _set_tamano_plano(valor: Vector2) -> void:
	tamano_plano = valor
	_inicializar_nodos_si_es_necesario()
	if is_instance_valid(malla_nubes) and malla_nubes.mesh is PlaneMesh:
		(malla_nubes.mesh as PlaneMesh).size = tamano_plano


func _set_capas_render(valor: int) -> void:
	capas_render = valor
	_inicializar_nodos_si_es_necesario()
	if is_instance_valid(malla_nubes):
		malla_nubes.layers = capas_render


func _set_desvanecer_bordes(valor: bool) -> void:
	desvanecer_bordes = valor
	var mat: ShaderMaterial = _obtener_material()
	if is_instance_valid(mat):
		mat.set_shader_parameter("habilitar_fade_bordes", desvanecer_bordes)
