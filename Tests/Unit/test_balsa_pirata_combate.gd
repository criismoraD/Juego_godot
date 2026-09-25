extends "res://addons/gut/test.gd"

## Tests de la balsa pirata de combate (plataforma flotante hostil del río).

const BALSA_SCENE: PackedScene = preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirataCombate.tscn")
const CANOA_ESCENA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestBalsaCombate"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is BalsaPirataCombate or n is EnemyBase:
			n.free()


func _crear_balsa() -> BalsaPirataCombate:
	var balsa := BALSA_SCENE.instantiate() as BalsaPirataCombate
	assert_not_null(balsa, "Debe instanciar BalsaPirataCombate")
	balsa.position = Vector3(30.0, 0.0, -7.5)
	balsa.activar_al_entrar_en_camara = false
	_root_test.add_child(balsa)
	return balsa


func _contar_tripulacion(balsa: BalsaPirataCombate) -> Dictionary:
	var cuenta := {"pirata": 0, "embajador": 0, "arquera": 0, "total": 0}
	for n in balsa.find_children("*", "CharacterBody3D", true, false):
		if n is PirataGoblin:
			cuenta["pirata"] += 1
			cuenta["total"] += 1
		elif n is ImpEstandarte:
			cuenta["embajador"] += 1
			cuenta["total"] += 1
		elif n is GoblinGirl:
			cuenta["arquera"] += 1
			cuenta["total"] += 1
	return cuenta


func test_balsa_instancia_con_casco_y_vida() -> void:
	# Arrange & Act
	var balsa := _crear_balsa()

	# Assert: modelo, colisión enemiga, 16 de vida e inactiva hasta la cámara
	assert_not_null(balsa.find_child("BalsaPirataModel", true, false), "Debe traer el modelo de balsa")
	var casco := balsa.find_child("CascoBalsa", true, false) as StaticBody3D
	assert_not_null(casco, "Debe tener casco con colisión")
	assert_true(casco.collision_layer & 4 != 0, "El casco debe estar en capa de enemigos")
	assert_almost_eq(balsa.vida_actual, 16.0, 0.001, "El casco debe tener 16 de vida")
	assert_false(balsa._activa, "Inactiva hasta entrar en cámara")
	assert_false(balsa.esta_destruida(), "No nace destruida")
	assert_true(balsa.is_processing(), "El _process debe correr desde el inicio para detectar la cámara")


func test_activar_despliega_mezcla_preposicionada() -> void:
	# Arrange: 2 piratas + 1 embajador + 1 arquera, sin aleatorizar ni intervalo
	var balsa := _crear_balsa()
	balsa.cantidad_pirata = 2
	balsa.cantidad_imp_embajador = 1
	balsa.cantidad_goblin_arquera = 1
	balsa.mezclar_orden_aleatorio = false
	balsa.intervalo_spawn = 0.0

	# Act: activar y desplegar
	balsa.activar()
	assert_true(balsa._activa, "Debe activarse")
	assert_true(balsa.is_in_group("enemies"), "Activa debe contar como enemiga")
	for i in range(6):
		balsa._process(0.1)

	# Assert: tripulación completa embarcada en sus puestos
	var cuenta := _contar_tripulacion(balsa)
	assert_eq(cuenta["total"], 4, "Debe desplegar la mezcla completa")
	assert_eq(cuenta["pirata"], 2, "2 piratas")
	assert_eq(cuenta["embajador"], 1, "1 embajador")
	assert_eq(cuenta["arquera"], 1, "1 arquera")
	for n in balsa.find_children("*", "CharacterBody3D", true, false):
		if n is EnemyBase:
			assert_eq((n as Node3D).get_parent(), balsa, "Cada tripulante debe colgar de la balsa")
	var xs := []
	for n in balsa.find_children("*", "CharacterBody3D", true, false):
		if n is EnemyBase:
			xs.append((n as Node3D).position.x)
	assert_gt(xs.max(), xs.min(), "Los puestos deben repartirse a lo ancho")


func test_tripulacion_exterminada_hunde_balsa() -> void:
	# Arrange: 1 arquera desplegada
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var arquera := _root_test.find_child("GoblinGirl", true, false)
	if arquera == null:
		for n in balsa.find_children("*", "CharacterBody3D", true, false):
			if n is GoblinGirl:
				arquera = n
				break
	assert_not_null(arquera, "Debe haberse desplegado la arquera")

	# Act: muere la última tripulante
	arquera.queue_free()
	await get_tree().process_frame

	# Assert: la balsa se destruye como en el nivel 5
	assert_true(balsa.esta_destruida(), "Sin tripulantes debe destruirse")


