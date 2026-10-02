@tool
class_name BanderaImperio
extends Sprite3D
## Estandarte del imperio en el Nivel Tutorial con animación de viento en la
## parte inferior: la parte superior queda fija (colgada) y la inferior ondea,
## igual que la bandera snake.
## Sincroniza automáticamente la textura con el ShaderMaterial tanto en el
## editor como en juego.

const TEXTURA_DEFAULT: Texture2D = preload("res://TEST_/Bandera imperio.png")
const SHADER_DEFAULT: Shader = preload("res://System/Shaders/bandera_colgante.gdshader")


func _ready() -> void:
	if texture == null:
		texture = TEXTURA_DEFAULT
	_sincronizar_material()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE or what == NOTIFICATION_READY:
		_sincronizar_material()


func _sincronizar_material() -> void:
	var tex_actual: Texture2D = texture if texture != null else TEXTURA_DEFAULT

	if material_override == null:
		var sm := ShaderMaterial.new()
		sm.shader = SHADER_DEFAULT
		sm.set_shader_parameter("albedo_texture", tex_actual)
		sm.set_shader_parameter("tint_color", Color(1, 1, 1, 1))
		sm.set_shader_parameter("wind_speed", 2.0)
		sm.set_shader_parameter("wind_strength", 0.08)
		sm.set_shader_parameter("flutter_speed", 4.2)
		sm.set_shader_parameter("flutter_strength", 0.03)
		material_override = sm
	elif material_override is ShaderMaterial:
		var sm := material_override as ShaderMaterial
		if sm.get_shader_parameter("albedo_texture") == null:
			sm.set_shader_parameter("albedo_texture", tex_actual)
