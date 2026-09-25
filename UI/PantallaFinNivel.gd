class_name PantallaFinNivel
extends CanvasLayer

## Pantalla y transición cinemática de finalización de nivel.
## Utiliza el shader modular (res://shader/transition.gdshader) configurado con un barrido
## de derecha a izquierda y textura de patrón semitono circular (circle_02.tres).
## Al cubrir la pantalla, despliega el texto localizado de nivel completado y el botón Continuar.

# === SIGNALS ===
signal transicion_completada
signal continuar_presionado

# === CONSTANTES ===
const RUTA_SHADER_TRANSICION: String = "res://shader/transition.gdshader"
const RUTA_SHAPE_TEXTURE: String = "res://assets/BinbunVFX/shared/texture/gradient/circle/circle_02.tres"
const TEXTO_DEFECTO_TITULO: String = "¡NIVEL 1 COMPLETADO!"
const TEXTO_DEFECTO_BOTON: String = "Continuar"
const CLAVE_TRADUCCION_TITULO: String = "NIVEL_1_COMPLETADO"
const CLAVE_TRADUCCION_BOTON: String = "BOTON_CONTINUAR"
const CAPA_CANVAS_DEFECTO: int = 210
const RESOLUCION_BASE: Vector2 = Vector2(1920.0, 1080.0)

# Colores y estilo
const COLOR_BORDE_BOTON: Color = Color(0.85, 0.65, 0.2, 1.0)
const COLOR_FONDO_BOTON_NORMAL: Color = Color(0.12, 0.08, 0.05, 0.95)
const COLOR_FONDO_BOTON_HOVER: Color = Color(0.2, 0.14, 0.08, 0.95)
const COLOR_FONDO_BOTON_PRESSED: Color = Color(0.08, 0.05, 0.02, 0.95)
const COLOR_TEXTO_BOTON: Color = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_TEXTO_BOTON_HOVER: Color = Color(1.0, 0.95, 0.6, 1.0)

# === EXPORTS ===
@export_category("Configuración de Transición")
@export var duracion_transicion: float = 1.4
@export var duracion_fade_ui: float = 0.4
@export var ancho_transicion_shader: float = 0.675
@export var tiling_shape_shader: float = 36.47
@export var color_base_transicion: Color = Color.BLACK

@export_category("Textos y Destino")
@export var clave_traduccion_titulo: String = CLAVE_TRADUCCION_TITULO
@export var clave_traduccion_boton: String = CLAVE_TRADUCCION_BOTON
@export var escena_siguiente: String = "res://Levels/Player_Interior.tscn"

@export_category("Silencio Final")
## Al cubrir toda la pantalla: sin enemigos ni combate sonando (música, SFX y loops).
@export var detener_audio_al_cubrir: bool = true
## La música del nivel sigue sonando bajo la cortinilla negra.
@export var mantener_musica_al_cubrir: bool = true
## Congela el mundo para que ningún loop re-arranque (se reanuda en Continuar).
@export var pausar_mundo_al_cubrir: bool = true

# === VARIABLES PÚBLICAS Y PRIVADAS ===
var on_continuar_callback: Callable = Callable()

var _rect_transicion: ColorRect = null
var _rect_fondo_negro: ColorRect = null
var _material_transicion: ShaderMaterial = null
var _gradiente_lineal: GradientTexture2D = null
var _shape_textura: Texture2D = null

var _contenedor_ui: Control = null
var _centro_victoria: CenterContainer = null
var _vbox_centro: VBoxContainer = null
var _label_titulo: Label = null
var _btn_continuar: Button = null

var _tween_transicion: Tween = null
var _tween_ui: Tween = null
var _factor_actual: float = 0.0
var _transicion_en_curso: bool = false
var _ui_construida: bool = false


# === FUNCIONES BUILT-IN ===
func _init() -> void:
	layer = CAPA_CANVAS_DEFECTO
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if not _ui_construida:
		_construir_jerarquia()

	_actualizar_resolucion()
	var vp := get_viewport()
	if is_instance_valid(vp) and not vp.size_changed.is_connected(_actualizar_resolucion):
		vp.size_changed.connect(_actualizar_resolucion)


