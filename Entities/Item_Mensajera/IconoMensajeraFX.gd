class_name IconoMensajeraFX
extends Area3D

## Icono de invocación de la mensajera (nivel 5): flota sobre RimAreaVFX_03,
## palpita y desaparece al ser activado por la jugadora.

signal activada

const SFX_REFUERZO_MENSAJERA: AudioStream = preload("res://System/Audio/SFX/Sonido_refuerzo_mensajera.mp3")

@export_category("Flotación")
@export var altura_flotacion: float = 0.75  ## Altura del icono sobre la base del VFX
@export var amplitud_flotacion: float = 0.05  ## Sube/baja suave
@export var velocidad_flotacion: float = 2.2
@export_category("Palpitar")
@export var escala_base_icono: float = 1.0
@export var escala_palpito: float = 1.12  ## Pico del latido
@export var duracion_palpito: float = 0.55
@export var retardo_armado: float = 1.0  ## Segundos antes de poder activarse (evita auto-activación al aparecer)

var _icono: Sprite3D = null
var _vfx_luz: Node3D = null
var _activado: bool = false
var _armado: bool = false
var _tiempo: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_icono = get_node_or_null("Icono") as Sprite3D
	_vfx_luz = get_node_or_null("VFXLuz") as Node3D
	# Inactivo hasta pasar el retardo de armado
	set_deferred("monitoring", false)
	get_tree().create_timer(retardo_armado).timeout.connect(func():
		if is_instance_valid(self) and not _activado:
			_armado = true
			set_deferred("monitoring", true)
	)

	# Latido del icono: escala sube/baja rítmicamente
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
	# Flotación suave sobre la columna de luz
	_tiempo += delta
	_icono.position.y = altura_flotacion + sin(_tiempo * velocidad_flotacion) * amplitud_flotacion


func _on_body_entered(body: Node3D) -> void:
	if _activado or not _armado:
		return
	if not body.is_in_group("player"):
		return
	_activado = true
	set_deferred("monitoring", false)

	# El item refuerzo llena al completo todos los corazones de la jugadora
	if body.has_method("curar") and "vida_maxima" in body:
		body.curar(int(body.vida_maxima))
	elif "health" in body and "vida_maxima" in body:
		body.health = body.vida_maxima
		if body.has_signal("health_changed"):
			body.health_changed.emit(body.health)

	_crear_particulas_disolucion_moradas()
	_reproducir_sonido_refuerzo()
	activada.emit()
	_desaparecer()


func _crear_particulas_disolucion_moradas() -> void:
	# Mismo efecto que enemigos al disolverse (GoblinPiezaFisica/CanastaCaida) pero en morado
	var particles := GPUParticles3D.new()
	particles.name = "ParticulasDisolucionMoradas"
	particles.amount = 32
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.0
	particles.randomness = 0.5

	var color_morado := Color(0.8, 0.2, 0.8, 1.0)

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
		get_tree().create_timer(1.3).timeout.connect(func():
			if is_instance_valid(particles):
				particles.emitting = false
				get_tree().create_timer(0.7).timeout.connect(func():
					if is_instance_valid(particles):
						particles.queue_free()
				)
		)


func _reproducir_sonido_refuerzo() -> void:
	if not SFX_REFUERZO_MENSAJERA:
		return
	var sfx_player := AudioStreamPlayer.new()
	sfx_player.stream = SFX_REFUERZO_MENSAJERA
	sfx_player.volume_db = 2.0
	sfx_player.bus = "Master"
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	if root:
		root.add_child(sfx_player)
		sfx_player.play()
		sfx_player.finished.connect(sfx_player.queue_free)
	else:
		sfx_player.queue_free()


## Desaparición: encoge rápido y se libera
func _desaparecer() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if _icono:
		tw.tween_property(_icono, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