func test_casco_aguanta_16_impactos() -> void:
	# Arrange
	var balsa := _crear_balsa()
	balsa.activar()

	# Act & Assert: 15 no la hunden, 16 sí
	balsa.take_damage(15.0)
	assert_false(balsa.esta_destruida(), "Con 15 de daño sigue a flote")
	balsa.take_damage(1.0)
	assert_true(balsa.esta_destruida(), "Con 16 de daño se destruye")


func test_navega_de_derecha_a_izquierda() -> void:
	# Arrange: 1 tripulante viva para no hundirse, navegando al oeste
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = true
	balsa.x_destino_navegacion = -30.0
	balsa.velocidad_navegacion_combate = 1.5
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var x_antes: float = balsa._posicion_base.x

	# Act: navegar 2 segundos
	balsa._process(1.0)
	balsa._process(1.0)

	# Assert: avanza hacia la izquierda
	assert_lt(balsa._posicion_base.x, x_antes - 2.0, "Debe navegar de derecha a izquierda")


func test_activacion_solo_en_camara() -> void:
	# Arrange: cámara en x=0 y balsa lejos
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.global_position = Vector3.ZERO
	cam.make_current()
	var balsa := _crear_balsa()
	balsa.position.x = 10.0
	balsa.activar_al_entrar_en_camara = true

	# Act: fuera de cuadro no se activa
	balsa._process(0.1)

	# Assert: sigue inactiva lejos
	assert_false(balsa._activa, "Lejos de cámara no debe activarse")

	# Act: ya en cuadro
	balsa.position.x = 2.0
	balsa._process(0.1)

	# Assert: se activa centrada
	assert_true(balsa._activa, "En cuadro debe activarse")

	# Cleanup
	cam.queue_free()


func test_activacion_antes_que_freno_canoa() -> void:
	# Arrange & Act
	var balsa := _crear_balsa()

	# Assert: la balsa debe despertar (y agruparse) antes de que la canoa
	# tenga que frenar (2.4 contacto + 3.0 margen = 5.4m), o la atraviesa dormida
	assert_gt(balsa.distancia_activacion_x, 2.4 + balsa.margen_bloqueo_proa, "Activar más lejos de lo que frena la canoa")


func test_plataforma_a_altura_de_cubierta() -> void:
	# Arrange & Act
	var balsa := _crear_balsa()

	# Assert: piso sólido como el submarino, con la cara arriba en altura_cubierta
	var cub := balsa.find_child("PlataformaCubierta", true, false) as AnimatableBody3D
	assert_not_null(cub, "Debe existir PlataformaCubierta")
	var col := cub.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(col, "La plataforma debe tener colisión")
	var caja := col.shape as BoxShape3D
	assert_not_null(caja, "La colisión debe ser caja")
	assert_almost_eq(col.position.y + caja.size.y * 0.5, balsa.altura_cubierta, 0.02, "El piso debe enrasar con altura_cubierta")


func test_tripulante_queda_parado_en_cubierta() -> void:
	# Arrange: 1 arquera embarcada
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var arquera := _ultima_enemiga()
	assert_not_null(arquera, "Debe haberse desplegado la arquera")

	# Act: dejar que la física la asiente en el piso
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: de pie sobre la cubierta (0.12 local * escala Y 3 = 0.36 mundo)
	assert_almost_eq(arquera.global_position.y, 0.36, 0.15, "La tripulante debe quedar parada en cubierta, sin caerse")


func test_canoa_frena_ante_balsa_hasta_destruirla() -> void:
	# Arrange: canoa quieta y balsa activa en su carril por delante
	var canoa: CanoaProtagonistaRio = CANOA_ESCENA.instantiate() as CanoaProtagonistaRio
	_root_test.add_child(canoa)
	canoa.global_position = Vector3(0.0, 0.0, -7.5)
	var balsa := _crear_balsa()
	balsa.position = Vector3(4.0, 0.0, -7.5)
	balsa.activar()

	# Act: la canoa evalúa a la balsa (dx=4 <= 2.4+3.0 contacto)
	canoa._actualizar_reaccion_enemigos()

	# Assert: detenida, sin pasar sobre ella
	assert_true(canoa.esta_detenida_por_enemigo(), "La canoa debe detenerse ante la balsa")
	assert_eq(canoa.obtener_factor_velocidad_actual(), 0.0, "Velocidad 0 ante la balsa")

	# Act: destruida la balsa, la canoa reanuda
	balsa.take_damage(99.0)
	canoa._actualizar_reaccion_enemigos()

	# Assert: vía libre
	assert_false(canoa.esta_detenida_por_enemigo(), "Destruida la balsa, la canoa avanza")

	# Cleanup: fuera del after_each genérico
	canoa.free()


