class_name AutoBalancer
extends Node
## Simulador de miles de partidas para ajuste automático de dificultad
## Analiza estadísticas y sugiere balanceos de enemigos, armas y niveles

signal simulation_complete(stats: Dictionary)
signal balance_suggestion_ready(suggestion: Dictionary)

@export var simulations_per_run: int = 1000
@export var player_skill_levels: Array[float] = [0.3, 0.5, 0.7, 0.9]
@export var debug_mode: bool = false

var _simulation_results: Array[Dictionary] = []
var _enemy_stats: Dictionary = {}
var _weapon_stats: Dictionary = {}
var _level_stats: Dictionary = {}

func _ready() -> void:
	pass


func run_full_simulation() -> void:
	print("Iniciando simulación de " + str(simulations_per_run) + " partidas...")
	
	_simulation_results.clear()
	
	for i in range(simulations_per_run):
		var skill_index: int = randi() % player_skill_levels.size()
		var player_skill: float = player_skill_levels[skill_index]
		
		var result: Dictionary = simulate_single_game(player_skill)
		_simulation_results.append(result)
		
		if debug_mode and i % 100 == 0:
			print("  Progreso: " + str(i) + "/" + str(simulations_per_run))
	
	analyze_results()
	simulation_complete.emit(get_aggregate_stats())


func simulate_single_game(player_skill: float) -> Dictionary:
	var result: Dictionary = {
		"player_skill": player_skill,
		"completed": false,
		"time_elapsed": 0.0,
		"deaths": 0,
		"enemies_defeated": 0,
		"damage_taken": 0,
		"damage_dealt": 0,
		"health_potions_used": 0,
		"level_reached": 0
	}
	
	var current_health: float = 100.0
	var max_health: float = 100.0
	var level: int = 1
	
	while current_health > 0 and level <= 30:
		result["level_reached"] = level
		
		var level_data: Dictionary = simulate_level(level, player_skill, current_health)
		
		result["time_elapsed"] += level_data["time"]
		result["enemies_defeated"] += level_data["enemies_defeated"]
		result["damage_taken"] += level_data["damage_taken"]
		result["damage_dealt"] += level_data["damage_dealt"]
		result["health_potions_used"] += level_data["potions_used"]
		
		current_health -= level_data["damage_taken"]
		
		if current_health <= 0:
			result["deaths"] += 1
			current_health = max_health * 0.5  # Respawn con mitad de vida
		else:
			result["completed"] = level == 30
			level += 1
	
	return result


func simulate_level(level: int, player_skill: float, current_health: float) -> Dictionary:
	var result: Dictionary = {
		"time": 0.0,
		"enemies_defeated": 0,
		"damage_taken": 0.0,
		"damage_dealt": 0.0,
		"potions_used": 0
	}
	
	var base_enemy_count: int = 5 + level * 2
	var enemy_difficulty_multiplier: float = 1.0 + (level * 0.1)
	
	for e in range(base_enemy_count):
		var enemy_result: Dictionary = simulate_enemy_encounter(
			player_skill, 
			current_health, 
			enemy_difficulty_multiplier
		)
		
		result["damage_taken"] += enemy_result["damage_to_player"]
		result["damage_dealt"] += enemy_result["damage_to_enemy"]
		result["enemies_defeated"] += 1 if enemy_result["enemy_defeated"] else 0
		
		if enemy_result["time_taken"] > 0:
			result["time"] += enemy_result["time_taken"]
		
		if current_health - result["damage_taken"] < 25 and result["potions_used"] < 3:
			result["potions_used"] += 1
			current_health += 30
	
	result["time"] += 30.0  # Tiempo base por nivel
	
	return result


func simulate_enemy_encounter(player_skill: float, player_health: float, difficulty_mult: float) -> Dictionary:
	var result: Dictionary = {
		"damage_to_player": 0.0,
		"damage_to_enemy": 0.0,
		"enemy_defeated": false,
		"time_taken": 0.0
	}
	
	var enemy_health: float = 20.0 * difficulty_mult
	var enemy_damage: float = 5.0 * difficulty_mult
	var player_damage: float = 10.0 * (0.5 + player_skill)
	
	var accuracy: float = 0.5 + (player_skill * 0.4)  # 50% a 90%
	var dodge_chance: float = player_skill * 0.3  # 0% a 30%
	
	var turns: int = 0
	while enemy_health > 0 and player_health - result["damage_to_player"] > 0:
		turns += 1
		
		# Turno del jugador
		if randf() < accuracy:
			var damage: float = player_damage * (0.8 + randf() * 0.4)
			result["damage_to_enemy"] += damage
			enemy_health -= damage
		
		# Turno del enemigo
		if enemy_health > 0 and randf() > dodge_chance:
			var damage: float = enemy_damage * (0.8 + randf() * 0.4)
			result["damage_to_player"] += damage
		
		if turns > 50:  # Límite de seguridad
			break
	
	result["enemy_defeated"] = enemy_health <= 0
	result["time_taken"] = float(turns) * 0.5
	
	return result


func analyze_results() -> void:
	_analyze_enemy_balance()
	_analyze_weapon_balance()
	_analyze_level_difficulty()
	
	generate_suggestions()


func _analyze_enemy_balance() -> void:
	_enemy_stats = {
		"avg_time_to_defeat": 0.0,
		"avg_damage_to_player": 0.0,
		"kill_rate": 0.0
	}
	
	var total_damage: float = 0.0
	var total_time: float = 0.0
	var total_enemies: int = 0
	
	for result in _simulation_results:
		total_damage += result["damage_taken"]
		total_time += result["time_elapsed"]
		total_enemies += result["enemies_defeated"]
	
	if total_enemies > 0:
		_enemy_stats["avg_damage_to_player"] = total_damage / total_enemies
		_enemy_stats["avg_time_to_defeat"] = total_time / total_enemies
	
	_enemy_stats["kill_rate"] = float(total_enemies) / float(_simulation_results.size())


