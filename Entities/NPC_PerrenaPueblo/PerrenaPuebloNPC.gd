@tool
class_name PerrenaPuebloNPC
extends Node3D

## NPC Neutral Perrena Pueblo:
## Puede patrullar una distancia configurable desplazándose horizontalmente en el eje X (2.5D)
## con su animación 'Caminar' y giro orgánico de 180° del Pivot al alcanzar el límite,
## al igual que el Orco Cerdo, la Ratona Herrera y la Arquera Aliada.
## Cuando está en modo estático (o con animaciones desactivadas), permite seleccionar y reproducir
## entre sus diversas poses ('Pose feemenina fija', 'Idle', 'Baile', 'Celebracion', etc.)
## o respiración procedural.

# ─────────────────────────────────────────────
# SEÑALES
# ─────────────────────────────────────────────
signal estado_cambiado(nuevo_estado: Estado)
signal animacion_cambiada(nombre_animacion: StringName)
signal direccion_cambiada(nueva_direccion: float)
signal pose_estatica_cambiada(nueva_pose: String)

# ─────────────────────────────────────────────
# ENUMS Y CONSTANTES
# ─────────────────────────────────────────────
enum Estado {
	CAMINANDO,
	GIRANDO,
	ESTATICO,
}

enum Direccion {
	DERECHA = 1,
	IZQUIERDA = -1,
}

const MATERIAL_DEFECTO: Material = preload("res://Entities/Jugador_Perrena/PERRENA_MAT.tres")
const NOMBRE_ANIM_CAMINAR: StringName = &"Caminar"
const POSE_GALA: String = "Pose feemenina fija"
const POSE_IDLE: String = "Idle"
const POSE_RESPIRACION: String = "Respiracion"

const ANGULO_PIVOT_DERECHA: float = 90.0
const ANGULO_PIVOT_IZQUIERDA: float = -90.0
const VELOCIDAD_MINIMA_DESACELERACION: float = 0.2
const FACTOR_FRENO_DEFAULT: float = 0.4

# ─── Interacción / Diálogo Pueblo ─────────────────────────────────────────────
const ESCENA_DIALOGO_TORRE: PackedScene = preload("res://UI/DialogoConversacionNivel5.tscn")
const JINGLE_PERRENA: AudioStream = preload("res://System/Audio/Music/Perrena Jingle.mp3")
const RADIO_INTERACCION: float = 1.5
const ALTURA_PROMPT: float = 1.25
const DURACION_FUNDIDO: float = 0.3
const COLOR_TINTE_MORADO: Color = Color(0.78, 0.48, 0.95, 0.0)
const ALFA_TINTE_MAXIMO: float = 0.22
const HABLANTE_PERRENA: String = "perrena"
const HABLANTE_ERYN: String = "eryn"

const DIALOGO_PUEBLO_PAGINAS: Array[String] = [
	"PERRENA_PUEBLO_1",
	"PERRENA_PUEBLO_2",
	"PERRENA_PUEBLO_3",
	"PERRENA_PUEBLO_4",
	"PERRENA_PUEBLO_5",
]
const DIALOGO_PUEBLO_HABLANTES: Array[String] = [
	"perrena",
	"eryn",
	"perrena",
	"perrena",
	"eryn",
]

# ─────────────────────────────────────────────
# EXPORTS – Configuración Visual
# ─────────────────────────────────────────────
@export_category("Configuración Visual")
@export var material_npc: Material = MATERIAL_DEFECTO:
	set(nuevo_material):
		material_npc = nuevo_material
		_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()

# ─────────────────────────────────────────────
# EXPORTS – Patrulla y Desplazamiento
# ─────────────────────────────────────────────
@export_category("Patrulla y Desplazamiento")
@export var estatico: bool = false:  ## Si está activo, detiene la patrulla y ejecuta la pose estática configurada
	set(valor):
		if estatico == valor:
			return
		estatico = valor
		animaciones_desactivadas = valor
		_actualizar_modo_estatico()

@export var animaciones_desactivadas: bool = false:  ## Alias explícito para pausar desplazamiento y posar al NPC
	set(valor):
		if animaciones_desactivadas == valor:
			return
		animaciones_desactivadas = valor
		estatico = valor
		_actualizar_modo_estatico()

@export var direccion_inicial: Direccion = Direccion.DERECHA:  ## Dirección inicial: DERECHA (+X) o IZQUIERDA (-X)
	set(nueva_dir):
		direccion_inicial = nueva_dir
		_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
		_configurar_pivot()
		_actualizar_orientacion_visual()

