extends "res://addons/gut/test.gd"

## Tests unitarios para la corrección de hachas flotantes de Perrena en río
## y la calibración de la hitbox de DefensoraPerrena en modo canoa.

var DefensoraScene: PackedScene = preload("res://Entities/Defensora_Perrena/DefensoraPerrena.tscn")
var HachaScene: PackedScene = preload("res://Entities/Proyectil_Hacha_Perrena/HachaPerrena.tscn")
var ArrowEnemyScene: PackedScene = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestHachaHitbox"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is DefensoraPerrena or n is HachaPerrenaProjectile or n is GoblinGirlArrowProjectile:
			n.free()


## 1. El hacha de Perrena debe ignorar proyectiles enemigos en el aire sin clavarse ni detenerse
func test_hacha_perrena_ignora_flecha_enemiga_en_el_aire() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null)

	var flecha_enemiga: GoblinGirlArrowProjectile = ArrowEnemyScene.instantiate() as GoblinGirlArrowProjectile
	_root_test.add_child(flecha_enemiga)

	# Act: el hacha detecta la flecha enemiga entrando a su Area3D
	hacha._on_area_entered(flecha_enemiga)

	# Assert: no debe procesar impacto ni quedar clavada
	assert_false(hacha.is_stuck, "El hacha no debe clavarse al entrar en contacto con una flecha enemiga")
	assert_false(hacha._impacto_procesado, "El impacto no debe procesarse contra proyectiles")
	assert_ne(hacha.velocity, Vector3.ZERO, "La velocidad del hacha debe mantenerse intacta")


## 2. El hacha de Perrena debe ignorar áreas que no son objetivos de combate (triggers, detectores)
func test_hacha_perrena_ignora_areas_no_objetivo_y_detectores() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)
	hacha.initialize(Vector3.RIGHT, 1.0, null)

	var detector := Area3D.new()
	detector.name = "DetectorContactoEnemigos"
	_root_test.add_child(detector)

	# Act
	hacha._on_area_entered(detector)

	# Assert: debe seguir volando sin trabarse
	assert_false(hacha.is_stuck, "El hacha no debe clavarse en áreas de detección o triggers")
	assert_false(hacha._impacto_procesado, "No debe procesar impacto contra áreas no combativas")


## 3. Si el hacha elimina al enemigo con el golpe, se desvanece rápidamente tras 0.35s en vez de 3.0s
func test_hacha_perrena_desvanecimiento_rapido_al_matar_enemigo() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	var enemy_script := GDScript.new()
	enemy_script.source_code = "extends Node3D\nvar health: int = 1\nfunc take_damage(d: float) -> void:\n\thealth -= int(d)\n"
	enemy_script.reload()

	var enemy := Node3D.new()
	enemy.name = "GoblinDebil"
	enemy.set_script(enemy_script)
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)

	# Act: impacto mata al enemigo
	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)

	# Assert: se clava en el momento
	assert_true(hacha.is_stuck, "Debe registrar impacto y quedar clavada")
	assert_false(hacha._desvaneciendose, "En el instante 0 no debe desvanecerse todavía para registrar visualmente el impacto")

	# Esperar 0.45s (supera dur_pegada de 0.35s para enemigos muertos)
	await get_tree().create_timer(0.45).timeout

	# Assert: ya inició el desvanecimiento rápido
	assert_true(hacha._desvaneciendose, "Debe haber iniciado el desvanecimiento rápido sin esperar 3 segundos")


## 4. Si el enemigo sobrevivió pero se destruye luego, el hacha se desvanece de inmediato
func test_hacha_perrena_se_libera_si_enemigo_desaparece() -> void:
	# Arrange
	var hacha: HachaPerrenaProjectile = HachaScene.instantiate() as HachaPerrenaProjectile
	_root_test.add_child(hacha)

	var enemy_script := GDScript.new()
	enemy_script.source_code = "extends Node3D\nvar health: int = 10\nfunc take_damage(d: float) -> void:\n\thealth -= int(d)\n"
	enemy_script.reload()

	var enemy := Node3D.new()
	enemy.name = "GoblinFuerte"
	enemy.set_script(enemy_script)
	enemy.add_to_group("enemies")
	_root_test.add_child(enemy)

	hacha._procesar_impacto(enemy, Vector3.ZERO, Vector3.UP)
	assert_true(hacha.is_stuck)
	assert_false(hacha._desvaneciendose)

	# Act: el enemigo se libera (muere o sale de escena)
	enemy.free()
	await get_tree().process_frame

	# Assert: el hacha detecta tree_exiting y activa su desvanecimiento
	assert_true(hacha._desvaneciendose, "El hacha debe iniciar desvanecimiento si el enemigo desaparece")


