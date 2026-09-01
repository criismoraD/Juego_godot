class_name PuertaTrigger
extends Area3D

## Controlador de interacción con la puerta de la torre.
## - Se activa y muestra ÚNICAMENTE durante las cortinillas entre oleadas (intermisión / victoria) Y al pisar el trigger.
## - Durante el combate o al inicio de la oleada permanece 100% OCULTO e INACTIVO.
## - Al presionar Flecha Arriba (↑) o W durante la cortinilla sobre el trigger:
##   centra al jugador con la puerta en X, gira hacia el fondo, entra caminando y ejecuta la cortinilla circular a Player_Interior.tscn.

@export var escena_destino: String = "res://Levels/Player_Interior.tscn"

var _oleada_activa: bool = true
var _en_cortinilla_entre_oleadas: bool = false

var _jugador_dentro: bool = false
var _jugador_ref: CharacterBody3D = null
var _transicion_en_curso: bool = false

var _plano_iluminado: MeshInstance3D = null
var _material_plano: StandardMaterial3D = null
var _icono_ui_gameui: TextureRect = null
var _tiempo_anim: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	call_deferred("_inicializar")


func _inicializar() -> void:
	_conectar_spawner()
	_buscar_plano_iluminado()
	_buscar_icono_gameui()
	_apagar_todo()


func _conectar_spawner() -> void:
	var spawner = get_tree().get_first_node_in_group("wave_spawners")
	if not spawner:
		spawner = get_parent().find_child("WaveSpawner", true, false)
	if spawner:
		if spawner.has_signal("oleada_iniciada"):
			if not spawner.oleada_iniciada.is_connected(_on_oleada_iniciada):
				spawner.oleada_iniciada.connect(_on_oleada_iniciada)
		if spawner.has_signal("oleada_completada"):
			if not spawner.oleada_completada.is_connected(_on_oleada_completada):
				spawner.oleada_completada.connect(_on_oleada_completada)


func _on_oleada_iniciada(_numero_oleada: int) -> void:
	_oleada_activa = true
	_en_cortinilla_entre_oleadas = false
	_apagar_todo()


func _on_oleada_completada(_numero_oleada: int) -> void:
	_oleada_activa = false
	_en_cortinilla_entre_oleadas = true


func _esta_en_cortinilla_entre_oleadas() -> bool:
	if _transicion_en_curso:
		return false
	var cortinillas = get_tree().get_nodes_in_group("pantalla_victoria_cortinilla")
	for c in cortinillas:
		if is_instance_valid(c) and c.is_inside_tree() and c.visible:
			return true
	return (_en_cortinilla_entre_oleadas and not _oleada_activa)


func _buscar_plano_iluminado() -> void:
	var root := get_tree().root
	var all_meshes := root.find_children("*PLANO_ILUMINADO*", "MeshInstance3D", true, false)
	if all_meshes.size() > 0:
		_plano_iluminado = all_meshes[0] as MeshInstance3D
	if not _plano_iluminado:
		var torre := root.find_child("TORRE", true, false)
		if torre:
			_plano_iluminado = torre.find_child("PLANO_ILUMINADO", true, false) as MeshInstance3D

	if _plano_iluminado:
		_plano_iluminado.visible = false
		_material_plano = load("res://Entities/Ambiente_Torre/PLANO_ILUMINADO_MAT.tres") as StandardMaterial3D
		if _material_plano:
			_material_plano = _material_plano.duplicate() as StandardMaterial3D
			_material_plano.albedo_color = Color(1.0, 1.0, 1.0, 0.06)
			_material_plano.emission_enabled = true
			_material_plano.emission = Color(1.0, 1.0, 1.0, 1.0)
			_material_plano.emission_energy_multiplier = 0.7
			_plano_iluminado.material_override = _material_plano


func _buscar_icono_gameui() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if not game_ui:
		game_ui = get_tree().root.find_child("GameUI", true, false)
	if game_ui:
		_icono_ui_gameui = game_ui.find_child("IconoPuerta", true, false) as TextureRect
		if _icono_ui_gameui:
			_icono_ui_gameui.visible = false