@export var distancia_recorrido: float = 6.0  ## Distancia total a recorrer antes de girar (metros)
@export var velocidad_caminar: float = 1.8   ## Velocidad de caminata horizontal (m/s)
@export_range(0.2, 2.0, 0.05) var tiempo_giro: float = 0.8  ## Tiempo que toma rotar 180° al girar
@export_range(0.1, 1.5, 0.05) var tiempo_transicion: float = 0.3  ## Tiempo de crossfade/blend entre animaciones
@export_range(0.1, 2.0, 0.05) var distancia_desaceleracion: float = 0.6  ## Distancia previa al límite para desacelerar suavemente
@export_range(0.1, 2.0, 0.05) var tiempo_aceleracion: float = 0.6  ## Tiempo de aceleración tras girar

@export_group("Posado 360 Grados", "posar_")
@export var posar_360: bool = false:  ## Habilita posar libremente la orientación en cualquier ángulo de 0 a 360°
	set(valor):
		posar_360 = valor
		_actualizar_orientacion_visual()

@export_range(0.0, 360.0, 0.5, "suffix:°") var posar_angulo: float = 90.0:  ## Ángulo Y de orientación (0° = Frente, 90° = Derecha, 180° = Espalda, 270° = Izquierda)
	set(grados):
		posar_angulo = wrapf(grados, 0.0, 360.0)
		if not posar_360:
			posar_360 = true
		_actualizar_orientacion_visual()

@export_group("")

# ─────────────────────────────────────────────
# EXPORTS – Modo Estático y Poses
# ─────────────────────────────────────────────
@export_category("Modo Estático y Poses")
@export_enum("Pose feemenina fija", "Idle", "Baile", "Celebracion", "ejercicio", "pararse", "Idle agachada", "Idle Canoa", "Respiracion") var pose_estatica: String = POSE_GALA:  ## Pose o animación al estar estático
	set(nueva_pose):
		pose_estatica = nueva_pose
		pose_estatica_cambiada.emit(pose_estatica)
		if estatico or animaciones_desactivadas:
			_actualizar_modo_estatico()

@export_range(0.1, 2.0, 0.05) var velocidad_anim_pose: float = 1.0:  ## Velocidad de reproducción para la pose / idle estático
	set(valor):
		velocidad_anim_pose = maxf(valor, 0.05)
		_aplicar_velocidad_animacion()

@export_range(0.1, 2.0, 0.05) var velocidad_anim_caminar: float = 1.0:  ## Escala de velocidad para la animación de caminata
	set(valor):
		velocidad_anim_caminar = maxf(valor, 0.05)
		_aplicar_velocidad_animacion()

## Alternancia gala/idle como en la torre: 10 s de pose sexy y 10 s de
## idle con fundido suave. Solo en modo estático.
@export var alternar_pose_idle: bool = false:
	set(v):
		alternar_pose_idle = v
		_tiempo_alternancia = 0.0
		_en_pose_gala = true
@export var duracion_pose_gala: float = 10.0
@export var duracion_pose_idle: float = 10.0
@export var fundido_alternancia: float = 0.6

@export_group("Respiración Procedural", "respiracion_")
@export_range(0.5, 4.0, 0.1) var respiracion_velocidad: float = 1.8  ## Velocidad del ciclo de respiración (rad/s)
@export_range(0.005, 0.08, 0.005) var respiracion_intensidad: float = 0.02  ## Intensidad de la deformación sutil de respiración
@export_group("")

# ─────────────────────────────────────────────
# EXPORTS – Previsualización en Editor
# ─────────────────────────────────────────────
@export_category("Previsualización en Editor")
@export_enum("Ninguna", "Caminar", "Pose feemenina fija", "Idle", "Baile", "Celebracion", "ejercicio", "pararse", "Idle agachada", "Correr") var previsualizar_animacion: String = POSE_GALA:
	set(nombre):
		previsualizar_animacion = nombre
		_actualizar_previsualizacion_editor()

# ─────────────────────────────────────────────
# VARIABLES PRIVADAS
# ─────────────────────────────────────────────
var _estado_actual: Estado = Estado.CAMINANDO
var _direccion_actual: float = 1.0
var _distancia_acumulada: float = 0.0
var _tiempo_en_estado: float = 0.0
var _activo: bool = true
var _velocidad_actual: float = 1.8
var _angulo_giro_inicio: float = ANGULO_PIVOT_DERECHA
var _angulo_giro_destino: float = ANGULO_PIVOT_IZQUIERDA

