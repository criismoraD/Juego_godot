class_name EventBus
extends Node
## EventBus Global - Sistema de mensajería para desacoplar comunicación entre sistemas
## 
## Uso:
##   EventBus.emit_signal("enemy_died", enemy_id, position)
##   EventBus.connect("enemy_died", _on_enemy_died)
##
## Eventos disponibles:
##   - player_damaged(new_health: int)
##   - player_died()
##   - enemy_died(enemy_type: String, position: Vector3)
##   - wave_started(wave_number: int)
##   - wave_completed(wave_number: int)
##   - level_completed(level_number: int)
##   - projectile_hit(position: Vector3, damage: int)
##   - audio_request(sound_name: String, volume_db: float)

# Señales dinámicas del sistema
signal player_damaged(new_health: int)
signal player_died()
signal enemy_died(enemy_type: String, position: Vector3, score_value: int)
signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int, remaining_waves: int)
signal level_completed(level_number: int, is_pacifist: bool)
signal projectile_hit(position: Vector3, damage: int, hit_object: String)
signal audio_request(sound_name: String, volume_db: float, is_3d: bool, position_3d: Vector3)
signal game_paused(is_paused: bool)
signal ui_update(ui_element: String, data: Variant)

# Registro de listeners para debug
var _listeners_count: Dictionary = {}

func _ready():
	# No hacer nada especial aquí, el EventBus es pasivo
	pass

## Conecta un listener a un evento
func connect(event_name: String, callable: Callable, flags: int = 0) -> Error:
	if not _listeners_count.has(event_name):
		_listeners_count[event_name] = 0
	_listeners_count[event_name] += 1
	
	match event_name:
		"player_damaged":
			return player_damaged.connect(callable, flags)
		"player_died":
			return player_died.connect(callable, flags)
		"enemy_died":
			return enemy_died.connect(callable, flags)
		"wave_started":
			return wave_started.connect(callable, flags)
		"wave_completed":
			return wave_completed.connect(callable, flags)
		"level_completed":
			return level_completed.connect(callable, flags)
		"projectile_hit":
			return projectile_hit.connect(callable, flags)
		"audio_request":
			return audio_request.connect(callable, flags)
		"game_paused":
			return game_paused.connect(callable, flags)
		"ui_update":
			return ui_update.connect(callable, flags)
		_:
			push_warning("[EventBus] Evento desconocido: " + event_name)
			return ERR_DOES_NOT_EXIST

## Desconecta un listener de un evento
func disconnect(event_name: String, callable: Callable) -> Error:
	if _listeners_count.has(event_name):
		_listeners_count[event_name] = max(0, _listeners_count[event_name] - 1)
	
	match event_name:
		"player_damaged":
			return player_damaged.disconnect(callable)
		"player_died":
			return player_died.disconnect(callable)
		"enemy_died":
			return enemy_died.disconnect(callable)
		"wave_started":
			return wave_started.disconnect(callable)
		"wave_completed":
			return wave_completed.disconnect(callable)
		"level_completed":
			return level_completed.disconnect(callable)
		"projectile_hit":
			return projectile_hit.disconnect(callable)
		"audio_request":
			return audio_request.disconnect(callable)
		"game_paused":
			return game_paused.disconnect(callable)
		"ui_update":
			return ui_update.disconnect(callable)
		_:
			return ERR_DOES_NOT_EXIST

## Emite un evento con datos opcionales
func emit_event(event_name: String, args: Array = []) -> void:
	match event_name:
		"player_damaged":
			player_damaged.emit(args[0] if args.size() > 0 else 0)
		"player_died":
			player_died.emit()
		"enemy_died":
			enemy_died.emit(
				args[0] if args.size() > 0 else "",
				args[1] if args.size() > 1 else Vector3.ZERO,
				args[2] if args.size() > 2 else 0
			)
		"wave_started":
			wave_started.emit(
				args[0] if args.size() > 0 else 0,
				args[1] if args.size() > 1 else 0
			)
		"wave_completed":
			wave_completed.emit(
				args[0] if args.size() > 0 else 0,
				args[1] if args.size() > 1 else 0
			)
		"level_completed":
			level_completed.emit(
				args[0] if args.size() > 0 else 0,
				args[1] if args.size() > 1 else false
			)
		"projectile_hit":
			projectile_hit.emit(
				args[0] if args.size() > 0 else Vector3.ZERO,
				args[1] if args.size() > 1 else 0,
				args[2] if args.size() > 2 else ""
			)
		"audio_request":
			audio_request.emit(
				args[0] if args.size() > 0 else "",
				args[1] if args.size() > 1 else 0.0,
				args[2] if args.size() > 2 else false,
				args[3] if args.size() > 3 else Vector3.ZERO
			)
		"game_paused":
			game_paused.emit(args[0] if args.size() > 0 else false)
		"ui_update":
			ui_update.emit(
				args[0] if args.size() > 0 else "",
				args[1] if args.size() > 1 else null
			)
		_:
			push_warning("[EventBus] Intento de emitir evento desconocido: " + event_name)

## Obtiene estadísticas de listeners conectados (para debug)
func get_listener_stats() -> Dictionary:
	return _listeners_count.duplicate()

## Limpia todas las conexiones (solo usar en tests o reset completo)
func clear_all_connections() -> void:
	var events = ["player_damaged", "player_died", "enemy_died", "wave_started", 
				  "wave_completed", "level_completed", "projectile_hit", 
				  "audio_request", "game_paused", "ui_update"]
	for event in events:
		match event:
			"player_damaged":
				for conn in player_damaged.get_connections():
					player_damaged.disconnect(conn["callable"])
			"player_died":
				for conn in player_died.get_connections():
					player_died.disconnect(conn["callable"])
			"enemy_died":
				for conn in enemy_died.get_connections():
					enemy_died.disconnect(conn["callable"])
			"wave_started":
				for conn in wave_started.get_connections():
					wave_started.disconnect(conn["callable"])
			"wave_completed":
				for conn in wave_completed.get_connections():
					wave_completed.disconnect(conn["callable"])
			"level_completed":
				for conn in level_completed.get_connections():
					level_completed.disconnect(conn["callable"])
			"projectile_hit":
				for conn in projectile_hit.get_connections():
					projectile_hit.disconnect(conn["callable"])
			"audio_request":
				for conn in audio_request.get_connections():
					audio_request.disconnect(conn["callable"])
			"game_paused":
				for conn in game_paused.get_connections():
					game_paused.disconnect(conn["callable"])
			"ui_update":
				for conn in ui_update.get_connections():
					ui_update.disconnect(conn["callable"])
	_listeners_count.clear()
