extends Node3D

## Script principal del nivel. Controla el flujo:
## Nivel 0 (pacifista) → Nivel 1 (combate) → Nivel 2 (pendiente)

# === CONFIGURACIÓN GENERAL ===
@export_category("Configuración General")
@export var limite_fin_mapa_x: float = -5.0 ## Posición X donde el Imp se detiene
@export var total_enemigos_nivel1: int = 13 ## Enemigos totales en el Nivel 1

# === CONFIGURACIÓN NIVEL 0 (PACIFISTA) ===
@export_category("Nivel 0 — Pacifista")
@export var velocidad_pacificos: float = 0.5 ## Velocidad de caminata de los pacíficos
@export var offset_entre_pacificos: float = 0.4 ## Separación X entre cada pacífico al spawnear
@export var tamano_imagen_emisario: Vector2 = Vector2(180, 180) ## Tamaño del icono del emisario en el diálogo
@export var tamano_imagen_protagonista: Vector2 = Vector2(180, 180) ## Tamaño del icono de la protagonista en el diálogo inicial
@export var retroceso_parada_arqueras: float = 0.2 ## Cada arquera se para 0.2u más adelante que la anterior
@export var delay_dialogo_inicio: float = 1.0 ## Segundos antes de mostrar el mensaje inicial de protagonista
@export var delay_dialogo_pacifico: float = 2.0 ## Segundos de espera antes de mostrar el diálogo pacifista
@export_range(0.005, 0.08, 0.005) var velocidad_texto_novela: float = 0.02 ## Velocidad del reveal del texto (segundos por caracter)
@export_range(0.9, 2.0, 0.05) var pitch_habla_protagonista: float = 1.1 ## Pitch del tecleo metálico del diálogo inicial
@export var volumen_habla_protagonista_db: float = -16.0 ## Volumen del tecleo metálico en diálogo inicial
@export_range(2, 20, 1) var chars_por_habla_protagonista: int = 7 ## Frecuencia del tecleo metálico
@export_range(0.05, 0.5, 0.01) var intervalo_min_habla_protagonista: float = 0.18 ## Intervalo mínimo entre sonidos de habla

# === ESTADO DEL NIVEL ===
enum NivelEstado { NIVEL_0, TRANSICION, NIVEL_1, VICTORIA_PACIFISTA, VICTORIA_NIVEL1, OLEADAS_LIBRES }
var estado_actual: int = NivelEstado.NIVEL_0
var enemigos_pacificos: Array = [] ## Los 3 enemigos del nivel 0
var imp_estandarte: Node3D = null ## Referencia al imp que lleva el estandarte

# === REFERENCIAS ===
@onready var wave_spawner: WaveSpawner = $WaveSpawner
@onready var game_ui = $GameUI
@onready var texture_rect = $SubViewport/TextureRect

# === ESCENAS ===
var escena_imp_estandarte: PackedScene = preload("res://Scenes/Characters/ImpEnemyEstandarte.tscn")
var sfx_habla_dialogo: AudioStream = preload("res://Assets/Environment/Shield/IMPACTO_ESCUDO_BALLESTA.mp3")
var estados_proceso_jugador: Dictionary = {}
var estados_proceso_dialogo: Dictionary = {}
var estado_spawner_dialogo: Dictionary = {}
var _dialogo_audio_player: AudioStreamPlayer

func _ready():
	_dialogo_audio_player = AudioStreamPlayer.new()
	_dialogo_audio_player.bus = "Master"
	add_child(_dialogo_audio_player)

	# Ocultar TextureRect del SubViewport
	if texture_rect:
		texture_rect.visible = false

	# Warm-up de shaders
	VFXFactory.warmup_shaders(self)

	# Esperar un frame para que todos los nodos estén listos
	await get_tree().process_frame

	# Detener el spawner automático desde el inicio para evitar aparición previa al diálogo.
	wave_spawner.detener_spawning()

	# Espera inicial solicitada antes del cuadro de diálogo
	await get_tree().create_timer(delay_dialogo_inicio).timeout

	# Mensaje inicial de protagonista antes de iniciar el flujo pacifista
	await _mostrar_dialogo_inicio_protagonista()

	# Iniciar Nivel 0
	_iniciar_nivel_0()

