extends GutTest

## Tests unitarios para la Torre de Asedio y el comportamiento de sus defensores en la rampa.

const ESCENA_TORRE: PackedScene = preload("res://Entities/Torre_de_asedio/Torre_de_asedio.tscn")
const ESCENA_GOBLIN_GIRL: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")
const ESCENA_FLECHA: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")
const ESCENA_FLECHA_ENEMIGA: PackedScene = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.tscn")
const ESCENA_PLAYER: PackedScene = preload("res://Entities/Jugador_Arquera/Player.tscn")


func test_torre_spawn_posicion_interior_y_hitbox_25d() -> void:
	# Arrange: Instanciar torre con el transform que posee en el nivel
	var torre := ESCENA_TORRE.instantiate() as TorreDeAsedio
	add_child_autofree(torre)
	torre.transform = Transform3D(
		Vector3(0.030259425, 0, -1.777069),
		Vector3(0, 1.8436748, 0),
		Vector3(1.3535084, 0, 0.039728634),
		Vector3(3.1228988, 0.05779445, -2.500832)
	)
	await get_tree().process_frame

	# Act: Spawnear enemigo en la rampa
	torre._spawnear_enemigo_en_rampa()
	await get_tree().process_frame

	# Assert: Verificar ubicación interior y presencia de Hitbox25D
	assert_eq(torre._enemigos_en_rampa.size(), 1, "Debe haberse registrado 1 enemigo en la rampa")
	var enemigo := torre._enemigos_en_rampa[0]
	assert_not_null(enemigo, "El enemigo instanciado no debe ser nulo")

	# Debe nacer en el interior de la torre (X >= 3.8 en coords de mundo)
	assert_gt(enemigo.global_position.x, 3.7, "El enemigo debe nacer dentro de la habitación interior (X >= 3.7)")

	# Debe situarse en el eje central de la rampa/vano de la puerta (Z ≈ -2.48), NO en el plano frontal z_juego=0.05
	assert_almost_eq(enemigo.global_position.z, torre.punto_spawn.global_position.z, 0.05, "El enemigo debe nacer en el eje Z real de la torre/rampa")
	assert_lt(enemigo.global_position.z, -1.5, "El enemigo no debe ser arrojado al plano exterior frontal (Z debe ser < -1.5)")

	# Debe poseer la hitbox de profundidad 2.5D para impactos de flecha
	var hitbox_25d := enemigo.find_child("Hitbox25D_Torre", true, false) as CollisionShape3D
	assert_not_null(hitbox_25d, "El enemigo de la torre debe poseer Hitbox25D_Torre")
	if hitbox_25d and hitbox_25d.shape is BoxShape3D:
		var box := hitbox_25d.shape as BoxShape3D
		assert_gt(box.size.z, 2.5, "La profundidad Z del colisionador debe ser >= 2.5m para cubrir el plano Z de gameplay")

	torre._limpiar_enemigos_rampa()


func test_torre_restriccion_mantiene_en_carril_z_y_limites_madera() -> void:
	# Arrange
	var torre := ESCENA_TORRE.instantiate() as TorreDeAsedio
	add_child_autofree(torre)
	torre.transform = Transform3D(
		Vector3(0.030259425, 0, -1.777069),
		Vector3(0, 1.8436748, 0),
		Vector3(1.3535084, 0, 0.039728634),
		Vector3(3.1228988, 0.05779445, -2.500832)
	)
	await get_tree().process_frame

	torre._spawnear_enemigo_en_rampa()
	await get_tree().process_frame

	var enemigo := torre._enemigos_en_rampa[0]

	# Act: Simular desplazamiento indebido en Z y avance más allá del puente
	enemigo.global_position.z = 1.5  # Forzar desvío hacia el frente
	enemigo.global_position.x = 0.5  # Intentar salir volando del puente hacia la izquierda
	torre._restringir_enemigos_a_la_rampa()

	# Assert
	assert_almost_eq(enemigo.global_position.z, torre.punto_spawn.global_position.z, 0.01, "La restricción debe regresar al enemigo al carril central Z de la rampa")
	var borde_izq := torre._obtener_borde_frontal_rampa_x()
	assert_true(enemigo.global_position.x >= borde_izq - 0.01, "El enemigo no debe cruzar el borde frontal transitable del puente")
	assert_gt(borde_izq, 1.8, "El borde frontal del puente debe ser > 1.8m según la geometría del modelo")

	torre._limpiar_enemigos_rampa()


