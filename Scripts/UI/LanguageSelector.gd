extends Control

@onready var grid: GridContainer = $CenterContainer/GridContainer
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var hover_player: AudioStreamPlayer = $HoverPlayer
@onready var click_player: AudioStreamPlayer = $ClickPlayer

# Language code → native display name
const LANGUAGES := {
	"es": "Español",
	"en": "English",
	"ja": "日本語",
	"ru": "Русский",
}

func _ready() -> void:
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.visible = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_create_language_buttons()

	# Fade in
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _create_language_buttons() -> void:
	for lang_code in LANGUAGES:
		var btn = Button.new()
		btn.text = LANGUAGES[lang_code]
		btn.custom_minimum_size = Vector2(240, 55)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.7, 1))
		btn.pivot_offset = Vector2(120, 27)

		# Apply styles
		btn.add_theme_stylebox_override("normal", _make_style(Color(0.15, 0.1, 0.2, 0.9), Color(0.7, 0.55, 0.3, 0.8), 0))
		btn.add_theme_stylebox_override("hover", _make_style(Color(0.3, 0.2, 0.1, 1), Color(0.95, 0.8, 0.45, 1), 8))
		btn.add_theme_stylebox_override("pressed", _make_style(Color(0.45, 0.3, 0.15, 1), Color(1, 0.9, 0.55, 1), 0))

		btn.pressed.connect(_on_language_selected.bind(lang_code))
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_unhover.bind(btn))

		grid.add_child(btn)

func _make_style(bg: Color, border: Color, shadow: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	if shadow > 0:
		style.shadow_color = Color(0.95, 0.75, 0.3, 0.35)
		style.shadow_size = shadow
	return style

func _on_button_hover(btn: Button) -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
	if hover_player and hover_player.stream:
		hover_player.play()

func _on_button_unhover(btn: Button) -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)

func _on_language_selected(lang_code: String) -> void:
	if click_player and click_player.stream:
		click_player.play()
	TranslationServer.set_locale(lang_code)
	_go_to_intro()

func _go_to_intro() -> void:
	# Disable all buttons
	for child in grid.get_children():
		if child is Button:
			child.disabled = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func(): get_tree().change_scene_to_file("res://Scenes/UI/IntroScene.tscn"))
