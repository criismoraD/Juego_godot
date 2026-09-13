class_name DialogoComic
extends CanvasLayer
signal continuado
const SHADER_ERYN_TITS: Shader = preload("res://System/Shaders/eryn_tits_jiggle.gdshader")

@export var velocidad_texto: float = 0.02
@export var chars_por_sonido: int = 4
@export var intervalo_min_sonido: float = 0.18
@export var audio_stream: AudioStream
@export var audio_volume_db: float = -18.0
@export var audio_pitch_scale: float = 1.0
@export var paginas_texto: PackedStringArray = PackedStringArray()
@export var paginas_imagenes: Array[Texture2D] = []
## Hablante por página ("eryn"/"perrena", en minúsculas; vacío = eryn).
## Solo tiene efecto con dos retratos (RetratoEryn + RetratoPerrena).
@export var paginas_hablante: PackedStringArray = PackedStringArray()
@export var nombre_perrena: String = "Perrena"

@export_group("Bamboleo ErynTits")
@export var bamboleo_activo: bool = true
@export_enum("Arriba_Abajo", "Derecha_Izquierda") var direccion_bamboleo: String = "Arriba_Abajo"
@export var bamboleo_amplitud: float = 0.038
@export var factor_lado_derecho: float = 1.8
var retrato_eryn: Node = null
var retrato_perrena: Node = null
var _modo_dual: bool = false
var _escala_eryn_base := Vector2.ONE
var _escala_perrena_base := Vector2.ONE
var _pos_eryn_base := Vector2.ZERO
var _pos_perrena_base := Vector2.ZERO
var _alto_eryn_px: float = 0.0
var _alto_perrena_px: float = 0.0
var _nombre_eryn: String = ""
var _nombre_perrena: String = ""
const COLOR_RETRATO_APAGADO := Color(0.45, 0.45, 0.45)
const ESCALA_RETRATO_APAGADO: float = 0.85
var _revelando: bool = false
var _indice_pagina: int = 0
var _audio_player: AudioStreamPlayer
var _timer_revelado: Timer
var _ultimo_audio_ms: int = 0
var _total_chars_pagina: int = 0
@export_group("Respiración Inicial Eryn")
@export var respiracion_activa: bool = true
@export var respiracion_amplitud: float = 0.025

@export_group("Respiración en Bucle (Idle)")
@export var bucle_respiracion_activo: bool = true:
	set(valor):
		bucle_respiracion_activo = valor
		if not bucle_respiracion_activo:
			_detener_bucle_respiracion()
		elif is_inside_tree():
			_iniciar_bucle_respiracion()
@export var bucle_amplitud_torso: float = 0.009
@export var bucle_amplitud_tits: float = 0.28
@export var bucle_duracion_ciclo: float = 3.2
var _tween_bucle: Tween = null
var _prota_nodo: Node2D = null
var _escala_prota_base := Vector2.ONE
var _pos_prota_base := Vector2.ZERO
var _alto_prota_px: float = 0.0
var _escala_tits_base := Vector2.ONE
var _pos_tits_base := Vector2.ZERO
var _tween_respiracion: Tween = null
var _ha_respirado_eryn: bool = false
var _nodo_eryn_tits: CanvasItem = null
var _material_eryn_tits: ShaderMaterial = null
var _tween_eryn_tits: Tween = null
@onready var dialogo_label: RichTextLabel = _obtener_dialogo_label()
@onready var boton_continuar: Button = _obtener_boton_continuar()
@onready var icono_retrato: TextureRect = _obtener_icono_retrato()


func _obtener_dialogo_label() -> RichTextLabel:
	var nodo := find_child("Dialogo", true, false)
	if nodo is RichTextLabel:
		return nodo

	nodo = get_node_or_null("Panel/HBox/Texto/Dialogo")
	if nodo is RichTextLabel:
		return nodo

	return null


