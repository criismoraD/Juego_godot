extends "res://addons/gut/test.gd"


func test_asegurar_outline_global_registra_parametro_bool() -> void:
	# Arrange / Act / Assert
	assert_true(
		ProjectSettings.has_setting(ShaderGlobals.RUTA_PARAMETRO_OUTLINE_GLOBAL),
		"El parametro global de outline debe vivir en project.godot"
	)

	var shader_global: Dictionary = ProjectSettings.get_setting(
		ShaderGlobals.RUTA_PARAMETRO_OUTLINE_GLOBAL
	)
	assert_eq(
		shader_global.get("type", ""),
		"bool",
		"El parametro global de outline debe estar registrado como bool"
	)
	assert_false(shader_global.get("value", true), "El outline global debe iniciar inactivo para el editor")
