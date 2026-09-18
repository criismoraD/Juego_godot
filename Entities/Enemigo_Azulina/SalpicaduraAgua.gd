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
const SHADER_DISOLUCION_SPRITE: Shader = preload("res://System/Shaders/dissolve_sprite.gdshader")
const COLOR_DISOLUCION_SPLASH: Color = Color(0.35, 0.85, 1.0, 1.0)

# === EXPORTS ===
@export_category("Efecto de Disolución Celeste")
@export var disolucion_celeste: bool = true  ## Efecto de disolución celeste al aparecer y desaparecer
@export var duracion_disolucion_entrada: float = 0.22  ## Segundos para materializarse al emerger
@export var duracion_disolucion_salida: float = 0.25  ## Segundos para desintegrarse al terminar

static var _cache_frames: Dictionary = {}

var _tiempo_editor: float = 0.0
var _material_splash: ShaderMaterial = null
var _tween_splash: Tween = null


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
	_configurar_material_disolucion()


func _configurar_material_disolucion() -> void:
	if not disolucion_celeste:
		material_override = null
		_material_splash = null
		return
	if _material_splash == null:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_DISOLUCION_SPRITE
		mat.set_shader_parameter("glow_color", COLOR_DISOLUCION_SPLASH)
		mat.set_shader_parameter("glow_intensity", 8.0)
		mat.set_shader_parameter("edge_thickness", 0.08)
		mat.set_shader_parameter("noise_scale", 16.0)
		mat.set_shader_parameter("dissolve_amount", 0.0 if Engine.is_editor_hint() else 1.0)
		material_override = mat
		_material_splash = mat


func _actualizar_textura_shader() -> void:
	if not is_instance_valid(_material_splash) or sprite_frames == null:
		return
	if not sprite_frames.has_animation(ANIM_AGUA):
		return
	var total: int = sprite_frames.get_frame_count(ANIM_AGUA)
	if total == 0:
		return
	var f_clamped: int = clampi(frame, 0, total - 1)
	var tex: Texture2D = sprite_frames.get_frame_texture(ANIM_AGUA, f_clamped)
	if tex != null:
		_material_splash.set_shader_parameter("albedo_texture", tex)


func _actualizar_disolucion_splash(valor: float) -> void:
	if is_instance_valid(_material_splash):
		_material_splash.set_shader_parameter("dissolve_amount", valor)


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
	if not animation_finished.is_connected(_on_impacto_terminado):
		animation_finished.connect(_on_impacto_terminado)
	if not frame_changed.is_connected(_on_splash_frame_changed):
		frame_changed.connect(_on_splash_frame_changed)
	_actualizar_textura_shader()
	if not Engine.is_editor_hint():
		play(ANIM_AGUA)
		if disolucion_celeste and is_inside_tree():
			_iniciar_ciclo_disolucion()


func _on_splash_frame_changed() -> void:
	_actualizar_textura_shader()


func _iniciar_ciclo_disolucion() -> void:
	if not disolucion_celeste or Engine.is_editor_hint() or not is_inside_tree():
		return
	if _tween_splash != null and _tween_splash.is_valid():
		_tween_splash.kill()

	var duracion_total: float = float(TOTAL_CUADROS_AGUA) / maxf(1.0, velocidad_fps)
	var t_entrada: float = clampf(duracion_disolucion_entrada, 0.05, duracion_total * 0.35)
	var t_salida: float = clampf(duracion_disolucion_salida, 0.05, duracion_total * 0.40)
	var t_espera: float = maxf(0.0, duracion_total - t_entrada - t_salida)

	_actualizar_disolucion_splash(1.0)
	_tween_splash = create_tween()
	# 1. Entrada: materialización de 1.0 a 0.0 en los primeros cuadros
	_tween_splash.tween_method(_actualizar_disolucion_splash, 1.0, 0.0, t_entrada).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 2. Mantiene visibilidad completa en el pico del impacto
	if t_espera > 0.0:
		_tween_splash.tween_interval(t_espera)
	# 3. Salida: desintegración de 0.0 a 1.0 mientras caen los últimos cuadros (sin congelar ningún frame)
	_tween_splash.tween_method(_actualizar_disolucion_splash, 0.0, 1.0, t_salida).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 4. Al completar, se libera inmediatamente (ejecución única)
	if not reproduccion_en_bucle:
		_tween_splash.tween_callback(queue_free)


func _on_impacto_terminado() -> void:
	if not reproduccion_en_bucle and not Engine.is_editor_hint():
		queue_free()


## Reproduce el impacto con su sonido de chapoteo posicionado en la rompiente.
func disparar_impacto(posicion_impacto: Vector3, en_bucle: bool = false) -> void:
	super.disparar_impacto(posicion_impacto, en_bucle)
	if Engine.is_editor_hint():
		return
	_actualizar_textura_shader()
	if disolucion_celeste and is_inside_tree():
		_iniciar_ciclo_disolucion()
	if get_tree() == null:
		return
	AudioManager.play_sfx_3d("splash_agua", global_position)
