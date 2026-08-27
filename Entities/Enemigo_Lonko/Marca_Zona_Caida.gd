class_name MarcaZonaCaida
extends Node3D
## Marca de zona de caída para el ataque definitivo de Lonko.
## Muestra una marca en el suelo orientada a la pantalla (billboard),
## con aros verdes expandiéndose y la imagen Craneo_target.png animada con pulso.

@export_category("Marca de Caída")
@export var radio_marca: float = 0.55  ## Radio final de cada aro
@export var duracion_marca: float = 1.4  ## Tiempo total de aviso antes de la caída
@export var intervalo_anillo: float = 0.28  ## Desfase entre la aparición de cada aro
@export var duracion_expansion: float = 0.80  ## Tiempo que tarda un aro en expandirse y desvanecerse
@export var color_marca: Color = Color(0.2, 1.0, 0.2, 1.0)  ## Verde lima
@export var altura_y: float = 0.06  ## Posición Y sobre la superficie del suelo
@export var textura_craneo: Texture2D = preload("res://Entities/Enemigo_Lonko/Craneo_target.png")

var _craneo_node: Sprite3D = null
var _destruyendo: bool = false


## Posiciona la marca sobre el suelo, muestra el cráneo animado y lanza la secuencia de aros.
func iniciar(posicion: Vector3) -> void:
	global_position = Vector3(posicion.x, altura_y, posicion.z)
	_crear_craneo_target()
	_crear_secuencia_anillos()


func _crear_craneo_target() -> void:
	if not textura_craneo:
		return
	_craneo_node = Sprite3D.new()
	_craneo_node.name = "CraneoTarget"
	_craneo_node.texture = textura_craneo
	_craneo_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_craneo_node.shaded = false
	_craneo_node.no_depth_test = true  ## Máxima prioridad: siempre sobrepuesto a todos los elementos (pilares, personajes, suelo)
	_craneo_node.render_priority = 127  ## Prioridad máxima absoluta de renderizado
	_craneo_node.sorting_offset = 100.0
	_craneo_node.scale = Vector3(0.105, 0.105, 0.105)
	_craneo_node.position = Vector3(0.0, 0.02, 0.0)  ## Centrado exactamente en el medio de los aros
	_craneo_node.modulate = Color(1.0, 1.0, 1.0, 0.95)
	add_child(_craneo_node)

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_craneo_node, "scale", Vector3(0.118, 0.118, 0.118), 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_craneo_node, "scale", Vector3(0.092, 0.092, 0.092), 0.35) \
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
	torus.rings = 6
	torus.ring_segments = 36
	mesh_anillo.mesh = torus

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true  ## Por encima de pilares y obstáculos
	material.render_priority = 126
	material.albedo_color = Color(color_marca.r, color_marca.g, color_marca.b, 1.0)
	material.emission_enabled = true
	material.emission = color_marca
	material.emission_energy_multiplier = 3.0
	mesh_anillo.material_override = material
	mesh_anillo.sorting_offset = 95.0
	mesh_anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	mesh_anillo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mesh_anillo.position = Vector3(0.0, 0.02, 0.0)
	mesh_anillo.scale = Vector3(0.12, 0.12, 0.12)
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