func _ultima_enemiga() -> Node3D:
	for n in _root_test.find_children("*", "CharacterBody3D", true, false):
		if n is EnemyBase:
			return n as Node3D
	return null


func test_tripulacion_con_fisica_parada_en_cubierta() -> void:
	# Arrange: 1 arquera embarcada, balsa quieta tras desplegar
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = false
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	balsa.detener()
	var arquera := _ultima_enemiga()
	assert_not_null(arquera, "Debe haberse desplegado la arquera")

	# Assert: física encendida como la del submarino, pero en combate y quieta
	assert_true(arquera.is_physics_processing(), "Como el submarino: con física")
	assert_eq((arquera as EnemyBase).current_state, EnemyBase.State.SHOOTING, "Debe estar atacando")

	# Act: frames reales de física sobre su plataforma
	var y_antes: float = arquera.global_position.y
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: de pie sobre la cubierta, sin caerse
	assert_almost_eq(arquera.global_position.y, y_antes, 0.05, "El piso la sostiene")


func test_balsa_frena_y_se_detiene_ante_canoa() -> void:
	# Arrange: balsa navegando con 1 tripulante viva + canoa de verdad lejos
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = true
	balsa.x_destino_navegacion = -30.0
	balsa.velocidad_navegacion_combate = 1.5
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var canoa: CanoaProtagonistaRio = CANOA_ESCENA.instantiate() as CanoaProtagonistaRio
	_root_test.add_child(canoa)

	# Act: canoa lejos (dx=10, fuera de frenado)
	canoa.global_position = Vector3(balsa._posicion_base.x - 10.0, 0.0, -7.5)
	balsa._process(0.5)

	# Assert: marcha plena
	assert_true(balsa.esta_navegando(), "Lejos debe seguir navegando")
	assert_almost_eq(balsa._velocidad_navegacion, 1.5, 0.01, "Lejos va a velocidad plena")

	# Act: canoa a media distancia de frenado (dx≈4.75, factor 0.5)
	canoa.global_position = Vector3(balsa._posicion_base.x - 4.75, 0.0, -7.5)
	balsa._process(0.1)

	# Assert: media marcha
	assert_almost_eq(balsa._velocidad_navegacion, 0.75, 0.15, "A media distancia baja a media marcha")

	# Act: canoa pegada (dx=2, dentro de detención)
	canoa.global_position = Vector3(balsa._posicion_base.x - 2.0, 0.0, -7.5)
	balsa._process(0.1)
	var x_quieta: float = balsa._posicion_base.x

	# Assert: detenida del todo y sin avanzar más
	assert_false(balsa.esta_navegando(), "Pegada a la canoa debe detenerse")
	balsa._process(0.5)
	assert_almost_eq(balsa._posicion_base.x, x_quieta, 0.001, "Detenida no debe avanzar")

	# Cleanup
	canoa.free()


func test_piratas_miran_izquierda_resto_igual() -> void:
	# Arrange: 1 pirata + 1 arquera + 1 embajador sin aleatorizar
	var balsa := _crear_balsa()
	balsa.cantidad_pirata = 1
	balsa.cantidad_goblin_arquera = 1
	balsa.cantidad_imp_embajador = 1
	balsa.mezclar_orden_aleatorio = false
	balsa.intervalo_spawn = 0.0
	balsa.activar()
	for i in range(5):
		balsa._process(0.1)

	# Assert: pirata a la izquierda (proa/jugadora), resto como el submarino
	var pirata: Node3D = null
	var arquera: Node3D = null
	var embajador: Node3D = null
	for n in balsa.find_children("*", "CharacterBody3D", true, false):
		if n is PirataGoblin:
			pirata = n as Node3D
		elif n is GoblinGirl:
			arquera = n as Node3D
		elif n is ImpEstandarte:
			embajador = n as Node3D
	assert_not_null(pirata, "Debe haber pirata")
	assert_not_null(arquera, "Debe haber arquera")
	assert_not_null(embajador, "Debe haber embajador")
	assert_almost_eq(pirata.rotation.y, 0.0, 0.01, "El pirata mira a la izquierda como en el submarino")
	assert_almost_eq(arquera.rotation.y, 0.0, 0.01, "La arquera mira a la izquierda con 0.0")
	assert_almost_eq(embajador.rotation.y, 0.0, 0.01, "El embajador mira a la izquierda con 0.0")