var _anim_player_ref: AnimationPlayer = null
var _pivot_visual: Node3D = null
var _nodo_modelo_ref: Node3D = null
var _tiempo_respiracion: float = 0.0
var _tiempo_alternancia: float = 0.0
var _en_pose_gala: bool = true
var _escala_base_modelo: Vector3 = Vector3.ONE

# ─── Interacción / Diálogo Pueblo ─────────────────────────────────────────────
var _jugador_cerca: bool = false
var _dialogo_activo: bool = false
var _dialogo_mostrado: bool = false
var _prompt_hablar: Node3D = null
var _tween_prompt: Tween = null
var _tween_morado: Tween = null
var _tint_mat: StandardMaterial3D = null
var _jingle_player: AudioStreamPlayer = null
var _jugador_nodo: Node3D = null

# ─────────────────────────────────────────────
# ONREADY
# ─────────────────────────────────────────────
@onready var _pivot_nodo: Node3D = %Pivot if has_node("%Pivot") else null

# ─────────────────────────────────────────────
# BUILT-INS
# ─────────────────────────────────────────────
func _ready() -> void:
	_velocidad_actual = velocidad_caminar
	_configurar_pivot()
	_capturar_escala_base()
	_aplicar_material()
	_aplicar_capa_visual()
	_inicializar_animator()

	_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
	_actualizar_orientacion_visual()

	if Engine.is_editor_hint():
		_actualizar_previsualizacion_editor()
		if estatico or animaciones_desactivadas:
			_actualizar_modo_estatico()
		return

	if estatico or animaciones_desactivadas:
		pausar()
	else:
		iniciar_caminata()

	_construir_interaccion()
	add_to_group("npcs")
	add_to_group("npc_dialogo")


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _activo:
		return

	_actualizar_proximidad()

	if estatico or animaciones_desactivadas:
		if alternar_pose_idle:
			_procesar_alternancia_pose(delta)
			return
		if pose_estatica.to_lower() == "respiracion":
			_procesar_respiracion(delta)
		return

	_tiempo_en_estado += delta

	match _estado_actual:
		Estado.CAMINANDO:
			_procesar_caminata(delta)

		Estado.GIRANDO:
			_procesar_giro(delta)


# ─────────────────────────────────────────────
# FUNCIONES PÚBLICAS
# ─────────────────────────────────────────────

## Inicia el estado de caminata en la dirección actual con aceleración suave.
func iniciar_caminata() -> void:
	_cambiar_estado(Estado.CAMINANDO)
	_tiempo_en_estado = 0.0

	var ap := _obtener_animation_player()
	if not ap:
		return

	ap.speed_scale = velocidad_anim_caminar
	if ap.has_animation(NOMBRE_ANIM_CAMINAR):
		var clip := ap.get_animation(NOMBRE_ANIM_CAMINAR)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if ap.current_animation != NOMBRE_ANIM_CAMINAR or not ap.is_playing():
			ap.play(NOMBRE_ANIM_CAMINAR, tiempo_transicion)
		animacion_cambiada.emit(NOMBRE_ANIM_CAMINAR)


## Inicia la rotación de 180 grados del Pivot al alcanzar el límite manteniendo la caminata activa.
func iniciar_giro() -> void:
	_cambiar_estado(Estado.GIRANDO)
	_tiempo_en_estado = 0.0
	_velocidad_actual = 0.0

	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		_angulo_giro_inicio = _pivot_visual.rotation_degrees.y
		if _direccion_actual > 0.0:
			_angulo_giro_destino = _angulo_giro_inicio + 180.0
		else:
			_angulo_giro_destino = _angulo_giro_inicio - 180.0

	var ap := _obtener_animation_player()
	if ap:
		ap.speed_scale = velocidad_anim_caminar
		if ap.has_animation(NOMBRE_ANIM_CAMINAR) and not ap.is_playing():
			ap.play(NOMBRE_ANIM_CAMINAR)


## Pausa el desplazamiento y activa la pose estática seleccionada.
func pausar() -> void:
	estatico = true
	animaciones_desactivadas = true
	_actualizar_modo_estatico()


## Reanuda la patrulla y desplazamiento activo con la animación de caminata.
func reanudar() -> void:
	estatico = false
	animaciones_desactivadas = false
	_actualizar_modo_estatico()


## Desactiva las animaciones de desplazamiento, ejecutando la pose estática.
func desactivar_animaciones() -> void:
	pausar()


## Activa las animaciones de desplazamiento reanudando la patrulla.
func activar_animaciones() -> void:
	reanudar()


