extends "res://addons/gut/test.gd"

## Tests unitarios para la restricción de ataque de los enemigos en el nivel río:
## Solo pueden atacar cuando aparecen en pantalla / rango de la cámara.

const GOBLIN_GIRL_SCENE := preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")
const GOBLIN_GENERAL_SCENE := preload("res://Entities/Enemigo_Goblin_General/GoblinGeneral.tscn")
const AZULINA_SCENE := preload("res://Entities/Enemigo_Azulina/Azulina.tscn")
const LONKO_SCENE := preload("res://Entities/Enemigo_Lonko/Lonko.tscn")

var _root_test: Node3D = null
var _camara_test: Camera3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestCamaraRio"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test

	_camara_test = Camera3D.new()
	_camara_test.name = "CamaraPrincipal"
	_camara_test.current = true
	_root_test.add_child(_camara_test)
	_camara_test.global_position = Vector3(0.0, 3.0, 30.0)


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is EnemyBase or n is Camera3D or n is RioEnCanoaConParallax:
			n.free()


func test_enemigo_con_restriccion_fuera_de_camara_no_puede_atacar() -> void:
	# Arrange
	var enemy := EnemyBase.new()
	_root_test.add_child(enemy)
	enemy.solo_atacar_en_pantalla = true
	enemy.global_position = Vector3(25.0, 0.0, 0.0)
	enemy.set("_camara_cache_pantalla", _camara_test)

	# Act
	var en_pantalla: bool = enemy.esta_en_pantalla_o_rango_camara()
	var puede: bool = enemy.puede_atacar()

	# Assert
	assert_false(en_pantalla, "Un enemigo a 25m con cámara en 0 no está en pantalla")
	assert_false(puede, "No debe poder atacar si está fuera de pantalla")


func test_enemigo_con_restriccion_dentro_de_camara_puede_atacar() -> void:
	# Arrange
	var enemy := EnemyBase.new()
	_root_test.add_child(enemy)
	enemy.solo_atacar_en_pantalla = true
	enemy.global_position = Vector3(4.0, 0.0, 0.0)
	enemy.set("_camara_cache_pantalla", _camara_test)

	# Act
	var en_pantalla: bool = enemy.esta_en_pantalla_o_rango_camara()
	var puede: bool = enemy.puede_atacar()

	# Assert
	assert_true(en_pantalla, "Un enemigo a 4m con cámara en 0 está dentro de rango de cámara")
	assert_true(puede, "Debe poder atacar cuando la cámara lo enfoca")


func test_enemigo_sin_restriccion_puede_atacar_en_cualquier_posicion() -> void:
	# Arrange
	var enemy := EnemyBase.new()
	_root_test.add_child(enemy)
	enemy.solo_atacar_en_pantalla = false
	enemy.global_position = Vector3(100.0, 0.0, 0.0)

	# Act & Assert
	assert_true(enemy.puede_atacar(), "En niveles normales sin restricción de cámara siempre puede atacar")


func test_goblin_girl_no_dispara_flecha_fuera_de_camara() -> void:
	# Arrange
	var girl: GoblinGirl = GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	_root_test.add_child(girl)
	girl.solo_atacar_en_pantalla = true
	girl.global_position = Vector3(30.0, 0.0, 0.0)
	girl.set("_camara_cache_pantalla", _camara_test)

	# Act: Intentar forzar disparo
	girl._shoot_arrow()

	# Assert: No debe haber instanciado ni lanzado proyectiles
	var proyectiles := []
	for child in get_tree().root.get_children():
		if child.name.begins_with("GoblinGirlArrow"):
			proyectiles.append(child)
	for child in _root_test.get_children():
		if child.name.begins_with("GoblinGirlArrow"):
			proyectiles.append(child)

	assert_eq(proyectiles.size(), 0, "GoblinGirl fuera de cámara no debe disparar flechas")


func test_goblin_general_bloquea_disparo_y_ult_fuera_de_camara() -> void:
	# Arrange
	var general: GoblinGeneral = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneral
	_root_test.add_child(general)
	general.solo_atacar_en_pantalla = true
	general.global_position = Vector3(45.0, 0.0, 0.0)
	general.set("_camara_cache_pantalla", _camara_test)

	# Act: Intentar disparar normal y ult
	general._disparar_flecha_normal()
	general._disparar_ult()

	# Assert
	var flechas := []
	for child in get_tree().root.get_children():
		if child.name.begins_with("GoblinGirlArrow"):
			flechas.append(child)
	for child in _root_test.get_children():
		if child.name.begins_with("GoblinGirlArrow"):
			flechas.append(child)

	assert_eq(flechas.size(), 0, "GoblinGeneral fuera de cámara no debe disparar flechas ni ult")