func _obtener_boton_continuar() -> Button:
	var nodo := find_child("BotonContinuar", true, false)
	if nodo is Button:
		return nodo

	nodo = get_node_or_null("Panel/HBox/Texto/BotonContinuar")
	if nodo is Button:
		return nodo

	return null


func _obtener_icono_retrato() -> TextureRect:
	var nodo := find_child("Icono", true, false)
	if nodo is TextureRect:
		return nodo

	nodo = get_node_or_null("Panel/HBox/Icono")
	if nodo is TextureRect:
		return nodo

	return null


func _ready():
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)

	_timer_revelado = Timer.new()
	_timer_revelado.one_shot = false
	_timer_revelado.autostart = false
	_timer_revelado.timeout.connect(_on_reveal_timer_timeout)
	add_child(_timer_revelado)

	# Traducir los contenidos del diálogo
	_traducir_dialogos()

	if boton_continuar:
		boton_continuar.visible = false
		boton_continuar.focus_mode = Control.FOCUS_NONE
		boton_continuar.pressed.connect(_on_continue_pressed)

	if paginas_texto.size() > 0:
		_indice_pagina = 0
		_aplicar_pagina_actual()

	_preparar_dialogo_label()
	_actualizar_texto_boton()
	_preparar_eryn_tits()
	_preparar_nodos_respiracion()
	_inicializar_dual()

	var boton_saltar = find_child("BotonSaltar", true, false)
	if boton_saltar and boton_saltar is Button:
		boton_saltar.text = tr("BTN_SKIP")
		boton_saltar.focus_mode = Control.FOCUS_NONE
		
		# Estilos premium (oscuro con borde dorado)
		var estilo_saltar = StyleBoxFlat.new()
		estilo_saltar.bg_color = Color(0.12, 0.08, 0.05, 0.8)
		estilo_saltar.border_color = Color(0.85, 0.65, 0.2)
		estilo_saltar.set_border_width_all(2)
		estilo_saltar.set_corner_radius_all(6)
		estilo_saltar.set_content_margin_all(8)
		boton_saltar.add_theme_stylebox_override("normal", estilo_saltar)
		
		var estilo_hover = estilo_saltar.duplicate()
		estilo_hover.bg_color = Color(0.2, 0.14, 0.08, 0.9)
		boton_saltar.add_theme_stylebox_override("hover", estilo_hover)
		
		var estilo_pressed = estilo_saltar.duplicate()
		estilo_pressed.bg_color = Color(0.08, 0.05, 0.02, 0.9)
		boton_saltar.add_theme_stylebox_override("pressed", estilo_pressed)
		
		boton_saltar.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		boton_saltar.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.6))
		boton_saltar.add_theme_font_size_override("font_size", 16)
		
		boton_saltar.pressed.connect(
			func():
				emit_signal("continuado")
		)

	await get_tree().process_frame
	if not _modo_dual and not _ha_respirado_eryn:
		_ha_respirado_eryn = true
		if respiracion_activa:
			_reproducir_respiracion_eryn()
		elif bucle_respiracion_activo:
			_iniciar_bucle_respiracion()
	_revelar_texto()


func _preparar_dialogo_label() -> void:
	if not dialogo_label:
		return

	# Evita relayout por caracter durante el reveal para bajar carga de CPU.
	dialogo_label.fit_content = false
	dialogo_label.scroll_active = false


func _on_reveal_timer_timeout() -> void:
	if not _revelando or not dialogo_label:
		return

	var chars_actuales = dialogo_label.visible_characters
	if chars_actuales >= _total_chars_pagina:
		_terminar_revelado()
		return

	var nuevos_chars = min(chars_actuales + 1, _total_chars_pagina)
	dialogo_label.visible_characters = nuevos_chars

	if nuevos_chars > 0 and nuevos_chars % max(chars_por_sonido, 1) == 0 and audio_stream:
		var ahora_ms: int = Time.get_ticks_msec()
		if ahora_ms - _ultimo_audio_ms >= int(intervalo_min_sonido * 1000.0):
			_reproducir_audio()
			_ultimo_audio_ms = ahora_ms

	if nuevos_chars >= _total_chars_pagina:
		_terminar_revelado()


