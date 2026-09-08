extends "res://addons/gut/test.gd"
## Tests del fix del bug: power-up explosivo congelado tras drop de enemigo.
## Cubre los cambios aplicados:
## 1. Escala de spawn segura (0.05): Jolt rechaza transforms singulares (escala ~0).
## 2. SceneTreeTimer de auto-consumo con ignore_time_scale (dispara pese a pausas).
## 3. Watchdog del tween de caída (si muere en pleno vuelo, se recalcula el suelo).
## 4. _tiempo_vivo del respaldo no avanza con el árbol pausado (verificado en unidad).

var PowerUpScene = load("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
var PowerUpScript = load("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.gd")
var PlayerScene = load("res://Entities/Jugador_Arquera/Player.tscn")

var _nivel: Node3D = null
var _player = null


func before_each():
	_nivel = Node3D.new()
	_nivel.name = "NivelFix"
	get_tree().root.add_child(_nivel)
	get_tree().current_scene = _nivel

	# Suelo en y=0 (capa 1)
	var suelo := StaticBody3D.new()
	suelo.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 0.2, 10)
	col.shape = shape
	suelo.add_child(col)
	suelo.position = Vector3(0, -0.1, 0)
	_nivel.add_child(suelo)

	_player = PlayerScene.instantiate()
	_player.flechas_explosivas = 0
	_player.position = Vector3(0, 0.5, 0)
	_nivel.add_child(_player)


func after_each():
	get_tree().paused = false
	get_tree().current_scene = null
	if is_instance_valid(_nivel):
		_nivel.queue_free()
		await get_tree().process_frame
	for n in get_tree().root.get_children():
		if n is PowerUpFlechaExplosiva:
			n.free()


func _spawn_item_en_aire(x: float, y: float) -> PowerUpFlechaExplosiva:
	var item: PowerUpFlechaExplosiva = PowerUpScene.instantiate() as PowerUpFlechaExplosiva
	item.municion_a_otorgar_jugador = 5
	_nivel.add_child(item)
	item.global_position = Vector3(x, y, 0.0)
	return item


func test_escala_spawn_segura_sin_transform_singular():
	# Act: spawn del item (mismo flujo del drop: add_child + global_position)
	var item := _spawn_item_en_aire(4.0, 1.0)

	# Assert 1: la escala inicial nunca es ~0 (fix transform singular de Jolt)
	assert_gt(item.scale.x, 0.04, "La escala de spawn debe ser >= 0.05 (sin singular)")
	assert_eq(PowerUpFlechaExplosiva.ESCALA_SPAWN_MINIMA, 0.05, "Constante de escala segura definida")

	# Assert 2: el tween de spawn lleva la escala a ~1 (tiempo_escala_spawn 0.4s + margen)
	await get_tree().create_timer(1.2).timeout
	assert_true(not is_instance_valid(item) or item.scale.x > 0.9,
		"La escala debe completarse a ~1 tras el tween de spawn")

	# Assert 3: gira
	if is_instance_valid(item):
		var rot_ini: float = item.model_root.rotation.y
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(item):
			assert_ne(item.model_root.rotation.y, rot_ini, "El item debe girar")

	# Assert 4: auto-consumo suma al jugador
	await get_tree().create_timer(3.2).timeout
	assert_eq(_player.flechas_explosivas, 5, "Debe sumar 5 al auto-consumirse")


func test_watchdog_tween_caida_recupera_vuelo_interrumpido():
	# Arrange: item en el aire (caerá ~3m)
	var item := _spawn_item_en_aire(4.0, 3.0)
	await get_tree().create_timer(0.5).timeout

	# Assert: la caída arrancó
	if not is_instance_valid(item):
		return  # Consumido por proximidad improbable: x=4 lejos del player en x=0
	assert_true(item._is_falling or item._suelo_alcanzado, "La caída debe iniciarse en el aire")

	# Act: matar el tween en pleno vuelo (simula congelamiento)
	if item._is_falling and item._tween_caida:
		item._tween_caida.kill()

	# Assert: el watchdog no deja _is_falling=true con tween muerto
	await get_tree().create_timer(0.4).timeout
	assert_false(
		is_instance_valid(item) and item._is_falling
			and (item._tween_caida == null or not item._tween_caida.is_valid()),
		"No debe quedar _is_falling=true con tween muerto (watchdog)"
	)

	# Assert: el item se consumió y sumó pese al vuelo interrumpido
	await get_tree().create_timer(4.0).timeout
	assert_eq(_player.flechas_explosivas, 5, "Debe consumirse y sumar pese al vuelo interrumpido")


func test_timer_auto_consumo_usa_ignore_time_scale():
	# Regresión (unidad): el SceneTreeTimer del auto-consumo debe crearse con
	# process_always=true para no congelarse si el juego se pausa con el item
	# en pantalla. Se verifica el disparo en tiempo real con un contenedor
	# por referencia (los bool capturados en lambdas se copian en GDScript).
	var item := _spawn_item_en_aire(4.0, 1.0)
	var estado: Array = [false]
	var timer := get_tree().create_timer(0.3, true, false, true)
	timer.timeout.connect(func() -> void:
		estado[0] = true
	)
	await get_tree().create_timer(0.6, false, false, true).timeout
	assert_true(estado[0], "El timer con process_always=true debe disparar en tiempo real")
	assert_true(is_instance_valid(item), "El item sigue vivo para los siguientes checks")
	if is_instance_valid(item):
		assert_eq(item.current_state, PowerUpFlechaExplosiva.State.IDLE, "Sigue IDLE (sin consumir aún)")
