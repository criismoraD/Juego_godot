extends GutTest

const SCENE_NIVEL01: String = "res://Levels/NIVEL01/NIVEL01.tscn"
const SCENE_RIO: String = "res://Levels/Rio en canoa con paralax.tscn"
const SCENE_TUTORIAL: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"
const SCENE_ASALTO: String = "res://Levels/NIVEL06_ASALTO/NIVEL06_ASALTO.tscn"

func test_nivel01_tiene_environment_independiente_y_valores_restaurados() -> void:
	var packed_n1 := load(SCENE_NIVEL01) as PackedScene
	assert_not_null(packed_n1, "NIVEL01 debe cargar correctamente")
	var state_n1 := packed_n1.get_state()
	
	var env_res_path: String = ""
	for i in range(state_n1.get_node_count()):
		for prop_idx in range(state_n1.get_node_property_count(i)):
			if state_n1.get_node_property_name(i, prop_idx) == "environment":
				var res = state_n1.get_node_property_value(i, prop_idx)
				if res is Environment:
					env_res_path = res.resource_path
	
	assert_eq(env_res_path, "res://Levels/NIVEL01/nivel01_environment.tres", "NIVEL01 debe usar su propio archivo nivel01_environment.tres")
	
	var env_n1 := load("res://Levels/NIVEL01/nivel01_environment.tres") as Environment
	assert_not_null(env_n1)
	assert_true(env_n1.adjustment_enabled, "adjustment_enabled debe estar activo en Nivel 01")
	assert_almost_eq(env_n1.adjustment_contrast, 1.15, 0.001, "adjustment_contrast debe ser 1.15 en Nivel 01")
	assert_almost_eq(env_n1.adjustment_saturation, 1.05, 0.001, "adjustment_saturation debe ser 1.05 en Nivel 01")
	assert_almost_eq(env_n1.fog_light_color.b, 0.79, 0.01, "fog_light_color debe tener componente azul alta (cielo azul)")
	assert_almost_eq(env_n1.fog_light_energy, 0.65, 0.01, "fog_light_energy debe ser 0.65 para iluminar el cielo")

func test_rio_environment_es_independiente_de_nivel01() -> void:
	var env_rio := load("res://Recursos_Compartidos/rio_environment.tres") as Environment
	var env_n1 := load("res://Levels/NIVEL01/nivel01_environment.tres") as Environment
	
	assert_ne(env_rio, env_n1, "Rio y Nivel 01 deben tener instancias de Environment totalmente separadas")
	assert_almost_eq(env_rio.fog_depth_begin, 37.2, 0.01, "fog_depth_begin del rio debe mantenerse en 37.2 para el agua turquesa")
	assert_true(env_rio.fog_light_color.r > env_rio.fog_light_color.b, "La niebla del rio debe ser calida/rojiza de atardecer")
	assert_true(env_n1.fog_light_color.b > env_n1.fog_light_color.r, "La niebla de Nivel 01 debe ser azulada (cielo azul)")

func test_niveles_no_comparten_mismo_archivo_environment() -> void:
	var paths: Array[String] = [
		"res://Levels/NIVEL01/nivel01_environment.tres",
		"res://Recursos_Compartidos/rio_environment.tres",
		"res://Levels/NIVEL_TUTORIAL/tutorial_environment.tres",
		"res://Levels/NIVEL06_ASALTO/nivel06_environment.tres"
	]
	var unique_paths := {}
	for p in paths:
		assert_false(unique_paths.has(p), "No debe haber duplicados de environment paths: " + p)
		unique_paths[p] = true
		assert_true(FileAccess.file_exists(p), "El archivo de environment debe existir: " + p)