func _mostrar_dialogo_inicio_protagonista():
	_set_juego_pausado_dialogo(true)

	var overlay = CanvasLayer.new()
	overlay.layer = 190
	overlay.name = "DialogoInicioProtagonista"
	add_child(overlay)

	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.0)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fondo)

	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.92)
	panel_style.border_color = Color(0.9, 0.8, 0.4)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)

	panel.anchor_left = 0.16
	panel.anchor_right = 0.84
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.42
	overlay.add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# Icono de protagonista a la izquierda
	var textura = load("res://Assets/PROTA_ICON.png")
	if textura:
		var img = TextureRect.new()
		img.texture = textura
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = tamano_imagen_protagonista
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(img)

	var vbox_texto = VBoxContainer.new()
	vbox_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_texto.add_theme_constant_override("separation", 10)
	hbox.add_child(vbox_texto)

	var nombre = Label.new()
	nombre.text = "Protagonista"
	nombre.add_theme_font_size_override("font_size", 34)
	nombre.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox_texto.add_child(nombre)

	var dialogo = RichTextLabel.new()
	dialogo.bbcode_enabled = true
	dialogo.text = "Veo una silueta en el horizonte preparen sus arcos, a mi señal"
	dialogo.add_theme_font_size_override("normal_font_size", 26)
	dialogo.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogo.fit_content = true
	dialogo.scroll_active = false
	vbox_texto.add_child(dialogo)

	dialogo.visible_characters = 0
	var total_chars: int = dialogo.get_total_character_count()
	if total_chars > 0:
		var tiempo_por_char: float = velocidad_texto_novela
		var chars_por_sonido: int = chars_por_habla_protagonista
		var ultimo_audio_ms: int = 0
		for i in range(total_chars + 1):
			if not is_instance_valid(dialogo) or not dialogo.is_inside_tree():
				break
			dialogo.visible_characters = i
			if i > 0 and i % chars_por_sonido == 0:
				var ahora_ms: int = Time.get_ticks_msec()
				if ahora_ms - ultimo_audio_ms >= int(intervalo_min_habla_protagonista * 1000.0):
					_reproducir_habla_femenina()
					ultimo_audio_ms = ahora_ms
			await get_tree().create_timer(tiempo_por_char).timeout

	var boton_continuar = Button.new()
	boton_continuar.text = tr("BOTON_CONTINUAR")
	boton_continuar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox_texto.add_child(boton_continuar)

	await boton_continuar.pressed
	if is_instance_valid(overlay):
		overlay.queue_free()
	_set_juego_pausado_dialogo(false)

func _reproducir_habla_femenina():
	if not sfx_habla_dialogo or not _dialogo_audio_player:
		return
	_dialogo_audio_player.stream = sfx_habla_dialogo
	_dialogo_audio_player.volume_db = volumen_habla_protagonista_db
	_dialogo_audio_player.pitch_scale = pitch_habla_protagonista
	_dialogo_audio_player.play()

func _process(_delta):
	match estado_actual:
		NivelEstado.NIVEL_0:
			_monitorear_nivel_0()
		NivelEstado.NIVEL_1:
			_monitorear_nivel_1()

# ═══════════════════════════════════════════════════════════════════════════════
# NIVEL 0 — PACIFISTA
# ═══════════════════════════════════════════════════════════════════════════════

func _iniciar_nivel_0():
	estado_actual = NivelEstado.NIVEL_0

	# Música de bosque (+12 dB = ~400% volumen)
	AudioManager.play_music(3, true, 12.0) # SONIDO BOSQUE.mp3

	# UI mínimo (solo corazones)
	await get_tree().process_frame
	if game_ui and game_ui.has_method("set_modo_minimo"):
		game_ui.set_modo_minimo(true)

	# Arqueras aliadas visibles pero sin disparar (solo pose IDLE)
	_set_aliadas_modo_pacifico()

	# Spawnear 3 enemigos pacíficos tras aceptar: 1 Imp con estandarte + 2 GoblinGirl.
	var escenas: Array[PackedScene] = [
		escena_imp_estandarte,
		wave_spawner.escena_goblin_girl,
		wave_spawner.escena_goblin_girl,
	]
	enemigos_pacificos = wave_spawner.spawn_pacificos(escenas, velocidad_pacificos, offset_entre_pacificos)

	# Asignar límite de parada escalonado: Imp en -5.0, arqueras en -4.8 y -4.6.
	for i in range(enemigos_pacificos.size()):
		var enemigo = enemigos_pacificos[i]
		if is_instance_valid(enemigo):
			enemigo.limite_pacifico_x = limite_fin_mapa_x + (i * retroceso_parada_arqueras)

	# Conectar señal de daño pacífico
	for enemigo in enemigos_pacificos:
		if is_instance_valid(enemigo) and enemigo.has_signal("pacifico_danado"):
			enemigo.pacifico_danado.connect(_on_pacifico_danado, CONNECT_ONE_SHOT)

	# Guardar referencia al imp del estandarte
	imp_estandarte = enemigos_pacificos[0]

