class_name MarcaZonaCaida
extends Node3D
## Marca de zona de caída para el ataque eléctrico de Lonko.
## Muestra una marca en la posición de impacto a Y = 0.1, orientada a la pantalla (billboard),
## con aros verdes expandiéndose y la imagen Craneo_target.png animada con pulso.


@export_category("Marca de Caída")
@export var radio_marca: float = 0.94  ## Radio final de cada aro (unidades de mundo)
@export var duracion_marca: float = 3.0  ## Tiempo total de aviso antes de la caída
@export var numero_anillos: int = 4  ## Cantidad de aros expandiéndose (efecto ola)
@export var intervalo_anillo: float = 0.35  ## Desfase entre la aparición de cada aro
@export var duracion_expansion: float = 1.0  ## Tiempo que tarda un aro en expandirse y desvanecerse
@export var color_marca: Color = Color(0.2, 1.0, 0.2, 1.0)  ## Verde lima
@export var altura_y: float = -0.01  ## Posición Y sobre el suelo
@export var textura_craneo: Texture2D = preload("res://Entities/Enemigo_Lonko/Craneo_target.png")

var _craneo_node: Sprite3D = null


## Posiciona la marca sobre el suelo, muestra el cráneo animado y lanza la secuencia de aros.
func iniciar(posicion: Vector3) -> void:
	_ubicar_en_piso(posicion)
	_crear_craneo_target()
	_crear_secuencia_anillos()


func _ubicar_en_piso(posicion: Vector3) -> void:
	global_position = Vector3(posicion.x, altura_y, posicion.z)


var _destruyendo: bool = false


func _crear_craneo_target() -> void:
	if not textura_craneo:
		return
	_craneo_node = Sprite3D.new()
	_craneo_node.name = "CraneoTarget"
	_craneo_node.texture = textura_craneo
	_craneo_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_craneo_node.shaded = false
	_craneo_node.render_priority = 2
	_craneo_node.layers = 3
	_craneo_node.scale = Vector3(0.105, 0.105, 0.105)
	_craneo_node.position = Vector3(0.0, 0.01, 0.0)
	add_child(_craneo_node)

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_craneo_node, "scale", Vector3(0.135, 0.135, 0.135), 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_craneo_node, "scale", Vector3(0.083, 0.083, 0.083), 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _crear_secuencia_anillos() -> void:
	while not _destruyendo:
		if not is_instance_valid(self) or not is_inside_tree():
			return
		_crear_anillo()
		await get_tree().create_timer(intervalo_anillo, false).timeout


func explotar_y_destruir() -> void:
	if _destruyendo:
		return
	_destruyendo = true
	queue_free()


func _crear_anillo() -> void:
	var mesh_anillo := MeshInstance3D.new()
	mesh_anillo.name = "Anillo"

	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	torus.rings = 8
	torus.ring_segments = 40
	mesh_anillo.mesh = torus

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color_marca.r, color_marca.g, color_marca.b, 1.0)
	material.emission_enabled = true
	material.emission = color_marca
	material.emission_energy_multiplier = 2.5
	mesh_anillo.material_override = material
	mesh_anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_anillo.layers = 3

	mesh_anillo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mesh_anillo.scale = Vector3(0.15, 0.15, 0.15)
	add_child(mesh_anillo)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_anillo, "scale", Vector3(radio_marca, radio_marca, radio_marca), duracion_expansion) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_actualizar_fade_anillo.bind(material), 1.0, 0.0, duracion_expansion) \
		.set_trans(Tween.TRANS_LINEAR)
	tween.chain().tween_callback(mesh_anillo.queue_free)


func _actualizar_fade_anillo(alpha: float, material: StandardMaterial3D) -> void:
	if material:
		material.albedo_color.a = alpha