func test_balsa_frena_ante_jugadora_grupo_player() -> void:
	# Arrange: balsa navegando + jugadora de verdad en grupo player
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = true
	balsa.x_destino_navegacion = -30.0
	balsa.velocidad_navegacion_combate = 1.5
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var player := Node3D.new()
	player.name = "PlayerFalsoFreno"
	player.add_to_group("player")
	get_tree().root.add_child(player)

	# Act: jugadora pegada (dx=2, dentro de detención)
	player.global_position = Vector3(balsa._posicion_base.x - 2.0, 0.0, -7.5)
	balsa._process(0.1)

	# Assert: detenida por la referencia robusta (sin necesidad de la canoa)
	assert_false(balsa.esta_navegando(), "Ante la jugadora debe detenerse")

	# Cleanup
	player.remove_from_group("player")
	player.free()


func test_balsa_frena_con_nodo_manual_sin_grupos() -> void:
	# Arrange: balsa navegando + referencia manual (sin grupos ni clases)
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = true
	balsa.x_destino_navegacion = -30.0
	balsa.velocidad_navegacion_combate = 1.5
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var marca := Node3D.new()
	marca.name = "MarcaFrenoManual"
	_root_test.add_child(marca)
	balsa.nodo_referencia_frenado = marca

	# Act: marca pegada (dx=2, dentro de detención)
	marca.global_position = Vector3(balsa._posicion_base.x - 2.0, 0.0, -7.5)
	balsa._process(0.1)

	# Assert: detenida por el nodo manual
	assert_false(balsa.esta_navegando(), "Con nodo manual debe detenerse")

	# Cleanup
	marca.free()


func test_watchdog_mete_en_combate_al_que_quede_caminando() -> void:
	# Arrange: 1 arquera embarcada y en combate
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var arquera := _ultima_enemiga() as EnemyBase
	assert_not_null(arquera, "Debe haberse desplegado la arquera")

	# Act: simular entrada a combate perdida (vuelve a WALKING)
	arquera.current_state = EnemyBase.State.WALKING
	balsa._process(0.1)

	# Assert: el guardián la devuelve a SHOOTING
	assert_eq(arquera.current_state, EnemyBase.State.SHOOTING, "El watchdog debe forzar el combate")


func test_watchdog_no_toca_ciclo_en_curso() -> void:
	# Arrange: 1 pirata a medio lanzamiento
	var balsa := _crear_balsa()
	balsa.cantidad_pirata = 1
	balsa.intervalo_spawn = 0.0
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var pirata := _ultima_enemiga() as ImpEnemy
	assert_not_null(pirata, "Debe haberse desplegado el pirata")
	pirata._start_throw_animation()
	pirata.is_throwing = true

	# Act: pasa el procesador con la cola vacía de spawns pendientes
	balsa._cola_mezcla.clear()
	balsa._process(0.05)

	# Assert: el lanzamiento sigue su curso sin reinicios
	assert_true(pirata.is_throwing, "No debe interrumpir un lanzamiento en curso")
	assert_eq(pirata.current_state, EnemyBase.State.SHOOTING, "Debe seguir en SHOOTING")


func test_respeta_rotacion_del_editor() -> void:
	# Arrange: balsa rotada a mano en el editor
	var balsa := BALSA_SCENE.instantiate() as BalsaPirataCombate
	assert_not_null(balsa, "Debe instanciar BalsaPirataCombate")
	balsa.rotation_degrees.y = 30.0
	_root_test.add_child(balsa)

	# Assert: se conserva tal cual, sin giro de proa
	assert_almost_eq(balsa.rotation_degrees.y, 30.0, 0.01, "Debe respetar la rotación del editor")
	assert_almost_eq(balsa._rotacion_base.y, 30.0, 0.01, "La base debe partir de la rotación del editor")


