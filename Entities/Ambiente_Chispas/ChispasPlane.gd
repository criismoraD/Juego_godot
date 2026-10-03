@tool
class_name ChispasPlane
extends GPUParticles3D

## Capa de partículas de chispas y ascuas incandescentes que caen simulando el incendio del nivel.
## Similar al efecto de HojasPlane, con selectores de velocidad, brillo, color y capa visual.

# ═══════════════════════════════════════════════════════════════════════════════
# ENUMS Y CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════

enum VelocidadPreset {
	LENTA_FLOTANTE,   ## 0.5 — Ascuas suspendidas que flotan despacio
	MEDIA,            ## 1.0 — Caída estándar de incendio
	RAPIDA,           ## 1.8 — Viento fuerte de combate
	TORMENTA_ASCUAS,  ## 2.8 — Ráfaga intensa de chispas
	PERSONALIZADA     ## Ajuste libre según variable velocidad
}

enum BrilloPreset {
	TENUE,             ## 1.2 — Sutiles puntos dorados
	MEDIO,             ## 2.5 — Visibilidad clara de fuego
	INTENSO,           ## 4.0 — Brillo incandescente (Glow activo)
	INCANDESCENTE_HDR, ## 7.0 — Fuerte destello HDR en pantalla
	PERSONALIZADO      ## Ajuste libre según variable brillo
}

enum ColorPreset {
	FUEGO_NARANJA,     ## Fuego cálido clásico: Color(1.0, 0.55, 0.12)
	ASCUAS_DORADAS,    ## Oro/ámbar ardiente: Color(1.0, 0.82, 0.22)
	BRASAS_ROJAS,      ## Rojo brasa profundo: Color(1.0, 0.25, 0.08)
	FUEGO_AZUL,        ## Fuego espectral / mágico: Color(0.2, 0.65, 1.0)
	FUEGO_VERDE,       ## Fuego tóxico / alquímico: Color(0.25, 1.0, 0.35)
	PERSONALIZADO      ## Ajuste libre según color_base
}

const VELOCIDAD_LENTA: float = 0.5
const VELOCIDAD_MEDIA: float = 1.0
const VELOCIDAD_RAPIDA: float = 1.8
const VELOCIDAD_TORMENTA: float = 2.8

const BRILLO_TENUE: float = 1.2
const BRILLO_MEDIO: float = 2.5
const BRILLO_INTENSO: float = 4.0
const BRILLO_INCANDESCENTE: float = 7.0

const COLOR_FUEGO_NARANJA: Color = Color(1.0, 0.55, 0.12, 1.0)
const COLOR_ASCUAS_DORADAS: Color = Color(1.0, 0.82, 0.22, 1.0)
const COLOR_BRASAS_ROJAS: Color = Color(1.0, 0.25, 0.08, 1.0)
const COLOR_FUEGO_AZUL: Color = Color(0.2, 0.65, 1.0, 1.0)
const COLOR_FUEGO_VERDE: Color = Color(0.25, 1.0, 0.35, 1.0)

const MATERIAL_BASE_DEFECTO: Material = preload("res://Entities/Ambiente_Chispas/MAT_chispas.tres")

# ═══════════════════════════════════════════════════════════════════════════════
# SELECTORES Y PROPIEDADES EXPORTADAS
# ═══════════════════════════════════════════════════════════════════════════════

@export_group("Selectores Principales")
## Multiplicador de velocidad de caída de las chispas (afecta gravedad y velocidad)
@export_range(0.1, 5.0, 0.05) var velocidad: float = 1.0:
	set(val):
		velocidad = val
		_actualizar_parametros()

## Intensidad de emisión y brillo HDR para activar el Glow/Bloom del incendio
@export_range(0.2, 10.0, 0.1) var brillo: float = 3.5:
	set(val):
		brillo = val
		_actualizar_parametros()

@export_group("Presets de Ajuste Rápido")
@export var preset_velocidad: VelocidadPreset = VelocidadPreset.MEDIA:
	set(val):
		preset_velocidad = val
		_aplicar_preset_velocidad()

@export var preset_brillo: BrilloPreset = BrilloPreset.INTENSO:
	set(val):
		preset_brillo = val
		_aplicar_preset_brillo()

@export var preset_color: ColorPreset = ColorPreset.FUEGO_NARANJA:
	set(val):
		preset_color = val
		_aplicar_preset_color()

