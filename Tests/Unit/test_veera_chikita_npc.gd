extends "res://addons/gut/test.gd"

## Tests unitarios para el NPC Veera Chikita: misma base que Veera
## (script, espada en mano derecha y cola en cadera) con el modelo chikita,
## instanciada en el nivel pueblo.

const SCENE_CHIKITA: PackedScene = preload("res://Entities/NPC_Veera/VeeraChikita.tscn")
const ESCENA_PUEBLO: String = "res://Levels/Nivel_Pueblo/NivelPueblo.tscn"


func test_chikita_instancia_con_espada_y_cola() -> void:
	# Arrange & Act
	var chikita := SCENE_CHIKITA.instantiate() as Veera
	assert_not_null(chikita, "VeeraChikita debe instanciarse")
	add_child_autofree(chikita)
	await get_tree().process_frame

	# Assert: mismo equipo que Veera (arma y cola)
	assert_true(chikita.equipar_espada, "La chikita debe llevar la espada equipada")
	assert_true(chikita.equipar_cola, "La chikita debe llevar la cola equipada")
	assert_not_null(chikita.obtener_espada(), "EspadaVeera debe estar acoplada")
	assert_not_null(chikita.obtener_cola(), "ColaVeera debe estar acoplada")


func test_chikita_usa_textura_propia() -> void:
	# Arrange & Act
	var chikita := SCENE_CHIKITA.instantiate() as Veera
	add_child_autofree(chikita)

	# Assert: material chikita, no el de la adulta
	assert_not_null(chikita.material_npc, "Debe tener material asignado")
	var tex: Texture2D = chikita.material_npc.albedo_texture
	assert_not_null(tex, "El material debe tener albedo")
	assert_string_contains(tex.resource_path, "Chikita", "Debe usar la textura de Veera Chikita")


func test_chikita_tiene_animacion_caminar() -> void:
	# Arrange & Act
	var chikita := SCENE_CHIKITA.instantiate() as Veera
	add_child_autofree(chikita)
	await get_tree().process_frame

	# Assert: el rig chikita trae Caminar para la patrulla
	var ap := chikita.obtener_animation_player()
	assert_not_null(ap, "Debe tener AnimationPlayer")
	assert_true(ap.has_animation("Caminar"), "Debe traer la animación Caminar")
	assert_eq(chikita.obtener_estado(), Veera.Estado.CAMINANDO, "Debe patrullar al iniciar")


func test_pueblo_contiene_veera_chikita() -> void:
	# Arrange & Act
	var packed := load(ESCENA_PUEBLO) as PackedScene
	assert_not_null(packed, "El nivel pueblo debe cargar")
	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel, "El nivel debe instanciarse")
	add_child_autofree(nivel)

	# Assert
	var chikita := nivel.find_child("VeeraChikita texto", true, false) as Veera
	assert_not_null(chikita, "El pueblo debe contener a VeeraChikita texto")
	assert_not_null(chikita.obtener_espada(), "La chikita del pueblo lleva espada")
	assert_not_null(chikita.obtener_cola(), "La chikita del pueblo lleva cola")