func test_tripulacion_mira_hacia_donde_navega_derecha() -> void:
	# Arrange: balsa navegando a +X con 1 pirata + 1 arquera
	var balsa := _crear_balsa()
	balsa.cantidad_pirata = 1
	balsa.cantidad_goblin_arquera = 1
	balsa.mezclar_orden_aleatorio = false
	balsa.intervalo_spawn = 0.0
	balsa.x_destino_navegacion = 60.0
	balsa.activar()
	for i in range(5):
		balsa._process(0.1)

	# Assert: navegando a la derecha miran a la derecha (relativo a raíz sin rotar)
	var pirata: Node3D = null
	var arquera: Node3D = null
	for n in balsa.find_children("*", "CharacterBody3D", true, false):
		if n is PirataGoblin:
			pirata = n as Node3D
		elif n is GoblinGirl:
			arquera = n as Node3D
	assert_not_null(pirata, "Debe haber pirata")
	assert_not_null(arquera, "Debe haber arquera")
	assert_almost_eq(angle_difference(pirata.rotation.y, PI), 0.0, 0.01, "Navegando a la derecha el pirata mira a la derecha")
	assert_almost_eq(angle_difference(arquera.rotation.y, PI), 0.0, 0.01, "Navegando a la derecha la arquera mira a la derecha")


func test_tripulacion_fija_en_puesto_ante_empujones() -> void:
	# Arrange: 1 arquera embarcada
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = false
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var arquera := _ultima_enemiga()
	assert_not_null(arquera, "Debe haberse desplegado la arquera")

	# Act: simular empujón que la saca del puesto
	arquera.global_position += Vector3(2.0, 0.0, 1.0)
	balsa._process(0.1)

	# Assert: vuelve a su XZ (la Y queda libre para la flotación)
	var puesto: Vector3 = arquera.get_meta("puesto_balsa")
	assert_almost_eq(arquera.global_position.x, puesto.x, 0.01, "Vuelve a su X")
	assert_almost_eq(arquera.global_position.z, puesto.z, 0.01, "Vuelve a su Z")


func test_velocidad_crucero_lenta() -> void:
	# Arrange & Act
	var balsa := _crear_balsa()

	# Assert: crucero lento por defecto
	assert_almost_eq(balsa.velocidad_navegacion_combate, 0.8, 0.001, "Velocidad de crucero 0.8 m/s")


func test_encuentro_completo_sin_contacto_y_con_ataques() -> void:
	# Arrange: réplica fiel del nivel (balsa en x=5.2 con 3+2, canoa en x=-6.7)
	var balsa := _crear_balsa()
	balsa.position = Vector3(5.2, 0.0, -7.75)
	balsa._posicion_base = balsa.position
	balsa.cantidad_pirata = 3
	balsa.cantidad_goblin_arquera = 2
	balsa.mezclar_orden_aleatorio = true
	balsa.intervalo_spawn = 1.0
	var canoa: CanoaProtagonistaRio = CANOA_ESCENA.instantiate() as CanoaProtagonistaRio
	_root_test.add_child(canoa)
	canoa.global_position = Vector3(-6.7, 0.0, -7.5)
	canoa._posicion_base = canoa.global_position
	var cam := Camera3D.new()
	get_tree().root.add_child(cam)
	cam.make_current()
	var player := Node3D.new()
	player.name = "PlayerEncuentroTotal"
	player.add_to_group("player")
	get_tree().root.add_child(player)
	var tiros_antes: int = _contar_proyectiles_enemigos()

	# Act: 30 segundos simulados; la canoa avanza solo lo que su freno permite
	var dx_minima := 9999.0
	for i in range(120):
		canoa._actualizar_reaccion_enemigos()
		canoa._aplicar_freno_contacto_enemigos()
		canoa._posicion_base.x += 0.2 * canoa.obtener_factor_velocidad_actual()
		canoa.global_position.x = canoa._posicion_base.x
		cam.global_position = Vector3(canoa.global_position.x, 3.0, 30.0)
		player.global_position = canoa.global_position
		balsa._process(0.25)
		for n in balsa.find_children("*", "CharacterBody3D", true, false):
			if n is EnemyBase and is_instance_valid(n):
				(n as EnemyBase)._process(0.25)
		dx_minima = minf(dx_minima, absf(balsa.global_position.x - canoa.global_position.x))

	# Assert: la balsa despertó sola, frenó antes de tocar y combatieron
	assert_true(balsa._activa, "La balsa debe activarse al acercarse la canoa")
	assert_gte(dx_minima, 2.0, "Jamás deben tocarse")
	assert_false(balsa.esta_navegando(), "La balsa debe haberse detenido")
	assert_gt(_contar_proyectiles_enemigos(), tiros_antes, "La tripulación debe haber disparado")

	# Cleanup
	player.remove_from_group("player")
	player.free()
	cam.queue_free()
	canoa.free()


