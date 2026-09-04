class_name BloodSplash2D
extends AnimatedSprite3D

## Controlador del efecto de sangre 2D en espacio 3D (2.5D).
## Reproduce una animación one-shot y se autodestruye al finalizar.
## Permite orientar el sprite según el vector de impacto de la flecha.

# === CONSTANTES ===
const DEFAULT_FPS: float = 14.0

# === EXPORTS ===
@export var autoplay_animation: StringName = &"default"
@export var custom_fps: float = DEFAULT_FPS
@export var destroy_after_anim: bool = true
@export var texture_strip: Texture2D = null
@export var frame_count: int = 4
@export var frame_size: Vector2i = Vector2i(110, 53)
@export var custom_regions: Array[Rect2] = []
@export var base_faces_left: bool = false

# === CACHÉ ESTÁTICA DE SPRITEFRAMES ===
static var _frames_cache: Dictionary = {}


func _ready() -> void:
	# Configuración visual para 2.5D
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = false
	render_priority = 1

	if sprite_frames == null and texture_strip != null:
		_build_sprite_frames_from_strip()

	if sprite_frames and sprite_frames.has_animation(autoplay_animation):
		sprite_frames.set_animation_loop(autoplay_animation, false)
		sprite_frames.set_animation_speed(autoplay_animation, custom_fps)
		play(autoplay_animation)

	animation_finished.connect(_on_animation_finished)


func _build_sprite_frames_from_strip() -> void:
	var path: String = texture_strip.resource_path if texture_strip else ""
	var cache_key: String = "%s_%d_%dx%d_%.1f" % [path, frame_count, frame_size.x, frame_size.y, custom_fps]

	if _frames_cache.has(cache_key):
		sprite_frames = _frames_cache[cache_key]
		return

	var sf := SpriteFrames.new()
	if not sf.has_animation(autoplay_animation):
		sf.add_animation(autoplay_animation)
	sf.set_animation_loop(autoplay_animation, false)
	sf.set_animation_speed(autoplay_animation, custom_fps)

	if not custom_regions.is_empty():
		for reg in custom_regions:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture_strip
			atlas.region = reg
			sf.add_frame(autoplay_animation, atlas)
	else:
		for i in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture_strip
			atlas.region = Rect2(float(i * frame_size.x), 0.0, float(frame_size.x), float(frame_size.y))
			sf.add_frame(autoplay_animation, atlas)

	_frames_cache[cache_key] = sf
	sprite_frames = sf


## Inicializa el efecto con posición de impacto, dirección del proyectil y color opcional.
func setup(hit_position: Vector3, hit_direction: Vector3 = Vector3.ZERO, custom_modulate: Color = Color.WHITE) -> void:
	global_position = hit_position
	modulate = custom_modulate

	var half_w: float = float(frame_size.x) * 0.5
	if not custom_regions.is_empty():
		half_w = custom_regions[0].size.x * 0.5

	if base_faces_left:
		# Textura base orientada hacia la izquierda
		if hit_direction != Vector3.ZERO and hit_direction.x < 0.0:
			flip_h = false
			offset = Vector2(-half_w, 0.0)
		else:
			flip_h = true
			offset = Vector2(half_w, 0.0)
	else:
		# Textura base orientada hacia la derecha (por defecto)
		if hit_direction != Vector3.ZERO and hit_direction.x < 0.0:
			# Flecha viajando hacia la izquierda (X < 0): voltear y anclar origen en hit_position proyectando a la izquierda
			flip_h = true
			offset = Vector2(-half_w, 0.0)
		else:
			# Flecha viajando hacia la derecha (X >= 0 o por defecto): anclar origen en hit_position proyectando a la derecha
			flip_h = false
			offset = Vector2(half_w, 0.0)


func _on_animation_finished() -> void:
	if destroy_after_anim:
		queue_free()