func _terminar_revelado() -> void:
	_revelando = false
	if _timer_revelado:
		_timer_revelado.stop()
	if dialogo_label:
		if _total_chars_pagina <= 0:
			_total_chars_pagina = dialogo_label.get_total_character_count()
		dialogo_label.visible_characters = _total_chars_pagina
	if boton_continuar:
		boton_continuar.visible = true


func _traducir_dialogos() -> void:
	var nodo_nombre = find_child("Nombre", true, false)
	if nodo_nombre and nodo_nombre is Label:
		nodo_nombre.text = tr(nodo_nombre.text)

	for i in range(paginas_texto.size()):
		paginas_texto[i] = tr(paginas_texto[i])


func _actualizar_texto_boton():
	if not boton_continuar:
		return

	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		boton_continuar.text = tr("BOTON_SIGUIENTE")
	else:
		boton_continuar.text = tr("BOTON_CONTINUAR")


func _aplicar_pagina_actual() -> void:
	if dialogo_label and paginas_texto.size() > 0 and _indice_pagina < paginas_texto.size():
		dialogo_label.text = paginas_texto[_indice_pagina]

	if (
		icono_retrato
		and _indice_pagina < paginas_imagenes.size()
		and paginas_imagenes[_indice_pagina]
	):
		icono_retrato.texture = paginas_imagenes[_indice_pagina]

	if _modo_dual:
		_actualizar_hablante()


## Duelo de retratos: el que no habla se encoge y oscurece. Solo si la
## escena trae RetratoEryn + RetratoPerrena (el intro no los tiene y queda
## exactamente igual que antes).
func _inicializar_dual() -> void:
	retrato_eryn = find_child("RetratoEryn", true, false)
	retrato_perrena = find_child("RetratoPerrena", true, false)
	_modo_dual = retrato_eryn != null and retrato_perrena != null
	if not _modo_dual:
		return
	_escala_eryn_base = _escala_nodo(retrato_eryn)
	_escala_perrena_base = _escala_nodo(retrato_perrena)
	_pos_eryn_base = _pos_nodo(retrato_eryn)
	_pos_perrena_base = _pos_nodo(retrato_perrena)
	_alto_eryn_px = _alto_retrato(retrato_eryn)
	_alto_perrena_px = _alto_retrato(retrato_perrena)
	var nodo_nombre = find_child("Nombre", true, false)
	if nodo_nombre and nodo_nombre is Label:
		_nombre_eryn = (nodo_nombre as Label).text
	_nombre_perrena = tr(nombre_perrena)
	_actualizar_hablante()


func _escala_nodo(nodo: Node) -> Vector2:
	if nodo is Node2D:
		return (nodo as Node2D).scale
	if nodo is Control:
		return (nodo as Control).scale
	return Vector2.ONE


func _pos_nodo(nodo: Node) -> Vector2:
	if nodo is Node2D:
		return (nodo as Node2D).position
	if nodo is Control:
		return (nodo as Control).position
	return Vector2.ZERO


## Alto en píxeles de la textura (para anclar el borde inferior al encoger).
func _alto_retrato(nodo: Node) -> float:
	if nodo is Sprite2D:
		var tex := (nodo as Sprite2D).texture as Texture2D
		if tex:
			return float(tex.get_height())
	if nodo is TextureRect:
		var tex2 := (nodo as TextureRect).texture as Texture2D
		if tex2:
			return float(tex2.get_height())
	return 0.0


func _hablante_actual() -> String:
	if _indice_pagina < paginas_hablante.size():
		var hab := String(paginas_hablante[_indice_pagina]).strip_edges().to_lower()
		if not hab.is_empty():
			return hab
	return "eryn"