@export_group("Color y Temperatura")
@export var color_base: Color = COLOR_FUEGO_NARANJA:
	set(val):
		color_base = val
		_actualizar_parametros()

@export_group("Capas y Render")
## Capa visual 3D (por defecto 2 = Fondo DOF para el nivel tutorial, igual que HojasPlane)
@export_flags_3d_render var capa_visual: int = 2:
	set(val):
		capa_visual = val
		layers = capa_visual

@export_group("Viento y Turbulencia")
## Deriva lateral del viento (negativo = hacia la izquierda, acompaña el avance del tutorial)
@export_range(-3.0, 3.0, 0.1) var viento_lateral: float = -0.35:
	set(val):
		viento_lateral = val
		_actualizar_parametros()

@export var turbulencia_activa: bool = true:
	set(val):
		turbulencia_activa = val
		_actualizar_parametros()

@export_range(0.01, 0.5, 0.01) var fuerza_turbulencia: float = 0.08:
	set(val):
		fuerza_turbulencia = val
		_actualizar_parametros()

@export_group("Área y Cobertura")
@export var ancho_emision: float = 35.0:
	set(val):
		ancho_emision = val
		_actualizar_parametros()

@export var alto_emision_offset: float = 11.0:
	set(val):
		alto_emision_offset = val
		_actualizar_parametros()

@export var profundidad_emision: float = 2.0:
	set(val):
		profundidad_emision = val
		_actualizar_parametros()

@export_range(10, 500, 10) var cantidad_chispas: int = 120:
	set(val):
		cantidad_chispas = val
		amount = cantidad_chispas

@export_range(0.02, 0.4, 0.01) var tamano_min: float = 0.06:
	set(val):
		tamano_min = val
		_actualizar_parametros()

@export_range(0.05, 0.8, 0.02) var tamano_max: float = 0.18:
	set(val):
		tamano_max = val
		_actualizar_parametros()


# ═══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA BUILT-IN
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_inicializar_nodos_base()
	_actualizar_parametros()
	preprocess = lifetime
	emitting = true


# ═══════════════════════════════════════════════════════════════════════════════
# MÉTODOS PÚBLICOS
# ═══════════════════════════════════════════════════════════════════════════════

## Ajusta la velocidad de caída de las chispas dinámicamente.
func establecer_velocidad(nueva_velocidad: float) -> void:
	preset_velocidad = VelocidadPreset.PERSONALIZADA
	velocidad = max(0.05, nueva_velocidad)


## Ajusta el brillo HDR y la intensidad de emisión de las ascuas.
func establecer_brillo(nuevo_brillo: float) -> void:
	preset_brillo = BrilloPreset.PERSONALIZADO
	brillo = max(0.1, nuevo_brillo)


## Ajusta el color base de las chispas.
func establecer_color(nuevo_color: Color) -> void:
	preset_color = ColorPreset.PERSONALIZADO
	color_base = nuevo_color


## Ajusta la capa visual de renderizado 3D.
func establecer_capa_visual(capa: int) -> void:
	capa_visual = capa


# ═══════════════════════════════════════════════════════════════════════════════
# ACTUALIZACIÓN DE PARÁMETROS
# ═══════════════════════════════════════════════════════════════════════════════

func _inicializar_nodos_base() -> void:
	layers = capa_visual
	amount = cantidad_chispas
	local_coords = false
	visibility_aabb = AABB(Vector3(-25, -15, -5), Vector3(50, 30, 10))

	# Si no tiene mesh asignado, asignar QuadMesh con el material aditivo
	if draw_pass_1 == null:
		var qmesh := QuadMesh.new()
		qmesh.size = Vector2(0.5, 0.5)
		qmesh.material = MATERIAL_BASE_DEFECTO
		draw_pass_1 = qmesh

	# Si no tiene process_material, instanciarlo
	if process_material == null or not (process_material is ParticleProcessMaterial):
		process_material = ParticleProcessMaterial.new()