func _exit_tree() -> void:
	var vp := get_viewport()
	if is_instance_valid(vp) and vp.size_changed.is_connected(_actualizar_resolucion):
		vp.size_changed.disconnect(_actualizar_resolucion)


# === FUNCIONES PÚBLICAS ===
## Inicia el barrido de transición de derecha a izquierda cubriendo la pantalla.
func iniciar_transicion(on_fin: Callable = Callable()) -> void:
	if _transicion_en_curso:
		return
	_transicion_en_curso = true

	if not _ui_construida:
		_construir_jerarquia()

	if on_fin.is_valid():
		on_continuar_callback = on_fin

	_rect_transicion.mouse_filter = Control.MOUSE_FILTER_STOP
	establecer_factor(0.0)

	if is_instance_valid(_tween_transicion) and _tween_transicion.is_running():
		_tween_transicion.kill()

	_tween_transicion = create_tween()
	_tween_transicion.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_transicion.tween_method(
		establecer_factor,
		0.0,
		1.0,
		maxf(duracion_transicion, 0.05)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween_transicion.finished.connect(_al_terminar_transicion)


## Retorna el progreso actual del factor de transición (0.0 a 1.0).
func obtener_factor() -> float:
	return _factor_actual


## Establece el factor de transición actualizándolo en el ShaderMaterial.
func establecer_factor(valor: float) -> void:
	_factor_actual = clampf(valor, 0.0, 1.0)
	if is_instance_valid(_material_transicion):
		_material_transicion.set_shader_parameter("factor", _factor_actual)
	if is_instance_valid(_rect_fondo_negro):
		if _factor_actual >= 0.7:
			_rect_fondo_negro.modulate.a = clampf((_factor_actual - 0.7) / 0.3, 0.0, 1.0)
		else:
			_rect_fondo_negro.modulate.a = 0.0


## Retorna la referencia al Label del título para inspección o pruebas.
func obtener_label_titulo() -> Label:
	return _label_titulo


## Retorna la referencia al Botón de continuar para inspección o pruebas.
func obtener_boton_continuar() -> Button:
	return _btn_continuar


## Retorna si la transición está en curso o terminada.
func esta_transicion_activa() -> bool:
	return _transicion_en_curso


# === FUNCIONES PRIVADAS ===
## Construye de forma programática el ColorRect con el shader de transición y el panel de victoria.
func _construir_jerarquia() -> void:
	if _ui_construida:
		return
	_ui_construida = true

	# 1. ColorRect que cubre toda la pantalla con el shader de transición
	_rect_transicion = ColorRect.new()
	_rect_transicion.name = "RectTransicion"
	_rect_transicion.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect_transicion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect_transicion.color = Color.WHITE

	_material_transicion = _crear_material_transicion()
	_rect_transicion.material = _material_transicion
	add_child(_rect_transicion)

	# 1b. Fondo negro sólido que asegura opacidad absoluta (negro total) al consolidarse la transición
	_rect_fondo_negro = ColorRect.new()
	_rect_fondo_negro.name = "FondoNegroSolido"
	_rect_fondo_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect_fondo_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect_fondo_negro.color = Color.BLACK
	_rect_fondo_negro.modulate.a = 0.0
	add_child(_rect_fondo_negro)

	# 2. Contenedor UI para textos y botón (inicialmente oculto / modulación 0)
	_contenedor_ui = Control.new()
	_contenedor_ui.name = "ContenedorVictoria"
	_contenedor_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contenedor_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenedor_ui.modulate.a = 0.0
	add_child(_contenedor_ui)

	# 3. CenterContainer a pantalla completa que centra de verdad el VBox
	# (PRESET_CENTER solo centra anclas: el contenido quedaba desplazado).
	_centro_victoria = CenterContainer.new()
	_centro_victoria.name = "CentroVictoria"
	_centro_victoria.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centro_victoria.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenedor_ui.add_child(_centro_victoria)

	# 4. VBoxContainer central (título centrado + botón Continuar debajo)
	_vbox_centro = VBoxContainer.new()
	_vbox_centro.name = "VBoxCentro"
	_vbox_centro.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox_centro.add_theme_constant_override("separation", 32)
	_centro_victoria.add_child(_vbox_centro)

	# 5. Label de título centrado
	_label_titulo = Label.new()
	_label_titulo.name = "LabelTitulo"
	_label_titulo.text = _obtener_texto_titulo()
	_label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var settings := LabelSettings.new()
	settings.font_size = 64
	settings.font_color = Color.WHITE
	settings.outline_size = 12
	settings.outline_color = Color.BLACK
	_label_titulo.label_settings = settings
	_vbox_centro.add_child(_label_titulo)

	# 6. Botón de continuar centrado debajo del título (oro / oscuro)
	_btn_continuar = Button.new()
	_btn_continuar.name = "BotonContinuar"
	_btn_continuar.text = _obtener_texto_boton()
	_btn_continuar.add_theme_font_size_override("font_size", 24)
	_btn_continuar.custom_minimum_size = Vector2(200.0, 54.0)
	_btn_continuar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_continuar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var estilo_base := StyleBoxFlat.new()
	estilo_base.bg_color = COLOR_FONDO_BOTON_NORMAL
	estilo_base.border_color = COLOR_BORDE_BOTON
	estilo_base.set_border_width_all(2)
	estilo_base.set_corner_radius_all(6)
	estilo_base.set_content_margin_all(12)
	_btn_continuar.add_theme_stylebox_override("normal", estilo_base)

	var estilo_hover := estilo_base.duplicate() as StyleBoxFlat
	estilo_hover.bg_color = COLOR_FONDO_BOTON_HOVER
	estilo_hover.border_color = Color(1.0, 0.85, 0.35, 1.0)
	_btn_continuar.add_theme_stylebox_override("hover", estilo_hover)

	var estilo_pressed := estilo_base.duplicate() as StyleBoxFlat
	estilo_pressed.bg_color = COLOR_FONDO_BOTON_PRESSED
	_btn_continuar.add_theme_stylebox_override("pressed", estilo_pressed)

	var estilo_focus := StyleBoxEmpty.new()
	_btn_continuar.add_theme_stylebox_override("focus", estilo_focus)

	_btn_continuar.add_theme_color_override("font_color", COLOR_TEXTO_BOTON)
	_btn_continuar.add_theme_color_override("font_hover_color", COLOR_TEXTO_BOTON_HOVER)
	_btn_continuar.add_theme_color_override("font_pressed_color", Color(0.85, 0.7, 0.2, 1.0))

	_btn_continuar.pressed.connect(_al_presionar_continuar)
	_vbox_centro.add_child(_btn_continuar)


## Instancia y parametriza el ShaderMaterial de transición modular.
func _crear_material_transicion() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := load(RUTA_SHADER_TRANSICION) as Shader
	if shader != null:
		mat.shader = shader

	_gradiente_lineal = _crear_gradiente_der_a_izq()
	_shape_textura = load(RUTA_SHAPE_TEXTURE) as Texture2D

	mat.set_shader_parameter("base_color", color_base_transicion)
	mat.set_shader_parameter("factor", 0.0)
	mat.set_shader_parameter("width", ancho_transicion_shader)
	mat.set_shader_parameter("gradient_texture", _gradiente_lineal)
	mat.set_shader_parameter("gradient_fixed", true)
	mat.set_shader_parameter("shape_texture", _shape_textura)
	mat.set_shader_parameter("shape_tiling", tiling_shape_shader)
	mat.set_shader_parameter("shape_rotation", 0.0)
	mat.set_shader_parameter("shape_scroll", Vector2.ZERO)
	mat.set_shader_parameter("shape_feathering", 0.0)
	mat.set_shader_parameter("shape_treshold", 1.0)
	mat.set_shader_parameter("node_resolution", RESOLUCION_BASE)

	return mat


## Crea el gradiente lineal de derecha a izquierda:
## fill_from = (1.0, 0.5) [negro: el barrido inicia a la derecha]
## fill_to   = (0.0, 0.5) [blanco: el barrido concluye a la izquierda]
func _crear_gradiente_der_a_izq() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color.BLACK, Color.WHITE])
	g.offsets = PackedFloat32Array([0.0, 1.0])

	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 512
	t.height = 512
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(1.0, 0.5)
	t.fill_to = Vector2(0.0, 0.5)
	return t