func _actualizar_hablante() -> void:
	if not _modo_dual:
		return
	var es_eryn := _hablante_actual() != "perrena"
	if not es_eryn:
		_detener_bucle_respiracion()
		if _tween_respiracion and _tween_respiracion.is_valid():
			_tween_respiracion.kill()
			_aplicar_respiracion(0.0)

	_aplicar_foco(retrato_eryn, es_eryn, _escala_eryn_base, _pos_eryn_base, _alto_eryn_px)
	_aplicar_foco(retrato_perrena, not es_eryn, _escala_perrena_base, _pos_perrena_base, _alto_perrena_px)
	var nodo_nombre = find_child("Nombre", true, false)
	if nodo_nombre and nodo_nombre is Label:
		(nodo_nombre as Label).text = _nombre_eryn if es_eryn else _nombre_perrena

	if es_eryn:
		if not _ha_respirado_eryn:
			_ha_respirado_eryn = true
			if respiracion_activa:
				_reproducir_respiracion_eryn()
			elif bucle_respiracion_activo:
				_iniciar_bucle_respiracion()
		elif bucle_respiracion_activo and (_tween_bucle == null or not _tween_bucle.is_valid()):
			_iniciar_bucle_respiracion()


## El inactivo se encoge y oscurece, pero su borde inferior queda anclado
## al marco (se baja la mitad de lo que pierde de alto) para que no flote
## ni parezca recortado.
func _aplicar_foco(nodo: Node, activo: bool, base_esc: Vector2, base_pos: Vector2, alto_px: float) -> void:
	if nodo == null:
		return
	if nodo is CanvasItem:
		(nodo as CanvasItem).modulate = Color.WHITE if activo else COLOR_RETRATO_APAGADO
	var nueva_esc: Vector2 = base_esc if activo else base_esc * ESCALA_RETRATO_APAGADO
	if nodo is Node2D:
		(nodo as Node2D).scale = nueva_esc
		(nodo as Node2D).position = Vector2(
			base_pos.x, base_pos.y + alto_px * (base_esc.y - nueva_esc.y) * 0.5
		)
	elif nodo is Control:
		(nodo as Control).scale = nueva_esc

	if (nodo == retrato_eryn or nodo == _prota_nodo) and _nodo_eryn_tits and _nodo_eryn_tits is Node2D:
		var factor: float = 1.0 if activo else ESCALA_RETRATO_APAGADO
		var tits_2d := _nodo_eryn_tits as Node2D
		tits_2d.modulate = Color.WHITE if activo else COLOR_RETRATO_APAGADO
		tits_2d.scale = _escala_tits_base * factor
		var offset_rel: Vector2 = _pos_tits_base - base_pos
		var dy_anchor: float = alto_px * (base_esc.y - nueva_esc.y) * 0.5
		tits_2d.position = Vector2(
			base_pos.x + offset_rel.x * factor,
			base_pos.y + dy_anchor + offset_rel.y * factor
		)


func _revelar_texto():
	if _revelando or not dialogo_label:
		return

	_revelando = true
	_ultimo_audio_ms = 0
	dialogo_label.visible_characters = 0
	_total_chars_pagina = dialogo_label.get_total_character_count()

	if _total_chars_pagina > 0:
		if _timer_revelado:
			_timer_revelado.wait_time = max(velocidad_texto, 0.01)
			_timer_revelado.start()
	else:
		_terminar_revelado()


func _reproducir_audio():
	return


func _on_continue_pressed():
	if _revelando:
		return

	_detener_bucle_respiracion()
	_animar_bamboleo_eryntits()

	if paginas_texto.size() > 1 and _indice_pagina < paginas_texto.size() - 1:
		_indice_pagina += 1
		_aplicar_pagina_actual()
		_actualizar_texto_boton()
		if boton_continuar:
			boton_continuar.visible = false
		_revelar_texto()
		return

	emit_signal("continuado")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _revelando:
			_terminar_revelado()
		else:
			_on_continue_pressed()


