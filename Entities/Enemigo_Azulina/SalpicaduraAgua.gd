class_name SalpicaduraAgua
extends SalpicaduraAzulina

## Salpicadura de agua para la emergencia de Azulina, construida igual que el fuego 2D:
## tira pre-alineada por la base (TEST_/Salpicadura_agua/salpicadura_agua_alineada.png),
## grilla uniforme de 3x1 recortada a ImageTexture, offset con la base en el origen.
## Un impacto que se libera solo al terminar.
## Al heredar de SalpicaduraAzulina sigue contando como tal en tests y spawners.

const TIRA_AGUA: Texture2D = preload("res://TEST_/Salpicadura_agua/salpicadura_agua_alineada.png")
const TOTAL_CUADROS_AGUA: int = 10
const COLUMNAS_TIRA: int = 10
const FILAS_TIRA: int = 1
const MEDIDA_CUADRO_AGUA := Vector2i(212, 74)
const BASE_ORIGEN_AGUA := Vector2(0.0, 37.0)  ## Base del splash en el origen, como OFFSET_BASE_FUEGO
const FPS_AGUA: float = 12.0
const PIXEL_SIZE_AGUA: float = 0.005
const ANIM_AGUA: StringName = &"default"

static var _cache_frames: Dictionary = {}

var _tiempo_editor: float = 0.0


func _ready() -> void:
	reproduccion_en_bucle = false
	animar_en_editor = true
	_asegurar_tira_compatible()
	_configurar_propias()
	_construir_frames()
	_iniciar()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if not Engine.is_editor_hint():
		return
	if not animar_en_editor or sprite_frames == null:
		return
	_tiempo_editor += delta
	var duracion: float = 1.0 / maxf(1.0, velocidad_fps)
	if _tiempo_editor >= duracion:
		_tiempo_editor = fmod(_tiempo_editor, duracion)
		var total: int = sprite_frames.get_frame_count(ANIM_AGUA)
		if total > 0:
			frame = (frame + 1) % total


func _configurar_propias() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	render_priority = 2
	offset = BASE_ORIGEN_AGUA
	pixel_size = PIXEL_SIZE_AGUA
	scale = Vector3(escala_efecto, escala_efecto, escala_efecto)


## Usa la tira alineada salvo que el override mida exactamente la grilla 3x1.
func _asegurar_tira_compatible() -> void:
	if _tira_es_compatible(tira_textura):
		return
	tira_textura = TIRA_AGUA


func _tira_es_compatible(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var img: Image = tex.get_image()
	if img == null:
		return false
	return img.get_size() == Vector2i(COLUMNAS_TIRA * MEDIDA_CUADRO_AGUA.x, FILAS_TIRA * MEDIDA_CUADRO_AGUA.y)


func _construir_frames() -> void:
	_asegurar_tira_compatible()
	if tira_textura == null:
		return

	var ruta: String = tira_textura.resource_path
	if _cache_frames.has(ruta):
		sprite_frames = _cache_frames[ruta]
		return

	var sf := SpriteFrames.new()
	if not sf.has_animation(ANIM_AGUA):
		sf.add_animation(ANIM_AGUA)

	sf.set_animation_loop(ANIM_AGUA, reproduccion_en_bucle)
	sf.set_animation_speed(ANIM_AGUA, velocidad_fps)

	var img_base: Image = tira_textura.get_image()
	for i in range(TOTAL_CUADROS_AGUA):
		var col: int = i % COLUMNAS_TIRA
		var fil: int = i / COLUMNAS_TIRA
		var rect := Rect2i(
			col * MEDIDA_CUADRO_AGUA.x,
			fil * MEDIDA_CUADRO_AGUA.y,
			MEDIDA_CUADRO_AGUA.x,
			MEDIDA_CUADRO_AGUA.y
		)
		if img_base != null:
			var frame_tex := ImageTexture.create_from_image(img_base.get_region(rect))
			sf.add_frame(ANIM_AGUA, frame_tex)
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = tira_textura
			atlas.region = Rect2(Vector2(rect.position), Vector2(rect.size))
			sf.add_frame(ANIM_AGUA, atlas)

	_cache_frames[ruta] = sf
	sprite_frames = sf


func _iniciar() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(ANIM_AGUA):
		return
	sprite_frames.set_animation_loop(ANIM_AGUA, reproduccion_en_bucle)
	sprite_frames.set_animation_speed(ANIM_AGUA, velocidad_fps)
	if not Engine.is_editor_hint():
		play(ANIM_AGUA)
	if not animation_finished.is_connected(_on_impacto_terminado):
		animation_finished.connect(_on_impacto_terminado)


func _on_impacto_terminado() -> void:
	if not reproduccion_en_bucle and not Engine.is_editor_hint():
		queue_free()


## Reproduce el impacto con su sonido de chapoteo posicionado en la rompiente.
func disparar_impacto(posicion_impacto: Vector3, en_bucle: bool = false) -> void:
	super.disparar_impacto(posicion_impacto, en_bucle)
	if Engine.is_editor_hint():
		return
	if get_tree() == null:
		return
	AudioManager.play_sfx_3d("splash_agua", global_position)
