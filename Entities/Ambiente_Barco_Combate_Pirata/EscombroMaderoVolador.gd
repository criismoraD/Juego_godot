class_name EscombroMaderoVolador
extends Node3D

## Escombro de madera expulsado acrobáticamente al ser destruido el Barco Combate Pirata.
## Vuela en trayectoria parabólica girando en 3D sobre su propio centro de masa
## hasta impactar con la superficie del agua, donde genera ondas circulares
## (como el impacto de flecha en el agua), sonido de chapoteo y se sumerge suavemente.

# === SEÑALES ===
signal cayo_al_agua(posicion_impacto: Vector3)

# === CONSTANTES ===
const MESHES_ESCOMBROS: Array[Mesh] = [
	preload("res://Entities/Ambiente_Barco_Combate_Pirata/Escombros/escombro_0.tres"),
	preload("res://Entities/Ambiente_Barco_Combate_Pirata/Escombros/escombro_1.tres"),
	preload("res://Entities/Ambiente_Barco_Combate_Pirata/Escombros/escombro_2.tres"),
	preload("res://Entities/Ambiente_Barco_Combate_Pirata/Escombros/escombro_3.tres"),
	preload("res://Entities/Ambiente_Barco_Combate_Pirata/Escombros/escombro_4.tres"),
	preload("res://Entities/Ambiente_Barco_Combate_Pirata/Escombros/escombro_5.tres"),
]
const MATERIAL_ESCOMBROS: Material = preload("res://Entities/Ambiente_Barco_Combate_Pirata/Escombros/maderos escombros_MAT.tres")
const ESCENA_SPLASH_AGUA: PackedScene = preload("res://VFX/SplashAgua/SCENES/splash_vfx.tscn")
const SFX_SPLASH_CLAVE: String = "splash_agua"

const ESTADO_INACTIVO: int = 0
const ESTADO_VOLANDO: int = 1
const ESTADO_SUMERGIDO: int = 2

const GRAVEDAD_DEFECTO: float = 12.0
const ESCALA_DEFECTO: float = 2.4
const ESCALA_SPLASH_DEFECTO: float = 0.35
const DURACION_SPLASH_AGUA: float = 2.0
const TIEMPO_DESAPARICION_AGUA: float = 1.6
const VELOCIDAD_HUNDIMIENTO_AGUA: float = 0.4
const FACTOR_FRICCION_AGUA: float = 0.85
const DESPLAZAMIENTO_HUNDIMIENTO_Y: float = 0.6

# === EXPORTS ===
@export_category("Física y Simulación")
@export var escala_modelo: float = ESCALA_DEFECTO:  ## Escala uniforme del escombro
	set(valor):
		escala_modelo = valor
		if is_instance_valid(_mesh_instance):
			_mesh_instance.scale = Vector3.ONE * escala_modelo
@export var gravedad: float = GRAVEDAD_DEFECTO  ## Aceleración de caída en m/s²
@export var nivel_agua: float = -0.3  ## Cota Y de la superficie del agua
@export var capa_visual: int = 1  ## Capa de renderizado (Frente = 1)
@export var escala_splash: float = ESCALA_SPLASH_DEFECTO  ## Tamaño de la onda al tocar agua
@export_range(0, 5, 1) var indice_pieza: int = 0  ## Índice de la malla (0 a 5)

# === VARIABLES PÚBLICAS Y PRIVADAS ===
var velocidad: Vector3 = Vector3.ZERO
var velocidad_rotacion: Vector3 = Vector3.ZERO

var _estado: int = ESTADO_INACTIVO
var _mesh_instance: MeshInstance3D = null
var _tiempo_en_agua: float = 0.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_crear_mesh_instance(indice_pieza)
	_aplicar_capa_visual_recursiva(self)


func _physics_process(delta: float) -> void:
	if _estado == ESTADO_INACTIVO:
		return

	if _estado == ESTADO_VOLANDO:
		_procesar_vuelo(delta)
	elif _estado == ESTADO_SUMERGIDO:
		_procesar_sumergido(delta)


