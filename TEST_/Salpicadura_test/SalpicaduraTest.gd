@tool
class_name SalpicaduraTest
extends AnimatedSprite3D

## Controlador de efecto visual 2.5D para la animación de impacto en el agua (13 cuadros).
## Permite reproducir en bucle para pruebas y posicionamiento tanto en el editor 3D
## como en tiempo de juego sobre la superficie del agua.

# === CONSTANTES ===
const DEFAULT_FPS: float = 12.0
const CANTIDAD_CUADROS: int = 13
const TAMANO_CUADRO: Vector2i = Vector2i(64, 136)
const OFFSET_BASE_AGUA: Vector2 = Vector2(0.0, 56.0)  ## Alinea el origen (Y=0) con la línea de agua
const ANIM_DEFAULT: StringName = &"default"
const TEXTURA_STRIP_DEFECTO: Texture2D = preload("res://TEST_/Salpicadura_test/salpicadura_test_strip.png")

# === EXPORTS ===
@export_category("Configuración de Animación")
@export var animar_en_editor: bool = true  ## Permite previsualizar la animación viva en el editor 3D
@export var reproduccion_en_bucle: bool = true  ## Si true, la salpicadura se repite continuamente para pruebas
@export var velocidad_fps: float = DEFAULT_FPS  ## Cuadros por segundo de la animación
@export var tira_textura: Texture2D = TEXTURA_STRIP_DEFECTO  ## Tira horizontal con los 13 cuadros

@export_category("Propiedades Visuales")
@export var capa_visual: int = 1  ## Capa de renderizado (1 visible por defecto en editor y juego)
@export var escala_efecto: float = 1.6  ## Escala uniforme recomendada para el impacto en agua

# === VARIABLES PRIVADAS ===
var _tiempo_acumulado_editor: float = 0.0
static var _cache_sprite_frames: Dictionary = {}


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_configurar_propiedades_visuales()
	_inicializar_sprite_frames()
	_iniciar_reproduccion()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	# Previsualización continua en el editor 3D de Godot
	if Engine.is_editor_hint():
		if not animar_en_editor or sprite_frames == null:
			return

		_tiempo_acumulado_editor += delta
		var duracion_cuadro: float = 1.0 / maxf(1.0, velocidad_fps)
		if _tiempo_acumulado_editor >= duracion_cuadro:
			_tiempo_acumulado_editor = fmod(_tiempo_acumulado_editor, duracion_cuadro)
			var total_cuadros: int = sprite_frames.get_frame_count(ANIM_DEFAULT)
			if total_cuadros > 0:
				frame = (frame + 1) % total_cuadros


# === FUNCIONES PÚBLICAS ===
## Configura la posición y activa un impacto de agua único o en bucle.
func disparar_impacto(posicion_impacto: Vector3, en_bucle: bool = false) -> void:
	global_position = posicion_impacto
	reproduccion_en_bucle = en_bucle
	if sprite_frames and sprite_frames.has_animation(ANIM_DEFAULT):
		sprite_frames.set_animation_loop(ANIM_DEFAULT, en_bucle)
	frame = 0
	play(ANIM_DEFAULT)


## Detiene la animación.
func detener_impacto() -> void:
	stop()
	frame = 0


# === FUNCIONES PRIVADAS ===
func _configurar_propiedades_visuales() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = false
	render_priority = 2
	offset = OFFSET_BASE_AGUA
	layers = capa_visual
	scale = Vector3(escala_efecto, escala_efecto, escala_efecto)


func _inicializar_sprite_frames() -> void:
	if sprite_frames != null:
		return

	if tira_textura == null:
		tira_textura = TEXTURA_STRIP_DEFECTO

	if tira_textura == null:
		return

	var ruta_textura: String = tira_textura.resource_path
	var clave_cache: String = "%s_%d_%dx%d_%.1f_%s" % [
		ruta_textura,
		CANTIDAD_CUADROS,
		TAMANO_CUADRO.x,
		TAMANO_CUADRO.y,
		velocidad_fps,
		str(reproduccion_en_bucle)
	]

	if _cache_sprite_frames.has(clave_cache):
		sprite_frames = _cache_sprite_frames[clave_cache]
		return

	var sf := SpriteFrames.new()
	if not sf.has_animation(ANIM_DEFAULT):
		sf.add_animation(ANIM_DEFAULT)

	sf.set_animation_loop(ANIM_DEFAULT, reproduccion_en_bucle)
	sf.set_animation_speed(ANIM_DEFAULT, velocidad_fps)

	for i in range(CANTIDAD_CUADROS):
		var atlas := AtlasTexture.new()
		atlas.atlas = tira_textura
		atlas.region = Rect2(
			float(i * TAMANO_CUADRO.x),
			0.0,
			float(TAMANO_CUADRO.x),
			float(TAMANO_CUADRO.y)
		)
		sf.add_frame(ANIM_DEFAULT, atlas)

	_cache_sprite_frames[clave_cache] = sf
	sprite_frames = sf


func _iniciar_reproduccion() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(ANIM_DEFAULT):
		return

	sprite_frames.set_animation_loop(ANIM_DEFAULT, reproduccion_en_bucle)
	sprite_frames.set_animation_speed(ANIM_DEFAULT, velocidad_fps)
	play(ANIM_DEFAULT)

	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	if not reproduccion_en_bucle and not Engine.is_editor_hint():
		queue_free()
