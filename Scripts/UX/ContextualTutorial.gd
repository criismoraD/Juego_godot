class_name ContextualTutorial
extends Node
## Sistema inteligente de tutoriales contextuales
## Detecta patrones de fallo y ofrece ayudas relevantes

signal tutorial_shown(tutorial_id: String, message: String)
signal player_improved(skill: String)

@export var debug_mode: bool = false

const SKILL_DEATHS_TO_HINT: int = 3
const SKILL_FAILURES_TO_HINT: int = 5

var _player_stats: Dictionary = {
	"deaths_by_enemy": {},
	"deaths_by_trap": 0,
	"failed_jumps": 0,
	"missed_shots": 0,
	"times_low_health": 0,
	"enemies_not_defeated": 0,
	"time_in_level": 0.0
}

var _shown_hints: Array[String] = []
var _current_level: String = ""
var _level_start_time: float = 0.0

func _ready() -> void:
	_load_player_stats()
	_connect_to_events()


func _connect_to_events() -> void:
	if EventBus:
		EventBus.player_damaged.connect(_on_player_damaged)
		EventBus.player_died.connect(_on_player_died)
		EventBus.enemy_spawned.connect(_on_enemy_spawned)
		EventBus.wave_cleared.connect(_on_wave_cleared)


func start_level(level_id: String) -> void:
	_current_level = level_id
	_level_start_time = Time.get_ticks_msec() / 1000.0
	_player_stats["time_in_level"] = 0.0


func end_level(completed: bool) -> void:
	var level_time: float = (Time.get_ticks_msec() / 1000.0) - _level_start_time
	_player_stats["time_in_level"] += level_time
	
	if completed:
		_reset_level_stats()
	
	_save_player_stats()


func register_death(enemy_type: String = "") -> void:
	if enemy_type.is_empty():
		_player_stats["deaths_by_trap"] += 1
	else:
		if enemy_type not in _player_stats["deaths_by_enemy"]:
			_player_stats["deaths_by_enemy"][enemy_type] = 0
		_player_stats["deaths_by_enemy"][enemy_type] += 1
	
	_check_for_death_hints(enemy_type)


func register_failed_jump() -> void:
	_player_stats["failed_jumps"] += 1
	_check_for_jump_hint()


func register_missed_shot() -> void:
	_player_stats["missed_shots"] += 1
	_check_for_aim_hint()


func register_low_health() -> void:
	_player_stats["times_low_health"] += 1
	_check_for_health_hint()


func show_hint(hint_id: String, force: bool = false) -> void:
	if not force and hint_id in _shown_hints:
		if debug_mode:
			print("Hint ya mostrado: " + hint_id)
		return
	
	var message: String = _get_hint_message(hint_id)
	if message.is_empty():
		return
	
	_shown_hints.append(hint_id)
	tutorial_shown.emit(hint_id, message)
	
	if debug_mode:
		print("[TUTORIAL] " + hint_id + ": " + message)


func reset_all_progress() -> void:
	_player_stats.clear()
	_shown_hints.clear()
	_save_player_stats()


func get_player_skill_level(skill: String) -> String:
	var stat_value: int = _get_stat_for_skill(skill)
	
	if stat_value < 2:
		return "EXPERTO"
	elif stat_value < 5:
		return "INTERMEDIO"
	else:
		return "PRINCIPIANTE"


func has_seen_hint(hint_id: String) -> bool:
	return hint_id in _shown_hints


func _check_for_death_hints(enemy_type: String) -> void:
	if enemy_type.is_empty():
		if _player_stats["deaths_by_trap"] >= SKILL_DEATHS_TO_HINT:
			show_hint("trap_awareness")
		return
	
	var deaths: int = _player_stats["deaths_by_enemy"].get(enemy_type, 0)
	if deaths >= SKILL_DEATHS_TO_HINT:
		var hint_id: String = "enemy_strategy_" + enemy_type
		show_hint(hint_id)


func _check_for_jump_hint() -> void:
	if _player_stats["failed_jumps"] >= SKILL_FAILURES_TO_HINT:
		show_hint("jump_timing")


func _check_for_aim_hint() -> void:
	if _player_stats["missed_shots"] >= SKILL_FAILURES_TO_HINT:
		show_hint("aiming_basics")


func _check_for_health_hint() -> void:
	if _player_stats["times_low_health"] >= SKILL_FAILURES_TO_HINT:
		show_hint("health_management")


func _get_hint_message(hint_id: String) -> String:
	match hint_id:
		"trap_awareness":
			return "Consejo: Observa el entorno antes de avanzar. Las trampas suelen tener patrones visibles."
		"jump_timing":
			return "Consejo: Mantén presionado el botón de salto para saltos más altos. Practica el timing en zonas seguras."
		"aiming_basics":
			return "Consejo: El juego tiene aim assist. Mantén el cursor cerca del enemigo para mejorar la precisión."
		"health_management":
			return "Consejo: No esperes a estar bajo de vida para buscar curación. Los kits de salud aparecen tras limpiar oleadas."
		"enemy_strategy_basic":
			return "Consejo: Los enemigos básicos son débiles pero numerosos. Prioriza los que están más cerca."
		"enemy_strategy_shooter":
			return "Consejo: Los enemigos a distancia son vulnerables cuando recargan. Aprovecha esos momentos."
		"enemy_strategy_tank":
			return "Consejo: Los tanques son lentos pero resistentes. Ataca por la espalda cuando sea posible."
		_:
			return ""


func _get_stat_for_skill(skill: String) -> int:
	match skill:
		"jumping":
			return _player_stats.get("failed_jumps", 0)
		"aiming":
			return _player_stats.get("missed_shots", 0)
		"survival":
			return _player_stats.get("times_low_health", 0)
		"trap_avoidance":
			return _player_stats.get("deaths_by_trap", 0)
		_:
			return 0


func _on_player_damaged(amount: int, damage_source: String) -> void:
	if amount > 0:
		register_low_health()


func _on_player_died(killer: String = "") -> void:
	register_death(killer)


func _on_enemy_spawned(enemy_type: String, _position: Vector2) -> void:
	pass


func _on_wave_cleared(_wave_number: int) -> void:
	pass


func _reset_level_stats() -> void:
	_player_stats["failed_jumps"] = 0
	_player_stats["missed_shots"] = 0
	_player_stats["times_low_health"] = 0


func _save_player_stats() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("tutorials", "stats", _player_stats)
	config.set_value("tutorials", "shown_hints", _shown_hints)
	config.save("user://tutorial_progress.cfg")


func _load_player_stats() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load("user://tutorial_progress.cfg")
	
	if err == OK:
		_player_stats = config.get_value("tutorials", "stats", {})
		_shown_hints = config.get_value("tutorials", "shown_hints", [])
