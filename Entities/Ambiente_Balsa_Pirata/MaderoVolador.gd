class_name MaderoVolador
extends Node3D

## Madero expulsado violentamente al explotar la balsa pirata.
## Vuela en trayectoria parabólica girando en el aire (similar al hueso proyectil)
## hasta impactar con el agua, donde genera una salpicadura y se sumerge.

# === SEÑALES ===
signal cayo_al_agua(posicion_impacto: Vector3)

# === CONSTANTES ===
const ESCENA_MODELO: PackedScene = preload("res://TEST_/Madero volador/Madero volador.glb")
const MATERIAL_MADERO: Material = preload("res://TEST_/Madero volador/Madero volador_MAT.tres")
const SFX_IMPACTO_AGUA: AudioStream = preload("res://TEST_/Impacto suelo.mp3")

const ESTADO_INACTIVO: int = 0
const ESTADO_VOLANDO: int = 1
const ESTADO_SUMERGIDO: int = 2

const ESCALA_DEFECTO: float = 1.35
const GRAVEDAD_DEFECTO: float = 12.0
const VELOCIDAD_HUNDIMIENTO_AGUA: float = 0.45
const FACTOR_FRICCION_AGUA: float = 0.82
const TIEMPO_DESAPARICION_AGUA: float = 1.6
const DURACION_VFX_SPLASH: float = 0.8

# === EXPORTS ===
@export_category("Física y Simulación")
@export var escala_modelo: float = ESCALA_DEFECTO  ## Escala uniforme del modelo del madero
@export var gravedad: float = GRAVEDAD_DEFECTO  ## Aceleración hacia abajo en m/s²
@export var nivel_agua: float = -0.3  ## Cota Y donde se considera la superficie del agua
@export var capa_visual: int = 2  ## Capa de renderizado (Fondo = 2)

# === VARIABLES PÚBLICAS Y PRIVADAS ===
var velocidad: Vector3 = Vector3.ZERO
var velocidad_rotacion: Vector3 = Vector3(9.0, 5.0, 7.5)

var _estado: int = ESTADO_INACTIVO
var _modelo: Node3D = null
var _tiempo_en_agua: float = 0.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_instanciar_modelo_si_necesario()
	_aplicar_capa_visual_recursiva(self)


func _physics_process(delta: float) -> void:
	if _estado == ESTADO_INACTIVO:
		return

	if _estado == ESTADO_VOLANDO:
		_procesar_vuelo(delta)
	elif _estado == ESTADO_SUMERGIDO:
		_procesar_sumergido(delta)


# === FUNCIONES PÚBLICAS ===
## Configura e inicia el lanzamiento balístico del madero desde una posición dada.
func lanzar(posicion_inicial: Vector3, impulso_inicial: Vector3, altura_agua: float, capa: int = 2) -> void:
	_instanciar_modelo_si_necesario()
	global_position = posicion_inicial
	velocidad = impulso_inicial
	nivel_agua = altura_agua
	capa_visual = capa
	_estado = ESTADO_VOLANDO
	_tiempo_en_agua = 0.0

	# Variación aleatoria controlada del giro para dar dinamismo acrobático
	velocidad_rotacion = Vector3(
		randf_range(7.0, 12.0) * (1.0 if randf() > 0.5 else -1.0),
		randf_range(4.0, 8.0) * (1.0 if randf() > 0.5 else -1.0),
		randf_range(6.0, 11.0) * (1.0 if randf() > 0.5 else -1.0)
	)
	_aplicar_capa_visual_recursiva(self)


## Retorna true si el madero está actualmente en vuelo acrobático.
func esta_volando() -> bool:
	return _estado == ESTADO_VOLANDO


## Retorna true si el madero ya impactó en el agua.
func esta_sumergido() -> bool:
	return _estado == ESTADO_SUMERGIDO


