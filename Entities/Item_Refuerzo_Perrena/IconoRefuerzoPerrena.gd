class_name IconoRefuerzoPerrena
extends Area3D

## Ítem de Invocación de Refuerzo de Perrena:
## Funciona de forma análoga al ítem de refuerzos del Nivel 5 (IconoMensajeraFX):
## Flota, palpita con animación suave, y al ser tocado por la jugadora:
## 1. Llena todos los corazones de la jugadora.
## 2. Reproduce los sonidos de refuerzo y partículas mágicas.
## 3. Invoca a la defensora especial Perrena en el escenario.
## 4. Emite la señal 'activada' y se desvanece.

signal activada

const SFX_REFUERZO_MENSAJERA: AudioStream = preload("res://System/Audio/SFX/Sonido_refuerzo_mensajera.mp3")
const SFX_REFUERZOS_ALIADAS: AudioStream = preload("res://TEST_/refuerzos.mp3")
const DEFENSORA_PERRENA_SCENE: PackedScene = preload("res://Entities/Defensora_Perrena/DefensoraPerrena.tscn")

@export_category("Flotación y Animación")
@export var altura_flotacion: float = 0.85
@export var amplitud_flotacion: float = 0.06
@export var velocidad_flotacion: float = 2.2
@export var escala_base_icono: float = 1.65
@export var escala_palpito: float = 1.12
@export var duracion_palpito: float = 0.55
@export var retardo_armado: float = 0.2  ## Tiempo antes de poder recogerse

var _icono: Sprite3D = null
var _vfx_luz: Node3D = null
var _activado: bool = false
var _armado: bool = false
var _tiempo: float = 0.0


func _ready() -> void:
	add_to_group("icono_refuerzo_perrena")
	# Asegurar que solo exista 1 icono de refuerzo de perrena a la vez
	for n in get_tree().get_nodes_in_group("icono_refuerzo_perrena"):
		if n != self and is_instance_valid(n):
			n.queue_free()

	body_entered.connect(_on_body_entered)
	_icono = get_node_or_null("Icono") as Sprite3D
	_vfx_luz = get_node_or_null("VFXLuz") as Node3D

	if _vfx_luz:
		# Mismo tono de aura que el ítem de refuerzos normal (IconoMensajeraFX)
		if "primary_color" in _vfx_luz:
			_vfx_luz.primary_color = Color(0.78, 0.45, 1, 1)
		if "secondary_color" in _vfx_luz:
			_vfx_luz.secondary_color = Color(0.55, 0.2, 1, 1)
		if "light_color" in _vfx_luz:
			_vfx_luz.light_color = Color(0.62, 0.3, 1, 1)
		var vfx_anim := _vfx_luz.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if vfx_anim and vfx_anim.has_animation("main"):
			vfx_anim.play("main")

	set_deferred("monitoring", false)
	get_tree().create_timer(retardo_armado).timeout.connect(func():
		if is_instance_valid(self) and not _activado:
			_armado = true
			set_deferred("monitoring", true)
	)

	# Animación de latido (palpitar)
	if _icono:
		var base := escala_base_icono
		var pico := escala_base_icono * escala_palpito
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(_icono, "scale", Vector3.ONE * pico, duracion_palpito) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_icono, "scale", Vector3.ONE * base, duracion_palpito) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if not _icono:
		return
	_tiempo += delta
	_icono.position.y = altura_flotacion + sin(_tiempo * velocidad_flotacion) * amplitud_flotacion
	_verificar_proximidad_jugador()


func _verificar_proximidad_jugador() -> void:
	if _activado or not _armado:
		return
	var player := get_tree().get_first_node_in_group("player") if get_tree() else null
	if not is_instance_valid(player) or not (player is Node3D):
		return
	var p3d := player as Node3D
	var diff_x: float = absf(global_position.x - p3d.global_position.x)
	var diff_y: float = absf(global_position.y - p3d.global_position.y)
	if diff_x <= 1.6 and diff_y <= 2.2:
		_on_body_entered(p3d)


