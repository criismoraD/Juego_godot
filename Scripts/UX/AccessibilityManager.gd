class_name AccessibilityManager
extends Node
## Gestor central de opciones de accesibilidad
## Daltonismo, tamaño de texto, subtítulos, controles adaptativos

signal settings_changed(settings: Dictionary)
signal colorblind_mode_changed(mode: String)
signal text_scale_changed(scale: float)
signal subtitles_toggled(enabled: bool)

enum ColorblindMode {
	NONE,
	DEUTERANOPIA,
	PROTANOPIA,
	TRITANOPIA
}

const DEFAULT_TEXT_SCALE: float = 1.0
const MIN_TEXT_SCALE: float = 0.5
const MAX_TEXT_SCALE: float = 2.0

var current_settings: Dictionary = {
	"colorblind_mode": ColorblindMode.NONE,
	"text_scale": DEFAULT_TEXT_SCALE,
	"subtitles_enabled": true,
	"high_contrast": false,
	"screen_reader": false,
	"reduce_motion": false,
	"hold_to_interact": false,
	"toggle_crouch": false,
	"auto_aim": false
}

var _colorblind_filters: Dictionary
var _canvas_layer: CanvasLayer

func _ready() -> void:
	_load_settings()
	_setup_colorblind_filters()


func _setup_colorblind_filters() -> void:
	_colorblind_filters = {
		ColorblindMode.NONE: null,
		ColorblindMode.DEUTERANOPIA: _create_deuteranopia_filter(),
		ColorblindMode.PROTANOPIA: _create_protanopia_filter(),
		ColorblindMode.TRITANOPIA: _create_tritanopia_filter()
	}


func _create_deuteranopia_filter() -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(1, 0, 0, 0.3)
	return rect


func _create_protanopia_filter() -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0, 1, 0, 0.3)
	return rect


func _create_tritanopia_filter() -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(0, 0, 1, 0.3)
	return rect


func set_colorblind_mode(mode: ColorblindMode) -> void:
	current_settings["colorblind_mode"] = mode
	_apply_colorblind_filter(mode)
	colorblind_mode_changed.emit(_get_colorblind_mode_name(mode))
	_save_settings()


func get_colorblind_mode() -> ColorblindMode:
	return current_settings["colorblind_mode"]


func set_text_scale(scale: float) -> void:
	scale = clamp(scale, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
	current_settings["text_scale"] = scale
	_apply_text_scale(scale)
	text_scale_changed.emit(scale)
	_save_settings()


func get_text_scale() -> float:
	return current_settings["text_scale"]


func enable_subtitles(enabled: bool) -> void:
	current_settings["subtitles_enabled"] = enabled
	subtitles_toggled.emit(enabled)
	_save_settings()


func are_subtitles_enabled() -> bool:
	return current_settings["subtitles_enabled"]


func toggle_high_contrast(enabled: bool) -> void:
	current_settings["high_contrast"] = enabled
	_apply_high_contrast(enabled)
	settings_changed.emit(current_settings)
	_save_settings()


func is_high_contrast_enabled() -> bool:
	return current_settings["high_contrast"]


func enable_reduce_motion(enabled: bool) -> void:
	current_settings["reduce_motion"] = enabled
	settings_changed.emit(current_settings)
	_save_settings()


func should_reduce_motion() -> bool:
	return current_settings["reduce_motion"]


func enable_hold_to_interact(enabled: bool) -> void:
	current_settings["hold_to_interact"] = enabled
	settings_changed.emit(current_settings)
	_save_settings()


func is_hold_to_interact() -> bool:
	return current_settings["hold_to_interact"]


func enable_toggle_crouch(enabled: bool) -> void:
	current_settings["toggle_crouch"] = enabled
	settings_changed.emit(current_settings)
	_save_settings()


func is_toggle_crouch() -> bool:
	return current_settings["toggle_crouch"]


func enable_auto_aim(enabled: bool) -> void:
	current_settings["auto_aim"] = enabled
	settings_changed.emit(current_settings)
	_save_settings()


func is_auto_aim_enabled() -> bool:
	return current_settings["auto_aim"]


func reset_to_defaults() -> void:
	current_settings = {
		"colorblind_mode": ColorblindMode.NONE,
		"text_scale": DEFAULT_TEXT_SCALE,
		"subtitles_enabled": true,
		"high_contrast": false,
		"screen_reader": false,
		"reduce_motion": false,
		"hold_to_interact": false,
		"toggle_crouch": false,
		"auto_aim": false
	}
	_apply_all_settings()
	settings_changed.emit(current_settings)
	_save_settings()


func get_all_settings() -> Dictionary:
	return current_settings.duplicate()


func _apply_all_settings() -> void:
	_apply_colorblind_filter(current_settings["colorblind_mode"])
	_apply_text_scale(current_settings["text_scale"])


func _apply_colorblind_filter(mode: ColorblindMode) -> void:
	if not has_node("/root/CanvasLayer"):
		return
	
	var canvas: CanvasLayer = get_node_or_null("/root/CanvasLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "CanvasLayer"
		get_node("/root").add_child(canvas)
	
	for child in canvas.get_children():
		child.queue_free()
	
	var filter: ColorRect = _colorblind_filters.get(mode)
	if filter:
		var new_filter: ColorRect = filter.duplicate()
		new_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(new_filter)


func _apply_text_scale(scale: float) -> void:
	var root: Node = get_tree().root
	_scale_fonts_recursive(root, scale)


func _scale_fonts_recursive(node: Node, scale: float) -> void:
	for child in node.get_children():
		if child is Label or child is Button or child is RichTextLabel:
			var base_size: int = 16
			child.add_theme_font_size_override("font_size", int(base_size * scale))
		_scale_fonts_recursive(child, scale)


func _apply_high_contrast(enabled: bool) -> void:
	if enabled:
		RenderingServer.set_default_clear_color(Color.BLACK)
	else:
		RenderingServer.set_default_clear_color(Color("#1a1a2e"))


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("accessibility", "settings", current_settings)
	config.save("user://accessibility_settings.cfg")


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load("user://accessibility_settings.cfg")
	
	if err == OK:
		var loaded_settings: Dictionary = config.get_value("accessibility", "settings", {})
		for key in loaded_settings.keys():
			current_settings[key] = loaded_settings[key]
		
		_apply_all_settings()


func _get_colorblind_mode_name(mode: ColorblindMode) -> String:
	match mode:
		ColorblindMode.NONE:
			return "Ninguno"
		ColorblindMode.DEUTERANOPIA:
			return "Deuteranopía"
		ColorblindMode.PROTANOPIA:
			return "Protanopía"
		ColorblindMode.TRITANOPIA:
			return "Tritanopía"
		_:
			return "Desconocido"
