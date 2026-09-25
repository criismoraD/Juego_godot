extends "res://addons/gut/test.gd"

## En el nivel del río ningún enemigo dropea power-ups al morir: solo la
## vasija contenedora los otorga. Cubre la detección central de nivel
## (EnemyBase.drops_bloqueados_en_nivel) y la guarda en los enemigos del río.

const ESCENA_GOBLIN: String = "res://Entities/Enemigo_Goblin/Goblin.tscn"
const ESCENA_GLOBO: String = "res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn"

var _escena_falsa: Node3D = null


func before_each() -> void:
	_escena_falsa = Node3D.new()
	_escena_falsa.name = "Rio_Mock"  # La detección del río es por nombre/entorno
	get_tree().root.add_child(_escena_falsa)
	get_tree().current_scene = _escena_falsa


func after_each() -> void:
	if is_instance_valid(_escena_falsa):
		_escena_falsa.free()
	get_tree().current_scene = null
	for n in get_tree().root.get_children():
		if n is EnemyBase:
			n.free()


func _contar_power_ups() -> int:
	var total := 0
	for n in get_tree().root.find_children("*", "Area3D", true, false):
		if "municion_a_otorgar_jugador" in n or "vida_a_restaurar" in n or "duracion_buff" in n:
			total += 1
	return total


func test_deteccion_nivel_rio_bloquea_drops() -> void:
	# Arrange & Act & Assert: escena "Rio_Mock" cuenta como nivel del río
	assert_true(EnemyBase.drops_bloqueados_en_nivel(get_tree()), "La escena río debe bloquear drops")
	# Act: sin escena activa no bloquea
	get_tree().current_scene = null
	assert_false(EnemyBase.drops_bloqueados_en_nivel(get_tree()), "Sin escena no bloquea")
	# Act: escena de otro nivel no bloquea
	_escena_falsa.name = "NIVEL01_Mock"
	get_tree().current_scene = _escena_falsa
	assert_false(EnemyBase.drops_bloqueados_en_nivel(get_tree()), "Nivel diezmo normal no bloquea")


func test_goblin_no_dropea_en_nivel_rio() -> void:
	# Arrange: goblin con drop garantizado (100%) pero en escena de río
	var goblin := (load(ESCENA_GOBLIN) as PackedScene).instantiate() as EnemyBase
	assert_not_null(goblin, "Debe instanciar el Goblin")
	add_child_autofree(goblin)
	goblin.set("drop_chance_flecha_explosiva", 1.0)
	var antes := _contar_power_ups()

	# Act
	goblin.call("_drop_power_up")

	# Assert: el drop está suprimido en el nivel del río
	assert_eq(_contar_power_ups(), antes, "En el río no debe soltar power-up aunque el chance sea 100%")


func test_goblin_si_dropea_en_nivel_normal() -> void:
	# Arrange: misma amenaza pero en un nivel cualquiera (no río)
	_escena_falsa.name = "NIVEL01_Mock"
	var goblin := (load(ESCENA_GOBLIN) as PackedScene).instantiate() as EnemyBase
	assert_not_null(goblin, "Debe instanciar el Goblin")
	add_child_autofree(goblin)
	goblin.set("drop_chance_flecha_explosiva", 1.0)
	var antes := _contar_power_ups()

	# Act
	goblin.call("_drop_power_up")

	# Assert: fuera del río el drop funciona normal
	assert_eq(_contar_power_ups(), antes + 1, "Fuera del río el drop normal se mantiene")


func test_globo_no_dropea_en_nivel_rio() -> void:
	# Arrange: globo con drops garantizados
	var globo := (load(ESCENA_GLOBO) as PackedScene).instantiate() as EnemyBase
	assert_not_null(globo, "Debe instanciar el Globo")
	add_child_autofree(globo)
	globo.set("posion_drop_chance", 1.0)
	globo.set("multiple_drop_chance", 1.0)
	var antes := _contar_power_ups()

	# Act
	globo.call("_drop_posion")
	globo.call("_drop_power_up_multiple")

	# Assert: ambos drops suprimidos en el río
	assert_eq(_contar_power_ups(), antes, "El globo no debe soltar nada en el nivel del río")


func test_azulina_no_dropea_fuego_rapido_en_nivel_rio() -> void:
	# Arrange: Azulina con drop garantizado (100%) pero en escena de río
	var azulina := (load("res://Entities/Enemigo_Azulina/Azulina.tscn") as PackedScene).instantiate() as EnemyBase
	assert_not_null(azulina, "Debe instanciar Azulina")
	add_child_autofree(azulina)
	azulina.set("probabilidad_drop_fuego_rapido", 1.0)
	var antes := _contar_power_ups()

	# Act
	azulina.call("_dropear_power_up")

	# Assert: drop de fuego rápido suprimido en el río
	assert_eq(_contar_power_ups(), antes, "Azulina no debe soltar fuego rápido en el nivel del río")


func test_azulina_si_dropea_en_nivel_normal() -> void:
	# Arrange: Azulina fuera del río con drop garantizado
	_escena_falsa.name = "NIVEL01_Mock"
	var azulina := (load("res://Entities/Enemigo_Azulina/Azulina.tscn") as PackedScene).instantiate() as EnemyBase
	assert_not_null(azulina, "Debe instanciar Azulina")
	add_child_autofree(azulina)
	azulina.set("probabilidad_drop_fuego_rapido", 1.0)
	var antes := _contar_power_ups()

	# Act
	azulina.call("_dropear_power_up")

	# Assert: fuera del río el drop funciona normal
	assert_gt(_contar_power_ups(), antes, "Azulina sí debe soltar fuego rápido fuera del río")