func _process(delta: float) -> void:
	if _transicion_en_curso:
		return

	var en_cortinilla: bool = _esta_en_cortinilla_entre_oleadas()

	# 1. La flecha roja SE MUESTRA SIEMPRE durante las cortinillas entre oleadas
	if not _icono_ui_gameui or not is_instance_valid(_icono_ui_gameui):
		_buscar_icono_gameui()

	if _icono_ui_gameui:
		_icono_ui_gameui.visible = en_cortinilla

	# 2. El plano blanco SOLO se muestra cuando se pisa el trigger durante la cortinilla
	var pisando_trigger: bool = en_cortinilla and _jugador_dentro and is_instance_valid(_jugador_ref)
	if _plano_iluminado:
		_plano_iluminado.visible = pisando_trigger
		if pisando_trigger and _material_plano:
			_tiempo_anim += delta * 4.0
			var alpha_pulso = 0.03 + (sin(_tiempo_anim * 1.5) * 0.5 + 0.5) * 0.05
			_material_plano.albedo_color.a = alpha_pulso

	# 3. Detectar si presiona Flecha Arriba o W para entrar (solo al pisar el trigger en la cortinilla)
	if pisando_trigger:
		var presiono_arriba: bool = (
			Input.is_action_just_pressed("ui_up")
			or Input.is_action_just_pressed("move_up")
			or Input.is_key_pressed(KEY_UP)
			or Input.is_key_pressed(KEY_W)
		)

		if presiono_arriba:
			_iniciar_secuencia_entrada()


func _on_body_entered(body: Node3D) -> void:
	if _transicion_en_curso:
		return
	if body.is_in_group("player") or body.name == "Player" or body is CharacterBody3D:
		_jugador_dentro = true
		_jugador_ref = body as CharacterBody3D


func _on_body_exited(body: Node3D) -> void:
	if body == _jugador_ref or body.is_in_group("player") or body.name == "Player":
		_jugador_dentro = false
		_jugador_ref = null
		if _plano_iluminado:
			_plano_iluminado.visible = false


func _apagar_todo() -> void:
	if _plano_iluminado:
		_plano_iluminado.visible = false
	if _icono_ui_gameui and is_instance_valid(_icono_ui_gameui):
		_icono_ui_gameui.visible = false


func _iniciar_secuencia_entrada() -> void:
	_transicion_en_curso = true
	_apagar_todo()

	# Registrar la oleada completada cuya cortinilla debemos restaurar al regresar
	var _spawner := get_tree().get_first_node_in_group("wave_spawners")
	if not _spawner:
		_spawner = get_parent().find_child("WaveSpawner", true, false)
	if _spawner and "oleada_combate" in _spawner and int(_spawner.oleada_combate) > 0:
		GameUI.regreso_desde_interior_oleada = int(_spawner.oleada_combate)

	var dest := escena_destino
	if not ResourceLoader.exists(dest):
		if ResourceLoader.exists("res://Levels/Player_Interior.tscn"):
			dest = "res://Levels/Player_Interior.tscn"
		elif ResourceLoader.exists("res://Levels/Nivel_Interior/Interio.tscn"):
			dest = "res://Levels/Nivel_Interior/Interio.tscn"

	if not is_instance_valid(_jugador_ref):
		SceneManager.cambiar_escena_cortinilla_circular(dest)
		return

	# Guardar posición de retorno (centrado frente a la puerta)
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").posicion_retorno_puerta = Vector3(global_position.x, _jugador_ref.global_position.y, _jugador_ref.global_position.z)

	# 1. Desactivar físicas y control de la arquera
	_jugador_ref.set_physics_process(false)
	if "velocity" in _jugador_ref:
		_jugador_ref.velocity = Vector3.ZERO

	# 2. Girar modelo de la arquera hacia el fondo (hacia la puerta / -Z)
	var model = _jugador_ref.find_child("ArqueraModel", true, false)
	if not model:
		model = _jugador_ref.find_child("Armature", true, false)
	if not model:
		model = _jugador_ref

	var tween := create_tween().set_parallel(true)
	tween.tween_property(model, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)

	# 3. Centrar al jugador con la puerta en X y caminar hacia el fondo (-Z)
	tween.tween_property(_jugador_ref, "global_position:x", global_position.x, 0.3).set_trans(Tween.TRANS_SINE)
	var pos_final_z: float = _jugador_ref.global_position.z - 1.8
	tween.tween_property(_jugador_ref, "global_position:z", pos_final_z, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. Activar animación de caminar hacia adelante
	var anim_tree = _jugador_ref.find_child("AnimationTree", true, false) as AnimationTree
	var anim_player = _jugador_ref.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_tree:
		anim_tree.set("parameters/Locomocion/transition_request", "caminar")
	elif anim_player:
		for a in ["Armature|Armature|CAMINAR_ADELANTE", "Armature|CAMINAR_ADELANTE", "CAMINAR_ADELANTE", "Armature|CORRER", "CORRER"]:
			if anim_player.has_animation(a):
				anim_player.play(a)
				break

	# 5. Transición con cortinilla circular
	await get_tree().create_timer(0.35).timeout
	SceneManager.cambiar_escena_cortinilla_circular(dest)
