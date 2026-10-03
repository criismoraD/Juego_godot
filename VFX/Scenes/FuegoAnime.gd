@tool
class_name FuegoAnime
extends Sprite3D

## Efecto de fuego estilo anime (2.5D): llama de dos capas con ruido,
## normales y distorsión + luz cálida parpadeante, todo configurable
## desde el inspector (color, tamaño, luz, velocidad, forma y texturas).
## Sin texturas asignadas las genera por procedimiento (ruido, silueta
## de llama y máscara); acepta las del repo original vía exports.

# === CONSTANTES ===
const SHADER_FUEGO_ANIME: Shader = preload("res://VFX/Shaders/fuego_anime.gdshader")
const TAMANO_RUIDO: int = 256
const TAMANO_LLAMA: Vector2i = Vector2i(128, 256)
const TAMANO_MASCARA: Vector2i = Vector2i(64, 256)
const BORDE_SUAVIZADO_RUIDO: int = 16
const FPS_MINIMO: float = 1.0
const PIXEL_SIZE_DEFECTO: float = 0.0055
const OFFSET_BASE_Y_DEFECTO: float = 120.0
const ALTURA_LUZ: float = 0.45
const ATENUACION_LUZ: float = 1.35

# === EXPORTS: COLORES DE LLAMA ===
@export_category("Llama (Colores Anime)")
@export var color_exterior_a: Color = Color(1.0, 0.0, 0.0, 1.0):
	set(v):
		color_exterior_a = v
		_set_param("color_exterior_a", v)
@export var color_exterior_b: Color = Color(1.0, 0.25, 0.0, 1.0):
	set(v):
		color_exterior_b = v
		_set_param("color_exterior_b", v)
@export var color_interior_a: Color = Color(1.0, 1.0, 0.0, 1.0):
	set(v):
		color_interior_a = v
		_set_param("color_interior_a", v)
@export var color_interior_b: Color = Color(1.0, 1.0, 0.5, 1.0):
	set(v):
		color_interior_b = v
		_set_param("color_interior_b", v)

# === EXPORTS: MOVIMIENTO ===
@export_category("Movimiento")
@export var velocidad: float = 0.5:
	set(v):
		velocidad = v
		_set_param("velocidad", v)
@export var usar_fps_personalizado: bool = true:
	set(v):
		usar_fps_personalizado = v
		_set_param("usar_fps_personalizado", v)
@export_range(1.0, 60.0, 1.0) var fps_efecto: float = 12.0:
	set(v):
		fps_efecto = maxf(FPS_MINIMO, v)
		_set_param("fps_efecto", fps_efecto)

# === EXPORTS: FORMA (RUIDO / DISTORSIÓN) ===
@export_category("Forma (Ruido y Distorsión)")
@export var escala_ruido_ext: float = 0.4:
	set(v):
		escala_ruido_ext = v
		_set_param("escala_ruido_ext", v)
@export var escala_ruido_int: float = 0.2:
	set(v):
		escala_ruido_int = v
		_set_param("escala_ruido_int", v)
@export var escala_normal_ext: float = 1.5:
	set(v):
		escala_normal_ext = v
		_set_param("escala_normal_ext", v)
@export var escala_normal_int: float = 2.0:
	set(v):
		escala_normal_int = v
		_set_param("escala_normal_int", v)
@export var distorsion_ext: float = 0.10:
	set(v):
		distorsion_ext = v
		_set_param("distorsion_ext", v)
@export var distorsion_int: float = 0.08:
	set(v):
		distorsion_int = v
		_set_param("distorsion_int", v)
@export var usar_mascara_exclusion: bool = true:
	set(v):
		usar_mascara_exclusion = v
		_set_param("usar_mascara_exclusion", v)
@export_range(0.0, 1.0, 0.01) var fuerza_mascara: float = 0.6:
	set(v):
		fuerza_mascara = clampf(v, 0.0, 1.0)
		_set_param("fuerza_mascara", fuerza_mascara)

# === EXPORTS: PRESENTACIÓN ===
@export_category("Presentación")
@export var escala: float = 1.0:
	set(v):
		escala = maxf(0.05, v)
		_aplicar_escala()
@export var intensidad_brillo: float = 1.0:
	set(v):
		intensidad_brillo = v
		_set_param("intensidad_brillo", v)
@export_range(0.0, 1.0, 0.01) var opacidad: float = 1.0:
	set(v):
		opacidad = clampf(v, 0.0, 1.0)
		_set_param("opacidad", opacidad)
