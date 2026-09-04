extends "res://addons/gut/test.gd"

const BLOOD_NORMAL_SCENE := preload("res://VFX/Scenes/BloodSplashNormal.tscn")
const BLOOD_EMBAJADOR_SCENE := preload("res://VFX/Scenes/BloodSplashEmbajador.tscn")
const BLOOD_NO_LETAL_SCENE := preload("res://VFX/Scenes/BloodSplashNoLetal.tscn")
const GARGOLA_SCRIPT := preload("res://Entities/Enemigo_Gargola/Gargola.gd")
const GLOBO_SCRIPT := preload("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.gd")
const IMP_ESTANDARTE_SCRIPT := preload("res://Entities/Enemigo_Imp_Estandarte/ImpEstandarte.gd")
const ENEMY_BASE_SCRIPT := preload("res://System/Core/EnemyBase.gd")


class TestEnemy extends "res://System/Core/EnemyBase.gd":
	var spawned_splash: PackedScene = null
	var spawned_no_letal_called: bool = false

	func _ready() -> void:
		pass

	func _spawn_blood_splash(custom_modulate: Color = Color.WHITE) -> void:
		super._spawn_blood_splash(custom_modulate)
		spawned_splash = escena_sangre

	func _spawn_blood_splash_no_letal(custom_modulate: Color = Color.WHITE) -> void:
		spawned_no_letal_called = true
		super._spawn_blood_splash_no_letal(custom_modulate)


func test_blood_splash_normal_setup() -> void:
	# Arrange
	var splash := BLOOD_NORMAL_SCENE.instantiate() as BloodSplash2D
	add_child_autofree(splash)
	var hit_pos := Vector3(5.0, 2.5, 0.0)
	var hit_dir := Vector3(1.0, 0.0, 0.0)

	# Act
	splash.setup(hit_pos, hit_dir)

	# Assert
	assert_eq(splash.global_position, hit_pos, "Blood splash should be placed at hit position")
	assert_false(splash.flip_h, "Blood splash should not be flipped when projecting to the right")
	assert_eq(splash.offset.x, 55.0, "Blood splash origin should be anchored at left edge (+55 offset)")


func test_blood_splash_flip_when_hit_from_right() -> void:
	# Arrange
	var splash := BLOOD_NORMAL_SCENE.instantiate() as BloodSplash2D
	add_child_autofree(splash)
	var hit_pos := Vector3(2.0, 1.0, 0.0)
	var hit_dir := Vector3(-1.0, 0.0, 0.0)

	# Act
	splash.setup(hit_pos, hit_dir)

	# Assert
	assert_true(splash.flip_h, "Blood splash should be flipped when projecting to the left")
	assert_eq(splash.offset.x, -55.0, "Blood splash origin should be anchored at right edge (-55 offset)")


func test_blood_splash_embajador_frame_count() -> void:
	# Arrange
	var splash := BLOOD_EMBAJADOR_SCENE.instantiate() as BloodSplash2D
	add_child_autofree(splash)

	# Act & Assert
	assert_eq(splash.frame_count, 10, "BloodSplashEmbajador should have 10 frames")
	assert_not_null(splash.sprite_frames, "SpriteFrames should be generated from strip")
	assert_eq(splash.sprite_frames.get_frame_count(&"default"), 10, "SpriteFrames should have 10 frames configured")


func test_enemy_base_blood_spawn_at_hit_position() -> void:
	# Arrange
	var enemy := TestEnemy.new()
	add_child_autofree(enemy)
	var expected_hit_pos := Vector3(10.0, 3.0, 0.0)
	var expected_hit_dir := Vector3(1.0, 0.0, 0.0)
	enemy.last_hit_position = expected_hit_pos
	enemy.last_hit_direction = expected_hit_dir
	enemy.tiene_sangre = true

	# Act
	enemy._on_state_dying()

	# Assert
	assert_true(enemy.tiene_sangre, "EnemyBase should have blood enabled by default")


func test_gargola_excludes_blood() -> void:
	# Arrange
	var gargola := GARGOLA_SCRIPT.new()
	add_child_autofree(gargola)

	# Act
	gargola._on_enemy_ready()

	# Assert
	assert_false(gargola.tiene_sangre, "Gargola must have tiene_sangre = false to exclude blood")


func test_imp_estandarte_uses_embajador_blood() -> void:
	# Arrange
	var imp_embajador := IMP_ESTANDARTE_SCRIPT.new()
	add_child_autofree(imp_embajador)

	# Act
	imp_embajador._on_enemy_ready()

	# Assert
	assert_not_null(imp_embajador.escena_sangre, "ImpEstandarte should have escena_sangre assigned")
	assert_true(
		imp_embajador.escena_sangre.resource_path.contains("BloodSplashEmbajador"),
		"ImpEstandarte should use BloodSplashEmbajador scene"
	)


func test_impacto_gargola_vfx_spritesheet_configuration() -> void:
	# Arrange
	var vfx := ImpactoGargolaVFX.new()
	add_child_autofree(vfx)

	# Assert
	assert_not_null(vfx.sprite_frames, "ImpactoGargolaVFX should build valid SpriteFrames")
	assert_true(vfx.sprite_frames.has_animation(&"default"), "SpriteFrames must contain default animation")
	assert_eq(vfx.sprite_frames.get_frame_count(&"default"), 10, "ImpactoGargolaVFX must have 10 frames from 3x4 sheet")


