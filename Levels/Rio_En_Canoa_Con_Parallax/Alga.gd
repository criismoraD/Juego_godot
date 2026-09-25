@tool
class_name Alga
extends Node3D

## Alga posicionable con oleaje en la parte superior para el nivel del rio.
## La base queda fija en el origen y la punta ondula por shader (peso por UV).
## Sincroniza la textura y los parametros con el ShaderMaterial en el editor y en juego.
## El nodo raiz queda libre para posicionarlo en el editor.

const TEXTURA_DEFAULT: Texture2D = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Texturas/Alga.png")
const SHADER_DEFAULT: Shader = preload("res://System/Shaders/alga_oleaje.gdshader")

@export_category("Oleaje")
@export var oleaje_speed: float = 1.5:
	set(nuevo_valor):
		oleaje_speed = nuevo_valor
		_aplicar_parametros()
@export var oleaje_strength: float = 0.08:
	set(nuevo_valor):
		oleaje_strength = nuevo_valor
		_aplicar_parametros()
@export var rizo_speed: float = 3.0:
	set(nuevo_valor):
		rizo_speed = nuevo_valor
		_aplicar_parametros()
@export var rizo_strength: float = 0.02:
	set(nuevo_valor):
		rizo_strength = nuevo_valor
		_aplicar_parametros()

@onready var cuerpo: Sprite3D = $Cuerpo


func _ready() -> void:
	if not is_instance_valid(cuerpo):
		return
	if cuerpo.texture == null:
		cuerpo.texture = TEXTURA_DEFAULT
	_sincronizar_material()
	_aplicar_parametros()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE or what == NOTIFICATION_READY:
		_sincronizar_material()
		_aplicar_parametros()


func _sincronizar_material() -> void:
	if not is_instance_valid(cuerpo):
		return
	var tex_actual: Texture2D = cuerpo.texture if cuerpo.texture != null else TEXTURA_DEFAULT

	if cuerpo.material_override == null:
		var sm := ShaderMaterial.new()
		sm.shader = SHADER_DEFAULT
		sm.set_shader_parameter("albedo_texture", tex_actual)
		sm.set_shader_parameter("tint_color", Color(1, 1, 1, 1))
		cuerpo.material_override = sm
	elif cuerpo.material_override is ShaderMaterial:
		var sm := cuerpo.material_override as ShaderMaterial
		if sm.get_shader_parameter("albedo_texture") == null:
			sm.set_shader_parameter("albedo_texture", tex_actual)


func _aplicar_parametros() -> void:
	if not is_node_ready() or not is_instance_valid(cuerpo):
		return
	var sm := cuerpo.material_override as ShaderMaterial
	if sm == null:
		return
	sm.set_shader_parameter("oleaje_speed", oleaje_speed)
	sm.set_shader_parameter("oleaje_strength", oleaje_strength)
	sm.set_shader_parameter("rizo_speed", rizo_speed)
	sm.set_shader_parameter("rizo_strength", rizo_strength)