@export var anclaje_base_y: float = OFFSET_BASE_Y_DEFECTO:
	set(v):
		anclaje_base_y = v
		offset = Vector2(0.0, anclaje_base_y)

# === EXPORTS: TEXTURAS (NULO = PROCEDURAL) ===
@export_category("Texturas (Vacío = Procedural)")
@export var textura_llama: Texture2D:
	set(v):
		textura_llama = v
		_aplicar_texturas()
@export var textura_ruido: Texture2D:
	set(v):
		textura_ruido = v
		_aplicar_texturas()
@export var textura_normal: Texture2D:
	set(v):
		textura_normal = v
		_set_param_textura("normal_tex", textura_normal, _tex_normal_gen)
@export var textura_mascara: Texture2D:
	set(v):
		textura_mascara = v
		_set_param_textura("mask_tex", textura_mascara, _tex_mascara_gen)
@export var semilla_ruido: int = 1234
@export var regenerar_texturas: bool = false:
	set(v):
		if v and is_node_ready():
			_generar_texturas_procedurales()
			_aplicar_texturas()
		regenerar_texturas = false

# === EXPORTS: LUZ CÁLIDA ===
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
@export var energia_luz_base: float = 1.2:
	set(v):
		energia_luz_base = v
		if is_instance_valid(luz_fuego):
			luz_fuego.light_energy = energia_luz_base
@export var radio_luz: float = 3.5:
	set(v):
		radio_luz = v
		if is_instance_valid(luz_fuego):
			luz_fuego.omni_range = radio_luz
@export var parpadeo_luz: bool = true
@export var variacion_flicker: float = 0.25
@export var frecuencia_flicker: float = 8.0
@export var respiracion_llama: bool = true
@export var intensidad_respiracion: float = 0.04

# === VARIABLES PRIVADAS ===
var _mat: ShaderMaterial = null
var _tiempo_flicker: float = 0.0
var _tiempo_respiracion: float = 0.0
var _tex_ruido_gen: Texture2D = null
var _tex_normal_gen: Texture2D = null
var _tex_llama_gen: Texture2D = null
var _tex_mascara_gen: Texture2D = null
var _notifier_pantalla: VisibleOnScreenNotifier3D = null

# === ONREADY ===
@onready var luz_fuego: OmniLight3D = get_node_or_null("LuzFuego") as OmniLight3D


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_configurar_propiedades_visuales()
	_generar_texturas_procedurales()
	_crear_material()
	_aplicar_todos_los_parametros()
	_aplicar_texturas()
	_aplicar_escala()
	_inicializar_luz()
	if not Engine.is_editor_hint():
		_configurar_notifier_pantalla()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_actualizar_luz_flicker(delta)
	_actualizar_respiracion()


# === FUNCIONES PÚBLICAS ===
func set_fuego_activo(activo: bool) -> void:
	visible = activo
	luz_activa = activo
	set_process(activo)


func obtener_luz() -> OmniLight3D:
	if not is_instance_valid(luz_fuego):
		luz_fuego = get_node_or_null("LuzFuego") as OmniLight3D
	return luz_fuego


# === FUNCIONES PRIVADAS: SETUP ===
func _configurar_propiedades_visuales() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	render_priority = 2
	pixel_size = PIXEL_SIZE_DEFECTO
	offset = Vector2(0.0, anclaje_base_y)


func _crear_material() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_FUEGO_ANIME
	material_override = _mat


func _aplicar_todos_los_parametros() -> void:
	_set_param("color_exterior_a", color_exterior_a)
	_set_param("color_exterior_b", color_exterior_b)
	_set_param("color_interior_a", color_interior_a)
	_set_param("color_interior_b", color_interior_b)
	_set_param("velocidad", velocidad)
	_set_param("usar_fps_personalizado", usar_fps_personalizado)
	_set_param("fps_efecto", fps_efecto)
	_set_param("escala_ruido_ext", escala_ruido_ext)
	_set_param("escala_ruido_int", escala_ruido_int)
	_set_param("escala_normal_ext", escala_normal_ext)
	_set_param("escala_normal_int", escala_normal_int)
	_set_param("distorsion_ext", distorsion_ext)
	_set_param("distorsion_int", distorsion_int)
	_set_param("usar_mascara_exclusion", usar_mascara_exclusion)
	_set_param("fuerza_mascara", fuerza_mascara)
	_set_param("intensidad_brillo", intensidad_brillo)
	_set_param("opacidad", opacidad)


