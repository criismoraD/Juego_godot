class_name ShaderGlobals
extends RefCounted

const PARAMETRO_OUTLINE_GLOBAL: StringName = &"Toon_LineaNegra_Activo"
const RUTA_PARAMETRO_OUTLINE_GLOBAL := "shader_globals/Toon_LineaNegra_Activo"
const PARAMETRO_OUTLINE_PROYECTILES: StringName = &"Toon_Proyectiles_Enemigos_Activo"


static func asegurar_outline_global(habilitado: bool = true) -> void:
	RenderingServer.global_shader_parameter_set(PARAMETRO_OUTLINE_GLOBAL, habilitado)


static func asegurar_outline_proyectiles(habilitado: bool = true) -> void:
	RenderingServer.global_shader_parameter_set(PARAMETRO_OUTLINE_PROYECTILES, habilitado)
