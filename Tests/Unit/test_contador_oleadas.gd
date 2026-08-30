extends "res://addons/gut/test.gd"

var WaveSpawnerScript = load("res://System/Core/WaveSpawner.gd")
var _spawner: WaveSpawner = null

func before_each():
	_spawner = WaveSpawnerScript.new()
	add_child_autofree(_spawner)
	_spawner._ready()
	_spawner.is_wave_active = false

func test_oleada_1_total_15_enemigos_barra_progreso():
	# Arrange: 3 enemigos pacíficos ya presentes en active_goblins
	var dummy1 := Node3D.new()
	var dummy2 := Node3D.new()
	var dummy3 := Node3D.new()
	add_child_autofree(dummy1)
	add_child_autofree(dummy2)
	add_child_autofree(dummy3)
	_spawner.active_goblins = [dummy1, dummy2, dummy3]

	# Act: Iniciar oleada 1
	_spawner.oleada_combate = 1
	_spawner._start_wave()

	# Assert: total 15 (12 en cola + 3 pacíficos), 0 muertos al inicio
	assert_eq(_spawner.enemigos_por_oleada, 15, "Oleada 1 debe tener exactamente 15 enemigos")
	assert_eq(_spawner.cola_spawn.size(), 12, "La cola de la Oleada 1 debe tener 12 enemigos")
	assert_eq(_spawner.goblins_spawned_in_wave, 3, "Los 3 pacíficos cuentan como ya spawneados")
	assert_eq(_spawner.enemigos_muertos_en_oleada, 0, "Al inicio debe haber 0 muertos")

func test_oleada_2_total_25_enemigos_barra_progreso():
	# Act: Iniciar oleada 2
	_spawner.oleada_combate = 2
	_spawner._start_wave()

	# Assert: 25 enemigos totales y en cola
	assert_eq(_spawner.enemigos_por_oleada, 25, "Oleada 2 debe tener 25 enemigos")
	assert_eq(_spawner.cola_spawn.size(), 25, "La cola de la Oleada 2 debe tener 25 enemigos")

func test_oleada_3_total_30_enemigos_barra_progreso():
	# Act: Iniciar oleada 3
	_spawner.oleada_combate = 3
	_spawner._start_wave()

	# Assert: 30 enemigos totales y en cola
	assert_eq(_spawner.enemigos_por_oleada, 30, "Oleada 3 debe tener 30 enemigos")
	assert_eq(_spawner.cola_spawn.size(), 30, "La cola de la Oleada 3 debe tener 30 enemigos")

func test_oleada_4_total_45_enemigos_barra_progreso_con_cuerno():
	# Act: Iniciar oleada 4
	_spawner.oleada_combate = 4
	_spawner._start_wave()

	# Assert: Total en barra es 45 inmediatamente desde el inicio
	assert_eq(_spawner.enemigos_por_oleada, 45, "Oleada 4 debe mostrar 45 enemigos en la barra de progreso")
	assert_eq(_spawner.cola_spawn.size(), 34, "La cola base de Oleada 4 es 34 (el Globo spawnea aparte, 3s antes del cuerno)")

	# Act: El Globo reemplaza a 1 ballestero (spawnea 3s antes del cuerno)
	_spawner._spawnear_globo_oleada_4()

	# Act: Disparo de evento cuerno (refuerzos +10: 8 ballestas + 2 imps)
	_spawner._iniciar_evento_cuerno(10, false)

	# Assert: Total se mantiene firme en 45 y la suma de cola + spawneados es 45
	assert_eq(_spawner.enemigos_por_oleada, 45, "Total en barra debe mantenerse en 45")
	assert_eq(_spawner.cola_spawn.size() + _spawner.goblins_spawned_in_wave, 45, "La suma de cola y spawneados debe ser 45")

func test_oleada_5_total_50_enemigos_barra_progreso_con_cuerno():
	# Act: Iniciar oleada 5
	_spawner.oleada_combate = 5
	_spawner._start_wave()

	# Assert: Total en barra es 50 inmediatamente desde el inicio
	assert_eq(_spawner.enemigos_por_oleada, 50, "Oleada 5 debe mostrar 50 enemigos en la barra de progreso")
	assert_eq(_spawner.cola_spawn.size(), 40, "La cola inicial base de Oleada 5 es 40")

	# Act: Disparo de evento cuerno (refuerzos +10: 5 arqueras + 5 ballestas)
	_spawner._iniciar_evento_cuerno(10, false)

	# Assert: Total se mantiene firme en 50 y la cola suma los 10 refuerzos
	assert_eq(_spawner.enemigos_por_oleada, 50, "Total en barra debe mantenerse en 50")
	assert_eq(_spawner.cola_spawn.size(), 50, "La cola con refuerzos debe sumar 50")

func test_oleada_no_termina_prematuramente_si_quedan_enemigos_en_cola_o_activos():
	# Arrange
	_spawner.oleada_combate = 2
	_spawner._start_wave()
	_spawner.enemigos_muertos_en_oleada = 10
	_spawner.goblins_spawned_in_wave = 15

	watch_signals(_spawner)

	# Act: Ejecutar chequeo de fin de oleada con cola aún llena
	_spawner._check_wave_complete()

	# Assert: NO debe terminar la oleada
	assert_true(_spawner.is_wave_active, "La oleada debe permanecer activa mientras haya enemigos en cola")
	assert_signal_not_emitted(_spawner, "oleada_completada", "NO debe emitir oleada_completada prematuramente")

func test_oleada_termina_unicamente_al_matar_todos_los_enemigos():
	# Arrange
	_spawner.oleada_combate = 2
	_spawner._start_wave()
	_spawner.cola_spawn.clear()
	_spawner.active_goblins.clear()
	_spawner.goblins_spawned_in_wave = 25
	_spawner.enemigos_muertos_en_oleada = 25

	watch_signals(_spawner)

	# Act
	_spawner._check_wave_complete()

	# Assert: Termina exactamente al cumplir todos los requisitos
	assert_false(_spawner.is_wave_active, "La oleada debe finalizar cuando cola y activos estén vacíos y muertes completadas")
	assert_signal_emitted(_spawner, "oleada_completada", "Debe emitir oleada_completada al culminar al 100%")