func _monitorear_nivel_0():
	# Limpiar enemigos inválidos
	enemigos_pacificos = enemigos_pacificos.filter(func(e): return is_instance_valid(e))

	if enemigos_pacificos.is_empty():
		return

	# Verificar si todos se detuvieron en el borde
	var todos_detenidos := true
	for enemigo in enemigos_pacificos:
		if not enemigo.pacifico_detenido:
			todos_detenidos = false
			break

	if todos_detenidos:
		_victoria_pacifista()

# ═══════════════════════════════════════════════════════════════════════════════
# TRANSICIÓN: PACIFISTA → COMBATE
# ═══════════════════════════════════════════════════════════════════════════════

func _on_pacifico_danado():
	if estado_actual != NivelEstado.NIVEL_0:
		return
	estado_actual = NivelEstado.TRANSICION

	# Convertir pacíficos supervivientes en hostiles
	var supervivientes := 0
	for enemigo in enemigos_pacificos:
		if is_instance_valid(enemigo) and enemigo.current_state != EnemyBase.State.DYING and enemigo.current_state != EnemyBase.State.DEAD:
			enemigo.modo_pacifico = false
			# Forzar que se detengan y empiecen a atacar
			enemigo.target_walk_distance = enemigo.walked_distance
			supervivientes += 1

	# Música de batalla
	AudioManager.play_music(2) # BGM_battle.mp3

	# Restaurar UI completo
	if game_ui and game_ui.has_method("set_modo_minimo"):
		game_ui.set_modo_minimo(false)

	# Activar arqueras aliadas
	_set_aliadas_activas(true)

	# Iniciar Nivel 1: oleada de 13 enemigos (los supervivientes cuentan)
	_iniciar_nivel_1(supervivientes)

# ═══════════════════════════════════════════════════════════════════════════════
# NIVEL 1 — COMBATE (13 enemigos: Imp + GoblinGirl)
# ═══════════════════════════════════════════════════════════════════════════════

func _iniciar_nivel_1(supervivientes_pacificos: int = 0):
	estado_actual = NivelEstado.NIVEL_1

	# Los supervivientes ya están en active_goblins del spawner
	# Configurar para spawnear los que faltan
	var enemigos_a_spawnear = total_enemigos_nivel1 - supervivientes_pacificos

	wave_spawner.goblins_por_oleada = enemigos_a_spawnear
	wave_spawner.probabilidad_imp = 0.5
	wave_spawner.probabilidad_goblin_girl = 0.5
	wave_spawner.probabilidad_igual = false
	wave_spawner.forzar_tipo_enemigo = -1 # Normal (imp + goblin girl, sin goblin base)

	# Desactivar goblin base (solo imp + goblin girl)
	wave_spawner.escena_goblin = wave_spawner.escena_goblin_girl # Redirigir goblin → goblin_girl

	# Conectar señal de oleada completada
	if not wave_spawner.oleada_completada.is_connected(_on_nivel1_completado):
		wave_spawner.oleada_completada.connect(_on_nivel1_completado)

	# Iniciar el spawning
	wave_spawner.current_wave = 0
	wave_spawner.goblins_spawned_in_wave = 0
	wave_spawner.is_wave_active = false
	wave_spawner.wave_cooldown = 2.0

func _monitorear_nivel_1():
	# Verificar si todos los enemigos murieron (incluyendo supervivientes pacíficos)
	wave_spawner.active_goblins = wave_spawner.active_goblins.filter(func(g): return is_instance_valid(g))

	if wave_spawner.goblins_spawned_in_wave >= wave_spawner.goblins_por_oleada and wave_spawner.active_goblins.is_empty():
		_on_nivel1_completado(1)

