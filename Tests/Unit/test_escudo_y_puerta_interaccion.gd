extends GutTest

## Test unitario para verificar:
## 1. Parpadeo en rojo de los escudos (aliados y enemigos) al recibir impacto.
## 2. Orientación de la protagonista dando la espalda a la cámara (-Z) al entrar a la torre.

func test_escudo_material_flash_rojo() -> void:
	# Arrange
	var escudo_scene: PackedScene = load("res://Entities/Ambiente_Escudo/Escudo.tscn")
	var escudo_enemigo_scene: PackedScene = load("res://Entities/Ambiente_Escudo/Escudo_enemigo.tscn")
	
	var escudo: EscudoDestruible = escudo_scene.instantiate() as EscudoDestruible
	var escudo_enemigo: EscudoDestruible = escudo_enemigo_scene.instantiate() as EscudoDestruible
	add_child_autofree(escudo)
	add_child_autofree(escudo_enemigo)

	# Act
	var mat_flash_defensor: StandardMaterial3D = escudo._crear_material_flash(Color(1.0, 0.08, 0.08, 1.0), 3.0)
	var mat_flash_enemigo: StandardMaterial3D = escudo_enemigo._crear_material_flash(Color(1.0, 0.08, 0.08, 1.0), 3.0)

	# Assert
	assert_not_null(mat_flash_defensor, "El material de flash del defensor debe existir")
	assert_eq(mat_flash_defensor.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "El material de flash debe ser UNSHADED para visibilidad óptima")
	assert_gt(mat_flash_defensor.albedo_color.r, 0.8, "El color albedo de flash debe ser predominantemente rojo")
	assert_lt(mat_flash_defensor.albedo_color.g, 0.2, "El componente verde debe ser bajo")
	assert_lt(mat_flash_defensor.albedo_color.b, 0.2, "El componente azul debe ser bajo")
	assert_true(mat_flash_defensor.emission_enabled, "La emisión debe estar habilitada")

	assert_not_null(mat_flash_enemigo, "El material de flash del enemigo debe existir")
	assert_eq(mat_flash_enemigo.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "El material de flash enemigo debe ser UNSHADED")
	assert_gt(mat_flash_enemigo.albedo_color.r, 0.8, "El color albedo enemigo de flash debe ser predominantemente rojo")


func test_escudo_recolectar_mallas_ignora_flechas() -> void:
	# Arrange
	var escudo_scene: PackedScene = load("res://Entities/Ambiente_Escudo/Escudo.tscn")
	var escudo: EscudoDestruible = escudo_scene.instantiate() as EscudoDestruible
	add_child_autofree(escudo)

	# Simular una flecha clavada como hijo
	var flecha_simulada := Node3D.new()
	flecha_simulada.name = "Arrow_Stuck_01"
	flecha_simulada.add_to_group("flechas")
	var flecha_mesh := MeshInstance3D.new()
	flecha_simulada.add_child(flecha_mesh)
	escudo.add_child(flecha_simulada)

	# Act
	var mallas: Array[MeshInstance3D] = escudo._recolectar_mallas()

	# Assert
	assert_gt(mallas.size(), 0, "El escudo debe recolectar sus propias mallas")
	assert_false(mallas.has(flecha_mesh), "Las mallas de flechas clavadas deben ser ignoradas para el flash")


func test_puerta_arquera_orientacion_espalda_camara() -> void:
	# Arrange
	var puerta_script: GDScript = load("res://Levels/NIVEL01/PuertaTrigger.gd") as GDScript
	var puerta: Area3D = Area3D.new()
	puerta.set_script(puerta_script)
	add_child_autofree(puerta)

	var player_scene: PackedScene = load("res://Entities/Jugador_Arquera/Player.tscn")
	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	add_child_autofree(player)
	player.global_position = Vector3(0.0, 0.0, 0.0)

	var armature: Node3D = player.find_child("Armature", true, false) as Node3D
	var arquera_model: Node3D = player.find_child("ArqueraModel", true, false) as Node3D
	assert_not_null(armature, "Armature debe existir en Player")
	assert_not_null(arquera_model, "ArqueraModel debe existir en Player")

	# Act
	puerta._jugador_ref = player
	puerta._iniciar_secuencia_entrada()

	# Esperar un momento a que el tween comience/aplique la rotación
	await wait_seconds(0.26)

	# Assert
	# Armature.rotation.y = 90 deg (PI/2) orienta el frente del personaje hacia -Z (de espaldas a la cámara)
	var arm_rot_y_deg: float = rad_to_deg(armature.rotation.y)
	assert_almost_eq(arm_rot_y_deg, 90.0, 1.5, "Armature debe estar rotado a 90 grados (PI/2) para dar la espalda a la camara")

	# Verificar que el eje hacia adelante en espacio de mundo apunte hacia -Z (de espaldas a la cámara)
	var forward_world: Vector3 = armature.global_transform.basis.y
	assert_lt(forward_world.z, -0.01, "El eje frontal del personaje debe apuntar hacia -Z (hacia el fondo / torre / espalda a cámara)")