func _actualizar_parametros() -> void:
	layers = capa_visual
	amount = cantidad_chispas

	var mat_proc = process_material as ParticleProcessMaterial
	if mat_proc == null:
		mat_proc = ParticleProcessMaterial.new()
		process_material = mat_proc

	# 1. Área de emisión (Caja superior sobre la pantalla)
	mat_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat_proc.emission_box_extents = Vector3(ancho_emision * 0.5, 0.2, profundidad_emision * 0.5)
	mat_proc.emission_shape_offset = Vector3(0.0, alto_emision_offset, 0.0)

	# 2. Dirección, gravedad y velocidades escaladas por la velocidad
	mat_proc.direction = Vector3(viento_lateral, -1.0, 0.0).normalized()
	mat_proc.spread = 22.0
	mat_proc.initial_velocity_min = 0.4 * velocidad
	mat_proc.initial_velocity_max = 1.25 * velocidad
	mat_proc.gravity = Vector3(viento_lateral * 0.18 * velocidad, -0.6 * velocidad, 0.0)

	# 3. Turbulencia para fluctuación natural de ceniza ardiente
	mat_proc.turbulence_enabled = turbulencia_activa
	mat_proc.turbulence_noise_strength = fuerza_turbulencia
	mat_proc.turbulence_noise_scale = 5.0
	mat_proc.turbulence_influence_min = 0.02
	mat_proc.turbulence_influence_max = 0.06

	# 4. Tamaños y escala
	mat_proc.scale_min = tamano_min
	mat_proc.scale_max = tamano_max

	# 5. Gradiente de color según color_base y multiplicador de brillo HDR
	mat_proc.color_ramp = _generar_textura_gradiente_brillo()


func _generar_textura_gradiente_brillo() -> GradientTexture1D:
	var gradiente := Gradient.new()
	var b: float = brillo

	# Color inicial: entra transparente
	var c_ini := Color(color_base.r * b, color_base.g * b, color_base.b * b, 0.0)
	# Núcleo incandescente al 15% de vida: destello muy blanco/amarillo
	var c_pico := Color(
		clamp(color_base.r * b * 1.3, 0.0, 10.0),
		clamp(color_base.g * b * 1.15, 0.0, 10.0),
		clamp(color_base.b * b * 0.9, 0.0, 10.0),
		0.95
	)
	# Fase media: color base ardiente
	var c_medio := Color(
		clamp(color_base.r * b, 0.0, 10.0),
		clamp(color_base.g * b * 0.75, 0.0, 10.0),
		clamp(color_base.b * b * 0.35, 0.0, 10.0),
		0.85
	)
	# Fase final: brasa que se disipa suavemente sin oscurecer
	var c_fin := Color(
		clamp(color_base.r * b * 0.5, 0.0, 10.0),
		clamp(color_base.g * b * 0.25, 0.0, 10.0),
		clamp(color_base.b * b * 0.1, 0.0, 10.0),
		0.0
	)

	gradiente.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	gradiente.colors = PackedColorArray([c_ini, c_pico, c_medio, c_fin])

	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradiente
	return grad_tex


# ═══════════════════════════════════════════════════════════════════════════════
# PRESETS INTERNOS
# ═══════════════════════════════════════════════════════════════════════════════

func _aplicar_preset_velocidad() -> void:
	match preset_velocidad:
		VelocidadPreset.LENTA_FLOTANTE:
			velocidad = VELOCIDAD_LENTA
		VelocidadPreset.MEDIA:
			velocidad = VELOCIDAD_MEDIA
		VelocidadPreset.RAPIDA:
			velocidad = VELOCIDAD_RAPIDA
		VelocidadPreset.TORMENTA_ASCUAS:
			velocidad = VELOCIDAD_TORMENTA
		VelocidadPreset.PERSONALIZADA:
			pass


func _aplicar_preset_brillo() -> void:
	match preset_brillo:
		BrilloPreset.TENUE:
			brillo = BRILLO_TENUE
		BrilloPreset.MEDIO:
			brillo = BRILLO_MEDIO
		BrilloPreset.INTENSO:
			brillo = BRILLO_INTENSO
		BrilloPreset.INCANDESCENTE_HDR:
			brillo = BRILLO_INCANDESCENTE
		BrilloPreset.PERSONALIZADO:
			pass


func _aplicar_preset_color() -> void:
	match preset_color:
		ColorPreset.FUEGO_NARANJA:
			color_base = COLOR_FUEGO_NARANJA
		ColorPreset.ASCUAS_DORADAS:
			color_base = COLOR_ASCUAS_DORADAS
		ColorPreset.BRASAS_ROJAS:
			color_base = COLOR_BRASAS_ROJAS
		ColorPreset.FUEGO_AZUL:
			color_base = COLOR_FUEGO_AZUL
		ColorPreset.FUEGO_VERDE:
			color_base = COLOR_FUEGO_VERDE
		ColorPreset.PERSONALIZADO:
			pass