func _on_nivel1_completado(_numero_oleada: int):
	if estado_actual != NivelEstado.NIVEL_1:
		return
	estado_actual = NivelEstado.VICTORIA_NIVEL1

	wave_spawner.detener_spawning()
	print("[NIVEL01] ¡Nivel 1 completado! Mostrando victoria con botón continuar...")
	_mostrar_victoria_con_continuar(tr("NIVEL_1_COMPLETADO") if TranslationServer.get_locale() != "" else "¡Nivel 1 completado!")

# ═══════════════════════════════════════════════════════════════════════════════
# VICTORIA PACIFISTA
# ═══════════════════════════════════════════════════════════════════════════════

func _victoria_pacifista():
	if estado_actual != NivelEstado.NIVEL_0:
		return
	estado_actual = NivelEstado.VICTORIA_PACIFISTA

	wave_spawner.detener_spawning()

	# Reproducir música de victoria (sin loop)
	AudioManager.play_music(4, false) # VICTORY.mp3

	# Mostrar diálogo tipo novela visual tras un delay
	await get_tree().create_timer(delay_dialogo_pacifico).timeout
	_mostrar_dialogo_pacifista()

func _mostrar_dialogo_pacifista():
	_set_juego_pausado_dialogo(true)

	var overlay = CanvasLayer.new()
	overlay.layer = 200
	overlay.name = "DialogoPacifista"
	add_child(overlay)

	# Fondo semi-transparente
	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.0)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fondo)

	# Panel principal del emisario (compacto, solo texto superior)
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.1, 0.92)
	panel_style.border_color = Color(0.85, 0.65, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Posicionar: centrado horizontal, recuadro más pequeño en parte superior
	panel.anchor_left = 0.16
	panel.anchor_right = 0.84
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.42
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	overlay.add_child(panel)

	# Contenedor horizontal: texto + imagen (icono a la derecha)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# Contenedor de texto
	var vbox_texto = VBoxContainer.new()
	vbox_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_texto.add_theme_constant_override("separation", 10)
	hbox.add_child(vbox_texto)

	# Imagen IMP_ICON.png (retrato del emisario) a la derecha
	var textura = load("res://Assets/IMP_ICON.png")
	if textura:
		var img = TextureRect.new()
		img.texture = textura
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = tamano_imagen_emisario
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(img)

	# Nombre del personaje
	var nombre = Label.new()
	nombre.text = tr("EMISARIO_NOMBRE")
	nombre.add_theme_font_size_override("font_size", 34)
	nombre.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox_texto.add_child(nombre)

	# Texto del diálogo
	var dialogo = RichTextLabel.new()
	dialogo.bbcode_enabled = true
	dialogo.text = tr("DIALOGO_PACIFISTA")
	dialogo.add_theme_font_size_override("normal_font_size", 26)
	dialogo.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogo.fit_content = true
	dialogo.scroll_active = false
	vbox_texto.add_child(dialogo)

	# Efecto "novela ligera": revelar texto gradualmente
	dialogo.visible_characters = 0
	var total_chars: int = dialogo.get_total_character_count()
	if total_chars > 0:
		var tiempo_por_char: float = velocidad_texto_novela
		var chars_por_sonido: int = 4
		for i in range(total_chars + 1):
			if not is_instance_valid(dialogo) or not dialogo.is_inside_tree():
				break
			dialogo.visible_characters = i
			if i > 0 and i % chars_por_sonido == 0:
				AudioManager.play_sfx("shield_hit_arrow", -18.0)
			await get_tree().create_timer(tiempo_por_char).timeout

	# Botón para pasar a la segunda pantalla (resultado)
	var boton_continuar = Button.new()
	boton_continuar.text = tr("BOTON_CONTINUAR")
	boton_continuar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox_texto.add_child(boton_continuar)

	boton_continuar.pressed.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
		_mostrar_resultado_pacifista_pantalla_negra()
	)