## Mantiene node_resolution del shader sincronizado con el viewport.
func _actualizar_resolucion() -> void:
	if not is_instance_valid(_material_transicion):
		return
	var res := RESOLUCION_BASE
	var vp := get_viewport()
	if is_instance_valid(vp):
		var vp_rect := vp.get_visible_rect()
		if vp_rect.size.x > 0.0 and vp_rect.size.y > 0.0:
			res = vp_rect.size
	_material_transicion.set_shader_parameter("node_resolution", res)


## Retorna el texto del título considerando el sistema de traducción y fallback.
func _obtener_texto_titulo() -> String:
	var texto_tr := tr(clave_traduccion_titulo)
	if texto_tr != "" and texto_tr != clave_traduccion_titulo:
		return texto_tr.to_upper()
	return TEXTO_DEFECTO_TITULO


## Retorna el texto del botón considerando el sistema de traducción y fallback.
func _obtener_texto_boton() -> String:
	var texto_tr := tr(clave_traduccion_boton)
	if texto_tr != "" and texto_tr != clave_traduccion_boton:
		return texto_tr
	return TEXTO_DEFECTO_BOTON


## Callback al completarse el barrido completo de la pantalla.
func _al_terminar_transicion() -> void:
	establecer_factor(1.0)
	if is_instance_valid(_rect_fondo_negro):
		_rect_fondo_negro.modulate.a = 1.0
		_rect_fondo_negro.visible = true

	# Ocultar HUD de gameplay para garantizar pantalla en negro total sin interferencias
	if get_tree() != null:
		get_tree().call_group("ui_vida_protagonista", "hide")
		get_tree().call_group("hud", "hide")

	_aplicar_silencio_final()

	transicion_completada.emit()

	if is_instance_valid(_contenedor_ui):
		_contenedor_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		if is_instance_valid(_tween_ui) and _tween_ui.is_running():
			_tween_ui.kill()
		_tween_ui = create_tween()
		_tween_ui.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween_ui.tween_property(_contenedor_ui, "modulate:a", 1.0, duracion_fade_ui)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween_ui.finished.connect(func() -> void:
			if is_instance_valid(_btn_continuar) and not _btn_continuar.disabled:
				_btn_continuar.grab_focus()
		)