func _contar_proyectiles_enemigos() -> int:
	var total := 0
	for n in get_tree().root.find_children("*", "Area3D", true, false):
		if n is EspadaPirataProjectile or n is BalaCanonProjectile or n is GoblinGirlArrowProjectile:
			total += 1
	return total


func _contar_proyectiles_enemigos() -> int:
	var total := 0
	for n in get_tree().root.find_children("*", "Area3D", true, false):
		if n is EspadaPirataProjectile or n is BalaCanonProjectile or n is GoblinGirlArrowProjectile:
			total += 1
	return total


func test_encuentro_barco_canoa_sin_contacto_y_con_ataques() -> void:
	# Arrange: barco con pirata + arquera navegando hacia canoa quieta con jugadora
	var balsa := _crear_balsa()
	balsa.cantidad_pirata = 1
	balsa.cantidad_goblin_arquera = 1
	balsa.mezclar_orden_aleatorio = false
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = true
	balsa.x_destino_navegacion = -30.0
	balsa.velocidad_navegacion_combate = 0.8
	balsa.activar()
	var player := Node3D.new()
	player.name = "PlayerEncuentro"
	player.add_to_group("player")
	get_tree().root.add_child(player)
	player.global_position = Vector3(20.0, 0.0, -7.5)
	var tiros_antes: int = _contar_proyectiles_enemigos()

	# Act: 20 segundos simulados paso a paso
	var dx_minima := 9999.0
	for i in range(80):
		balsa._process(0.25)
		for n in balsa.find_children("*", "CharacterBody3D", true, false):
			if n is EnemyBase and is_instance_valid(n):
				(n as EnemyBase)._process(0.25)
		dx_minima = minf(dx_minima, balsa.global_position.x - player.global_position.x)

	# Assert: se detuvo antes de tocar y la tripulación disparó
	assert_gte(dx_minima, 2.5, "Nunca debe tocar a la canoa")
	assert_false(balsa.esta_navegando(), "Debe haberse detenido ante la canoa")
	assert_gt(_contar_proyectiles_enemigos(), tiros_antes, "La tripulación debe haber disparado")

	# Cleanup
	player.remove_from_group("player")
	player.free()


func test_destruir_oscurece_y_desintegra_como_enemigos() -> void:
	# Arrange
	var balsa := _crear_balsa()
	balsa.activar()

	# Act: destruir el casco
	balsa.destruir_balsa()

	# Assert: mallas con disolver, borde configurado y albedo oscurecido
	var con_disolver := 0
	for m in balsa.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not (mi.material_override is ShaderMaterial):
			continue
		var sm := mi.material_override as ShaderMaterial
		if sm.shader == BalsaPirataCombate.SHADER_DISOLVER:
			con_disolver += 1
			assert_not_null(sm.get_shader_parameter("albedo_texture"), "El disolver debe conservar la textura del casco")
			var glow: Color = sm.get_shader_parameter("glow_color")			assert_almost_eq(glow.r, balsa.color_borde_balsa.r, 0.01, "Borde del color configurado")
			assert_almost_eq(float(sm.get_shader_parameter("glow_intensity")), 6.0, 0.01, "Brillo de disolver enemigo")
			assert_not_null(sm.get_shader_parameter("albedo_tint"), "Debe conservar tinte de albedo")
			var tint: Vector3 = sm.get_shader_parameter("albedo_tint")
			assert_lt(tint.x, 0.6, "Albedo oscurecido R")
			assert_lt(tint.y, 0.6, "Albedo oscurecido G")
			assert_lt(tint.z, 0.6, "Albedo oscurecido B")
			assert_almost_eq(float(sm.get_shader_parameter("dissolve_amount")), 0.0, 0.001, "Empieza intacto")
	assert_gt(con_disolver, 0, "El casco debe disolverse como los enemigos")


