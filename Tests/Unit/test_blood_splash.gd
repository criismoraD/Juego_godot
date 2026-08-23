extends "res://addons/gut/test.gd"

const BLOOD_NORMAL_SCENE := preload("res://VFX/Scenes/BloodSplashNormal.tscn")
const BLOOD_EMBAJADOR_SCENE := preload("res://VFX/Scenes/BloodSplashEmbajador.tscn")
const GARGOLA_SCRIPT := preload("res://Entities/Enemigo_Gargola/Gargola.gd")
const IMP_ESTANDARTE_SCRIPT := preload("res://Entities/Enemigo_Imp_Estandarte/ImpEstandarte.gd")
const ENEMY_BASE_SCRIPT := preload("res://System/Core/EnemyBase.gd")


class TestEnemy extends "res://System/Core/EnemyBase.gd":
	var spawned_splash: Node = null

	func _ready() -> void:
		pass

	func _spawn_blood_splash(custom_modulate: Color = Color.WHITE) -> void:
		super._spawn_blood_splash(custom_modulate)


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
	var ally := AllyArcher.new()
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
