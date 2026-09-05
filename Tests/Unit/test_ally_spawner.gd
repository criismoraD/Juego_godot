extends GutTest

## Tests unitarios para el Spawner de Aliadas de Refuerzo en Nivel 6.
## Verifica la correcta instanciación de 1 Ballestera (último piso) y 9 Arqueras.

var AllySpawnerScript = load("res://Entities/Spawner_Aliadas/AllySpawner.gd")
var EscenaSpawner: PackedScene = load("res://Entities/Spawner_Aliadas/AllySpawner.tscn")
var EscenaNivel06: PackedScene = load("res://Levels/NIVEL06_ASALTO/NIVEL06_ASALTO.tscn")

var _spawner: AllySpawner = null
var _created_nodes: Array[Node] = []

class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false

func before_each():
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

func after_each():
	for node in _created_nodes:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.free()
	_created_nodes.clear()

	if is_instance_valid(_spawner):
		for ally in _spawner.aliadas_instanciadas:
			if is_instance_valid(ally):
				if ally.get_parent():
					ally.get_parent().remove_child(ally)
				ally.free()
		if _spawner.get_parent():
			_spawner.get_parent().remove_child(_spawner)
		_spawner.free()
		_spawner = null

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false

func test_ally_spawner_configuracion_por_defecto():
	_spawner = EscenaSpawner.instantiate() as AllySpawner
	_spawner.auto_iniciar = false
	add_child(_spawner)

	# 1 Ballestera y 9 Arqueras = 10 aliadas en total
	assert_eq(_spawner.distribucion_ballestera.size(), 1, "Debe haber exactamente 1 Ballestera configurada")
	assert_eq(_spawner.distribucion_arqueras.size(), 9, "Deben haber exactamente 9 Arqueras configuradas")

	# La ballestera siempre debe estar en el último piso (Piso 3)
	var ballestera_cfg: Dictionary = _spawner.distribucion_ballestera[0]
	assert_eq(ballestera_cfg.get("piso"), 3, "La Ballestera siempre debe estar asignada al piso 3 (último piso)")

	# Las 9 arqueras distribuidas en pisos 0, 1, 2 y 3
	var pisos_presentes: Array[int] = []
	for cfg: Dictionary in _spawner.distribucion_arqueras:
		var p: int = cfg.get("piso", -1)
		if not pisos_presentes.has(p):
			pisos_presentes.append(p)
	assert_true(pisos_presentes.has(0), "Debe haber arqueras en piso 0")
	assert_true(pisos_presentes.has(1), "Debe haber arqueras en piso 1")
	assert_true(pisos_presentes.has(2), "Debe haber arqueras en piso 2")
	assert_true(pisos_presentes.has(3), "Debe haber arqueras en piso 3")

func test_ally_spawner_spawn_ballestera_individual():
	_spawner = EscenaSpawner.instantiate() as AllySpawner
	_spawner.auto_iniciar = false
	add_child(_spawner)
	_spawner.global_position = Vector3(-13.5, 0.185, 3.0)

	var ballestera: Node3D = _spawner.spawn_aliada(AllySpawner.TIPO_BALLESTERA, 3, -8.7)
	assert_not_null(ballestera, "La ballestera no debe ser nula")
	_created_nodes.append(ballestera)

	assert_true(ballestera is AllyBallestera, "La entidad instanciada debe ser de tipo AllyBallestera")
	assert_true(ballestera.es_movil, "La ballestera debe ser móvil para desplazarse")
	assert_eq(ballestera.plataforma_asignada, 3, "La plataforma asignada debe ser 3")
	assert_true(ballestera.en_despliegue, "La ballestera debe iniciar en estado en_despliegue")
	assert_almost_eq(ballestera.global_position.z, 3.0, 0.05, "El plano Z de la ballestera debe ser 3.0")

