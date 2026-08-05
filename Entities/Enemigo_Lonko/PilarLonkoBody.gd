class_name PilarLonkoBody
extends StaticBody3D

## Cuerpo físico y receptor de daño del pilar de Lonko (13 de vida por defecto).
## Recibe impactos de las flechas del jugador, emite destello de daño y destruye el pilar si la vida llega a 0.

var lonko_ref: Node = null
@export var vida_maxima: float = 13.0  ## Vida máxima del pilar (modificable libremente en el Inspector de PilarLonko.tscn)
@export var vida_pilar: float = 13.0   ## Vida actual del pilar
var es_escudo_enemigo: bool = true  ## Marca este objeto como obstáculo enemigo (flechas enemigas lo ignoran, flechas del jugador lo dañan)
var es_pilar_enemigo: bool = true
var sfx_impacto_pilar_stream: AudioStream = preload("res://Entities/Enemigo_Lonko/Sonido impacto pilar.mp3")
var _original_materials: Array[Material] = []
var _mesh_instances: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("escudos")
	vida_pilar = vida_maxima


func inicializar(lonko: Node, vida_max_override: float = -1.0) -> void:
	lonko_ref = lonko
	# Si se modificó la vida en el Inspector de PilarLonko.tscn (diferente de 13.0),
	# se respeta su valor personalizado. De lo contrario, se usa vida_max_override.
	if vida_maxima == 13.0 and vida_max_override > 0.0:
		vida_maxima = vida_max_override

	vida_pilar = vida_maxima

	_mesh_instances.clear()
	_original_materials.clear()
	var parent_node := get_parent()
	if parent_node:
		var meshes := parent_node.find_children("*", "MeshInstance3D", true, false)
		for m in meshes:
			var mi := m as MeshInstance3D
			if mi:
				_mesh_instances.append(mi)
				_original_materials.append(mi.material_override)


func take_damage(amount: float) -> void:
	recibir_golpe(amount)


func recibir_golpe(amount: float = 1.0) -> void:
	if vida_pilar <= 0:
		return

	vida_pilar -= amount
	_reproducir_sonido_impacto()
	_flash_dano()

	if vida_pilar <= 0:
		if is_instance_valid(lonko_ref) and lonko_ref.has_method("_on_pilar_destruido"):
			lonko_ref._on_pilar_destruido()


func _reproducir_sonido_impacto() -> void:
	if sfx_impacto_pilar_stream:
		var player := AudioStreamPlayer.new()
		player.stream = sfx_impacto_pilar_stream
		player.volume_db = 0.0
		player.bus = "Master"
		var root := get_tree().current_scene
		if root:
			root.add_child(player)
			player.play()
			player.finished.connect(player.queue_free)
		else:
			player.queue_free()
	else:
		AudioManager.play_shield_hit()


func _flash_dano() -> void:
	for mi in _mesh_instances:
		if not is_instance_valid(mi):
			continue
		var flash_mat := StandardMaterial3D.new()
		flash_mat.emission_enabled = true
		flash_mat.emission = Color(1.0, 0.3, 0.3)
		flash_mat.emission_energy_multiplier = 3.0
		mi.material_override = flash_mat

	get_tree().create_timer(0.1).timeout.connect(func():
		for i in range(_mesh_instances.size()):
			var mi := _mesh_instances[i]
			if is_instance_valid(mi):
				mi.material_override = _original_materials[i] if i < _original_materials.size() else null
	)
