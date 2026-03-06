extends Control

@onready var splash_image: TextureRect = $CenterContainer/SplashImage
@onready var fade_overlay: ColorRect = $FadeOverlay

const ZOOM_DURATION := 2.5
const ZOOM_FROM := 1.0
const ZOOM_TO := 1.08
const FADE_IN_DURATION := 0.6
const FADE_OUT_DURATION := 0.8

var next_scene_path := "res://Scenes/UI/LanguageSelector.tscn"
var game_scene_path := "res://Scenes/Levels/NIVEL01.tscn"
var transitioning := false

func _enter_tree() -> void:
	# Silenciar música durante el splash (se inicia al terminar)
	if AudioManager and AudioManager.music_player:
		AudioManager.music_player.stop()

func _ready() -> void:
	# Asegurar que no hay música
	if AudioManager and AudioManager.music_player:
		AudioManager.music_player.stop()
	
	# Empezar completamente blanco
	fade_overlay.color = Color(1, 1, 1, 1)
	fade_overlay.visible = true
	
	# Escala inicial centrada
	splash_image.pivot_offset = splash_image.size / 2.0
	splash_image.scale = Vector2(ZOOM_FROM, ZOOM_FROM)
	
	# Crear botón de saltar
	_crear_boton_saltar()
	
	_play_splash_sequence()

func _crear_boton_saltar() -> void:
	var skip_btn = Button.new()
	skip_btn.name = "SkipButton"
	skip_btn.text = "SKIP ⏭"
	skip_btn.custom_minimum_size = Vector2(120, 40)
	
	# Estilo normal
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	style_normal.border_color = Color(0.8, 0.7, 0.5, 0.6)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.corner_radius_bottom_left = 8
	
	# Estilo hover
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.15, 0.1, 0.05, 0.75)
	style_hover.border_color = Color(1.0, 0.9, 0.6, 0.9)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_right = 8
	style_hover.corner_radius_bottom_left = 8
	
	skip_btn.add_theme_stylebox_override("normal", style_normal)
	skip_btn.add_theme_stylebox_override("hover", style_hover)
	skip_btn.add_theme_stylebox_override("pressed", style_hover)
	skip_btn.add_theme_font_size_override("font_size", 16)
	skip_btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 0.8))
	skip_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.75, 1.0))
	
	# Posición: esquina inferior derecha
	skip_btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	skip_btn.anchor_left = 1.0
	skip_btn.anchor_top = 1.0
	skip_btn.anchor_right = 1.0
	skip_btn.anchor_bottom = 1.0
	skip_btn.offset_left = -140
	skip_btn.offset_top = -60
	skip_btn.offset_right = -20
	skip_btn.offset_bottom = -20
	
	skip_btn.z_index = 100
	skip_btn.pressed.connect(_skip_to_game)
	add_child(skip_btn)

func _play_splash_sequence() -> void:
	var tween = create_tween()
	
	# Fase 1: Fade-in (aparece la imagen)
	tween.tween_property(fade_overlay, "color:a", 0.0, FADE_IN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# Fase 2: Zoom-in suave (simultáneo al final del fade)
	tween.parallel().tween_property(splash_image, "scale", Vector2(ZOOM_TO, ZOOM_TO), ZOOM_DURATION).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	# Breve pausa al finalizar zoom
	tween.tween_interval(0.3)
	
	# Fase 3: Fade-out a negro
	tween.tween_property(fade_overlay, "color:a", 1.0, FADE_OUT_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	# Al terminar, cambiar de escena
	tween.finished.connect(_on_splash_finished)

func _on_splash_finished() -> void:
	if transitioning:
		return
	# No music during language selector
	get_tree().change_scene_to_file(next_scene_path)

# Permitir saltar TODO con ESCAPE → ir directo al juego
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_skip_to_game()
		else:
			_skip_splash()
	elif event is InputEventMouseButton and event.pressed:
		_skip_splash()

# Saltar SOLO el splash → ir a LanguageSelector (comportamiento original)
func _skip_splash() -> void:
	if transitioning:
		return
	# Detener tweens actuales y hacer fade-out rápido
	var tweens = get_tree().get_processed_tweens()
	for t in tweens:
		t.kill()
	
	var skip_tween = create_tween()
	skip_tween.tween_property(fade_overlay, "color:a", 1.0, 0.3).set_ease(Tween.EASE_IN)
	skip_tween.finished.connect(_on_splash_finished)

# Saltar TODO → ir directo al juego
func _skip_to_game() -> void:
	if transitioning:
		return
	transitioning = true
	
	# Iniciar música de batalla (normalmente lo hace IntroScene)
	AudioManager.play_music(2)
	
	# Detener tweens actuales
	var tweens = get_tree().get_processed_tweens()
	for t in tweens:
		t.kill()
	
	var skip_tween = create_tween()
	skip_tween.tween_property(fade_overlay, "color:a", 1.0, 0.3).set_ease(Tween.EASE_IN)
	skip_tween.finished.connect(func():
		get_tree().change_scene_to_file(game_scene_path)
	)
