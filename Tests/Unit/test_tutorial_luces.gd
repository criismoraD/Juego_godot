extends "res://addons/gut/test.gd"

## Tests unitarios para la calibración de luces y prevención de parpadeo (Mobile Renderer 8-light limit)
## en la escena del nivel tutorial ('Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn').

const ESCENA_TUTORIAL_PATH: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"
const MAX_LUCES_MOBILE_POR_MALLA: int = 8
const ENERGIA_MAXIMA_SUAVE: float = 15.0
const ATENUACION_MINIMA_SUAVE: float = 1.5


func test_luz_centro_piso3_visible_para_camara_frente() -> void:
	# Arrange
	var packed := load(ESCENA_TUTORIAL_PATH) as PackedScene
	assert_not_null(packed, "La escena tutorial debe cargar")
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act
	var luz3: SpotLight3D = nivel.find_child("LuzCentroPiso3", true, false) as SpotLight3D
	var cam_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D

	# Assert (AAA)
	assert_not_null(luz3, "LuzCentroPiso3 debe existir en Lighting")
	assert_not_null(cam_frente, "CamaraFrente debe existir en SubViewportFrente3D")
	if luz3 != null and cam_frente != null:
		# Debe incluir la capa 1 (layers & 1 != 0) para que CamaraFrente la renderice y no se apague al pasar
		assert_true((luz3.layers & 1) != 0, "LuzCentroPiso3 debe incluir capa 1 en layers para ser visible por CamaraFrente")
		assert_true((luz3.light_cull_mask & 1) != 0, "LuzCentroPiso3 debe iluminar la capa 1 (jugador y piso)")
		# Comprobar intersección de cull_mask de la cámara con layers de la luz
		assert_true((cam_frente.cull_mask & luz3.layers) != 0, "CamaraFrente debe renderizar LuzCentroPiso3")


func test_luces_tutorial_omnilight_11_a_14_calibradas() -> void:
	# Arrange
	var packed := load(ESCENA_TUTORIAL_PATH) as PackedScene
	assert_not_null(packed, "La escena tutorial debe cargar")
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var nombres_luces: Array[String] = [
		"OmniLight3D11",
		"OmniLight3D12",
		"OmniLight3D13",
		"OmniLight3D14"
	]

	# Act & Assert (AAA)
	for nombre in nombres_luces:
		var luz: OmniLight3D = nivel.find_child(nombre, true, false) as OmniLight3D
		assert_not_null(luz, "Debe existir el nodo " + nombre)
		if luz == null:
			continue

		assert_gt(luz.light_energy, 0.0, nombre + " debe tener energía positiva")
		assert_lte(luz.light_energy, ENERGIA_MAXIMA_SUAVE, nombre + " debe tener energía controlada (<= 15.0)")
		assert_gte(luz.omni_attenuation, ATENUACION_MINIMA_SUAVE, nombre + " debe tener atenuación suave (>= 1.5)")
		assert_true(luz.distance_fade_enabled, nombre + " debe tener distance fade activo para transición suave")
		assert_eq(luz.light_cull_mask, 1, nombre + " debe iluminar la capa 1 (jugabilidad/frente)")


func test_luces_posicionales_capa_1_no_superan_limite_mobile() -> void:
	# Arrange: en el renderizador Mobile, el límite por malla es de 8 luces posicionales.
	var packed := load(ESCENA_TUTORIAL_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act: Contar cuántas luces posicionales (Omni / Spot) afectan a la capa 1 en la zona central (X entre -6 y 10)
	var luces_posicionales_capa_1: int = 0
	for hijo in nivel.find_children("*", "Light3D", true, false):
		if not (hijo is OmniLight3D or hijo is SpotLight3D):
			continue
		var luz: Light3D = hijo as Light3D
		if not luz.visible:
			continue
		# Comprobar si afecta a la capa 1
		if (luz.light_cull_mask & 1) != 0:
			if luz.global_position.x >= -6.0 and luz.global_position.x <= 10.0:
				luces_posicionales_capa_1 += 1

	# Assert: La cantidad de luces que tocan el suelo jugable en ese tramo no debe exceder 8
	assert_lte(luces_posicionales_capa_1, MAX_LUCES_MOBILE_POR_MALLA, "Las luces posicionales en capa 1 no deben exceder el límite de 8 de Godot Mobile")