func animar_bamboleo_eryntits() -> void:
	_animar_bamboleo_eryntits()


func _animar_bamboleo_eryntits() -> void:
	if not bamboleo_activo:
		return
	if _modo_dual and _hablante_actual() == "perrena":
		return

	if not _nodo_eryn_tits or not _material_eryn_tits:
		_preparar_eryn_tits()

	if not _material_eryn_tits:
		return

	if _tween_eryn_tits and _tween_eryn_tits.is_valid():
		_tween_eryn_tits.kill()

	_material_eryn_tits.set_shader_parameter("amplitud_uv", bamboleo_amplitud)
	_material_eryn_tits.set_shader_parameter("amplitud_y", bamboleo_amplitud)
	_material_eryn_tits.set_shader_parameter("factor_lado_derecho", factor_lado_derecho)

	_tween_eryn_tits = create_tween()
	_tween_eryn_tits.set_trans(Tween.TRANS_SINE)
	_tween_eryn_tits.set_ease(Tween.EASE_IN_OUT)

	if direccion_bamboleo == "Arriba_Abajo":
		_material_eryn_tits.set_shader_parameter("deformacion_x", 0.0)
		# Oscilación vertical elástica de arriba a abajo (caída por inercia y rebote ascendente amortiguado)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_y", 0.65, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_y", -0.46, 0.11)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_y", 0.32, 0.10)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_y", -0.18, 0.09)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_y", 0.09, 0.08)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_y", -0.03, 0.07)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_y", 0.0, 0.06)
	else:
		_material_eryn_tits.set_shader_parameter("deformacion_y", 0.0)
		# Oscilación armónica horizontal de derecha a izquierda
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_x", 0.65, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_x", -0.46, 0.11)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_x", 0.32, 0.10)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_x", -0.18, 0.09)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_x", 0.09, 0.08)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_x", -0.03, 0.07)
		_tween_eryn_tits.tween_property(_material_eryn_tits, "shader_parameter/deformacion_x", 0.0, 0.06)

	_tween_eryn_tits.tween_callback(_on_bamboleo_terminado)


func _preparar_eryn_tits() -> void:
	_nodo_eryn_tits = _obtener_eryn_tits()
	if not _nodo_eryn_tits:
		return
	_configurar_material_eryn_tits()


func _obtener_eryn_tits() -> CanvasItem:
	var posibles_nombres: PackedStringArray = [
		"Eryntits3",
		"ErynTits3",
		"eryntits3",
		"Eryntits_3",
		"Eryn_Tits_3",
		"Eryn_Tits3",
		"ErynTits",
		"eryntits",
		"Eryn_Tits",
		"Eryn_tits",
		"Eryntits"
	]
	for nombre in posibles_nombres:
		var nodo := find_child(nombre, true, false)
		if nodo is CanvasItem:
			return nodo as CanvasItem

	# Búsqueda flexible en toda la jerarquía de hijos
	for hijo in find_children("*", "CanvasItem", true, false):
		var n: String = hijo.name.to_lower()
		if "eryn" in n and "tit" in n:
			return hijo as CanvasItem
	return null


func _configurar_material_eryn_tits() -> void:
	if not _nodo_eryn_tits:
		return

	if _nodo_eryn_tits.material is ShaderMaterial and (_nodo_eryn_tits.material as ShaderMaterial).shader == SHADER_ERYN_TITS:
		_material_eryn_tits = _nodo_eryn_tits.material as ShaderMaterial
	else:
		_material_eryn_tits = ShaderMaterial.new()
		_material_eryn_tits.shader = SHADER_ERYN_TITS
		_nodo_eryn_tits.material = _material_eryn_tits

	_material_eryn_tits.set_shader_parameter("amplitud_uv", bamboleo_amplitud)
	_material_eryn_tits.set_shader_parameter("amplitud_y", bamboleo_amplitud)
	_material_eryn_tits.set_shader_parameter("factor_lado_derecho", factor_lado_derecho)
	_material_eryn_tits.set_shader_parameter("deformacion_x", 0.0)
	_material_eryn_tits.set_shader_parameter("deformacion_y", 0.0)


