class_name ScreenShake
extends Node
## Sistema de screen shake con curvas configurables
## Se usa añadiendo este nodo al Camera2D principal

@export var default_duration: float = 0.3
@export var default_intensity: float = 10.0
@export var decay_curve: Curve = null

var _camera: Camera2D
var _shake_active: bool = false
var _shake_timer: float = 0.0
var _initial_offset: Vector2
var _current_intensity: float = 0.0
var _noise: FastNoiseLite

func _ready() -> void:
	_camera = get_parent() as Camera2D
	if not _camera:
		push_error("ScreenShake: Debe ser hijo de Camera2D")
		return
	
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 2.0
	_noise.noise_type = FastNoiseLite.TYPE_WHITE


func _physics_process(delta: float) -> void:
	if not _shake_active or not _camera:
		return
	
	_shake_timer -= delta
	
	if _shake_timer <= 0:
		_stop_shake()
		return
	
	var progress: float = 1.0 - (_shake_timer / default_duration)
	var intensity_multiplier: float = _calculate_intensity(progress)
	
	var shake_offset: Vector2 = Vector2(
		_noise.get_noise_1d(Time.get_ticks_msec() * 0.001) * _current_intensity * intensity_multiplier,
		_noise.get_noise_1d(Time.get_ticks_msec() * 0.001 + 1000) * _current_intensity * intensity_multiplier
	)
	
	_camera.offset = _initial_offset + shake_offset


func start_shake(duration: float = -1, intensity: float = -1, priority: int = 0) -> void:
	if duration < 0:
		duration = default_duration
	if intensity < 0:
		intensity = default_intensity
	
	if _shake_active and priority <= 0:
		return
	
	_shake_active = true
	_shake_timer = duration
	_current_intensity = intensity
	_initial_offset = _camera.offset if _camera else Vector2.ZERO
	
	if decay_curve == null:
		decay_curve = Curve.new()
		decay_curve.add_point(0.0, 1.0)
		decay_curve.add_point(1.0, 0.0)


func stop_shake() -> void:
	_stop_shake()


func add_shake(duration: float, intensity: float, fade_in: float = 0.0) -> void:
	if not _shake_active:
		start_shake(duration, intensity)
		return
	
	if intensity > _current_intensity:
		_current_intensity = intensity
		_shake_timer = max(_shake_timer, duration)


func is_shaking() -> bool:
	return _shake_active


func get_remaining_time() -> float:
	return _shake_timer if _shake_active else 0.0


func _calculate_intensity(progress: float) -> float:
	if decay_curve:
		return decay_curve.sample_baked(progress)
	
	return 1.0 - progress


func _stop_shake() -> void:
	_shake_active = false
	_shake_timer = 0.0
	_current_intensity = 0.0
	
	if _camera:
		_camera.offset = _initial_offset