## Retorna true si el NPC está en modo estático o con animaciones desactivadas.
func esta_estatico() -> bool:
	return estatico or animaciones_desactivadas


## Retorna el estado actual del NPC.
func obtener_estado() -> Estado:
	return _estado_actual


## Retorna la dirección horizontal actual (1.0 = derecha, -1.0 = izquierda).
func obtener_direccion() -> float:
	return _direccion_actual


## Retorna la distancia acumulada en el tramo actual.
func obtener_distancia_acumulada() -> float:
	return _distancia_acumulada


## Retorna la velocidad horizontal efectiva actual.
func obtener_velocidad_actual() -> float:
	return _velocidad_actual


## Permite calibrar la distancia del recorrido y la velocidad de caminata.
func configurar_patrulla(distancia: float, velocidad: float) -> void:
	distancia_recorrido = maxf(distancia, 0.5)
	velocidad_caminar = maxf(velocidad, 0.1)


## Permite cambiar la pose estática activa.
func cambiar_pose_estatica(nueva_pose: String) -> void:
	pose_estatica = nueva_pose


## Retorna la pose estática configurada.
func obtener_pose_estatica() -> String:
	return pose_estatica


## Aplica manualmente el material configurado a las mallas del modelo.
func aplicar_material() -> void:
	_aplicar_material()


## Permite posar a Perrena en cualquier ángulo de 360 grados.
func posar(angulo_grados: float) -> void:
	posar_360 = true
	posar_angulo = wrapf(angulo_grados, 0.0, 360.0)
	_actualizar_orientacion_visual()


## Retorna el ángulo Y actual de orientación / posado.
func obtener_angulo_posado() -> float:
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		return _pivot_visual.rotation_degrees.y
	return posar_angulo

## Retorna el material de tinte morado utilizado en el overlay.
func obtener_material_tinte() -> StandardMaterial3D:
	return _tint_mat


## Retorna true si este NPC está actualmente en conversación.
## Usado por otros NPCs para el resaltado exclusivo (solo quien habla queda morado).
func esta_hablando_dialogo() -> bool:
	return _dialogo_activo


## Retorna true si el jugador está dentro del radio de interacción.
func esta_jugador_cerca() -> bool:
	return _jugador_cerca


# ─────────────────────────────────────────────
# FUNCIONES PRIVADAS
# ─────────────────────────────────────────────

func _procesar_caminata(delta: float) -> void:
	var distancia_restante: float = distancia_recorrido - _distancia_acumulada

	# Gestionar desaceleración suave al aproximarse al final del recorrido
	if distancia_restante <= distancia_desaceleracion:
		var factor_freno: float = clampf(distancia_restante / maxf(distancia_desaceleracion, 0.01), 0.0, 1.0)
		var vel_deseada: float = lerpf(VELOCIDAD_MINIMA_DESACELERACION, velocidad_caminar, factor_freno)
		_velocidad_actual = move_toward(_velocidad_actual, vel_deseada, (velocidad_caminar / FACTOR_FRENO_DEFAULT) * delta)
	else:
		# Aceleración progresiva desde el arranque o tras girar
		var tasa_acel: float = velocidad_caminar / maxf(tiempo_aceleracion, 0.05)
		_velocidad_actual = move_toward(_velocidad_actual, velocidad_caminar, tasa_acel * delta)

	var paso: float = _velocidad_actual * delta
	position.x += _direccion_actual * paso
	_distancia_acumulada += paso

	if _distancia_acumulada >= distancia_recorrido:
		iniciar_giro()


func _procesar_giro(delta: float) -> void:
	_configurar_pivot()

	if is_instance_valid(_pivot_visual) and tiempo_giro > 0.0:
		var progreso: float = clampf(_tiempo_en_estado / tiempo_giro, 0.0, 1.0)
		var curva_suave: float = 0.5 - 0.5 * cos(progreso * PI)
		_pivot_visual.rotation_degrees.y = lerpf(_angulo_giro_inicio, _angulo_giro_destino, curva_suave)

	if _tiempo_en_estado >= tiempo_giro:
		_finalizar_giro()


func _configurar_pivot() -> void:
	if is_instance_valid(_pivot_visual):
		return
	if is_instance_valid(_pivot_nodo):
		_pivot_visual = _pivot_nodo
		return
	_pivot_visual = get_node_or_null("Pivot") as Node3D
	if not _pivot_visual:
		_pivot_visual = get_node_or_null("Model") as Node3D
	if not _pivot_visual:
		var modelos := find_children("*", "Node3D", false, false)
		if not modelos.is_empty():
			_pivot_visual = modelos[0] as Node3D


