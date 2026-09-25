class_name CanonDestruidoVolador
extends Node3D

## Cañón destruido expulsado acrobáticamente al ser derrotado el Jefe Submarino en el Río.
## Vuela en trayectoria parabólica girando en 3D sobre su propio centro de masa
## hasta impactar con la superficie del agua, donde genera ondas circulares
## (como el impacto de flecha en el agua), sonido de chapoteo y se sumerge suavemente.

# === SEÑALES ===
signal cayo_al_agua(posicion_impacto: Vector3)

# === ENUMS Y CONSTANTES ===
enum TipoPieza {
	CANON = 0,
	TUERCA = 1,
}

const ESCENA_MODELO_CANON: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Modelos/Cañon destruido/Cañon destruido(3K).glb")
const MESH_TUERCA: Mesh = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Modelos/Cañon destruido/TuercaRuedaMesh.tres")
const MATERIAL_CANON: Material = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Modelos/Cañon destruido/CanonDestruido_Mat.tres")
const ESCENA_SPLASH_AGUA: PackedScene = preload("res://VFX/SplashAgua/SCENES/splash_vfx.tscn")
const SFX_SPLASH_CLAVE: String = "splash_agua"

const ESTADO_INACTIVO: int = 0
const ESTADO_VOLANDO: int = 1
const ESTADO_SUMERGIDO: int = 2

const GRAVEDAD_DEFECTO: float = 12.5
const ESCALA_DEFECTO_CANON: float = 2.0
const ESCALA_DEFECTO_TUERCA: float = 1.1
## Splash estilo Azulina (efecto completo) pero un poco menor que el anterior.
const ESCALA_SPLASH_DEFECTO: float = 0.5
const ESCALA_SPLASH_TUERCA: float = 0.3
const DURACION_SPLASH_AGUA: float = 2.0
const TIEMPO_DESAPARICION_AGUA: float = 1.8
const VELOCIDAD_HUNDIMIENTO_AGUA: float = 0.45
const FACTOR_FRICCION_AGUA: float = 0.85
const DESPLAZAMIENTO_HUNDIMIENTO_Y: float = 0.8

## Offset para centrar la geometría de Cañon destruido(3K).glb sobre su centro de masa
const OFFSET_CENTRO_CANON: Vector3 = Vector3(-0.32, -0.25, 0.0)
const OFFSET_CENTRO_TUERCA: Vector3 = Vector3.ZERO

# === EXPORTS ===
@export_category("Tipo de Pieza")
@export var tipo_pieza: TipoPieza = TipoPieza.CANON:
	set(valor):
		tipo_pieza = valor
		if is_inside_tree() or is_instance_valid(_pivot_rotacion):
			_crear_modelo()

@export_category("Física y Simulación")
@export var escala_modelo: float = ESCALA_DEFECTO_CANON  ## Escala uniforme de la pieza
@export var gravedad: float = GRAVEDAD_DEFECTO  ## Aceleración de caída en m/s²
@export var nivel_agua: float = -0.3  ## Cota Y de la superficie del agua
@export var capa_visual: int = 1  ## Capa de renderizado (Frente = 1)
@export var escala_splash: float = ESCALA_SPLASH_DEFECTO  ## Tamaño de la onda al tocar agua

# === VARIABLES PÚBLICAS Y PRIVADAS ===
var velocidad: Vector3 = Vector3.ZERO
var velocidad_rotacion: Vector3 = Vector3.ZERO

var _estado: int = ESTADO_INACTIVO
var _pivot_rotacion: Node3D = null
var _modelo_instancia: Node3D = null
var _tiempo_en_agua: float = 0.0


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	if not is_instance_valid(_pivot_rotacion):
		_crear_modelo()
	_aplicar_capa_visual_recursiva(self)


func _physics_process(delta: float) -> void:
	if _estado == ESTADO_INACTIVO:
		return

	if _estado == ESTADO_VOLANDO:
		_procesar_vuelo(delta)
	elif _estado == ESTADO_SUMERGIDO:
		_procesar_sumergido(delta)


# === FUNCIONES PÚBLICAS ===
## Configura e inicia el lanzamiento acrobático del cañón o tuerca destruida.
func lanzar(posicion_inicial: Vector3, impulso_inicial: Vector3, altura_agua: float = -0.3, capa: int = 1) -> void:
	if not is_instance_valid(_pivot_rotacion):
		_crear_modelo()
	global_position = posicion_inicial
	velocidad = impulso_inicial
	nivel_agua = altura_agua
	capa_visual = capa
	_estado = ESTADO_VOLANDO
	_tiempo_en_agua = 0.0

	# Rotación multi-eje acrobática orgánica adaptada al tipo de pieza
	if tipo_pieza == TipoPieza.TUERCA:
		velocidad_rotacion = Vector3(
			randf_range(8.0, 15.0) * (1.0 if randf() > 0.5 else -1.0),
			randf_range(10.0, 18.0) * (1.0 if randf() > 0.5 else -1.0),
			randf_range(6.0, 13.0) * (1.0 if randf() > 0.5 else -1.0)
		)
	else:
		velocidad_rotacion = Vector3(
			randf_range(6.0, 10.0) * (1.0 if randf() > 0.5 else -1.0),
			randf_range(5.0, 9.0) * (1.0 if randf() > 0.5 else -1.0),
			randf_range(4.0, 8.0) * (1.0 if randf() > 0.5 else -1.0)
		)
	_aplicar_capa_visual_recursiva(self)