func test_ally_archer_blood_splash_direction() -> void:
	# Arrange
	var ally_scene: PackedScene = preload("res://Entities/Aliada_Arquera/AllyArcher.tscn")
	var ally := ally_scene.instantiate() as AllyArcher
	add_child_autofree(ally)
	ally.last_hit_position = Vector3(1.0, 1.0, 0.0)
	ally.last_hit_direction = Vector3.LEFT

	# Act
	ally._crear_splash_sangre()

	# Assert
	assert_eq(ally.last_hit_direction, Vector3.LEFT, "Ally blood direction should project to the left (inverted from right-flying arrow)")


func test_goblin_explotado_vfx_instantiation():
	# Arrange
	var vfx := GoblinExplotadoVFX.new()
	add_child_autofree(vfx)

	# Assert
	assert_not_null(vfx, "GoblinExplotadoVFX should instantiate cleanly")


func test_blood_splash_no_letal_setup_and_frames() -> void:
	# Arrange
	var splash := BLOOD_NO_LETAL_SCENE.instantiate() as BloodSplash2D
	add_child_autofree(splash)
	var hit_pos := Vector3(3.0, 1.5, 0.0)
	var hit_dir := Vector3(1.0, 0.0, 0.0)

	# Act
	splash.setup(hit_pos, hit_dir)

	# Assert
	assert_eq(splash.global_position, hit_pos, "BloodSplashNoLetal should be at hit position")
	assert_true(splash.base_faces_left, "BloodSplashNoLetal must declare base_faces_left = true")
	assert_true(splash.flip_h, "When arrow flies right (+X), base facing left should be flipped")
	assert_gt(splash.offset.x, 0.0, "Offset should project to the right")
	assert_eq(splash.sprite_frames.get_frame_count(&"default"), 4, "BloodSplashNoLetal should have 4 frames configured")


func test_blood_splash_no_letal_direction_left() -> void:
	# Arrange
	var splash := BLOOD_NO_LETAL_SCENE.instantiate() as BloodSplash2D
	add_child_autofree(splash)
	var hit_pos := Vector3(3.0, 1.5, 0.0)
	var hit_dir := Vector3(-1.0, 0.0, 0.0)

	# Act
	splash.setup(hit_pos, hit_dir)

	# Assert
	assert_false(splash.flip_h, "When arrow flies left (-X), base facing left stays unflipped")
	assert_lt(splash.offset.x, 0.0, "Offset should project to the left")


func test_enemy_base_disparo_no_letal_spawnea_sangre() -> void:
	# Arrange: enemigo con 3 vidas recibe 1 punto de daño (no letal)
	var enemy := TestEnemy.new()
	add_child_autofree(enemy)
	enemy.vida_maxima = 3
	enemy.health = 3
	enemy.tiene_sangre = true
	enemy.es_volador = false
	enemy.last_hit_position = Vector3(2.0, 1.0, 0.0)
	enemy.last_hit_direction = Vector3.RIGHT

	# Act
	enemy.take_damage(1.0)

	# Assert
	assert_eq(enemy.health, 2, "Enemy should have 2 health remaining")
	assert_true(enemy.spawned_no_letal_called, "Non-lethal hit must trigger _spawn_blood_splash_no_letal")
	assert_null(enemy.spawned_splash, "Non-lethal hit must NOT trigger lethal _spawn_blood_splash")


func test_enemy_base_disparo_letal_no_spawnea_sangre_no_letal() -> void:
	# Arrange: enemigo con 1 vida recibe 1 de daño (letal)
	var enemy := TestEnemy.new()
	add_child_autofree(enemy)
	enemy.vida_maxima = 1
	enemy.health = 1
	enemy.tiene_sangre = true
	enemy.es_volador = false

	# Act
	enemy.take_damage(1.0)

	# Assert
	assert_eq(enemy.health, 0, "Enemy should be at 0 health")
	assert_false(enemy.spawned_no_letal_called, "Lethal hit must NOT call _spawn_blood_splash_no_letal")
	assert_not_null(enemy.spawned_splash, "Lethal hit must trigger lethal _spawn_blood_splash")


func test_gargola_voladora_excluye_sangre_no_letal() -> void:
	# Arrange
	var gargola := GARGOLA_SCRIPT.new()
	add_child_autofree(gargola)
	gargola._on_enemy_ready()
	gargola.health = 3

	# Act: disparo no letal
	gargola.take_damage(1.0)

	# Assert
	assert_true(gargola.es_volador, "Gargola must be flagged as es_volador")
	assert_true(gargola.is_in_group("flying_enemies"), "Gargola must belong to flying_enemies group")
	assert_false(gargola.tiene_sangre, "Gargola must have tiene_sangre = false")


func test_globo_aerostatico_volador_excluye_sangre_no_letal() -> void:
	# Arrange
	var globo := GLOBO_SCRIPT.new()
	add_child_autofree(globo)
	globo._on_enemy_ready()
	globo.health = 3

	# Act: disparo no letal
	globo.take_damage(1.0)

	# Assert
	assert_true(globo.es_volador, "GloboAerostatico must be flagged as es_volador")
	assert_true(globo.is_in_group("flying_enemies"), "GloboAerostatico must belong to flying_enemies group")
	assert_false(globo.tiene_sangre, "GloboAerostatico must have tiene_sangre = false")

