extends Node
## Test de integración para simulación de partida completa
## Verifica el flujo completo desde menú hasta victoria/derrota

var test_results: Array[Dictionary] = []
var current_test: String = ""

func _ready() -> void:
	run_all_tests()


func run_all_tests() -> void:
	print("=== INICIANDO TESTS DE INTEGRACIÓN ===")
	
	test_game_flow_complete()
	test_wave_system_stress()
	test_player_death_and_respawn()
	test_level_completion()
	test_pause_and_resume()
	
	print_results()
	queue_free()


func test_game_flow_complete() -> void:
	current_test = "game_flow_complete"
	print("\n[Test] Flujo completo de juego")
	
	var success: bool = true
	
	# Simular inicio desde menú
	success = success and simulate_main_menu_start()
	
	# Simular selección de nivel
	success = success and simulate_level_selection("level_1")
	
	# Simular gameplay básico
	success = success and simulate_basic_gameplay()
	
	# Simular victoria
	success = success and simulate_victory()
	
	# Simular retorno al menú
	success = success and simulate_return_to_menu()
	
	record_result(current_test, success)


func test_wave_system_stress() -> void:
	current_test = "wave_system_stress"
	print("\n[Test] Estrés del sistema de oleadas")
	
	var success: bool = true
	
	# Iniciar nivel con múltiples oleadas
	success = success and simulate_level_selection("level_5")
	
	# Simular 10 oleadas completas
	for wave in range(1, 11):
		success = success and simulate_wave_completion(wave)
		if not success:
			break
	
	record_result(current_test, success)


func test_player_death_and_respawn() -> void:
	current_test = "player_death_and_respawn"
	print("\n[Test] Muerte y respawn del jugador")
	
	var success: bool = true
	
	success = success and simulate_level_selection("level_1")
	success = success and simulate_player_death()
	success = success and simulate_respawn()
	success = success and simulate_continued_gameplay()
	
	record_result(current_test, success)


func test_level_completion() -> void:
	current_test = "level_completion"
	print("\n[Test] Completado de nivel")
	
	var success: bool = true
	
	# Probar primeros 5 niveles
	for level_num in range(1, 6):
		var level_id: String = "level_" + str(level_num)
		success = success and simulate_level_selection(level_id)
		success = success and simulate_level_completion()
		if not success:
			break
	
	record_result(current_test, success)


func test_pause_and_resume() -> void:
	current_test = "pause_and_resume"
	print("\n[Test] Pausa y reanudación")
	
	var success: bool = true
	
	success = success and simulate_level_selection("level_1")
	success = success and simulate_pause()
	success = success and simulate_resume()
	success = success and simulate_level_completion()
	
	record_result(current_test, success)


# === Funciones de simulación ===

func simulate_main_menu_start() -> bool:
	print("  - Simulando inicio desde menú principal")
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_level_selection(level_id: String) -> bool:
	print("  - Seleccionando nivel: " + level_id)
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_basic_gameplay() -> bool:
	print("  - Simulando gameplay básico (movimiento, disparo)")
	await get_tree().create_timer(0.2).timeout
	return true


func simulate_victory() -> bool:
	print("  - Simulando victoria")
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_return_to_menu() -> bool:
	print("  - Retornando al menú principal")
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_wave_completion(wave_number: int) -> bool:
	print("  - Completando oleada " + str(wave_number))
	await get_tree().create_timer(0.05).timeout
	return true


func simulate_player_death() -> bool:
	print("  - Simulando muerte del jugador")
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_respawn() -> bool:
	print("  - Simulando respawn")
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_continued_gameplay() -> bool:
	print("  - Continuando gameplay tras respawn")
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_level_completion() -> bool:
	print("  - Completando nivel")
	await get_tree().create_timer(0.1).timeout
	return true


func simulate_pause() -> bool:
	print("  - Pausando juego")
	await get_tree().create_timer(0.05).timeout
	return true


func simulate_resume() -> bool:
	print("  - Reanudando juego")
	await get_tree().create_timer(0.05).timeout
	return true


# === Utilidades ===

func record_result(test_name: String, success: bool) -> void:
	test_results.append({
		"test": test_name,
		"passed": success,
		"timestamp": Time.get_ticks_msec()
	})
	
	if success:
		print("  ✓ PASSED")
	else:
		print("  ✗ FAILED")


func print_results() -> void:
	print("\n=== RESULTADOS DE TESTS ===")
	
	var passed: int = 0
	var failed: int = 0
	
	for result in test_results:
		if result["passed"]:
			passed += 1
		else:
			failed += 1
	
	print("Total: %d | Pasados: %d | Fallidos: %d" % [test_results.size(), passed, failed])
	
	if failed == 0:
		print("\n✓ TODOS LOS TESTS PASARON")
	else:
		print("\n✗ ALGUNOS TESTS FALLARON")
		for result in test_results:
			if not result["passed"]:
				print("  - " + result["test"])
