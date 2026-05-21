class_name HitPause
extends Node
## Sistema de pausas dramáticas al impactar enemigos
## Añade peso y feedback visual a los combates

signal pause_started(duration: float)
signal pause_ended()

@export var default_duration: float = 0.1
@export var max_duration: float = 0.3
@export var cooldown: float = 0.2

var _time_scale_target: float = 1.0
var _pause_active: bool = false
var _pause_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _original_time_scale: float = 1.0

func _ready() -> void:
	_original_time_scale = Engine.time_scale


func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta
		return
	
	if not _pause_active:
		return
	
	_pause_timer -= delta
	
	if _pause_timer <= 0:
		_end_pause()
		return
	
	var progress: float = _pause_timer / default_duration
	Engine.time_scale = lerp(_time_scale_target, _original_time_scale, progress)


func trigger(duration: float = -1, time_scale: float = 0.1, force: bool = false) -> void:
	if not force and _cooldown_timer > 0:
		return
	
	if duration < 0:
		duration = default_duration
	
	duration = min(duration, max_duration)
	
	_pause_active = true
	_pause_timer = duration
	_time_scale_target = time_scale
	_cooldown_timer = cooldown + duration
	
	Engine.time_scale = time_scale
	pause_started.emit(duration)


func trigger_light() -> void:
	trigger(0.05, 0.3)


func trigger_heavy() -> void:
	trigger(0.2, 0.05)


func cancel() -> void:
	if _pause_active:
		_end_pause()


func is_active() -> bool:
	return _pause_active


func get_remaining_time() -> float:
	return _pause_timer if _pause_active else 0.0


func set_default_duration(duration: float) -> void:
	default_duration = clamp(duration, 0.01, max_duration)


func set_max_duration(duration: float) -> void:
	max_duration = max(duration, default_duration)


func _end_pause() -> void:
	_pause_active = false
	_pause_timer = 0.0
	Engine.time_scale = _original_time_scale
	pause_ended.emit()
