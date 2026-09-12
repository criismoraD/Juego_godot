class_name ShaderGlobals
extends RefCounted

const PARAMETRO_OUTLINE_GLOBAL: StringName = &"Toon_LineaNegra_Activo"
const RUTA_PARAMETRO_OUTLINE_GLOBAL := "shader_globals/Toon_LineaNegra_Activo"
const PARAMETRO_OUTLINE_PROYECTILES: StringName = &"Toon_Proyectiles_Enemigos_Activo"


static var outline_global_activo: bool = false
static var outline_proyectiles_activo: bool = false


static func asegurar_outline_global(habilitado: bool = true) -> void:
	outline_global_activo = habilitado
	RenderingServer.global_shader_parameter_set(PARAMETRO_OUTLINE_GLOBAL, habilitado)


static func asegurar_outline_proyectiles(habilitado: bool = true) -> void:
	outline_proyectiles_activo = habilitado
	RenderingServer.global_shader_parameter_set(PARAMETRO_OUTLINE_PROYECTILES, habilitado)


static func es_outline_global_activo() -> bool:
	return outline_global_activo


static func es_outline_proyectiles_activo() -> bool:
	return outline_proyectiles_activo
