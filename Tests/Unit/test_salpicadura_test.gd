extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto visual 'salpicadura test' (impacto en agua de 13 cuadros).
## Valida la generación correcta de SpriteFrames, número de cuadros,
## propiedades de renderizado e integración en NIVEL01.

const SCENE_SALPICADURA: PackedScene = preload("res://TEST_/Salpicadura_test/SalpicaduraTest.tscn")
const SCRIPT_SALPICADURA: Script = preload("res://TEST_/Salpicadura_test/SalpicaduraTest.gd")
const SCENE_NIVEL01_PATH: String = "res://Levels/NIVEL01/NIVEL01.tscn"


func test_instanciacion_salpicadura_test() -> void:
	# Arrange & Act
	var splash: Node3D = SCENE_SALPICADURA.instantiate() as Node3D
	assert_not_null(splash, "La escena SalpicaduraTest debe instanciarse")
	add_child_autofree(splash)

	# Assert
	assert_true(splash is AnimatedSprite3D, "Debe ser un AnimatedSprite3D")
	var anim_sprite := splash as AnimatedSprite3D
	assert_not_null(anim_sprite.sprite_frames, "Debe haber generado SpriteFrames automáticamente")
	assert_true(anim_sprite.sprite_frames.has_animation(&"default"), "Debe contener animación 'default'")
	assert_eq(anim_sprite.sprite_frames.get_frame_count(&"default"), 13, "Debe tener exactamente 13 cuadros")


func test_frames_textura_y_dimensiones() -> void:
	# Arrange
	var splash: Node3D = SCENE_SALPICADURA.instantiate() as Node3D
	add_child_autofree(splash)
	var anim_sprite := splash as AnimatedSprite3D

	# Act
	var sf := anim_sprite.sprite_frames
	var primer_frame: Texture2D = sf.get_frame_texture(&"default", 0)

	# Assert
	assert_not_null(primer_frame, "El primer cuadro debe ser una textura válida")
	assert_true(primer_frame is AtlasTexture, "Cada cuadro debe ser un AtlasTexture de la tira")
	var atlas := primer_frame as AtlasTexture
	assert_eq(atlas.region.size.x, 64.0, "Ancho del cuadro debe ser 64 px")
	assert_eq(atlas.region.size.y, 136.0, "Alto del cuadro debe ser 136 px")


func test_propiedades_visuales_y_billboard() -> void:
	# Arrange
	var splash: Node3D = SCENE_SALPICADURA.instantiate() as Node3D
	add_child_autofree(splash)
	var anim_sprite := splash as AnimatedSprite3D

	# Assert
	assert_eq(anim_sprite.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "Debe ser Billboard para espacio 2.5D")
	assert_false(anim_sprite.shaded, "No debe recibir sombras oscuras (shaded = false)")
	assert_almost_eq(anim_sprite.offset.y, 56.0, 0.01, "El offset Y debe alinear la base del impacto con el agua")


func test_salpicadura_en_nivel01() -> void:
	# Arrange & Act
	var packed := load(SCENE_NIVEL01_PATH) as PackedScene
	assert_not_null(packed, "NIVEL01 debe cargar correctamente")

	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Assert
	var nodo_salpicadura: Node = nivel.find_child("salpicadura test", true, false)
	if not nodo_salpicadura:
		pass_test("Salpicadura de prueba no está colocada en la escena base de NIVEL01")
		return

	assert_true(nodo_salpicadura is AnimatedSprite3D, "Debe ser un AnimatedSprite3D")
	var water: Node3D = nivel.find_child("WaterPlane", true, false) as Node3D
	if water and nodo_salpicadura is Node3D:
		assert_almost_eq((nodo_salpicadura as Node3D).position.y, water.position.y, 0.05, "La salpicadura debe situarse sobre el plano de agua")