# === FUNCIONES PÚBLICAS ===
## Configura e inicia el lanzamiento acrobático del escombro.
func lanzar(posicion_inicial: Vector3, impulso_inicial: Vector3, altura_agua: float, capa: int = 1, indice: int = 0) -> void:
	indice_pieza = clampi(indice, 0, MESHES_ESCOMBROS.size() - 1)
	_crear_mesh_instance(indice_pieza)
	global_position = posicion_inicial
	velocidad = impulso_inicial
	nivel_agua = altura_agua
	capa_visual = capa
	_estado = ESTADO_VOLANDO
	_tiempo_en_agua = 0.0

	# Rotación multi-eje aleatoria para lograr un giro acrobático orgánico
	velocidad_rotacion = Vector3(
		randf_range(6.0, 11.0) * (1.0 if randf() > 0.5 else -1.0),
		randf_range(4.0, 9.0) * (1.0 if randf() > 0.5 else -1.0),
		randf_range(5.0, 10.0) * (1.0 if randf() > 0.5 else -1.0)
	)
	_aplicar_capa_visual_recursiva(self)


## Retorna true si el escombro está actualmente volando en el aire.
func esta_volando() -> bool:
	return _estado == ESTADO_VOLANDO


## Retorna true si el escombro ya cayó al agua.
func esta_sumergido() -> bool:
	return _estado == ESTADO_SUMERGIDO


## Retorna el índice de la pieza de madera activa (0 a 5).
func obtener_indice_pieza() -> int:
	return indice_pieza


# === FUNCIONES PRIVADAS ===
func _crear_mesh_instance(indice: int) -> void:
	if is_instance_valid(_mesh_instance):
		_mesh_instance.queue_free()
		_mesh_instance = null

	var idx: int = clampi(indice, 0, MESHES_ESCOMBROS.size() - 1)
	var mesh_res: Mesh = MESHES_ESCOMBROS[idx]
	if mesh_res == null:
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "MeshEscombro_%d" % idx
	_mesh_instance.mesh = mesh_res
	if MATERIAL_ESCOMBROS != null:
		_mesh_instance.material_override = MATERIAL_ESCOMBROS
	_mesh_instance.scale = Vector3.ONE * escala_modelo
	add_child(_mesh_instance)


func _procesar_vuelo(delta: float) -> void:
	velocidad.y -= gravedad * delta
	global_position += velocidad * delta

	# Rotación acrobática sobre el propio centro del escombro
	if is_instance_valid(_mesh_instance):
		_mesh_instance.rotate_x(velocidad_rotacion.x * delta)
		_mesh_instance.rotate_y(velocidad_rotacion.y * delta)
		_mesh_instance.rotate_z(velocidad_rotacion.z * delta)

	# Impacto con el agua
	if global_position.y <= nivel_agua:
		_impactar_en_agua()


func _impactar_en_agua() -> void:
	_estado = ESTADO_SUMERGIDO
	global_position.y = nivel_agua

	# Frenado drástico en el agua
	velocidad.x *= 0.3
	velocidad.z *= 0.3
	velocidad.y = -VELOCIDAD_HUNDIMIENTO_AGUA
	velocidad_rotacion *= 0.2

	cayo_al_agua.emit(global_position)
	_generar_ondas_agua()
	_reproducir_sfx_splash()

	# Hundimiento suave y desvanecimiento
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - DESPLAZAMIENTO_HUNDIMIENTO_Y, TIEMPO_DESAPARICION_AGUA)\
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

	if is_instance_valid(_mesh_instance):
		_mesh_instance.rotate_x(velocidad_rotacion.x * delta)
		_mesh_instance.rotate_z(velocidad_rotacion.z * delta)


func _generar_ondas_agua() -> void:
	if not ESCENA_SPLASH_AGUA or not is_inside_tree() or get_tree() == null:
		return

	var splash: Node3D = ESCENA_SPLASH_AGUA.instantiate() as Node3D
	if splash == null:
		return

	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(splash)

	splash.global_position = Vector3(global_position.x, nivel_agua, global_position.z)
	splash.scale = Vector3.ONE * escala_splash

	# Solo ondas y burbujas (1 y 2), igual que las ondas del impacto de flecha en el agua
	if splash.has_method("toggle_layer_index"):
		for i in range(6):
			splash.toggle_layer_index(i, i == 1 or i == 2)
	if splash.has_method("play_splash"):
		splash.play_splash()

	_aplicar_capa_visual_recursiva(splash)

	get_tree().create_timer(DURACION_SPLASH_AGUA).timeout.connect(func() -> void:
		if is_instance_valid(splash):
			splash.queue_free()
	)


func _reproducir_sfx_splash() -> void:
	if not is_inside_tree() or get_tree() == null:
		return

	if has_node("/root/AudioManager"):
		var audio_mgr = get_node("/root/AudioManager")
		if audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx(SFX_SPLASH_CLAVE)


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa_visual
	for hijo: Node in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)