func _aplicar_texturas() -> void:
	_set_param_textura("draw_tex", textura_llama, _tex_llama_gen)
	_set_param_textura("noise_tex", textura_ruido, _tex_ruido_gen)
	_set_param_textura("normal_tex", textura_normal, _tex_normal_gen)
	_set_param_textura("mask_tex", textura_mascara, _tex_mascara_gen)


func _aplicar_escala() -> void:
	scale = Vector3(escala, escala, escala)


func _inicializar_luz() -> void:
	if luz_fuego == null:
		luz_fuego = get_node_or_null("LuzFuego") as OmniLight3D
	if luz_fuego == null:
		luz_fuego = OmniLight3D.new()
		luz_fuego.name = "LuzFuego"
		add_child(luz_fuego)
	luz_fuego.position = Vector3(0.0, ALTURA_LUZ, 0.0)
	luz_fuego.light_color = color_luz
	luz_fuego.light_energy = energia_luz_base
	luz_fuego.omni_range = radio_luz
	luz_fuego.omni_attenuation = ATENUACION_LUZ
	luz_fuego.shadow_enabled = false
	luz_fuego.visible = luz_activa


func _set_param(nombre: StringName, valor: Variant) -> void:
	if is_instance_valid(_mat):
		_mat.set_shader_parameter(nombre, valor)


func _set_param_textura(nombre: StringName, override_tex: Texture2D, fallback_tex: Texture2D) -> void:
	if not is_instance_valid(_mat):
		return
	if override_tex != null:
		_mat.set_shader_parameter(nombre, override_tex)
	elif fallback_tex != null:
		_mat.set_shader_parameter(nombre, fallback_tex)


# === FUNCIONES PRIVADAS: TEXTURAS PROCEDURALES ===
func _generar_texturas_procedurales() -> void:
	_tex_ruido_gen = _generar_textura_ruido()
	_tex_normal_gen = _generar_textura_normal(_tex_ruido_gen)
	_tex_llama_gen = _generar_textura_llama()
	_tex_mascara_gen = _generar_textura_mascara()
	if texture == null:
		texture = _generar_textura_blanca()