func test_azulina_bloquea_ataque_fuera_de_camara() -> void:
	# Arrange
	var azulina: Azulina = AZULINA_SCENE.instantiate() as Azulina
	_root_test.add_child(azulina)
	azulina.solo_atacar_en_pantalla = true
	azulina.global_position = Vector3(50.0, 0.0, 0.0)
	azulina.set("_camara_cache_pantalla", _camara_test)

	# Act: Intentar iniciar ataque y lanzar lanza
	azulina._iniciar_ataque()
	azulina._lanzar_lanza()

	# Assert
	assert_false(azulina.get("_lanzando"), "No debe entrar en estado de lanzamiento fuera de cámara")
	var lanzas := []
	for child in get_tree().root.get_children():
		if child.name.begins_with("LanzaAzulina"):
			lanzas.append(child)
	assert_eq(lanzas.size(), 0, "Azulina fuera de cámara no debe lanzar proyectiles")


func test_nivel_rio_configura_enemigos_automaticamente() -> void:
	# Arrange
	var rio := RioEnCanoaConParallax.new()
	_root_test.add_child(rio)
	rio.name = "RioNivelTest"
	var cam := Camera3D.new()
	cam.name = "CamaraPrincipal"
	rio.add_child(cam)
	rio.camara_principal = cam

	var enemy1 := EnemyBase.new()
	enemy1.name = "Enemy1"
	rio.add_child(enemy1)

	var enemy2 := EnemyBase.new()
	enemy2.name = "Enemy2"
	rio.add_child(enemy2)

	# Act
	rio._configurar_enemigos_para_camara()

	# Assert
	assert_true(enemy1.solo_atacar_en_pantalla, "Enemy1 debe quedar con solo_atacar_en_pantalla = true")
	assert_true(enemy2.solo_atacar_en_pantalla, "Enemy2 debe quedar con solo_atacar_en_pantalla = true")
	assert_eq(enemy1.get("_camara_cache_pantalla"), cam, "Enemy1 debe tener asociada la cámara principal del río")
	assert_eq(enemy2.get("_camara_cache_pantalla"), cam, "Enemy2 debe tener asociada la cámara principal del río")


func test_lonko_duerme_fuera_de_camara_y_despierta_en_rango() -> void:
	# Arrange
	var lonko: Lonko = LONKO_SCENE.instantiate() as Lonko
	lonko.activar_al_entrar_en_camara = true
	lonko.solo_atacar_en_pantalla = true
	_root_test.add_child(lonko)
	lonko.global_position = Vector3(50.0, 0.0, 0.0)
	lonko.set("_camara_cache_pantalla", _camara_test)
	lonko._iniciar_dormido_camara()

	# Assert dormido
	assert_true(lonko.get("_dormido_por_camara"), "Lonko debe iniciar dormido fuera de cámara")
	assert_false(lonko.is_physics_processing(), "Lonko no debe procesar física mientras duerme")

	# Act: cámara se acerca a rango de Lonko
	_camara_test.global_position = Vector3(45.0, 3.0, 30.0)
	lonko._process(0.016)

	# Assert despierto
	assert_false(lonko.get("_dormido_por_camara"), "Lonko debe despertar al entrar en rango de cámara")
	assert_true(lonko.is_physics_processing(), "Lonko debe activar física al despertar")


func test_lonko_despierta_al_recibir_dano() -> void:
	# Arrange
	var lonko: Lonko = LONKO_SCENE.instantiate() as Lonko
	lonko.activar_al_entrar_en_camara = true
	lonko.solo_atacar_en_pantalla = true
	_root_test.add_child(lonko)
	lonko.global_position = Vector3(60.0, 0.0, 0.0)
	lonko.set("_camara_cache_pantalla", _camara_test)
	lonko._iniciar_dormido_camara()

	assert_true(lonko.get("_dormido_por_camara"), "Lonko debe estar dormido antes de recibir daño")

	# Act
	lonko.take_damage(1.0)

	# Assert
	assert_false(lonko.get("_dormido_por_camara"), "Lonko debe despertar inmediatamente si recibe daño")


func test_goblin_girl_duerme_y_despierta_por_camara() -> void:
	# Arrange
	var girl: GoblinGirl = GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	girl.activar_al_entrar_en_camara = true
	girl.solo_atacar_en_pantalla = true
	_root_test.add_child(girl)
	girl.global_position = Vector3(50.0, 0.0, 0.0)
	girl.set("_camara_cache_pantalla", _camara_test)
	girl._iniciar_dormida_camara()

	# Assert dormida
	assert_true(girl.get("_dormida_por_camara"), "GoblinGirl debe estar dormida fuera de cámara")
	assert_false(girl.is_physics_processing(), "GoblinGirl no debe procesar física mientras duerme")

	# Act: cámara se acerca
	_camara_test.global_position = Vector3(45.0, 3.0, 30.0)
	girl._process(0.016)

	# Assert despierta
	assert_false(girl.get("_dormida_por_camara"), "GoblinGirl debe despertar al entrar en rango de cámara")
	assert_true(girl.is_physics_processing(), "GoblinGirl debe reanudar física al despertar")