func _actualizar_orientacion_visual() -> void:
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return
	if posar_360:
		_pivot_visual.rotation_degrees.y = posar_angulo
		return
	# En vista 2.5D: derecha (+X) = 90 grados en Y, izquierda (-X) = -90 grados en Y
	if _direccion_actual > 0.0:
		_pivot_visual.rotation_degrees.y = ANGULO_PIVOT_DERECHA
	else:
		_pivot_visual.rotation_degrees.y = ANGULO_PIVOT_IZQUIERDA


func _finalizar_giro() -> void:
	_direccion_actual = -_direccion_actual
	_distancia_acumulada = 0.0
	if posar_360:
		posar_angulo = wrapf(posar_angulo + 180.0, 0.0, 360.0)
	_actualizar_orientacion_visual()
	direccion_cambiada.emit(_direccion_actual)
	_cambiar_estado(Estado.CAMINANDO)
	_tiempo_en_estado = 0.0


func _inicializar_animator() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return

	var lista_animaciones: Array[String] = [
		NOMBRE_ANIM_CAMINAR,
		POSE_GALA,
		POSE_IDLE,
		"Baile",
		"Celebracion",
		"ejercicio",
		"pararse",
		"Idle agachada",
		"Idle Canoa"
	]

	for anim_nombre in lista_animaciones:
		var anim_res := _resolver_nombre_animacion(anim_nombre)
		if not anim_res.is_empty() and ap.has_animation(anim_res):
			var clip := ap.get_animation(anim_res)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR


func _obtener_skeleton() -> Skeleton3D:
	var skels := find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		return skels[0] as Skeleton3D
	return null


