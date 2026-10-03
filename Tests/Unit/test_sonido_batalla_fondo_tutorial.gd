extends "res://addons/gut/test.gd"

## Sonido de batalla de fondo del tutorial (bloques azul y rojo).
## El loop "Batalla tutorial" suena de fondo a volumen bajo solo con AMBOS
## bloques activos; si uno se desactiva, se apaga.

const ESCENA_TUTORIAL: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"
const ESCENA_SPAWNER: PackedScene = preload("res://Entities/Ambiente_BattleSpawner/BattleSpawnerCosmetic.tscn")

var _nivel: Node = null


func after_each() -> void:
	if is_instance_valid(_nivel):
		_nivel.free()
		_nivel = null
	for n in get_tree().root.get_children():
		if n is BattleSpawnerCosmetic:
			n.free()


## 1. El bloque informa inactivo antes de iniciar y activo tras iniciar.
func test_bloque_batalla_activo_transiciona_al_iniciar() -> void:
	# Arrange: spawner sin auto-inicio para controlar el momento
	var spawner := ESCENA_SPAWNER.instantiate() as BattleSpawnerCosmetic
	add_child_autofree(spawner)
	spawner.auto_iniciar = false
	spawner.cantidad_inicial = 0
	assert_false(spawner.batalla_activa(), "Sin iniciar no está activo")

	# Act
	spawner.iniciar_batalla()

	# Assert
	assert_true(spawner.batalla_activa(), "Tras iniciar está activo")


## 2. El nivel crea el loop de fondo a volumen bajo y en silencio inicial.
func test_nivel_prepara_loop_batalla_fondo_suave() -> void:
	# Arrange
	var nivel := _cargar_nivel()
	assert_not_null(nivel, "NIVEL_TUTORIAL.tscn debe cargar sin errores")

	# Assert
	var player := nivel.get_node_or_null("SonidoBatallaFondo") as AudioStreamPlayer
	assert_not_null(player, "Debe existir SonidoBatallaFondo")
	assert_lte(player.volume_db, -12.0, "De fondo: no debe sonar exageradamente fuerte")
	assert_false(player.playing, "En silencio antes de iniciar la batalla")
	var gritos := nivel.get_node_or_null("SonidoGritosGuerra") as AudioStreamPlayer
	assert_not_null(gritos, "Debe existir SonidoGritosGuerra")
	assert_lte(gritos.volume_db, -12.0, "Gritos de fondo: sin saturar")
	assert_false(gritos.playing, "Gritos en silencio antes de iniciar la batalla")
	var goblins := nivel.get_node_or_null("SonidoBatallaGoblins") as AudioStreamPlayer
	assert_not_null(goblins, "Debe existir SonidoBatallaGoblins")
	assert_gt(goblins.volume_db, gritos.volume_db, "Goblins un poco más fuerte para el ritmo")
	assert_false(goblins.playing, "Goblins en silencio antes de iniciar la batalla")


## 3. Suena con ambos bloques y se apaga si uno se desactiva.
func test_batalla_fondo_suena_con_ambos_bloques_y_calla_con_uno_menos() -> void:
	# Arrange
	var nivel := _cargar_nivel()
	var player := nivel.get_node_or_null("SonidoBatallaFondo") as AudioStreamPlayer
	assert_not_null(player, "Debe existir SonidoBatallaFondo")
	var azul := nivel.get_node_or_null("SpawnerBatallaAzul")
	var rojo := nivel.get_node_or_null("SpawnerBatallaRojo")
	assert_not_null(azul, "Debe existir SpawnerBatallaAzul")
	assert_not_null(rojo, "Debe existir SpawnerBatallaRojo")
	azul.set("cantidad_inicial", 0)
	rojo.set("cantidad_inicial", 0)

	# Act: ambos bloques inician su batalla
	azul.call("iniciar_batalla")
	rojo.call("iniciar_batalla")
	await get_tree().create_timer(0.6).timeout

	# Assert: base + fase inicial (gritos) sonando, goblins en espera
	assert_true(player.playing, "Debe sonar con ambos bloques activos")
	var gritos := nivel.get_node_or_null("SonidoGritosGuerra") as AudioStreamPlayer
	var goblins := nivel.get_node_or_null("SonidoBatallaGoblins") as AudioStreamPlayer
	assert_true(gritos.playing, "Gritos deben sonar en la fase inicial")
	assert_false(goblins.playing, "Goblins esperan su turno (alternancia)")

	# Act: forzar el cambio de fase a goblins
	nivel.set("_timer_ritmo_batalla", 999.0)
	await get_tree().create_timer(0.6).timeout

	# Assert: alternó sin solaparse
	assert_false(gritos.playing, "Gritos callan en fase de goblins")
	assert_true(goblins.playing, "Goblins suenan en su fase")

	# Act: se desactiva el bloque rojo
	rojo.free()
	await get_tree().create_timer(0.6).timeout

	# Assert: silencio total
	assert_false(player.playing, "Debe apagarse si un bloque se desactiva")
	assert_false(gritos.playing, "Gritos deben apagarse si un bloque se desactiva")
	assert_false(goblins.playing, "Goblins deben apagarse si un bloque se desactiva")


func _cargar_nivel() -> Node:
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	assert_not_null(escena, "NIVEL_TUTORIAL.tscn debe cargar sin errores")
	_nivel = escena.instantiate()
	get_tree().root.add_child(_nivel)
	return _nivel