func _analyze_weapon_balance() -> void:
	_weapon_stats = {
		"dps_effective": 0.0,
		"ttk_average": 0.0
	}
	
	var total_damage_dealt: float = 0.0
	var total_time: float = 0.0
	
	for result in _simulation_results:
		total_damage_dealt += result["damage_dealt"]
		total_time += result["time_elapsed"]
	
	if total_time > 0:
		_weapon_stats["dps_effective"] = total_damage_dealt / total_time
	
	if _weapon_stats["dps_effective"] > 0:
		_weapon_stats["ttk_average"] = 20.0 / _weapon_stats["dps_effective"]  # TTK para enemigo base


func _analyze_level_difficulty() -> void:
	_level_stats = {
		"completion_rate_by_level": {},
		"avg_deaths_by_level": {},
		"difficulty_spikes": []
	}
	
	var level_completions: Dictionary = {}
	var level_deaths: Dictionary = {}
	
	for result in _simulation_results:
		var level: int = result["level_reached"]
		
		for l in range(1, level + 1):
			if l not in level_completions:
				level_completions[l] = 0
				level_deaths[l] = 0
			
			if l < result["level_reached"]:
				level_completions[l] += 1
			elif l == result["level_reached"] and not result["completed"]:
				level_deaths[l] += 1
	
	for level in level_completions.keys():
		var total: int = _simulation_results.size()
		var completions: int = level_completions[level]
		var deaths: int = level_deaths.get(level, 0)
		
		_level_stats["completion_rate_by_level"][str(level)] = float(completions) / float(total)
		_level_stats["avg_deaths_by_level"][str(level)] = float(deaths) / float(total)
		
		# Detectar picos de dificultad (>20% más muertes que el nivel anterior)
		if level > 1:
			var prev_deaths: float = _level_stats["avg_deaths_by_level"].get(str(level - 1), 0.0)
			var curr_deaths: float = _level_stats["avg_deaths_by_level"][str(level)]
			
			if prev_deaths > 0 and (curr_deaths - prev_deaths) / prev_deaths > 0.2:
				_level_stats["difficulty_spikes"].append(level)


func generate_suggestions() -> void:
	var suggestions: Array[Dictionary] = []
	
	# Sugerencias para enemigos
	if _enemy_stats["avg_damage_to_player"] > 15.0:
		suggestions.append({
			"type": "enemy_damage",
			"priority": "HIGH",
			"message": "Los enemigos hacen demasiado daño. Reducir un 15-20%.",
			"suggested_change": -0.20
		})
	
	if _enemy_stats["avg_time_to_defeat"] > 30.0:
		suggestions.append({
			"type": "enemy_health",
			"priority": "MEDIUM",
			"message": "Los enemigos tardan mucho en derrotar. Reducir vida un 10-15%.",
			"suggested_change": -0.15
		})
	
	# Sugerencias para niveles
	for spike in _level_stats["difficulty_spikes"]:
		suggestions.append({
			"type": "level_difficulty",
			"priority": "HIGH",
			"message": "El nivel " + str(spike) + " tiene un pico de dificultad. Revisar diseño.",
			"level": spike
		})
	
	# Sugerencias generales
	var overall_completion: float = 0.0
	for result in _simulation_results:
		if result["completed"]:
			overall_completion += 1.0
	overall_completion /= float(_simulation_results.size())
	
	if overall_completion < 0.3:
		suggestions.append({
			"type": "overall_difficulty",
			"priority": "CRITICAL",
			"message": "Menos del 30% completa el juego. Reducir dificultad global.",
			"suggested_change": -0.25
		})
	elif overall_completion > 0.8:
		suggestions.append({
			"type": "overall_difficulty",
			"priority": "LOW",
			"message": "Más del 80% completa el juego. Podría ser muy fácil.",
			"suggested_change": 0.10
		})
	
	for suggestion in suggestions:
		balance_suggestion_ready.emit(suggestion)
		if debug_mode:
			print("[SUGERENCIA][" + suggestion["priority"] + "] " + suggestion["message"])


func get_aggregate_stats() -> Dictionary:
	return {
		"total_simulations": _simulation_results.size(),
		"overall_completion_rate": _calculate_completion_rate(),
		"avg_deaths": _calculate_avg_deaths(),
		"avg_time": _calculate_avg_time(),
		"enemy_stats": _enemy_stats,
		"weapon_stats": _weapon_stats,
		"level_stats": _level_stats
	}


func _calculate_completion_rate() -> float:
	var completions: int = 0
	for result in _simulation_results:
		if result["completed"]:
			completions += 1
	return float(completions) / float(_simulation_results.size()) if _simulation_results.size() > 0 else 0.0


func _calculate_avg_deaths() -> float:
	var total_deaths: int = 0
	for result in _simulation_results:
		total_deaths += result["deaths"]
	return float(total_deaths) / float(_simulation_results.size()) if _simulation_results.size() > 0 else 0.0


func _calculate_avg_time() -> float:
	var total_time: float = 0.0
	for result in _simulation_results:
		total_time += result["time_elapsed"]
	return total_time / float(_simulation_results.size()) if _simulation_results.size() > 0 else 0.0


func export_results_to_json() -> String:
	var stats: Dictionary = get_aggregate_stats()
	return JSON.stringify(stats, "\t")