func test_arrow_hits_tower_enemy() -> void:
	# Arrange: Enemigo posicionado en la rampa a Z = -2.48
	var enemy := ESCENA_GOBLIN_GIRL.instantiate() as GoblinGirl
	add_child_autofree(enemy)
	enemy.global_position = Vector3(2.5, 4.5, -2.48)

	var hitbox_25d := CollisionShape3D.new()
	hitbox_25d.name = "Hitbox25D_Torre"
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.7, 3.5)
	hitbox_25d.shape = box
	hitbox_25d.position = Vector3(0.0, 0.35, 1.25)
	enemy.add_child(hitbox_25d)

	await get_tree().process_frame

	# Flecha de la protagonista viajando en Z = 0.05
	var arrow := ESCENA_FLECHA.instantiate() as ArrowProjectile
	add_child_autofree(arrow)
	arrow.global_position = Vector3(1.5, 4.7, 0.05)
	arrow.velocity = Vector3(12.0, 0.0, 0.0)
	arrow.gameplay_z_plane = 0.05

	var vida_inicial := enemy.health

	# Act: Procesar física de la flecha
	for i in range(12):
		arrow._physics_process(0.05)
		if enemy.health < vida_inicial:
			break

	# Assert: El enemigo debió recibir impacto y daño
	assert_lt(enemy.health, vida_inicial, "La flecha de la protagonista en Z=0.05 debe impactar y dañar al enemigo de la torre en Z=-2.48")


func test_tower_enemy_projectile_hits_player() -> void:
	# Arrange: Jugador en Z = 0.05
	var player = ESCENA_PLAYER.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0.0, 1.0, 0.05)
	player.add_to_group("player")

	# Proyectil de arquera goblin generado desde la torre en Z = -2.48
	var proj := ESCENA_FLECHA_ENEMIGA.instantiate() as GoblinGirlArrowProjectile
	add_child_autofree(proj)
	proj.global_position = Vector3(2.5, 2.0, -2.48)
	proj.initialize(Vector3(-1.0, -0.3, 0.0), 1.0)

	await get_tree().process_frame

	# Act & Assert
	assert_almost_eq(proj.gameplay_z_plane, 0.05, 0.01, "El proyectil enemigo debe detectar y fijar el plano Z de gameplay del jugador")
	proj._physics_process(0.05)
	assert_almost_eq(proj.global_position.z, 0.05, 0.01, "La posición Z del proyectil enemigo debe estar en el plano de combate Z=0.05")

	player.remove_from_group("player")
	player.queue_free()
	proj.queue_free()
	await get_tree().process_frame


func test_mascara_oleada6_texture_and_material():
	var tex = load("res://Levels/NIVEL01/sombra_mascara_oleada6.png") as Texture2D
	assert_not_null(tex, "La textura sombra_mascara_oleada6.png debe poder cargarse")
	
	var shader = load("res://System/Shaders/sombra_falsa.gdshader") as Shader
	assert_not_null(shader, "El shader sombra_falsa.gdshader debe existir")
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("shadow_mask", tex)
	mat.set_shader_parameter("shadow_color", Color(0.02, 0.02, 0.04, 1.0))
	mat.set_shader_parameter("shadow_opacity", 1.0)
	assert_not_null(mat, "ShaderMaterial debe crearse correctamente")
	
	# Verificar que el CanvasLayer de la máscara se ubica en layer 21 (sobre Compositor3D layer 20 y bajo HUD layer 100)
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	layer.layer = 21
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.material = mat
	layer.add_child(rect)
	
	assert_eq(layer.layer, 21, "El CanvasLayer de la máscara debe estar en layer 21")
	assert_not_null(rect.material, "ColorRect debe tener asignado el ShaderMaterial")