func test_ally_spawner_spawn_arquera_individual():
	_spawner = EscenaSpawner.instantiate() as AllySpawner
	_spawner.auto_iniciar = false
	add_child(_spawner)
	_spawner.global_position = Vector3(-13.5, 0.185, 3.0)

	var arquera: Node3D = _spawner.spawn_aliada(AllySpawner.TIPO_ARQUERA, 2, -7.7)
	assert_not_null(arquera, "La arquera no debe ser nula")
	_created_nodes.append(arquera)

	assert_true(arquera is AllyArcher, "La entidad instanciada debe ser de tipo AllyArcher")
	assert_true(arquera.es_movil, "La arquera debe ser móvil para desplazarse")
	assert_eq(arquera.plataforma_asignada, 2, "La plataforma asignada debe ser 2")
	assert_true(arquera.en_despliegue, "La arquera debe iniciar en estado en_despliegue")
	assert_almost_eq(arquera.global_position.z, 3.0, 0.05, "El plano Z de la arquera debe ser 3.0")

func test_ally_spawner_secuencia_completa_10_aliadas():
	_spawner = EscenaSpawner.instantiate() as AllySpawner
	_spawner.auto_iniciar = false
	_spawner.intervalo_spawn = 0.0 # Instantáneo para test
	add_child(_spawner)
	_spawner.global_position = Vector3(-13.5, 0.185, 3.0)

	watch_signals(_spawner)
	_spawner.iniciar_spawn()

	assert_signal_emitted(_spawner, "all_allies_spawned", "Debe emitirse la señal all_allies_spawned")
	assert_signal_emit_count(_spawner, "ally_spawned", 10, "Deben emitirse 10 señales ally_spawned")
	assert_eq(_spawner.aliadas_instanciadas.size(), 10, "Deben haberse instanciado exactamente 10 aliadas")

	# La primera debe ser la ballestera en el piso 3
	var primera: Node3D = _spawner.aliadas_instanciadas[0]
	assert_true(primera is AllyBallestera, "La primera aliada debe ser la Ballestera")
	assert_eq(primera.plataforma_asignada, 3, "La Ballestera debe tener asignado el piso 3")

	# Las siguientes 9 deben ser arqueras
	for i in range(1, 10):
		var aliada: Node3D = _spawner.aliadas_instanciadas[i]
		assert_true(aliada is AllyArcher, "Las aliadas restantes deben ser de tipo AllyArcher")

func test_nivel06_contiene_spawner_y_plataformas():
	var nivel: Node3D = EscenaNivel06.instantiate() as Node3D
	assert_not_null(nivel, "El nivel 6 debe instanciarse correctamente")
	_created_nodes.append(nivel)

	# Verificar plataformas
	var p1: Node = nivel.get_node_or_null("PlataformaOneway1")
	var p2: Node = nivel.get_node_or_null("PlataformaOneway2")
	var p3: Node = nivel.get_node_or_null("PlataformaOneway3")
	assert_not_null(p1, "Debe existir PlataformaOneway1 en Nivel 6")
	assert_not_null(p2, "Debe existir PlataformaOneway2 en Nivel 6")
	assert_not_null(p3, "Debe existir PlataformaOneway3 en Nivel 6")

	# Verificar escaleras
	var l1: Node = p1.get_node_or_null("Ladder1") if p1 else null
	var l2: Node = p2.get_node_or_null("Ladder2") if p2 else null
	var l3: Node = p3.get_node_or_null("Ladder3") if p3 else null
	assert_not_null(l1, "Debe existir Ladder1 en PlataformaOneway1")
	assert_not_null(l2, "Debe existir Ladder2 en PlataformaOneway2")
	assert_not_null(l3, "Debe existir Ladder3 en PlataformaOneway3")

	# Verificar Spawner
	var spawner: Node = nivel.get_node_or_null("SpawnBallesterasAliadas")
	if not spawner:
		spawner = nivel.get_node_or_null("AllySpawner")
	assert_not_null(spawner, "Debe existir SpawnBallesterasAliadas en Nivel 6")
	if spawner and spawner is Node3D:
		assert_almost_eq(spawner.position.x, -11.5, 0.1, "El spawner debe estar en el lado izquierdo (x = -11.5)")
		assert_almost_eq(spawner.position.y, 0.185, 0.1, "El spawner debe estar en la altura de piso (y = 0.185)")
		assert_almost_eq(spawner.position.z, 3.0, 0.1, "El spawner debe estar alineado a Z = 3.0")