## Silencio total al cubrir la pantalla: SFX y loops persistentes
## (globo, canoa, tensados) + mundo pausado para que nada re-arranque.
## La música del nivel sigue sonando.
func _aplicar_silencio_final() -> void:
	if detener_audio_al_cubrir:
		AudioManager.stop_all(not mantener_musica_al_cubrir)
		_detener_reproductores_en_arbol()
	if pausar_mundo_al_cubrir and get_tree() != null:
		get_tree().paused = true


## Detiene todo AudioStreamPlayer en reproducción (atrapa loops fuera del
## grupo pausable_audio), salvo el reproductor de música si debe continuar.
## Los SFX de UI posteriores nacen nuevos: no afecta.
func _detener_reproductores_en_arbol() -> void:
	var arbol := get_tree()
	if arbol == null or arbol.root == null:
		return
	var musica: AudioStreamPlayer = null
	if mantener_musica_al_cubrir:
		musica = AudioManager.get_music_player()
	for nodo in arbol.root.find_children("*", "AudioStreamPlayer", true, false):
		var p := nodo as AudioStreamPlayer
		if p and p.playing and p != musica:
			p.stop()
	for nodo in arbol.root.find_children("*", "AudioStreamPlayer3D", true, false):
		var p3 := nodo as AudioStreamPlayer3D
		if p3 and p3.playing:
			p3.stop()


## Callback al hacer click en el botón Continuar.
func _al_presionar_continuar() -> void:
	if not is_instance_valid(_btn_continuar) or _btn_continuar.disabled:
		return
	if get_tree() != null:
		get_tree().paused = false
	_btn_continuar.disabled = true
	continuar_presionado.emit()

	if on_continuar_callback.is_valid():
		on_continuar_callback.call()
		return

	if escena_siguiente != "" and ResourceLoader.exists(escena_siguiente):
		if has_node("/root/SceneManager"):
			var scene_mgr = get_node("/root/SceneManager")
			if scene_mgr.has_method("change_scene"):
				scene_mgr.call("change_scene", escena_siguiente)
				return
		get_tree().change_scene_to_file(escena_siguiente)