func _obtener_animation_player() -> AnimationPlayer:
	if is_instance_valid(_anim_player_ref):
		return _anim_player_ref

	var ap := get_node_or_null("%AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref

	ap = get_node_or_null("Pivot/Model/AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref

	ap = get_node_or_null("Pivot/AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref

	var encontrados := find_children("*", "AnimationPlayer", true, false)
	if not encontrados.is_empty():
		_anim_player_ref = encontrados[0] as AnimationPlayer
		return _anim_player_ref

	return null


func _cambiar_estado(nuevo: Estado) -> void:
	if _estado_actual == nuevo:
		return
	_estado_actual = nuevo
	estado_cambiado.emit(_estado_actual)


func _aplicar_material() -> void:
	if material_npc == null:
		return
	var meshes := find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi:
			mi.material_override = material_npc
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				mi.set_surface_override_material(0, material_npc)


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)


## Alterna pose de gala e idle con fundido suave, como en la torre.
## Solo se usa en modo estático con alternar_pose_idle activo.
func _procesar_alternancia_pose(delta: float) -> void:
	var ap := _obtener_animation_player()
	if ap == null:
		return
	_tiempo_alternancia += delta
	var duracion: float = duracion_pose_gala if _en_pose_gala else duracion_pose_idle
	if _tiempo_alternancia >= duracion:
		_tiempo_alternancia = 0.0
		_en_pose_gala = not _en_pose_gala
	var anim_res := _resolver_nombre_animacion(POSE_GALA if _en_pose_gala else POSE_IDLE)
	if anim_res.is_empty() or not ap.has_animation(anim_res):
		return
	var clip := ap.get_animation(anim_res)
	if clip:
		clip.loop_mode = Animation.LOOP_LINEAR
	ap.speed_scale = velocidad_anim_pose
	if ap.current_animation != anim_res or not ap.is_playing():
		ap.play(anim_res, fundido_alternancia)


func _actualizar_modo_estatico() -> void:
	if not is_inside_tree() and not is_node_ready():
		return

	if estatico or animaciones_desactivadas:
		_cambiar_estado(Estado.ESTATICO)
		_velocidad_actual = 0.0
		var ap := _obtener_animation_player()
		var anim_res := _resolver_nombre_animacion(pose_estatica)
		if ap and not anim_res.is_empty() and pose_estatica.to_lower() != "respiracion":
			_restaurar_transform_modelo()
			ap.speed_scale = velocidad_anim_pose
			var clip := ap.get_animation(anim_res)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
			if ap.current_animation != anim_res or not ap.is_playing():
				ap.play(anim_res, tiempo_transicion)
			animacion_cambiada.emit(anim_res)
		else:
			if ap:
				ap.stop()
	else:
		_restaurar_transform_modelo()
		if not Engine.is_editor_hint():
			iniciar_caminata()


func _actualizar_previsualizacion_editor() -> void:
	if not Engine.is_editor_hint():
		return
	var ap := _obtener_animation_player()
	if not ap:
		return
	if previsualizar_animacion == "Ninguna" or previsualizar_animacion.is_empty():
		ap.stop()
		return
	var anim_res := _resolver_nombre_animacion(previsualizar_animacion)
	if not anim_res.is_empty() and ap.has_animation(anim_res):
		var clip := ap.get_animation(anim_res)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if anim_res == NOMBRE_ANIM_CAMINAR:
			ap.speed_scale = velocidad_anim_caminar
		else:
			ap.speed_scale = velocidad_anim_pose
		ap.play(anim_res)


func _aplicar_velocidad_animacion() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	if ap.current_animation == NOMBRE_ANIM_CAMINAR or (Engine.is_editor_hint() and previsualizar_animacion == NOMBRE_ANIM_CAMINAR):
		ap.speed_scale = velocidad_anim_caminar
	else:
		ap.speed_scale = velocidad_anim_pose


func _capturar_escala_base() -> void:
	var nodo_modelo := _obtener_nodo_modelo()
	if is_instance_valid(nodo_modelo):
		_escala_base_modelo = nodo_modelo.scale


func _restaurar_transform_modelo() -> void:
	var nodo_modelo := _obtener_nodo_modelo()
	if is_instance_valid(nodo_modelo):
		nodo_modelo.scale = _escala_base_modelo


func _obtener_nodo_modelo() -> Node3D:
	if is_instance_valid(_nodo_modelo_ref):
		return _nodo_modelo_ref
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		var model_node := _pivot_visual.get_node_or_null("Model") as Node3D
		if model_node:
			_nodo_modelo_ref = model_node
			return _nodo_modelo_ref
		return _pivot_visual
	return null


func _procesar_respiracion(delta: float) -> void:
	_tiempo_respiracion += delta * respiracion_velocidad
	var onda: float = sin(_tiempo_respiracion)

	var nodo_modelo := _obtener_nodo_modelo()
	if not is_instance_valid(nodo_modelo):
		return

	var factor_y: float = 1.0 + (onda * respiracion_intensidad)
	var factor_z: float = 1.0 + (onda * respiracion_intensidad * 0.8)
	var factor_x: float = 1.0 + (onda * respiracion_intensidad * 0.4)

	nodo_modelo.scale = Vector3(
		_escala_base_modelo.x * factor_x,
		_escala_base_modelo.y * factor_y,
		_escala_base_modelo.z * factor_z
	)


func _resolver_nombre_animacion(nombre: String) -> StringName:
	var ap := _obtener_animation_player()
	if not ap:
		return StringName()
	if ap.has_animation(nombre):
		return StringName(nombre)
	for anim in ap.get_animation_list():
		if anim.to_lower() == nombre.to_lower():
			return StringName(anim)
	return StringName()


# ─────────────────────────────────────────────
# INTERACCIÓN Y DIÁLOGO – NIVEL PUEBLO
# ─────────────────────────────────────────────

## Construye el Label3D de prompt reutilizando el nodo existente en la escena
## o creando uno dinámico si no existe. Parámetros idénticos al resto de NPCs del pueblo.
func _construir_interaccion() -> void:
	_prompt_hablar = find_child("PromptHablar", true, false) as Label3D
	if _prompt_hablar == null:
		var lbl := Label3D.new()
		lbl.name = "PromptHablar"
		lbl.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
		lbl.pixel_size = 0.0035
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 22
		lbl.outline_size = 5
		lbl.modulate = Color(1.0, 1.0, 1.0, 0.0)
		lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.0)
		lbl.position = Vector3(0.0, ALTURA_PROMPT, 0.0)
		lbl.visible = false
		add_child(lbl)
		_prompt_hablar = lbl
	else:
		# Normalizar un nodo existente a los parámetros estándar
		var lbl := _prompt_hablar as Label3D
		lbl.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
		lbl.pixel_size = 0.0035
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 22
		lbl.outline_size = 5
		lbl.modulate = Color(1.0, 1.0, 1.0, 0.0)
		lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.0)
		lbl.visible = false


## Detecta si el jugador está dentro del radio de interacción y conmuta el prompt.
## Si otro NPC está hablando, este NPC apaga su resaltado (solo quien habla queda morado).
func _actualizar_proximidad() -> void:
	var jugador := _obtener_jugador()
	if jugador == null:
		return
	var cerca_fisica: bool = global_position.distance_to(jugador.global_position) <= RADIO_INTERACCION
	var cerca: bool = cerca_fisica
	if not _dialogo_activo and cerca_fisica and _hay_otro_npc_hablando():
		cerca = false
	if cerca == _jugador_cerca:
		return
	_jugador_cerca = cerca
	_animar_prompt(cerca)
	_animar_morado(cerca)