func _on_body_entered(body: Node3D) -> void:
	if _activado or not _armado:
		return
	if not body.is_in_group("player"):
		return

	_activado = true
	set_deferred("monitoring", false)

	# 1. Curación completa de la jugadora (igual que ítem nivel 5)
	if body.has_method("curar") and "vida_maxima" in body:
		body.curar(int(body.vida_maxima))
	elif "health" in body and "vida_maxima" in body:
		body.health = body.vida_maxima
		if body.has_signal("health_changed"):
			body.health_changed.emit(body.health)

	# 2. Efectos visuales y sonidos
	_crear_particulas_disolucion()
	_reproducir_sfx_refuerzo()
	_reproducir_sfx_refuerzos_aliadas()

	# 3. Invocar a la Defensora Perrena en el escenario
	_invocar_perrena(body)

	activada.emit()
	_desaparecer()


func _invocar_perrena(player_ref: Node3D) -> void:
	var root: Node = get_parent() if get_parent() else (get_tree().current_scene if get_tree().current_scene else get_tree().root)
	var scene_to_instantiate: PackedScene = DEFENSORA_PERRENA_SCENE
	if not scene_to_instantiate or not scene_to_instantiate.can_instantiate():
		scene_to_instantiate = load("res://Entities/Defensora_Perrena/DefensoraPerrena.tscn") as PackedScene

	if not scene_to_instantiate or not scene_to_instantiate.can_instantiate():
		return

	var perrena := scene_to_instantiate.instantiate() as DefensoraPerrena
	if not perrena:
		return

	# Asegurar escala del modelo jugable (0.3)
	perrena.scale = Vector3(0.3, 0.3, 0.3)
	root.add_child(perrena)

	# Iniciar despliegue: llega corriendo mirando adelante, se posiciona tras el primer escudo y pinchos, y defiende hasta 6 impactos
	perrena.desplegar_hacia_primer_escudo()


func _crear_particulas_disolucion() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ParticulasDisolucionPerrena"
	particles.amount = 36
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 0.0
	particles.randomness = 0.5

	var color_morado := Color(0.8, 0.2, 0.8, 1.0)  # Tono púrpura/morado idéntico al icono de refuerzos normal

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(0.08, 0.08, 0.08)
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 30.0
	process_mat.initial_velocity_min = 0.3
	process_mat.initial_velocity_max = 0.8
	process_mat.gravity = Vector3(0, 0.5, 0)
	process_mat.scale_min = 0.15
	process_mat.scale_max = 0.65

	var gradient := Gradient.new()
	gradient.set_color(0, color_morado)
	gradient.set_color(1, Color(color_morado.r, color_morado.g, color_morado.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.25, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	process_mat.scale_curve = scale_tex

	particles.process_material = process_mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024

	var part_mat := StandardMaterial3D.new()
	part_mat.albedo_color = color_morado
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = color_morado
	part_mat.emission_energy_multiplier = 2.0
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	particles.draw_pass_1 = sphere

	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	if root:
		root.add_child(particles)
		particles.global_position = global_position + Vector3(0.0, altura_flotacion, 0.0)
		particles.emitting = true
		var tw := particles.create_tween()
		tw.tween_interval(1.4)
		tw.tween_property(particles, "emitting", false, 0.0)
		tw.tween_interval(0.6)
		tw.tween_callback(particles.queue_free)


func _reproducir_sfx_refuerzo() -> void:
	if not SFX_REFUERZO_MENSAJERA:
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = SFX_REFUERZO_MENSAJERA
	sfx_player.volume_db = 2.0
	sfx_player.bus = "Master"
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	if root:
		root.add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	else:
		sfx_player.queue_free()


func _reproducir_sfx_refuerzos_aliadas() -> void:
	if not SFX_REFUERZOS_ALIADAS:
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = SFX_REFUERZOS_ALIADAS
	sfx_player.volume_db = 2.0
	sfx_player.bus = "Master"
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	if root:
		root.add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	else:
		sfx_player.queue_free()


func _desaparecer() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _icono:
		tw.tween_property(_icono, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
