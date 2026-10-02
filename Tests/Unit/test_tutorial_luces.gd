extends "res://addons/gut/test.gd"

## Tests unitarios para la calibración de luces y prevención de parpadeo (Mobile Renderer 8-light limit)
## en la escena del nivel tutorial ('Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn').

const ESCENA_TUTORIAL_PATH: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"
const MAX_LUCES_MOBILE_POR_MALLA: int = 8
const ENERGIA_MAXIMA_SUAVE: float = 1.2
const ATENUACION_MINIMA_SUAVE: float = 1.5


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

		assert_lte(luz.light_energy, ENERGIA_MAXIMA_SUAVE, nombre + " debe tener energía suave (<= 1.2)")
		assert_gte(luz.omni_attenuation, ATENUACION_MINIMA_SUAVE, nombre + " debe tener atenuación suave (>= 1.5)")
		assert_true(luz.distance_fade_enabled, nombre + " debe tener distance fade activo para transición suave")
		assert_eq(luz.light_cull_mask, 1, nombre + " debe iluminar únicamente la capa 1 (jugabilidad/frente)")


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