## Retorna el nodo del jugador (busca en grupo "player").
func _obtener_jugador() -> Node3D:
	if is_instance_valid(_jugador_nodo):
		return _jugador_nodo
	var arbol := get_tree()
	if arbol == null:
		return null
	_jugador_nodo = arbol.get_first_node_in_group("player") as Node3D
	return _jugador_nodo


## Fundido suave del prompt con Tween (0.3 s).
func _animar_prompt(activo: bool) -> void:
	if _prompt_hablar == null:
		return
	if _tween_prompt and _tween_prompt.is_valid():
		_tween_prompt.kill()
	if get_tree() == null:
		_prompt_hablar.visible = activo
		if "modulate" in _prompt_hablar:
			_prompt_hablar.modulate.a = 1.0 if activo else 0.0
		return
	_tween_prompt = create_tween().set_parallel(true)
	var objetivo: float = 1.0 if activo else 0.0
	if activo:
		if _prompt_hablar is Label3D:
			(_prompt_hablar as Label3D).text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
		_prompt_hablar.visible = true
	_tween_prompt.tween_property(_prompt_hablar, "modulate:a", objetivo, DURACION_FUNDIDO).set_trans(Tween.TRANS_SINE)
	if _prompt_hablar is Label3D:
		_tween_prompt.tween_property(_prompt_hablar, "outline_modulate:a", objetivo, DURACION_FUNDIDO).set_trans(Tween.TRANS_SINE)
	if not activo:
		_tween_prompt.chain().tween_callback(_ocultar_prompt_si_lejos)


func _ocultar_prompt_si_lejos() -> void:
	if not _jugador_cerca and _prompt_hablar:
		_prompt_hablar.visible = false


func _configurar_tinte_morado() -> void:
	if _tint_mat == null:
		_tint_mat = StandardMaterial3D.new()
		_tint_mat.cull_mode = BaseMaterial3D.CULL_BACK
		_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		_tint_mat.albedo_color = COLOR_TINTE_MORADO

	var meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi:
			mi.material_overlay = _tint_mat


## Aplica tinte morado overlay a todos los MeshInstance3D del NPC con Tween suave (0.3 s).
func _animar_morado(activo: bool) -> void:
	if _tween_morado and _tween_morado.is_valid():
		_tween_morado.kill()

	if _tint_mat == null:
		_configurar_tinte_morado()

	var target_alpha: float = ALFA_TINTE_MAXIMO if activo else 0.0
	if not is_inside_tree() or get_tree() == null:
		if _tint_mat:
			_tint_mat.albedo_color.a = target_alpha
		return

	_tween_morado = create_tween()
	var duracion: float = DURACION_FUNDIDO if activo else 0.25
	_tween_morado.tween_method(
		func(alpha: float) -> void:
			if _tint_mat:
				_tint_mat.albedo_color = Color(COLOR_TINTE_MORADO.r, COLOR_TINTE_MORADO.g, COLOR_TINTE_MORADO.b, alpha),
		_tint_mat.albedo_color.a,
		target_alpha,
		duracion
	).set_trans(Tween.TRANS_SINE)


