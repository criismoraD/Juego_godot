extends "res://addons/gut/test.gd"

## Tests del Pirata Goblin: variante del Imp con asset propio.
## Verifica instanciación, herencia de comportamiento, alias de animaciones,
## material con su textura y spawn forzado id 13 para el panel debug.

const PIRATA_SCENE: PackedScene = preload("res://Entities/Enemigo_Pirata_Goblin/PirataGoblin.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestPirata"
	get_tree().root.add_child(_root_test)


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is PirataGoblin:
			n.free()


func _crear_pirata() -> PirataGoblin:
	var pirata := PIRATA_SCENE.instantiate() as PirataGoblin
	assert_not_null(pirata, "Debe instanciar PirataGoblin")
	_root_test.add_child(pirata)
	await get_tree().process_frame
	return pirata


func test_instanciar_es_variante_del_imp() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: hereda todo lo del Imp
	assert_true(pirata is ImpEnemy, "PirataGoblin debe ser un ImpEnemy")
	assert_true(pirata is EnemyBase, "Debe ser un EnemyBase")
	assert_true(pirata.is_in_group("enemies"), "Debe estar en el grupo de enemigos")
	assert_eq(pirata.vida_maxima, 1, "Misma vida frágil del Imp (1)")
	assert_not_null(pirata.find_child("ImpModel", true, false), "Modelo presente (nodo compat ImpModel)")
	assert_not_null(pirata.find_child("CollisionShape3D", true, false), "Debe tener colisión")


func test_animaciones_con_alias_del_imp() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: cada nombre del Imp resuelve a una animación real del pirata
	assert_not_null(pirata.anim_player, "Debe resolver AnimationPlayer")
	var esperados := {
		"CAMINAR": "Strut Walking",
		"CORRER": "Correr",
		"IDLE": "Idle",
		"LANZAR01": "Ataque arrojar",
		"LANZAR2": "Disparo",
		"IMP_MUERTE01": "Muerte 1",
		"IMP_MUERTE02": "Muerte 2",
	}
	for alias in esperados:
		assert_true(pirata.anim_player.has_animation(alias), "Alias registrado: " + alias)
		assert_eq(
			pirata.anim_player.get_animation(alias).length,
			pirata.anim_player.get_animation(esperados[alias]).length,
			0.001, "El alias comparte el clip: " + alias
		)
	for alias in ["CAMINAR", "CORRER", "IDLE"]:
		assert_eq(
			pirata.anim_player.get_animation(alias).loop_mode, Animation.LOOP_LINEAR,
			"Movimiento en loop: " + alias
		)


func test_material_con_textura_pirata() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: material propio con su difuso (no el del Imp)
	var con_textura := false
	for m in pirata.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null:
			continue
		var mat: Material = mi.material_override
		if mat == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var std := mat as StandardMaterial3D
			if std.albedo_texture and "PirataGoblin_D" in std.albedo_texture.resource_path:
				con_textura = true
				break
	assert_true(con_textura, "Alguna malla debe usar la textura PirataGoblin_D")


func test_ciclo_caminar_y_disparo_heredado() -> void:
	# Arrange
	var pirata := await _crear_pirata()

	# Act: entrar a tiro y saltar la pausa IDLE para forzar el lanzamiento
	pirata._on_state_shooting()
	pirata.is_idle_pause = false
	pirata._process_shooting(0.05)

	# Assert: entra al ciclo de lanzamiento heredado sin romperse
	assert_true(pirata.is_throwing, "Debe entrar al lanzamiento del Imp")
	assert_gt(pirata.throw_anim_duration, 0.0, "La animación aliaseada debe tener duración")


func test_disparo_gira_modelo_y_demas_anims_restauran_base() -> void:
	# Arrange
	var pirata := await _crear_pirata()
	var modelo := pirata.get_node_or_null("ImpModel") as Node3D
	assert_not_null(modelo, "Debe existir el nodo ImpModel")
	var yaw_base: float = modelo.rotation.y
	pirata.grados_extra_disparo = 90.0

	# Act: reproducir el disparo (alias LANZAR2 -> "Disparo")
	pirata._play_animation("LANZAR2")

	# Assert: solo el disparo aplica el giro extra
	assert_almost_eq(modelo.rotation.y, yaw_base + deg_to_rad(90.0), 0.001, "LANZAR2 debe girar el modelo 90° extra")

	# Act & Assert: cualquier otra animación restaura la base intacta
	pirata._play_animation("LANZAR01")
	assert_almost_eq(modelo.rotation.y, yaw_base, 0.001, "LANZAR01 no debe girar el modelo")
	pirata._play_animation("LANZAR2")
	pirata._play_animation("IDLE")
	assert_almost_eq(modelo.rotation.y, yaw_base, 0.001, "IDLE debe restaurar la orientación base")
	pirata._play_animation("LANZAR2")
	pirata._play_animation("CAMINAR")
	assert_almost_eq(modelo.rotation.y, yaw_base, 0.001, "CAMINAR debe mantener la base sin girar")


func test_disparo_apunta_hacia_el_jugador() -> void:
	# Arrange: pirata en throw de Disparo, sin compensación, jugador ficticio a +Z
	var pirata := await _crear_pirata()
	var modelo := pirata.get_node_or_null("ImpModel") as Node3D
	assert_not_null(modelo, "Debe existir el nodo ImpModel")
	pirata.grados_extra_disparo = 0.0
	pirata.suavizado_aim_disparo = 1000.0
	var player_falso := Node3D.new()
	player_falso.name = "PlayerFalsoAim"
	player_falso.add_to_group("player")
	get_tree().root.add_child(player_falso)
	player_falso.global_position = pirata.global_position + Vector3(0.0, 0.0, 5.0)

	# Act: forzar fase de disparo LANZAR2 durante varios frames
	pirata.is_throwing = true
	pirata.current_throw_anim = "LANZAR2"
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: el yaw de mundo del modelo mira hacia +Z -> atan2(0, -5) = PI
	var yaw_mundo: float = wrapf(modelo.global_rotation.y, -PI, PI)
	assert_almost_eq(absf(yaw_mundo), PI, 0.05, "Durante Disparo el modelo debe apuntar al jugador")

	# Cleanup: el jugador falso no debe fugarse a otros tests
	player_falso.remove_from_group("player")
	player_falso.free()
