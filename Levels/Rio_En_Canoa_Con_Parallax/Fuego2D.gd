@tool
class_name Fuego2D
extends AnimatedSprite3D

## Efecto de fuego 2D animado fluido con luz omnidireccional cálida parpadeante
## para el nivel del río y ambientación 2.5D.
## Utiliza una secuencia de 12 cuadros perfectamente alineados en su base
## para eliminar vibraciones o saltos horizontales.
## Permite difuminar/suavizar los bordes mediante un shader bokeh estilizado.

# === CONSTANTES ===
const CANTIDAD_CUADROS: int = 12
const COLUMNAS_SPRITESHEET: int = 4
const FILAS_SPRITESHEET: int = 3
const TAMANO_CUADRO: Vector2i = Vector2i(96, 160)
const OFFSET_BASE_FUEGO: Vector2 = Vector2(0.0, 74.0)  ## Centra la base de la llama en el origen (0, 0, 0)
const FPS_DEFECTO: float = 14.0
const ANIM_DEFAULT: StringName = &"fuego"
const TEXTURA_FUEGO_DEFECTO: Texture2D = preload("res://Levels/Rio_En_Canoa_Con_Parallax/fuego_2d_alineado.png")
const SHADER_FUEGO_DEFECTO: Shader = preload("res://Levels/Rio_En_Canoa_Con_Parallax/fuego_2d.gdshader")

# === EXPORTS ===
@export_category("Animación de Fuego")
@export var animar_en_editor: bool = true  ## Si true, la animación y el parpadeo se previsualizan en el editor 3D
@export var velocidad_fps: float = FPS_DEFECTO:  ## Cuadros por segundo de la animación de llama
	set(v):
		velocidad_fps = maxf(1.0, v)
		if sprite_frames and sprite_frames.has_animation(ANIM_DEFAULT):
			sprite_frames.set_animation_speed(ANIM_DEFAULT, velocidad_fps)

@export var tira_textura: Texture2D = TEXTURA_FUEGO_DEFECTO:
	set(v):
		tira_textura = v
		if is_node_ready():
			_reconstruir_sprite_frames()

@export_category("Efectos Visuales (Difuminado)")
## Nivel de difuminado o suavizado bokeh (0.0 = nítido, >0.0 = difuminado estilizado 2.5D)
@export_range(0.0, 8.0, 0.1) var difuminado: float = 0.0:
	set(v):
		difuminado = clampf(v, 0.0, 8.0)
		_actualizar_material_difuminado()

## Tinte de color para matizar la llama (opcional)
@export var tinte: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(v):
		tinte = v
		if is_instance_valid(_shader_material):
			_shader_material.set_shader_parameter("tint_color", tinte)

@export_category("Luz Cálida (OmniLight3D)")
@export var luz_activa: bool = true:
	set(v):
		luz_activa = v
		if is_instance_valid(luz_fuego):
			luz_fuego.visible = luz_activa

@export var color_luz: Color = Color(1.0, 0.65, 0.25, 1.0):
	set(v):
		color_luz = v
		if is_instance_valid(luz_fuego):
			luz_fuego.light_color = color_luz

@export var energia_luz_base: float = 1.2
@export var radio_luz: float = 3.5:
	set(v):
		radio_luz = v
		if is_instance_valid(luz_fuego):
			luz_fuego.omni_range = radio_luz

@export var parpadeo_luz: bool = true
@export var variacion_flicker: float = 0.25
@export var frecuencia_flicker: float = 8.0

@export_category("Fluidez y Respiración")
@export var respiracion_llama: bool = true  ## Si true, la escala oscila sutilmente simulando la respiración del fuego
@export var escala_base: float = 1.0:
	set(v):
		escala_base = v
		scale = Vector3(escala_base, escala_base, escala_base)

@export var intensidad_respiracion: float = 0.04  ## Amplitud de la oscilación de tamaño

# === VARIABLES PÚBLICAS Y PRIVADAS ===
var _tiempo_editor: float = 0.0
var _tiempo_flicker: float = 0.0
var _shader_material: ShaderMaterial = null
static var _cache_sprite_frames: Dictionary = {}

# === ONREADY ===
@onready var luz_fuego: OmniLight3D = get_node_or_null("LuzFuego") as OmniLight3D


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_configurar_propiedades_visuales()
	_inicializar_sprite_frames()
	_inicializar_luz()
	_actualizar_material_difuminado()
	_iniciar_animacion()
	if not frame_changed.is_connected(_on_frame_changed):
		frame_changed.connect(_on_frame_changed)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	_actualizar_luz_flicker(delta)
	_actualizar_respiracion(delta)

	if Engine.is_editor_hint():
		_procesar_animacion_editor(delta)


# === FUNCIONES PÚBLICAS ===
## Configura el estado activo del fuego (visibilidad y luz).
func set_fuego_activo(activo: bool) -> void:
	visible = activo
	luz_activa = activo
	set_process(activo)


## Retorna la referencia a la luz del fuego.
func obtener_luz() -> OmniLight3D:
	if not is_instance_valid(luz_fuego):
		luz_fuego = get_node_or_null("LuzFuego") as OmniLight3D
	return luz_fuego


## Permite consultar si el shader de difuminado está activo.
func tiene_difuminado_activo() -> bool:
	return difuminado > 0.001 and material_override != null


# === FUNCIONES PRIVADAS ===
func _configurar_propiedades_visuales() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	render_priority = 2
	offset = OFFSET_BASE_FUEGO
	pixel_size = 0.0055
	scale = Vector3(escala_base, escala_base, escala_base)


