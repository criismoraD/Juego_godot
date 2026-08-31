class_name PuertaTrigger
extends Area3D

## Controlador de interacción con la puerta de la torre.
## - Se activa ÚNICAMENTE al terminar la oleada (cortinilla de victoria / intermisión) Y al acercarse el jugador.
## - Muestra el IconoPuerta de GameUI.tscn en su posición exacta configurada en el editor.
## - Enciende PLANO_ILUMINADO con efecto parpadeante en blanco semi-transparente.
## - Al mantener W o Espacio por 2s: camina hacia el fondo y ejecuta la transición circular a Player_Interior.tscn.
## - Guarda la posición de retorno para volver exactamente al mismo punto al salir de la habitación.

@export var tiempo_requerido: float = 2.0
@export var escena_destino: String = "res://Levels/Player_Interior.tscn"

var _oleada_activa: bool = true
var _en_cortinilla_victoria: bool = false

var _jugador_dentro: bool = false
var _jugador_ref: CharacterBody3D = null
var _tiempo_mantenido: float = 0.0
var _transicion_en_curso: bool = false

var _plano_iluminado: MeshInstance3D = null
var _material_plano: StandardMaterial3D = null
var _icono_ui_gameui: TextureRect = null
var _label_ui_prompt: Label = null
var _tiempo_anim: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	call_deferred("_inicializar")


func _inicializar() -> void:
	_conectar_spawner()
	_buscar_plano_iluminado()
	_buscar_icono_gameui()


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
	_en_cortinilla_victoria = false
	_apagar_indicadores()


func _on_oleada_completada(_numero_oleada: int) -> void:
	_oleada_activa = false
	_en_cortinilla_victoria = true


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
			_material_plano.albedo_color = Color(1.0, 1.0, 1.0, 0.20)
			_material_plano.emission_enabled = true
			_material_plano.emission = Color(1.0, 1.0, 1.0, 1.0)
			_material_plano.emission_energy_multiplier = 1.6
			_plano_iluminado.material_override = _material_plano


func _buscar_icono_gameui() -> void:
	var game_ui = get_tree().get_first_node_in_group("game_ui")
	if not game_ui:
		game_ui = get_tree().root.find_child("GameUI", true, false)
	if game_ui:
		_icono_ui_gameui = game_ui.find_child("IconoPuerta", true, false) as TextureRect
		if _icono_ui_gameui:
			_icono_ui_gameui.visible = false
			# Crear label informativo debajo del icono si no existe
			if not _label_ui_prompt:
				_label_ui_prompt = Label.new()
				_label_ui_prompt.name = "LabelPromptPuerta"
				_label_ui_prompt.text = "Mantén [W] o [Espacio]"
				_label_ui_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_label_ui_prompt.add_theme_font_size_override("font_size", 15)
				_label_ui_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
				_label_ui_prompt.add_theme_constant_override("outline_size", 5)
				_label_ui_prompt.position = Vector2(-35, 115)
				_label_ui_prompt.size = Vector2(180, 25)
				_label_ui_prompt.visible = false
				_icono_ui_gameui.add_child(_label_ui_prompt)


func _puede_interactuar() -> bool:
	if _transicion_en_curso:
		return false
	var hay_cortinilla := get_tree().get_nodes_in_group("pantalla_victoria_cortinilla").size() > 0
	return (_en_cortinilla_victoria or hay_cortinilla or not _oleada_activa)


func _process(delta: float) -> void:
	if _transicion_en_curso:
		return

	_verificar_proximidad_jugador()

	var activo: bool = _puede_interactuar() and _jugador_dentro and is_instance_valid(_jugador_ref)

	if not activo:
		_apagar_indicadores()
		_tiempo_mantenido = 0.0
		return

	# Mostrar indicadores y parpadear plano iluminado en blanco
	_tiempo_anim += delta * 4.5
	if not _icono_ui_gameui or not is_instance_valid(_icono_ui_gameui):
		_buscar_icono_gameui()

	if _icono_ui_gameui:
		_icono_ui_gameui.visible = true
		if _label_ui_prompt:
			_label_ui_prompt.visible = true

	if _plano_iluminado:
		_plano_iluminado.visible = true
		if _material_plano:
			var alpha_pulso = 0.10 + (sin(_tiempo_anim * 1.5) * 0.5 + 0.5) * 0.18
			_material_plano.albedo_color.a = alpha_pulso

	# Detectar pulsación mantenida de W o Espacio
	var manteniendo := (
		Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_action_pressed("move_up")
		or Input.is_action_pressed("jump")
	)

	if manteniendo:
		_tiempo_mantenido += delta
		if _label_ui_prompt:
			var pct := int(clampf(_tiempo_mantenido / tiempo_requerido, 0.0, 1.0) * 100.0)
			_label_ui_prompt.text = "Entrando... %d%%" % pct

		if _tiempo_mantenido >= tiempo_requerido:
			_iniciar_secuencia_entrada()
	else:
		_tiempo_mantenido = maxf(0.0, _tiempo_mantenido - delta * 3.0)
		if _label_ui_prompt:
			_label_ui_prompt.text = "Mantén [W] o [Espacio]"