func test_escudo_aliado_profundidad_z_detras_de_protagonista() -> void:
	# Arrange
	var escudo_scene: PackedScene = load("res://Entities/Ambiente_Escudo/Escudo.tscn")
	var escudo: EscudoDestruible = escudo_scene.instantiate() as EscudoDestruible
	escudo.position = Vector3(0.0, 0.0, 0.0)

	var player_scene: PackedScene = load("res://Entities/Jugador_Arquera/Player.tscn")
	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D

	# Act
	add_child_autofree(escudo)
	add_child_autofree(player)

	# Assert
	assert_true(escudo.auto_profundidad_aliado, "auto_profundidad_aliado debe estar activado por defecto")
	assert_almost_eq(escudo.global_position.z, escudo.plano_profundidad_aliado_z, 0.01, "El escudo aliado debe posicionarse en o detrás de su plano Z (-0.38)")
	assert_gt(player.plano_profundidad_z, escudo.global_position.z, "La protagonista debe tener un plano Z superior al escudo para verse siempre por delante")


func test_escudo_enemigo_animacion_impacto_y_flash_rojo() -> void:
	# Arrange
	var escudo_enemigo_scene: PackedScene = load("res://Entities/Ambiente_Escudo/Escudo_enemigo.tscn")
	var escudo: EscudoDestruible = escudo_enemigo_scene.instantiate() as EscudoDestruible
	add_child_autofree(escudo)

	# Act
	var mat_flash: StandardMaterial3D = escudo._crear_material_flash(Color(1.0, 0.08, 0.08, 1.0), 3.0)
	escudo._flash_dano()

	# Assert
	assert_true(escudo.es_escudo_enemigo, "Debe ser escudo enemigo")
	assert_gt(mat_flash.albedo_color.r, 0.8, "El parpadeo debe ser rojo")
	assert_lt(mat_flash.albedo_color.g, 0.2, "El componente verde debe ser bajo")
	assert_not_null(escudo._escala_base, "La escala base debe ser registrada para el punch de impacto")


func test_imp_escudo_animacion_impacto_y_flash_rojo() -> void:
	# Arrange
	var imp_scene: PackedScene = load("res://Entities/Enemigo_Imp_Escudo/ImpShieldGirl.tscn")
	var imp: ImpShieldGirl = imp_scene.instantiate() as ImpShieldGirl
	add_child_autofree(imp)

	# Act
	imp._flash_escudo()

	# Assert
	assert_not_null(imp.escudo_node, "El Imp debe tener nodo de escudo")
	assert_not_null(imp._flash_mat, "El Imp debe tener material de flash")
	assert_gt(imp._flash_mat.albedo_color.r, 0.8, "El flash del escudo del Imp debe ser rojo")
	assert_lt(imp._flash_mat.albedo_color.g, 0.2, "El componente verde debe ser bajo")
	assert_true(imp.has_meta("_escudo_orig_scale"), "Debe guardar la escala original del escudo para la animación de expansión y contracción")


func test_guardiana_moradita_escudo_animacion_impacto_y_flash_rojo() -> void:
	# Arrange
	var goblina_scene: PackedScene = load("res://Entities/Enemigo_Goblina_Escudo_Pesado/GuardianaMoradita.tscn")
	var goblina: GuardianaMoradita = goblina_scene.instantiate() as GuardianaMoradita
	add_child_autofree(goblina)

	# Act
	goblina._flash_impacto_escudo_rojo()

	# Assert
	assert_not_null(goblina._flash_rojo_mat, "Debe tener material de flash rojo")
	assert_gt(goblina._flash_rojo_mat.albedo_color.r, 0.8, "El flash debe ser rojo")
	assert_lt(goblina._flash_rojo_mat.albedo_color.g, 0.2, "El componente verde debe ser bajo")
	assert_true(goblina.has_meta("_escudo_orig_scale"), "Debe guardar la escala original del escudo pesado para la animación de expansión y contracción")
