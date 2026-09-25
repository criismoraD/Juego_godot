extends GutTest

## El ult de despedida del canon persigue a la canoa en el rio y su
## explosion dana en area (antes caia donde la canoa ESTABA y no danaba).

const FLECHA_ULT_SCENE: PackedScene = preload("res://Entities/Enemigo_Lonko/Flecha_Electrica_Ataque.tscn")

var scene_root: Node3D


class JugadorFalsoUlt extends Node3D:
	var salud: int = 5
	var golpes: int = 0
	var paralisis: float = 0.0

	func take_damage(amount: float) -> void:
		golpes += 1
		salud -= int(amount)

	func aplicar_paralisis(seg: float) -> void:
		paralisis = seg


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_marca_sigue_a_canoa_con_jugadora_a_bordo() -> void:
	# Arrange: flecha + canoa + jugadora a bordo
	var flecha := FLECHA_ULT_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame
	var canoa := Node3D.new()
	canoa.name = "CanoaSeguimiento"
	canoa.add_to_group("canoas_aliadas")
	scene_root.add_child(canoa)
	canoa.global_position = Vector3(10, 0, -7.5)
	var jug := Node3D.new()
	jug.add_to_group("player")
	scene_root.add_child(jug)
	jug.global_position = Vector3(10, 0.5, -7.5)
	var marca := Node3D.new()
	scene_root.add_child(marca)
	flecha._punto_caida = Vector3(0, 0, 0)
	flecha._marca = marca

	# Act: la canoa avanza con la jugadora a bordo
	flecha._actualizar_punto_caida_movil()

	# Assert: punto y marca siguen a la canoa
	assert_eq(flecha._punto_caida.x, 10.0, "El punto debe seguir a la canoa")
	assert_eq(marca.global_position.x, 10.0, "La marca debe moverse con el punto")

	# Act: la jugadora se aleja de la canoa (ya no va a bordo)
	jug.global_position = Vector3(50, 0.5, -7.5)
	flecha._actualizar_punto_caida_movil()

	# Assert: punto fijo (esquivable, como en NIVEL01)
	assert_eq(flecha._punto_caida.x, 10.0, "Sin jugadora a bordo el punto queda fijo")


func test_marca_queda_fija_sin_canoa() -> void:
	# Arrange: flecha sin canoa en escena (NIVEL01)
	var flecha := FLECHA_ULT_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame
	flecha._punto_caida = Vector3(-8, 0, 0)

	# Act
	flecha._actualizar_punto_caida_movil()

	# Assert
	assert_eq(flecha._punto_caida.x, -8.0, "Sin canoa el punto queda fijo")


func test_explosion_dana_en_area_y_no_duplica() -> void:
	# Arrange: flecha + jugadora dentro del radio
	var flecha := FLECHA_ULT_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame
	flecha.global_position = Vector3(0, 0.3, 0)
	var jug := JugadorFalsoUlt.new()
	jug.add_to_group("player")
	scene_root.add_child(jug)
	jug.global_position = Vector3(0.3, 0.5, 0.0)

	# Act
	flecha._aplicar_dano_en_area()

	# Assert: dano + paralisis una sola vez
	assert_eq(jug.golpes, 1, "La jugadora recibe el golpe en area")
	assert_eq(jug.salud, 4, "La vida baja 1")
	assert_eq(jug.paralisis, 4.0, "Aplica paralisis")

	# Act: segunda aplicacion (contacto + explosion el mismo frame)
	flecha._aplicar_dano_en_area()

	# Assert: sin duplicar
	assert_eq(jug.golpes, 1, "No debe duplicar el golpe")


func test_explosion_fuera_de_radio_no_dana() -> void:
	# Arrange: jugadora lejos del impacto
	var flecha := FLECHA_ULT_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame
	flecha.global_position = Vector3(0, 0.3, 0)
	var jug := JugadorFalsoUlt.new()
	jug.add_to_group("player")
	scene_root.add_child(jug)
	jug.global_position = Vector3(5, 0.5, 0.0)

	# Act
	flecha._aplicar_dano_en_area()

	# Assert
	assert_eq(jug.golpes, 0, "Fuera del radio no hay dano")
	assert_eq(jug.salud, 5, "La vida queda intacta")


func test_marca_no_persigue_a_jugadora_al_moverse_en_canoa() -> void:
	# Arrange: flecha + canoa en X=10 + jugadora en X=10 (offset relativo 0.0)
	var flecha := FLECHA_ULT_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame
	var canoa := Node3D.new()
	canoa.name = "CanoaNoPersigue"
	canoa.add_to_group("canoas_aliadas")
	scene_root.add_child(canoa)
	canoa.global_position = Vector3(10, 0, -7.5)
	var jug := Node3D.new()
	jug.add_to_group("player")
	scene_root.add_child(jug)
	jug.global_position = Vector3(10, 0.5, -7.5)
	var marca := Node3D.new()
	scene_root.add_child(marca)
	flecha._punto_caida = Vector3(0, 0, 0)
	flecha._marca = marca

	# Act 1: Se fija la marca inicial en la canoa donde estaba la jugadora (offset 0)
	flecha._actualizar_punto_caida_movil()
	assert_eq(flecha._punto_caida.x, 10.0, "Punto marcado inicialmente en X=10")

	# Act 2: La jugadora se mueve hacia la derecha en la canoa para esquivar (X=10.8)
	jug.global_position = Vector3(10.8, 0.5, -7.5)
	flecha._actualizar_punto_caida_movil()

	# Assert 2: El punto de caída NO debe perseguir a la jugadora; queda en el offset original (10.0)
	assert_eq(flecha._punto_caida.x, 10.0, "El ult no debe perseguir a la jugadora al moverse en la canoa")
	assert_eq(marca.global_position.x, 10.0, "La marca visual no debe seguir a la jugadora")

	# Act 3: La canoa avanza a X=14.0 mientras la jugadora sigue esquivada en X=14.8
	canoa.global_position = Vector3(14.0, 0, -7.5)
	jug.global_position = Vector3(14.8, 0.5, -7.5)
	flecha._actualizar_punto_caida_movil()

	# Assert 3: El punto avanza solidario a la canoa (14.0 + 0.0), no con la jugadora (14.8)
	assert_eq(flecha._punto_caida.x, 14.0, "El punto avanza con la canoa manteniendo el offset fijo de la marca")


func test_jugadora_en_canoa_esquiva_dano_fuera_de_radio() -> void:
	# Arrange: Flecha impacta en la canoa en X=0.0; la jugadora se movio a X=0.7 (fuera de radio_dano_area=0.40)
	var flecha := FLECHA_ULT_SCENE.instantiate() as FlechaElectricaAtaque
	scene_root.add_child(flecha)
	await get_tree().process_frame
	flecha.global_position = Vector3(0, 0.3, 0)
	var canoa := Node3D.new()
	canoa.add_to_group("canoas_aliadas")
	scene_root.add_child(canoa)
	canoa.global_position = Vector3(0, 0, 0)
	var jug := JugadorFalsoUlt.new()
	jug.add_to_group("player")
	scene_root.add_child(jug)
	jug.global_position = Vector3(0.7, 0.3, 0.0)  # A 0.7m del centro (radio_dano_area es 0.40)

	# Act: Detonación del impacto
	flecha._aplicar_dano_en_area()

	# Assert: La jugadora no recibe daño a pesar de estar a bordo de la canoa
	assert_eq(jug.golpes, 0, "La jugadora esquivo el impacto al alejarse de la marca")
	assert_eq(jug.salud, 5, "La vida se mantiene intacta tras esquivar")