func _apagar_indicadores() -> void:
	if _icono_ui_gameui and is_instance_valid(_icono_ui_gameui):
		_icono_ui_gameui.visible = false
	if _label_ui_prompt and is_instance_valid(_label_ui_prompt):
		_label_ui_prompt.visible = false
	if _plano_iluminado:
		_plano_iluminado.visible = false


func _verificar_proximidad_jugador() -> void:
	if not is_inside_tree():
		return
	if not _jugador_ref or not is_instance_valid(_jugador_ref):
		var prota: Node = get_tree().get_first_node_in_group("player")
		if not prota:
			prota = get_tree().root.find_child("Player", true, false)
		if prota and prota is CharacterBody3D:
			var dx: float = absf(prota.global_position.x - global_position.x)
			var dz: float = absf(prota.global_position.z - global_position.z)
			if dx < 1.8 and dz < 2.5:
				_on_body_entered(prota)
	else:
		var dx: float = absf(_jugador_ref.global_position.x - global_position.x)
		var dz: float = absf(_jugador_ref.global_position.z - global_position.z)
		if dx > 2.2 or dz > 3.0:
			_on_body_exited(_jugador_ref)


func _on_body_entered(body: Node3D) -> void:
	if _transicion_en_curso:
		return
	if body.is_in_group("player") or body.name == "Player" or body is CharacterBody3D:
		_jugador_dentro = true
		_jugador_ref = body as CharacterBody3D
		_tiempo_mantenido = 0.0


func _on_body_exited(body: Node3D) -> void:
	if body == _jugador_ref:
		_jugador_dentro = false
		_jugador_ref = null
		_tiempo_mantenido = 0.0
		_apagar_indicadores()


func _iniciar_secuencia_entrada() -> void:
	_transicion_en_curso = true
	_apagar_indicadores()

	var dest := escena_destino
	if not ResourceLoader.exists(dest):
		if ResourceLoader.exists("res://Levels/Player_Interior.tscn"):
			dest = "res://Levels/Player_Interior.tscn"
		elif ResourceLoader.exists("res://Levels/Nivel_Interior/Interio.tscn"):
			dest = "res://Levels/Nivel_Interior/Interio.tscn"

	if not is_instance_valid(_jugador_ref):
		SceneManager.cambiar_escena_cortinilla_circular(dest)
		return

	# Guardar posición para regresar al mismo punto
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").posicion_retorno_puerta = _jugador_ref.global_position

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
	tween.tween_property(model, "rotation:y", 0.0, 0.35).set_trans(Tween.TRANS_SINE)

	# Caminar hacia el fondo (-Z)
	var pos_final: Vector3 = _jugador_ref.global_position + Vector3(0, 0, -1.8)
	tween.tween_property(_jugador_ref, "global_position:z", pos_final.z, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. Activar animación de caminar hacia adelante
	var anim_tree = _jugador_ref.find_child("AnimationTree", true, false) as AnimationTree
	var anim_player = _jugador_ref.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_tree:
		anim_tree.set("parameters/Locomocion/transition_request", "caminar")
	elif anim_player:
		for a in ["Armature|Armature|CAMINAR_ADELANTE", "Armature|CAMINAR_ADELANTE", "CAMINAR_ADELANTE", "Armature|CORRER", "CORRER"]:
			if anim_player.has_animation(a):
				anim_player.play(a)
				break

	# 4. Transición con cortinilla circular
	await get_tree().create_timer(0.3).timeout
	SceneManager.cambiar_escena_cortinilla_circular(dest)