## 5. De pie en niveles estándar, la hitbox de Perrena mide ~1.70m de altura en el mundo
func test_defensora_perrena_hitbox_dimensiones_de_pie() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.scale = Vector3(0.3, 0.3, 0.3)
	defensora._actualizar_dimensiones_hitbox()

	# Assert
	assert_false(defensora.en_canoa, "No debe estar en canoa por defecto")
	var col := defensora.hitbox_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_not_null(col)
	var shape := col.shape as CapsuleShape3D
	assert_not_null(shape)

	var alto_mundo: float = shape.height * defensora.scale.y
	assert_almost_eq(alto_mundo, 1.70, 0.05, "La altura mundo de pie debe ser aprox 1.70m")
	var radio_mundo: float = shape.radius * defensora.scale.x
	assert_almost_eq(radio_mundo, 0.35, 0.05, "El radio mundo de pie debe ser aprox 0.35m")


## 6. En modo canoa, la hitbox de Perrena se reduce a ~0.75m de altura en el mundo
func test_defensora_perrena_hitbox_dimensiones_en_canoa() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	# Escala de Perrena en canoa (0.18 bajo padre 2.0 = 0.36 mundo)
	defensora.scale = Vector3(0.36, 0.36, 0.36)

	# Act: activar modo canoa
	defensora.fijar_modo_canoa(true)

	# Assert
	assert_true(defensora.en_canoa, "Debe estar en modo canoa")
	var col := defensora.hitbox_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_not_null(col)
	var shape := col.shape as CapsuleShape3D
	assert_not_null(shape)

	var alto_mundo: float = shape.height * defensora.scale.y
	assert_almost_eq(alto_mundo, 0.75, 0.05, "La altura mundo en canoa debe ser aprox 0.75m (sentada)")
	var radio_mundo: float = shape.radius * defensora.scale.x
	assert_almost_eq(radio_mundo, 0.28, 0.05, "El radio mundo en canoa debe ser aprox 0.28m")

	# La cúspide de la cápsula debe quedar a 0.75m del piso, NO a 2.04m
	var pos_y_mundo: float = col.position.y * defensora.scale.y
	var tope_capsula_mundo: float = pos_y_mundo + (alto_mundo * 0.5)
	assert_almost_eq(tope_capsula_mundo, 0.75, 0.05, "El tope de la cápsula en mundo debe estar en 0.75m")
	assert_lt(tope_capsula_mundo, 1.0, "El tope de la cápsula sentada debe ser estrictamente menor a 1.0m")


## 7. Una flecha que pasa a 1.3m sobre el piso de la canoa no intersecta a Perrena sentada
func test_flecha_enemiga_alta_no_impacta_perrena_en_canoa() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.scale = Vector3(0.36, 0.36, 0.36)
	defensora.global_position = Vector3(0.0, 0.0, 0.0)
	defensora.fijar_modo_canoa(true)

	var col := defensora.hitbox_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var shape := col.shape as CapsuleShape3D

	var alto_mundo: float = shape.height * 0.36
	var pos_y_mundo: float = col.position.y * 0.36
	var tope_hitbox_y: float = pos_y_mundo + (alto_mundo * 0.5)

	# Una flecha volando a Y = 1.3m de altura
	var altura_flecha_alta: float = 1.3

	# Assert: la flecha está significativamente más arriba que el tope de la hitbox
	assert_gt(altura_flecha_alta, tope_hitbox_y + 0.4, "La flecha a 1.3m debe pasar limpiamente por encima del tope de 0.75m de Perrena")