## Captura KEY_E cuando el jugador está cerca. El diálogo queda disponible
## siempre, incluso después de haberlo escuchado (reinteractuable).
func _unhandled_input(evento: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _dialogo_activo:
		return
	if not _jugador_cerca:
		return
	if _hay_otro_npc_hablando():
		return
	if not (evento is InputEventKey):
		return
	var tecla_ev := evento as InputEventKey
	if not tecla_ev.pressed or tecla_ev.echo:
		return
	if tecla_ev.keycode == KEY_E:
		_mostrar_dialogo_pueblo()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _dialogo_activo:
		if is_instance_valid(_jingle_player) and _jingle_player.playing:
			_jingle_player.stop()
		AudioManager.resume_music()
		_set_movimiento_jugador(true)


## Instancia y muestra el diálogo de conversación del pueblo (repetible).
func _mostrar_dialogo_pueblo() -> void:
	if _dialogo_activo:
		return
	if _hay_otro_npc_hablando():
		return
	if get_tree() == null:
		return
	_dialogo_activo = true
	_apagar_resaltado_otros_npcs()
	if _prompt_hablar:
		_prompt_hablar.visible = false

	# Congelar al jugador por completo (sin movimiento, salto, disparo ni recarga)
	_set_movimiento_jugador(false)

	# Pausar la música del nivel y reproducir el jingle de Perrena en loop continuo
	AudioManager.pause_music()
	if _jingle_player == null:
		_jingle_player = AudioStreamPlayer.new()
		_jingle_player.name = "PerrenaJinglePlayer"
		_jingle_player.bus = "Master"
		_jingle_player.finished.connect(_on_jingle_player_finished)
		add_child(_jingle_player)

	_jingle_player.stream = JINGLE_PERRENA
	if _jingle_player.stream and "loop" in _jingle_player.stream:
		_jingle_player.stream.set("loop", true)
	_jingle_player.volume_db = -2.0
	_jingle_player.play()

	var dialogo := ESCENA_DIALOGO_TORRE.instantiate() as DialogoComic
	if dialogo == null:
		push_warning("[PerrenaPuebloNPC] La escena de diálogo no usa DialogoComic.")
		_dialogo_activo = false
		if is_instance_valid(_jingle_player) and _jingle_player.playing:
			_jingle_player.stop()
		AudioManager.resume_music()
		_set_movimiento_jugador(true)
		return
	dialogo.paginas_texto = PackedStringArray(DIALOGO_PUEBLO_PAGINAS)
	dialogo.paginas_hablante = PackedStringArray(DIALOGO_PUEBLO_HABLANTES)
	var ancla: Node = get_tree().current_scene
	if ancla == null:
		ancla = get_parent()
	dialogo.continuado.connect(_on_dialogo_terminado.bind(dialogo))
	ancla.add_child(dialogo)


## Callback al terminar el diálogo: libera la escena, detiene el jingle,
## reanuda la música del nivel, descongela al jugador y deja el diálogo disponible.
func _on_dialogo_terminado(dialogo: DialogoComic) -> void:
	if is_instance_valid(dialogo):
		dialogo.queue_free()
	_dialogo_activo = false
	_dialogo_mostrado = true

	# Detener el jingle de Perrena y reanudar la música normal del nivel
	if is_instance_valid(_jingle_player) and _jingle_player.playing:
		_jingle_player.stop()
	AudioManager.resume_music()

	# Descongelar al jugador
	_set_movimiento_jugador(true)

	# Reevaluar proximidad: si el jugador sigue cerca, mantener prompt y morado.
	_jugador_cerca = false
	_actualizar_proximidad()
	if not _jugador_cerca:
		_animar_morado(false)


func _on_jingle_player_finished() -> void:
	if _dialogo_activo and is_instance_valid(_jingle_player):
		_jingle_player.play()



## True si algún otro NPC del grupo está actualmente en conversación.
func _hay_otro_npc_hablando() -> bool:
	var arbol := get_tree()
	if arbol == null:
		return false
	for nodo in arbol.get_nodes_in_group("npc_dialogo"):
		if nodo == self:
			continue
		if not is_instance_valid(nodo):
			continue
		if nodo.has_method("esta_hablando_dialogo"):
			if bool(nodo.call("esta_hablando_dialogo")):
				return true
	return false


## Apaga el resaltado morado y el prompt de los demás NPCs para que
## solo este NPC permanezca morado mientras habla.
func _apagar_resaltado_otros_npcs() -> void:
	var arbol := get_tree()
	if arbol == null:
		return
	for nodo in arbol.get_nodes_in_group("npc_dialogo"):
		if nodo == self:
			continue
		if not is_instance_valid(nodo):
			continue
		if nodo.has_method("_forzar_apagado_proximidad"):
			nodo.call("_forzar_apagado_proximidad")


## Apaga prompt y tinte propios cuando otro NPC inicia su diálogo.
## No hace nada si este NPC es quien está hablando.
func _forzar_apagado_proximidad() -> void:
	if _dialogo_activo:
		return
	_jugador_cerca = false
	_animar_prompt(false)
	_animar_morado(false)


## Bloquea o desbloquea el movimiento y acciones del jugador.
func _set_movimiento_jugador(permitir: bool) -> void:
	var arbol := get_tree()
	if arbol == null:
		return
	for jugador in arbol.get_nodes_in_group("player"):
		if not is_instance_valid(jugador):
			continue
		if jugador.has_method("set_puede_moverse"):
			jugador.call("set_puede_moverse", permitir)
		elif "puede_moverse" in jugador:
			jugador.puede_moverse = permitir
		elif "can_move" in jugador:
			jugador.can_move = permitir

		if not permitir:
			if "velocity" in jugador:
				jugador.velocity = Vector3.ZERO