func _mostrar_resultado_pacifista_pantalla_negra():
	var overlay = CanvasLayer.new()
	overlay.layer = 210
	overlay.name = "ResultadoPacifista"
	add_child(overlay)

	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 1)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fondo)

	var contenedor = VBoxContainer.new()
	contenedor.anchor_left = 0.08
	contenedor.anchor_right = 0.92
	contenedor.anchor_top = 0.2
	contenedor.anchor_bottom = 0.8
	contenedor.alignment = BoxContainer.ALIGNMENT_CENTER
	contenedor.add_theme_constant_override("separation", 24)
	overlay.add_child(contenedor)

	var resultado = RichTextLabel.new()
	resultado.bbcode_enabled = true
	resultado.text = tr("RESULTADO_PACIFISTA")
	resultado.add_theme_font_size_override("normal_font_size", 30)
	resultado.add_theme_color_override("default_color", Color(1, 1, 1))
	resultado.fit_content = true
	resultado.scroll_active = false
	resultado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resultado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.add_child(resultado)

	var boton_cerrar = Button.new()
	boton_cerrar.text = tr("BOTON_CONTINUAR")
	boton_cerrar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	contenedor.add_child(boton_cerrar)

	var boton_reiniciar = Button.new()
	boton_reiniciar.text = "Reiniciar"
	boton_reiniciar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	contenedor.add_child(boton_reiniciar)

	boton_cerrar.pressed.connect(func():
		_set_juego_pausado_dialogo(false)
		if is_instance_valid(overlay):
			overlay.queue_free()
	)

	boton_reiniciar.pressed.connect(func():
		_set_juego_pausado_dialogo(false)
		if is_instance_valid(overlay):
			overlay.queue_free()
		_reiniciar_nivel01_limpio()
	)

func _reiniciar_nivel01_limpio():
	# Limpiar enemigos/proyectiles spawneados en root antes de recargar escena.
	var grupos_a_limpiar: Array[String] = ["enemy_projectiles", "enemies", "shield_imps"]
	for grupo in grupos_a_limpiar:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(nodo):
				nodo.queue_free()

	# Esperar a que queue_free se aplique para evitar residuos entre recargas.
	await get_tree().process_frame
	await get_tree().process_frame

	get_tree().change_scene_to_file("res://Scenes/Levels/NIVEL01.tscn")

func _mostrar_texto_guerra():
	var overlay = CanvasLayer.new()
	overlay.layer = 200
	overlay.name = "TextoGuerra"
	add_child(overlay)

	# Panel centrado
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.02, 0.02, 0.9)
	panel_style.border_color = Color(0.9, 0.2, 0.1)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)

	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.35
	panel.anchor_bottom = 0.55
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	overlay.add_child(panel)

	var label = Label.new()
	label.text = tr("TEXTO_GUERRA")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)

	# Auto-destruir después de 3 segundos
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
	)

func _mostrar_victoria(mensaje: String):
	var overlay = CanvasLayer.new()
	overlay.layer = 200
	add_child(overlay)

	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.7)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fondo)

	var label = Label.new()
	label.text = mensaje
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	# Centrado horizontal, mitad de alto centrado vertical
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.25
	label.anchor_bottom = 0.75
	label.offset_left = 0
	label.offset_right = 0
	label.offset_top = 0
	label.offset_bottom = 0
	overlay.add_child(label)

# ═══════════════════════════════════════════════════════════════════════════════
# OLEADAS LIBRES (post Nivel 1)
# ═══════════════════════════════════════════════════════════════════════════════

func _mostrar_victoria_con_continuar(mensaje: String):
	var overlay = CanvasLayer.new()
	overlay.layer = 200
	overlay.name = "VictoriaContinuar"
	add_child(overlay)

	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.7)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fondo)

	# Contenedor centrado
	var center = VBoxContainer.new()
	center.anchor_left = 0.2
	center.anchor_right = 0.8
	center.anchor_top = 0.3
	center.anchor_bottom = 0.7
	center.offset_left = 0
	center.offset_right = 0
	center.offset_top = 0
	center.offset_bottom = 0
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 30)
	overlay.add_child(center)

	# Texto de victoria
	var label = Label.new()
	label.text = mensaje
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	center.add_child(label)

	# Botón "Continuar"
	var boton = Button.new()
	boton.text = tr("BOTON_CONTINUAR")
	boton.add_theme_font_size_override("font_size", 24)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.08, 0.05, 0.95)
	btn_style.border_color = Color(0.85, 0.65, 0.2)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(12)
	boton.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.14, 0.08, 0.95)
	boton.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.08, 0.05, 0.02, 0.95)
	boton.add_theme_stylebox_override("pressed", btn_pressed)

	boton.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	boton.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.6))
	boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(boton)

	boton.pressed.connect(func():
		overlay.queue_free()
		_iniciar_oleadas_libres()
	)