func test_tripulacion_viaja_con_balsa_en_marcha() -> void:
	# Arrange: 1 arquera embarcada, balsa navegando a la izquierda
	var balsa := _crear_balsa()
	balsa.cantidad_goblin_arquera = 1
	balsa.intervalo_spawn = 0.0
	balsa.navegar_al_activar = true
	balsa.x_destino_navegacion = -30.0
	balsa.velocidad_navegacion_combate = 1.5
	balsa.activar()
	for i in range(3):
		balsa._process(0.1)
	var arquera := _ultima_enemiga()
	assert_not_null(arquera, "Debe haberse desplegado la arquera")
	var x_antes: float = arquera.global_position.x
	var offset_antes: Vector3 = arquera.global_position - balsa.global_position

	# Act: navegar 1 segundo
	balsa._process(1.0)

	# Assert: la balsa avanzó y la tripulante conserva su sitio relativo
	assert_lt(balsa._posicion_base.x, 30.0 - 1.0, "La balsa avanza a la izquierda")
	assert_lt(arquera.global_position.x, x_antes - 1.0, "La tripulante viaja con la balsa")
	var offset_despues: Vector3 = arquera.global_position - balsa.global_position
	assert_almost_eq((offset_despues - offset_antes).length(), 0.0, 0.1, "Mantiene su puesto relativo")


func _crear_falsa_tripulante() -> Node3D:
	# Sosias de tripulante: malla con textura estandar (palo) + malla con
	# shader de viento con textura (tela del estandarte) + sombra sin textura.
	var falso := Node3D.new()
	falso.name = "FalsoTripulante"
	var tex: Texture2D = load("res://Entities/Ambiente_Estandarte/estandarte_D.jpg") as Texture2D
	assert_not_null(tex, "La textura del estandarte debe existir")
	var palo := MeshInstance3D.new()
	palo.name = "PALO"
	var quad_palo := QuadMesh.new()
	quad_palo.size = Vector2(0.2, 1.0)
	var mat_palo := StandardMaterial3D.new()
	mat_palo.albedo_texture = tex
	quad_palo.material = mat_palo
	palo.mesh = quad_palo
	falso.add_child(palo)
	var tela := MeshInstance3D.new()
	tela.name = "TELA"
	var quad_tela := QuadMesh.new()
	quad_tela.size = Vector2(0.5, 0.4)
	tela.mesh = quad_tela
	var mat_viento := ShaderMaterial.new()
	mat_viento.shader = load("res://Entities/Ambiente_Estandarte/wind_flag.gdshader") as Shader
	tela.set_surface_override_material(0, mat_viento)
	falso.add_child(tela)
	mat_viento.set_shader_parameter("albedo_texture", tex)
	mat_viento.set_shader_parameter("albedo_color", Color(1, 1, 1, 1))
	var sombra := MeshInstance3D.new()
	sombra.name = "SombraPersonaje"
	var quad_sombra := QuadMesh.new()
	quad_sombra.size = Vector2(0.3, 0.3)
	sombra.mesh = quad_sombra
	var mat_sombra := ShaderMaterial.new()
	mat_sombra.shader = load("res://System/Shaders/dissolve.gdshader") as Shader
	sombra.set_surface_override_material(0, mat_sombra)
	falso.add_child(sombra)
	return falso


func test_aparicion_tripulante_conserva_texturas_y_omite_sombra() -> void:
	# Arrange: balsa + falsa tripulante (palo texturizado, tela con viento
	# texturizado, sombra sin textura)
	var balsa := _crear_balsa()
	var falso := _crear_falsa_tripulante()
	_root_test.add_child(falso)
	var palo := falso.find_child("PALO", true, false) as MeshInstance3D
	var tela := falso.find_child("TELA", true, false) as MeshInstance3D
	var sombra := falso.find_child("SombraPersonaje", true, false) as MeshInstance3D

	# Act: animacion de aparicion morada
	balsa._animar_aparicion_tripulante(falso)

	# Assert: ambas mallas con textura disuelven CON su textura (no en blanco)
	var dis_palo := palo.material_override as ShaderMaterial
	assert_not_null(dis_palo, "El palo debe tener dissolve durante la aparicion")
	assert_not_null(dis_palo.get_shader_parameter("albedo_texture"), "El dissolve del palo debe llevar su textura")
	var dis_tela := tela.material_override as ShaderMaterial
	assert_not_null(dis_tela, "La tela debe tener dissolve durante la aparicion")
	assert_not_null(dis_tela.get_shader_parameter("albedo_texture"), "El dissolve de la tela debe llevar su textura (no blanco)")
	assert_null(sombra.material_override, "La sombra sin textura no debe disolverse")