func reproducir_respiracion_eryn() -> void:
	_ha_respirado_eryn = true
	_reproducir_respiracion_eryn()


func _preparar_nodos_respiracion() -> void:
	if _prota_nodo != null:
		return

	var nodo := find_child("ProtaNormal", true, false)
	if not nodo:
		nodo = find_child("RetratoEryn", true, false)

	if nodo is Node2D:
		_prota_nodo = nodo as Node2D
		_escala_prota_base = _prota_nodo.scale
		_pos_prota_base = _prota_nodo.position
		_alto_prota_px = _alto_retrato(_prota_nodo)

	if not _nodo_eryn_tits:
		_nodo_eryn_tits = _obtener_eryn_tits()

	if _nodo_eryn_tits and _nodo_eryn_tits is Node2D:
		_escala_tits_base = (_nodo_eryn_tits as Node2D).scale
		_pos_tits_base = (_nodo_eryn_tits as Node2D).position


func _reproducir_respiracion_eryn() -> void:
	if not respiracion_activa:
		return

	_preparar_nodos_respiracion()
	if not _prota_nodo:
		return

	if _tween_respiracion and _tween_respiracion.is_valid():
		_tween_respiracion.kill()

	_tween_respiracion = create_tween()
	_tween_respiracion.set_trans(Tween.TRANS_SINE)
	_tween_respiracion.set_ease(Tween.EASE_IN_OUT)

	# 1. Inhalación ágil y rápida (stretch vertical con ligero squash en X)
	_tween_respiracion.tween_method(_aplicar_respiracion, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. En el ápice de la inhalación, se dispara el rebote elástico de Eryntits
	_tween_respiracion.tween_callback(_animar_bamboleo_eryntits)
	# 3. Exhalación y asentamiento rápido hacia el reposo
	_tween_respiracion.tween_method(_aplicar_respiracion, 1.0, 0.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _aplicar_respiracion(factor: float) -> void:
	# Squash & Stretch sutil de respiración:
	# Stretch en Y (+2.2% máx), Squash en X (-1.0% máx)
	var esc_factor := Vector2(
		1.0 - factor * (respiracion_amplitud * 0.45),
		1.0 + factor * respiracion_amplitud
	)

	if _prota_nodo:
		_prota_nodo.scale = _escala_prota_base * esc_factor
		var dy: float = _alto_prota_px * (_escala_prota_base.y * (esc_factor.y - 1.0)) * 0.5
		_prota_nodo.position = Vector2(_pos_prota_base.x, _pos_prota_base.y - dy)

	if _nodo_eryn_tits and _nodo_eryn_tits is Node2D:
		var tits_2d := _nodo_eryn_tits as Node2D
		tits_2d.scale = _escala_tits_base * esc_factor
		var dy_t: float = _alto_prota_px * (_escala_prota_base.y * (esc_factor.y - 1.0)) * 0.5
		tits_2d.position = Vector2(_pos_tits_base.x, _pos_tits_base.y - dy_t)


func _on_bamboleo_terminado() -> void:
	if bucle_respiracion_activo:
		_iniciar_bucle_respiracion()


func iniciar_bucle_respiracion() -> void:
	_iniciar_bucle_respiracion()


func detener_bucle_respiracion() -> void:
	_detener_bucle_respiracion()


func _iniciar_bucle_respiracion() -> void:
	if not bucle_respiracion_activo:
		return
	if _modo_dual and _hablante_actual() == "perrena":
		return

	_preparar_nodos_respiracion()
	if not _prota_nodo:
		return

	_detener_bucle_respiracion()

	_tween_bucle = create_tween().set_loops()
	_tween_bucle.set_trans(Tween.TRANS_SINE)
	_tween_bucle.set_ease(Tween.EASE_IN_OUT)

	var t: float = bucle_duracion_ciclo
	var t_sube: float = t * 0.40
	var t_pausa_alta: float = t * 0.10
	var t_cae: float = t * 0.34
	var t_rebote: float = t * 0.08
	var t_reposo: float = t * 0.08

	# 1. Inhalación: ascenso suave y continuo de 0.0 a 1.0 (sin ningún rebote en la cima)
	_tween_bucle.tween_method(_aplicar_respiracion_bucle, 0.0, 1.0, t_sube).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 2. Pausa breve de aire lleno en reposo
	_tween_bucle.tween_interval(t_pausa_alta)
	# 3. Exhalación: descenso suave hacia el reposo neutro
	_tween_bucle.tween_method(_aplicar_respiracion_bucle, 1.0, -0.15, t_cae).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 4. Rebote elástico sutil e independiente del busto al asentarse
	_tween_bucle.tween_method(_aplicar_respiracion_bucle, -0.15, 0.05, t_rebote).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 5. Retorno final a reposo neutro (0.0)
	_tween_bucle.tween_method(_aplicar_respiracion_bucle, 0.05, 0.0, t_reposo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _detener_bucle_respiracion() -> void:
	if _tween_bucle and _tween_bucle.is_valid():
		_tween_bucle.kill()
	_tween_bucle = null
	if _material_eryn_tits:
		_material_eryn_tits.set_shader_parameter("deformacion_y", 0.0)
	if _modo_dual and _hablante_actual() == "perrena":
		return
	if _prota_nodo:
		_prota_nodo.scale = _escala_prota_base
		_prota_nodo.position = _pos_prota_base
	if _nodo_eryn_tits and _nodo_eryn_tits is Node2D:
		(_nodo_eryn_tits as Node2D).scale = _escala_tits_base
		(_nodo_eryn_tits as Node2D).position = _pos_tits_base


func _aplicar_respiracion_bucle(factor: float) -> void:
	# factor va de -0.15 a 1.0
	# 1. Movimiento del cuerpo (ProtaNormal): elevación suave y continua, anclada en la base y sin rebote en la cima
	var factor_cuerpo: float = clampf(factor, 0.0, 1.0)
	var esc_factor := Vector2(
		1.0 - factor_cuerpo * (bucle_amplitud_torso * 0.45),
		1.0 + factor_cuerpo * bucle_amplitud_torso
	)

	if _prota_nodo:
		_prota_nodo.scale = _escala_prota_base * esc_factor
		var dy: float = _alto_prota_px * (_escala_prota_base.y * (esc_factor.y - 1.0)) * 0.5
		_prota_nodo.position = Vector2(_pos_prota_base.x, _pos_prota_base.y - dy)

	# 2. Capa base de Eryntits3: coincide exactamente en escala y posición con ProtaNormal
	if _nodo_eryn_tits and _nodo_eryn_tits is Node2D:
		var tits_2d := _nodo_eryn_tits as Node2D
		tits_2d.scale = _escala_tits_base * esc_factor
		var dy_t: float = _alto_prota_px * (_escala_prota_base.y * (esc_factor.y - 1.0)) * 0.5
		tits_2d.position = Vector2(_pos_tits_base.x, _pos_tits_base.y - dy_t)

	# 3. Rebote elástico independiente de los pechos en su propio shader
	if _material_eryn_tits:
		var def_y: float = factor * bucle_amplitud_tits
		_material_eryn_tits.set_shader_parameter("deformacion_y", def_y)


func _exit_tree() -> void:
	_detener_bucle_respiracion()



