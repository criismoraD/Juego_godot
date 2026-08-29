class_name LoadingScreen
extends CanvasLayer

@onready var root_control: Control = $RootControl
@onready var tip_label: Label = %TipLabel
@onready var percent_label: Label = %PercentLabel
@onready var progress_bar: ProgressBar = %ProgressBar

var _target_progress: float = 0.0
var _current_progress: float = 0.0
var _anim_speed: float = 8.0
var _fading_out: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 250
	progress_bar.value = 0.0
	percent_label.text = "0%"
	if is_instance_valid(tip_label):
		tip_label.text = "Cargando..."


func _process(delta: float) -> void:
	if _current_progress < _target_progress:
		_current_progress = move_toward(_current_progress, _target_progress, _anim_speed * delta * maxf(1.0, (_target_progress - _current_progress) * 4.0))
		progress_bar.value = _current_progress * 100.0
		percent_label.text = "%d%%" % int(_current_progress * 100.0)


func set_progress(val: float) -> void:
	_target_progress = clampf(val, 0.0, 1.0)


func set_status_text(text: String) -> void:
	if is_instance_valid(tip_label):
		tip_label.text = text


## Transición de entrada
func fade_in(duration: float = 0.25) -> void:
	if is_instance_valid(root_control):
		root_control.modulate.a = 0.0
		var tween := create_tween()
		if tween:
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(root_control, "modulate:a", 1.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Transición de salida (Fade out hacia la nueva escena y auto-eliminación)
func fade_out(duration: float = 0.35) -> void:
	if _fading_out:
		return
	_fading_out = true

	if is_instance_valid(root_control):
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tween := create_tween()
	if tween:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		if is_instance_valid(root_control):
			tween.tween_property(root_control, "modulate:a", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(self._on_fade_out_finished)

	var safety_timer := get_tree().create_timer(duration + 0.15, false, false, true)
	safety_timer.timeout.connect(self._on_fade_out_finished)


func _on_fade_out_finished() -> void:
	if is_instance_valid(self):
		queue_free()