func _generar_textura_blanca() -> Texture2D:
	var img := Image.create(TAMANO_LLAMA.x, TAMANO_LLAMA.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _generar_textura_ruido() -> Texture2D:
	var ruido := FastNoiseLite.new()
	ruido.seed = semilla_ruido
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.fractal_octaves = 4
	ruido.frequency = 0.03
	var img := Image.create(TAMANO_RUIDO, TAMANO_RUIDO, false, Image.FORMAT_RGBA8)
	for y in range(TAMANO_RUIDO):
		for x in range(TAMANO_RUIDO):
			var v: float = clampf(ruido.get_noise_2d(float(x), float(y)) * 0.5 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_suavizar_bordes_envolventes(img)
	return ImageTexture.create_from_image(img)


func _generar_textura_normal(_base_ruido: Texture2D) -> Texture2D:
	var ruido_b := FastNoiseLite.new()
	ruido_b.seed = semilla_ruido + 999
	ruido_b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_b.fractal_octaves = 4
	ruido_b.frequency = 0.03
	var ruido_a := FastNoiseLite.new()
	ruido_a.seed = semilla_ruido
	ruido_a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_a.fractal_octaves = 4
	ruido_a.frequency = 0.03
	var img := Image.create(TAMANO_RUIDO, TAMANO_RUIDO, false, Image.FORMAT_RGBA8)
	for y in range(TAMANO_RUIDO):
		for x in range(TAMANO_RUIDO):
			var r: float = clampf(ruido_a.get_noise_2d(float(x), float(y)) * 0.5 + 0.5, 0.0, 1.0)
			var g: float = clampf(ruido_b.get_noise_2d(float(y), float(x)) * 0.5 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(r, g, 0.5, 1.0))
	_suavizar_bordes_envolventes(img)
	return ImageTexture.create_from_image(img)


func _generar_textura_llama() -> Texture2D:
	var w: int = TAMANO_LLAMA.x
	var h: int = TAMANO_LLAMA.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var y01: float = 1.0 - float(y) / float(maxi(h - 1, 1))  # 0 abajo (base), 1 arriba (punta)
		var cuerpo: float = sin(PI * clampf(pow(y01, 0.8), 0.0, 1.0))
		var medio_ancho: float = 0.05 + 0.28 * cuerpo
		var centro_x: float = 0.5 + 0.03 * sin(y01 * 5.0)
		for x in range(w):
			var d: float = absf(float(x) / float(maxi(w - 1, 1)) - centro_x) / maxf(medio_ancho, 0.02)
			var fuera: float = clampf((1.0 - d) * 2.0, 0.0, 1.0)
			var di: float = absf(float(x) / float(maxi(w - 1, 1)) - centro_x) / maxf(medio_ancho * 0.55, 0.02)
			var dentro: float = clampf((1.0 - di) * 1.5, 0.0, 1.0) * fuera
			img.set_pixel(x, y, Color(fuera, dentro, 0.0, fuera))
	return ImageTexture.create_from_image(img)


func _generar_textura_mascara() -> Texture2D:
	var w: int = TAMANO_MASCARA.x
	var h: int = TAMANO_MASCARA.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var y01: float = 1.0 - float(y) / float(maxi(h - 1, 1))
		var m: float = clampf(1.0 - y01 * 1.2, 0.0, 1.0)  # base estable, punta libre
		for x in range(w):
			img.set_pixel(x, y, Color(m, m, m, 1.0))
	return ImageTexture.create_from_image(img)


## Funde los bordes opuestos para que el ruido repita sin costura visible.
func _suavizar_bordes_envolventes(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var n: int = mini(BORDE_SUAVIZADO_RUIDO, mini(w, h) / 2)
	for y in range(h):
		for i in range(n):
			var f: float = float(i) / float(maxi(n, 1))
			var c_izq: Color = img.get_pixel(i, y)
			var c_der: Color = img.get_pixel(w - n + i, y)
			img.set_pixel(i, y, c_izq.lerp(c_der, (1.0 - f) * 0.5))
			img.set_pixel(w - 1 - i, y, c_der.lerp(c_izq, (1.0 - f) * 0.5))
	for x in range(w):
		for i in range(n):
			var f: float = float(i) / float(maxi(n, 1))
			var c_arr: Color = img.get_pixel(x, i)
			var c_aba: Color = img.get_pixel(x, h - n + i)
			img.set_pixel(x, i, c_arr.lerp(c_aba, (1.0 - f) * 0.5))
			img.set_pixel(x, h - 1 - i, c_aba.lerp(c_arr, (1.0 - f) * 0.5))


# === FUNCIONES PRIVADAS: RUNTIME ===
func _actualizar_luz_flicker(delta: float) -> void:
	if not is_instance_valid(luz_fuego) or not luz_activa or not parpadeo_luz:
		return
	_tiempo_flicker += delta * frecuencia_flicker
	var onda: float = sin(_tiempo_flicker) * 0.5 + sin(_tiempo_flicker * 2.37) * 0.3 + sin(_tiempo_flicker * 0.43) * 0.2
	luz_fuego.light_energy = energia_luz_base + (onda * variacion_flicker)


func _actualizar_respiracion() -> void:
	if not respiracion_llama:
		return
	_tiempo_respiracion += get_process_delta_time()
	var factor_y: float = 1.0 + sin(_tiempo_respiracion * 6.0) * intensidad_respiracion
	var factor_x: float = 1.0 + cos(_tiempo_respiracion * 5.0) * (intensidad_respiracion * 0.5)
	scale = Vector3(escala * factor_x, escala * factor_y, escala)


func _configurar_notifier_pantalla() -> void:
	_notifier_pantalla = VisibleOnScreenNotifier3D.new()
	_notifier_pantalla.name = "NotifierPantalla"
	var radio_total: float = maxf(radio_luz, 1.5)
	_notifier_pantalla.aabb = AABB(
		Vector3(-radio_total, -0.5, -radio_total),
		Vector3(radio_total * 2.0, radio_total * 2.0, radio_total * 2.0)
	)
	add_child(_notifier_pantalla)
	_notifier_pantalla.screen_entered.connect(_al_entrar_pantalla)
	_notifier_pantalla.screen_exited.connect(_al_salir_pantalla)


func _al_entrar_pantalla() -> void:
	set_process(true)
	if is_instance_valid(luz_fuego):
		luz_fuego.visible = luz_activa


func _al_salir_pantalla() -> void:
	set_process(false)
	if is_instance_valid(luz_fuego):
		luz_fuego.visible = false
