extends "res://addons/gut/test.gd"

## Tests unitarios para el sistema de no colisión entre unidades a pie aliadas
## y prioridad visual (profundidad Z) de la protagonista y los 5 defensores:
## 1. Arquera
## 2. Perrena
## 3. Ballestera
## 4. Imperio Hombre (Imperio Man)
## 5. Imperio Girl

const PlayerScript = preload("res://Entities/Jugador_Arquera/Player.gd")
const AllyArcherScript = preload("res://Entities/Aliada_Arquera/AllyArcher.gd")
const AllyBallesteraScript = preload("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
const DefensoraPerrenaScript = preload("res://Entities/Defensora_Perrena/DefensoraPerrena.gd")
const ImperioManScript = preload("res://Entities/Enemigo_ImperioMan/ImperioMan.gd")
const ImperioGirlScript = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.gd")

const PlayerScene: PackedScene = preload("res://Entities/Jugador_Arquera/Player.tscn")
const ArcherScene: PackedScene = preload("res://Entities/Aliada_Arquera/AllyArcher.tscn")
const BallesteraScene: PackedScene = preload("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")
const DefensoraScene: PackedScene = preload("res://Entities/Defensora_Perrena/DefensoraPerrena.tscn")
const ImperioManScene: PackedScene = preload("res://Entities/Enemigo_ImperioMan/ImperioMan.tscn")
const ImperioGirlScene: PackedScene = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.tscn")


func test_sin_colision_fisica_entre_los_5_defensores_aliados() -> void:
	# Arrange: Instanciar los 5 defensores aliados a pie
	var player: Player = PlayerScene.instantiate() as Player
	var archer: AllyArcher = ArcherScene.instantiate() as AllyArcher
	var ballestera: AllyBallestera = BallesteraScene.instantiate() as AllyBallestera
	var perrena: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	var imperio_man: ImperioMan = ImperioManScene.instantiate() as ImperioMan
	var imperio_girl: ImperioGirl = ImperioGirlScene.instantiate() as ImperioGirl

	add_child_autofree(player)
	add_child_autofree(archer)
	add_child_autofree(ballestera)
	add_child_autofree(perrena)
	add_child_autofree(imperio_man)
	add_child_autofree(imperio_girl)

	# Act
	player._aplicar_colision_jugador()
	imperio_girl._aplicar_colision_jugador()

	# Assert 1: Capa y máscaras de protagonistas (Player e Imperio Girl)
	for prota in [player, imperio_girl]:
		assert_eq(prota.collision_layer, 1, "La protagonista debe pertenecer a capa 1")
		assert_eq(prota.collision_mask & (1 << 1), 0, "No debe colisionar físicamente con capa 2 (defensoras)")
		assert_eq(prota.collision_mask & (1 << 3), 0, "No debe colisionar con capa 4 (proyectiles)")

	# Assert 2: Hitboxes de aliadas a distancia y de soporte no tienen máscara sólida
	assert_eq(archer.hitbox_body.collision_mask, 0, "Hitbox de arquera debe tener mask 0")
	assert_eq(ballestera.hitbox_body.collision_mask, 0, "Hitbox de ballestera debe tener mask 0")
	assert_eq(perrena.hitbox_body.collision_mask, 0, "Hitbox de Perrena debe tener mask 0")

	# Assert 3: Excepciones de colisión activas para Imperio Man
	assert_true(
		imperio_man.get_collision_exceptions().has(player) or player.get_collision_exceptions().has(imperio_man),
		"Imperio Man y Player deben tener excepción de colisión mutua para traspasarse sin chocar"
	)


func test_jerarquia_visual_completa_5_defensores_sin_interseccion() -> void:
	# Arrange: Instanciar las unidades defensoras
	var player: Player = PlayerScene.instantiate() as Player
	var imperio_man: ImperioMan = ImperioManScene.instantiate() as ImperioMan
	var ballestera: AllyBallestera = BallesteraScene.instantiate() as AllyBallestera
	var perrena: DefensoraPerrena = DefensoraScene.instantiate() as DefensoraPerrena
	var archer: AllyArcher = ArcherScene.instantiate() as AllyArcher

	add_child_autofree(player)
	add_child_autofree(imperio_man)
	add_child_autofree(ballestera)
	add_child_autofree(perrena)
	add_child_autofree(archer)

	# Act: Extraer posiciones globales Z de las mallas visuales efectivas
	var z_vis_prota: float = player.visual_model.global_position.z if player.visual_model else player.global_position.z + Player.OFFSET_VISUAL_PROTA_BASE_Z
	var z_vis_imp_man: float = imperio_man.model_root.global_position.z if imperio_man.model_root else imperio_man.global_position.z
	var z_vis_ballestera: float = ballestera.model_root.global_position.z if ballestera.model_root else ballestera.global_position.z
	var z_vis_perrena: float = perrena.model_root.global_position.z if perrena.model_root else perrena.global_position.z
	var z_vis_archer: float = archer.model_root.global_position.z if archer.model_root else archer.global_position.z

	# Assert: Cadena estricta y escalonada de profundidad visual:
	# Protagonista > Imperio Hombre > Ballestera > Perrena > Arquera
	assert_gt(z_vis_prota, z_vis_imp_man, "La protagonista debe renderizarse visualmente por delante de Imperio Hombre")
	assert_gt(z_vis_imp_man, z_vis_ballestera, "Imperio Hombre debe renderizarse visualmente por delante de la ballestera")
	assert_gt(z_vis_ballestera, z_vis_perrena, "La ballestera debe renderizarse visualmente por delante de Perrena")
	assert_gt(z_vis_perrena, z_vis_archer, "Perrena debe renderizarse visualmente por delante de la arquera aliada")


func test_imperio_girl_comparte_maxima_prioridad_visual_frontal() -> void:
	# Arrange
	var girl: ImperioGirl = ImperioGirlScene.instantiate() as ImperioGirl
	var archer: AllyArcher = ArcherScene.instantiate() as AllyArcher

	add_child_autofree(girl)
	add_child_autofree(archer)

	# Act
	var z_vis_girl: float = girl.visual_model.global_position.z if girl.visual_model else girl.global_position.z + Player.OFFSET_VISUAL_PROTA_BASE_Z
	var z_vis_archer: float = archer.model_root.global_position.z if archer.model_root else archer.global_position.z

	# Assert
	assert_gt(z_vis_girl, z_vis_archer, "Imperio Girl debe tener máxima prioridad visual frontal sobre la defensora arquera")


func test_adaptacion_dinamica_prioridad_visual_protagonista_ante_aliado_cercano() -> void:
	# Arrange
	var player: Player = PlayerScene.instantiate() as Player
	add_child_autofree(player)
	player.global_position = Vector3(0.0, 0.0, 0.0)

	var npc_dummy := Node3D.new()
	npc_dummy.name = "DefensoraCercana"
	npc_dummy.add_to_group("allies")
	add_child_autofree(npc_dummy)

	# Simular defensora ubicada en Z = 2.0 y a 1 metro de distancia en X
	npc_dummy.global_position = Vector3(1.0, 0.0, 2.0)

	# Act: Simular actualización de física para calcular prioridad visual dinámica
	player._actualizar_prioridad_visual_frente(0.5)

	# Assert: El modelo de la protagonista debe haber subido su Z por encima del aliado + MARGEN
	var z_vis_player: float = player.visual_model.global_position.z
	var z_esperado_minimo: float = npc_dummy.global_position.z + Player.MARGEN_VISUAL_FRENTE_Z

	assert_gt(z_vis_player, npc_dummy.global_position.z, "La protagonista debe verse por delante de la defensora aliada")
	assert_almost_eq(z_vis_player, z_esperado_minimo, 0.1, "La protagonista debe posicionarse con el margen visual de seguridad sobre la defensora")


func test_npcs_patrulleros_nivel_pueblo_separados_en_z_sin_interseccion() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Act
	var npc2: Node3D = nivel.find_child("ArqueraAliadaNPC2", true, false) as Node3D
	var npc6: Node3D = nivel.find_child("ArqueraAliadaNPC6", true, false) as Node3D

	# Assert
	assert_not_null(npc2, "ArqueraAliadaNPC2 debe existir en NivelPueblo")
	assert_not_null(npc6, "ArqueraAliadaNPC6 debe existir en NivelPueblo")

	var diff_z: float = absf(npc2.position.z - npc6.position.z)
	assert_gt(diff_z, 0.20, "Las dos arqueras patrulleras del pueblo deben tener al menos 20 cm de separación en Z para no atravesarse (actual: %.2fm)" % diff_z)


func test_dialogo_pueblo_no_pausa_aliados_ni_npcs() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")

	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	var npc2: Node3D = nivel.find_child("ArqueraAliadaNPC2", true, false) as Node3D
	assert_not_null(npc2, "ArqueraAliadaNPC2 debe existir en NivelPueblo")

	# Act: Simular activación de diálogo inicial en Nivel Pueblo
	nivel._set_juego_pausado_dialogo(true)

	# Assert: El NPC aliado en Nivel Pueblo debe permanecer procesando activamente
	assert_true(npc2.is_processing(), "En Nivel Pueblo, los NPCs/aliados deben seguir procesando durante el diálogo para mantener sus rutinas")

	# Limpieza
	nivel._set_juego_pausado_dialogo(false)