## Retorna true si el cañón o tuerca está volando por los aires.
func esta_volando() -> bool:
	return _estado == ESTADO_VOLANDO


## Retorna true si el cañón o tuerca ya cayó al agua.
func esta_sumergido() -> bool:
	return _estado == ESTADO_SUMERGIDO


## Retorna la referencia a la instancia del modelo 3D.
func obtener_modelo_instancia() -> Node3D:
	return _modelo_instancia


# === FUNCIONES PRIVADAS ===
func _crear_modelo() -> void:
	if is_instance_valid(_pivot_rotacion):
		_pivot_rotacion.queue_free()
		_pivot_rotacion = null

	var escala_final: float = escala_modelo
	if tipo_pieza == TipoPieza.TUERCA and is_equal_approx(escala_modelo, ESCALA_DEFECTO_CANON):
		escala_final = ESCALA_DEFECTO_TUERCA

	_pivot_rotacion = Node3D.new()
	_pivot_rotacion.name = "PivotRotacionCanon" if tipo_pieza == TipoPieza.CANON else "PivotRotacionTuerca"
	_pivot_rotacion.scale = Vector3.ONE * escala_final
	add_child(_pivot_rotacion)

	if tipo_pieza == TipoPieza.TUERCA:
		var mi := MeshInstance3D.new()
		mi.name = "MallaTuercaDestruida"
		mi.mesh = MESH_TUERCA
		mi.material_override = MATERIAL_CANON
		mi.position = OFFSET_CENTRO_TUERCA
		_modelo_instancia = mi
		_pivot_rotacion.add_child(_modelo_instancia)
	else:
		if ESCENA_MODELO_CANON == null:
			return

		var modelo: Node = ESCENA_MODELO_CANON.instantiate()
		if not (modelo is Node3D):
			modelo.queue_free()
			return

		_modelo_instancia = modelo as Node3D
		_modelo_instancia.name = "ModeloCanonDestruido"
		_modelo_instancia.position = OFFSET_CENTRO_CANON
		_pivot_rotacion.add_child(_modelo_instancia)

		# Aplicar textura difusa y material a todas las mallas
		_aplicar_material_recursivo(_modelo_instancia, MATERIAL_CANON)


func _aplicar_material_recursivo(nodo: Node, mat: Material) -> void:
	if not is_instance_valid(nodo) or mat == null:
		return
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		mi.material_override = mat
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s, mat)
	for c in nodo.get_children():
		_aplicar_material_recursivo(c, mat)


func _procesar_vuelo(delta: float) -> void:
	velocidad.y -= gravedad * delta
	global_position += velocidad * delta

	# Rotación acrobática sobre el propio centro del cañón
	if is_instance_valid(_pivot_rotacion):
		_pivot_rotacion.rotate_x(velocidad_rotacion.x * delta)
		_pivot_rotacion.rotate_y(velocidad_rotacion.y * delta)
		_pivot_rotacion.rotate_z(velocidad_rotacion.z * delta)

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

	if is_instance_valid(_pivot_rotacion):
		_pivot_rotacion.rotate_x(velocidad_rotacion.x * delta)
		_pivot_rotacion.rotate_z(velocidad_rotacion.z * delta)


func _generar_ondas_agua() -> Node3D:
	if not ESCENA_SPLASH_AGUA or not is_inside_tree() or get_tree() == null:
		return null

	var splash: Node3D = ESCENA_SPLASH_AGUA.instantiate() as Node3D
	if splash == null:
		return null

	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(splash)

	splash.global_position = Vector3(global_position.x, nivel_agua, global_position.z)
	var escala_final_splash: float = escala_splash
	if tipo_pieza == TipoPieza.TUERCA and is_equal_approx(escala_splash, ESCALA_SPLASH_DEFECTO):
		escala_final_splash = ESCALA_SPLASH_TUERCA
	splash.scale = Vector3.ONE * escala_final_splash

	# Efecto de splash completo estilo Azulina (las 6 capas: pilar, ondas,
	# burbujas, gotas, impacto y remate), sin recortes.
	if splash.has_method("play_splash"):
		splash.play_splash()

	_aplicar_capa_visual_recursiva(splash)

	get_tree().create_timer(DURACION_SPLASH_AGUA).timeout.connect(func() -> void:
		if is_instance_valid(splash):
			splash.queue_free()
	)
	return splash


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