# === FUNCIONES PRIVADAS ===
func _instanciar_modelo_si_necesario() -> void:
	if is_instance_valid(_modelo):
		return

	if not ESCENA_MODELO:
		return

	_modelo = ESCENA_MODELO.instantiate() as Node3D
	if not _modelo:
		return

	_modelo.name = "ModeloMadero"
	_modelo.scale = Vector3(escala_modelo, escala_modelo, escala_modelo)
	add_child(_modelo)

	if MATERIAL_MADERO:
		for m in _modelo.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if is_instance_valid(mi) and mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					mi.set_surface_override_material(s, MATERIAL_MADERO)


func _procesar_vuelo(delta: float) -> void:
	velocidad.y -= gravedad * delta
	global_position += velocidad * delta

	# Rotación acrobática en 3D
	if is_instance_valid(_modelo):
		_modelo.rotate_x(velocidad_rotacion.x * delta)
		_modelo.rotate_y(velocidad_rotacion.y * delta)
		_modelo.rotate_z(velocidad_rotacion.z * delta)

	# Detección de colisión / entrada a la superficie del agua
	if global_position.y <= nivel_agua:
		_impactar_en_agua()


func _impactar_en_agua() -> void:
	_estado = ESTADO_SUMERGIDO
	global_position.y = nivel_agua
	# Frenado drástico inmediato al chocar con el agua
	velocidad.x *= 0.35
	velocidad.z *= 0.35
	velocidad.y = -VELOCIDAD_HUNDIMIENTO_AGUA
	velocidad_rotacion *= 0.25

	cayo_al_agua.emit(global_position)
	_generar_salpicadura_agua()
	_reproducir_sfx_impacto()

	# Animación de hundimiento suave y desvanecimiento final
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 0.7, TIEMPO_DESAPARICION_AGUA)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ZERO, TIEMPO_DESAPARICION_AGUA)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _procesar_sumergido(delta: float) -> void:
	_tiempo_en_agua += delta
	velocidad.x *= FACTOR_FRICCION_AGUA
	velocidad.z *= FACTOR_FRICCION_AGUA
	global_position.x += velocidad.x * delta
	global_position.z += velocidad.z * delta

	if is_instance_valid(_modelo):
		_modelo.rotate_x(velocidad_rotacion.x * delta)
		_modelo.rotate_z(velocidad_rotacion.z * delta)


func _generar_salpicadura_agua() -> void:
	var root_scene: Node = get_tree().current_scene if is_inside_tree() and get_tree() else null
	if root_scene == null and is_inside_tree() and get_tree():
		root_scene = get_tree().root

	var particles := GPUParticles3D.new()
	particles.name = "WaterSplashMadero"
	particles.amount = 10
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.92

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.08
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 30.0
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 2.2
	pmat.gravity = Vector3(0.0, -9.0, 0.0)
	pmat.scale_min = 0.05
	pmat.scale_max = 0.12
	particles.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.82, 0.94, 1.0, 0.85)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true

	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	quad.material = mat
	particles.draw_pass_1 = quad

	if root_scene:
		root_scene.add_child(particles)
	else:
		add_child(particles)

	particles.global_position = global_position
	_aplicar_capa_visual_recursiva(particles)
	particles.emitting = true

	if is_inside_tree() and get_tree():
		get_tree().create_timer(DURACION_VFX_SPLASH).timeout.connect(func() -> void:
			if is_instance_valid(particles):
				particles.queue_free()
		)


func _reproducir_sfx_impacto() -> void:
	if not SFX_IMPACTO_AGUA or not is_inside_tree() or not get_tree():
		return

	var root_scene: Node = get_tree().current_scene if get_tree() else null
	if root_scene == null and get_tree():
		root_scene = get_tree().root

	var player := AudioStreamPlayer3D.new()
	player.stream = SFX_IMPACTO_AGUA
	player.volume_db = -3.0
	player.pitch_scale = randf_range(1.1, 1.35)  # Pitch más alto para simular chapoteo
	player.unit_size = 9.0
	player.max_distance = 50.0
	player.bus = "Master"

	if root_scene:
		root_scene.add_child(player)
	else:
		add_child(player)

	player.global_position = global_position
	player.play()
	player.finished.connect(player.queue_free)


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)