func _iniciar_oleadas_libres():
	estado_actual = NivelEstado.OLEADAS_LIBRES
	print("[NIVEL01] Oleadas libres iniciadas — enemigos al azar")

	# Restaurar goblin base para que aparezcan los 3 tipos
	wave_spawner.escena_goblin = preload("res://Scenes/Characters/Goblin.tscn")

	# Probabilidad igual: 33% cada tipo
	wave_spawner.probabilidad_igual = true
	wave_spawner.forzar_tipo_enemigo = -1
	wave_spawner.goblins_por_oleada = 8
	wave_spawner.intervalo_aparicion = 4.0

	# Reiniciar wave y arrancar
	wave_spawner.current_wave = 0
	wave_spawner.goblins_spawned_in_wave = 0
	wave_spawner.is_wave_active = false
	wave_spawner.wave_cooldown = 1.0

# ═══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ═══════════════════════════════════════════════════════════════════════════════

func _set_aliadas_activas(activas: bool):
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally is AllyArcher:
			ally.visible = activas
			ally.set_process(activas)
			ally.set_physics_process(activas)
			var hitbox = ally.get("hitbox_body")
			if hitbox and is_instance_valid(hitbox):
				hitbox.collision_layer = 2 if activas else 0

## Arqueras visibles en pose IDLE pero sin disparar
func _set_aliadas_modo_pacifico():
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally is AllyArcher:
			ally.visible = true
			ally.set_process(false) # No disparan
			ally.set_physics_process(false)
			var hitbox = ally.get("hitbox_body")
			if hitbox and is_instance_valid(hitbox):
				hitbox.collision_layer = 0 # Sin colisión

func _set_movimiento_jugador_bloqueado(bloqueado: bool):
	for jugador in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(jugador):
			continue

		var id_jugador: int = jugador.get_instance_id()
		if bloqueado:
			if not estados_proceso_jugador.has(id_jugador):
				estados_proceso_jugador[id_jugador] = {
					"process": jugador.is_processing(),
					"physics": jugador.is_physics_processing()
				}
			jugador.set_process(false)
			jugador.set_physics_process(false)
		else:
			var estado = estados_proceso_jugador.get(id_jugador, {"process": true, "physics": true})
			jugador.set_process(bool(estado["process"]))
			jugador.set_physics_process(bool(estado["physics"]))

	if not bloqueado:
		estados_proceso_jugador.clear()

func _set_juego_pausado_dialogo(bloqueado: bool):
	_set_movimiento_jugador_bloqueado(bloqueado)

	if not is_instance_valid(wave_spawner):
		return

	var id_spawner: int = wave_spawner.get_instance_id()
	if bloqueado:
		if not estado_spawner_dialogo.has(id_spawner):
			estado_spawner_dialogo[id_spawner] = {
				"process": wave_spawner.is_processing(),
				"physics": wave_spawner.is_physics_processing()
			}
		wave_spawner.set_process(false)
		wave_spawner.set_physics_process(false)
	else:
		var estado_spawner = estado_spawner_dialogo.get(id_spawner, {"process": true, "physics": true})
		wave_spawner.set_process(bool(estado_spawner["process"]))
		wave_spawner.set_physics_process(bool(estado_spawner["physics"]))
		estado_spawner_dialogo.clear()

	var grupos_a_pausar: Array[String] = ["enemies", "enemy_projectiles", "allies", "shield_imps"]
	for grupo in grupos_a_pausar:
		for nodo in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(nodo):
				continue

			var id_nodo: int = nodo.get_instance_id()
			if bloqueado:
				if not estados_proceso_dialogo.has(id_nodo):
					estados_proceso_dialogo[id_nodo] = {
						"process": nodo.is_processing(),
						"physics": nodo.is_physics_processing()
					}
				nodo.set_process(false)
				nodo.set_physics_process(false)
			else:
				var estado_nodo = estados_proceso_dialogo.get(id_nodo, {"process": true, "physics": true})
				nodo.set_process(bool(estado_nodo["process"]))
				nodo.set_physics_process(bool(estado_nodo["physics"]))

	if not bloqueado:
		estados_proceso_dialogo.clear()
