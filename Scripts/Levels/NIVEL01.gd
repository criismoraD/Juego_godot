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
@export var tamano_imagen_emisario: Vector2 = Vector2(150, 200) ## Tamaño de la imagen del emisario en el diálogo
@export var retroceso_parada_arqueras: float = 0.2 ## Cada arquera se para 0.2u más adelante que la anterior
@export var delay_dialogo_pacifico: float = 3.0 ## Segundos de espera antes de mostrar el diálogo

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

func _ready():
	# Ocultar TextureRect del SubViewport
	if texture_rect:
		texture_rect.visible = false

	# Warm-up de shaders
	VFXFactory.warmup_shaders(self)

	# Esperar un frame para que todos los nodos estén listos
	await get_tree().process_frame

	# Detener el spawner automático
	wave_spawner.detener_spawning()

	# Iniciar Nivel 0
	_iniciar_nivel_0()

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

	# Spawnear 3 enemigos pacíficos: 1 Imp con estandarte (adelante) + 2 GoblinGirl (detrás)
	var escenas: Array[PackedScene] = [
		escena_imp_estandarte,
		wave_spawner.escena_goblin_girl,
		wave_spawner.escena_goblin_girl,
	]
	enemigos_pacificos = wave_spawner.spawn_pacificos(escenas, velocidad_pacificos, offset_entre_pacificos)

	# Asignar límite de parada escalonado: Imp en -5.0, arqueras en -4.8 y -4.6
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
	var overlay = CanvasLayer.new()
	overlay.layer = 200
	add_child(overlay)

	# Fondo semi-transparente
	var fondo = ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.5)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fondo)

	# Panel principal del diálogo (centro-superior)
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.06, 0.1, 0.92)
	panel_style.border_color = Color(0.85, 0.65, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Posicionar: centrado horizontal, parte superior
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.85
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	overlay.add_child(panel)

	# Contenedor horizontal: imagen + texto
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	# Imagen WIP.png (retrato del emisario)
	var textura = load("res://WIP.png")
	if textura:
		var img = TextureRect.new()
		img.texture = textura
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = tamano_imagen_emisario
		img.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(img)

	# Contenedor de texto
	var vbox_texto = VBoxContainer.new()
	vbox_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_texto.add_theme_constant_override("separation", 15)
	hbox.add_child(vbox_texto)

	# Nombre del personaje
	var nombre = Label.new()
	nombre.text = tr("EMISARIO_NOMBRE")
	nombre.add_theme_font_size_override("font_size", 28)
	nombre.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox_texto.add_child(nombre)

	# Texto del diálogo
	var dialogo = RichTextLabel.new()
	dialogo.bbcode_enabled = true
	dialogo.text = tr("DIALOGO_PACIFISTA")
	dialogo.add_theme_font_size_override("normal_font_size", 18)
	dialogo.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	dialogo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogo.scroll_active = true
	vbox_texto.add_child(dialogo)

	# Texto de resultado
	var resultado = RichTextLabel.new()
	resultado.bbcode_enabled = true
	resultado.text = "[i]" + tr("RESULTADO_PACIFISTA") + "[/i]"
	resultado.add_theme_font_size_override("normal_font_size", 16)
	resultado.add_theme_color_override("default_color", Color(0.7, 0.85, 0.6))
	resultado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_texto.add_child(resultado)

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