func _inicializar_sprite_frames() -> void:
	if tira_textura == null:
		tira_textura = TEXTURA_FUEGO_DEFECTO
	if tira_textura == null:
		return

	var ruta: String = tira_textura.resource_path
	if _cache_sprite_frames.has(ruta):
		sprite_frames = _cache_sprite_frames[ruta]
		return

	var sf := SpriteFrames.new()
	if not sf.has_animation(ANIM_DEFAULT):
		sf.add_animation(ANIM_DEFAULT)

	sf.set_animation_loop(ANIM_DEFAULT, true)
	sf.set_animation_speed(ANIM_DEFAULT, velocidad_fps)

	var img_base: Image = tira_textura.get_image()
	for i in range(CANTIDAD_CUADROS):
		var col: int = i % COLUMNAS_SPRITESHEET
		var row: int = i / COLUMNAS_SPRITESHEET
		var rect := Rect2i(
			col * TAMANO_CUADRO.x,
			row * TAMANO_CUADRO.y,
			TAMANO_CUADRO.x,
			TAMANO_CUADRO.y
		)
		if img_base != null:
			var sub_img: Image = img_base.get_region(rect)
			var frame_tex := ImageTexture.create_from_image(sub_img)
			sf.add_frame(ANIM_DEFAULT, frame_tex)
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = tira_textura
			atlas.region = Rect2(Vector2(rect.position), Vector2(rect.size))
			sf.add_frame(ANIM_DEFAULT, atlas)

	_cache_sprite_frames[ruta] = sf
	sprite_frames = sf


func _reconstruir_sprite_frames() -> void:
	if tira_textura != null:
		_cache_sprite_frames.erase(tira_textura.resource_path)
	_inicializar_sprite_frames()
	_iniciar_animacion()
	_actualizar_textura_shader()


func _inicializar_luz() -> void:
	if luz_fuego == null:
		luz_fuego = get_node_or_null("LuzFuego") as OmniLight3D
	if luz_fuego == null:
		luz_fuego = OmniLight3D.new()
		luz_fuego.name = "LuzFuego"
		add_child(luz_fuego)

	luz_fuego.position = Vector3(0.0, 0.45, 0.0)  ## En el centro de la llama
	luz_fuego.light_color = color_luz
	luz_fuego.light_energy = energia_luz_base
	luz_fuego.omni_range = radio_luz
	luz_fuego.omni_attenuation = 1.35
	luz_fuego.shadow_enabled = false
	luz_fuego.visible = luz_activa


func _iniciar_animacion() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(ANIM_DEFAULT):
		return
	sprite_frames.set_animation_loop(ANIM_DEFAULT, true)
	sprite_frames.set_animation_speed(ANIM_DEFAULT, velocidad_fps)
	if not Engine.is_editor_hint():
		play(ANIM_DEFAULT)


func _actualizar_material_difuminado() -> void:
	if difuminado <= 0.001:
		material_override = null
		_shader_material = null
		return

	if _shader_material == null:
		_shader_material = ShaderMaterial.new()
		_shader_material.shader = SHADER_FUEGO_DEFECTO

	_shader_material.set_shader_parameter("blur_amount", difuminado)
	_shader_material.set_shader_parameter("tint_color", tinte)
	material_override = _shader_material
	_actualizar_textura_shader()


func _actualizar_textura_shader() -> void:
	if not is_instance_valid(_shader_material) or sprite_frames == null:
		return
	if not sprite_frames.has_animation(ANIM_DEFAULT):
		return
	var total: int = sprite_frames.get_frame_count(ANIM_DEFAULT)
	if total == 0:
		return
	var f_clamped: int = clampi(frame, 0, total - 1)
	var tex: Texture2D = sprite_frames.get_frame_texture(ANIM_DEFAULT, f_clamped)
	if tex != null:
		_shader_material.set_shader_parameter("albedo_texture", tex)


func _on_frame_changed() -> void:
	if difuminado > 0.001:
		_actualizar_textura_shader()


func _actualizar_luz_flicker(delta: float) -> void:
	if not is_instance_valid(luz_fuego) or not luz_activa or not parpadeo_luz:
		return
	_tiempo_flicker += delta * frecuencia_flicker
	var onda: float = sin(_tiempo_flicker) * 0.5 + sin(_tiempo_flicker * 2.37) * 0.3 + sin(_tiempo_flicker * 0.43) * 0.2
	luz_fuego.light_energy = energia_luz_base + (onda * variacion_flicker)


func _actualizar_respiracion(_delta: float) -> void:
	if not respiracion_llama:
		return
	var factor_y: float = 1.0 + sin(_tiempo_flicker * 0.8) * intensidad_respiracion
	var factor_x: float = 1.0 + cos(_tiempo_flicker * 0.7) * (intensidad_respiracion * 0.5)
	scale = Vector3(escala_base * factor_x, escala_base * factor_y, escala_base)


func _procesar_animacion_editor(delta: float) -> void:
	if not animar_en_editor or sprite_frames == null:
		return
	_tiempo_editor += delta
	var duracion: float = 1.0 / maxf(1.0, velocidad_fps)
	if _tiempo_editor >= duracion:
		_tiempo_editor = fmod(_tiempo_editor, duracion)
		var total: int = sprite_frames.get_frame_count(ANIM_DEFAULT)
		if total > 0:
			frame = (frame + 1) % total
			if difuminado > 0.001:
				_actualizar_textura_shader()
