@tool
class_name PirataGoblinNPC
extends Node3D

## NPC Neutral Pirata Goblin: Patrulla una distancia configurable caminando
## continuamente con la animación 'Strut Walking'.
## Al alcanzar el límite del recorrido, desacelera suavemente, rota 180 grados
## de forma orgánica manteniendo la animación 'Strut Walking', cambia de sentido
## y retoma la marcha con aceleración progresiva en un ciclo continuo sin fin.

# ─────────────────────────────────────────────
# SEÑALES
# ─────────────────────────────────────────────
signal estado_cambiado(nuevo_estado: Estado)
signal direccion_cambiada(nueva_direccion: float)

# ─────────────────────────────────────────────
# ENUMS Y CONSTANTES
# ─────────────────────────────────────────────
enum Estado {
	CAMINANDO,
	GIRANDO,
}

enum Direccion {
	DERECHA = 1,
	IZQUIERDA = -1,
}

const MATERIAL_DEFECTO: Material = preload("res://Entities/Enemigo_Pirata_Goblin/MAT_PIRATA_GOBLIN.tres")
const NOMBRE_ANIM_CAMINAR: StringName = &"Strut Walking"
const ANGULO_PIVOT_DERECHA: float = 90.0
const ANGULO_PIVOT_IZQUIERDA: float = -90.0
const VELOCIDAD_MINIMA_DESACELERACION: float = 0.15

# ─────────────────────────────────────────────
# EXPORTS – Configuración Visual
# ─────────────────────────────────────────────
@export_category("Configuración Visual")
@export var material_npc: Material = MATERIAL_DEFECTO:
	set(nuevo_material):
		material_npc = nuevo_material
		_aplicar_material()

@export var sin_linea_negra: bool = false:  ## Quita el contorno toon (next_pass) de las mallas
	set(v):
		sin_linea_negra = v
		_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()

# ─────────────────────────────────────────────
# EXPORTS – Patrulla y Recorrido
# ─────────────────────────────────────────────
@export_category("Patrulla y Recorrido")
@export var direccion_inicial: Direccion = Direccion.DERECHA:  ## Dirección inicial: DERECHA (+X) o IZQUIERDA (-X)
	set(nueva_dir):
		direccion_inicial = nueva_dir
		_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
		_configurar_pivot()
		_actualizar_orientacion_visual()

@export var distancia_recorrido: float = 5.0  ## Distancia total a recorrer antes de girar (metros)
@export var velocidad_caminar: float = 1.2   ## Velocidad de caminata horizontal (m/s)
@export_range(0.2, 2.0, 0.05) var tiempo_giro: float = 0.8  ## Tiempo que toma rotar 180° al girar
@export_range(0.1, 2.0, 0.05) var distancia_desaceleracion: float = 0.5  ## Distancia previa al límite para desacelerar suavemente
@export_range(0.1, 2.0, 0.05) var tiempo_aceleracion: float = 0.5  ## Tiempo de aceleración tras girar

# ─────────────────────────────────────────────
# EXPORTS – Animaciones
# ─────────────────────────────────────────────
@export_category("Animación")
@export var anim_caminar: StringName = NOMBRE_ANIM_CAMINAR
@export_range(0.5, 2.0, 0.05) var velocidad_animacion: float = 1.0

# ─────────────────────────────────────────────
# VARIABLES PRIVADAS
# ─────────────────────────────────────────────
var _estado_actual: Estado = Estado.CAMINANDO
var _direccion_actual: float = 1.0
var _distancia_acumulada: float = 0.0
var _tiempo_en_estado: float = 0.0
var _activo: bool = true
var _velocidad_actual: float = 1.2
var _angulo_giro_inicio: float = ANGULO_PIVOT_DERECHA
var _angulo_giro_destino: float = ANGULO_PIVOT_IZQUIERDA

var _anim_player_ref: AnimationPlayer = null
var _pivot_visual: Node3D = null


# ─────────────────────────────────────────────
# BUILT-INS
# ─────────────────────────────────────────────
func _ready() -> void:
	if "fondo" in name.to_lower():
		capa_visual = 2

	_velocidad_actual = velocidad_caminar
	_configurar_pivot()
	_aplicar_material()
	_aplicar_capa_visual()
	_inicializar_animator()

	_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
	_actualizar_orientacion_visual()

	if Engine.is_editor_hint():
		return

	iniciar_caminata()

	# El nivel re-aplica el outline global en su _ready (posterior al nuestro):
	# re-quitarlo diferido para que gane al forzar_outline_en_runtime.
	if sin_linea_negra:
		_reaplicar_sin_outline()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _activo:
		return
	if delta <= 0.0:
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

## Inicia el ciclo de caminata continua con la animación 'Strut Walking'.
func iniciar_caminata() -> void:
	_cambiar_estado(Estado.CAMINANDO)
	_tiempo_en_estado = 0.0

	var ap := _obtener_animation_player()
	if ap and ap.has_animation(anim_caminar):
		var clip := ap.get_animation(anim_caminar)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = velocidad_animacion
		if ap.current_animation != anim_caminar or not ap.is_playing():
			ap.play(anim_caminar, 0.3)


## Inicia el giro de 180 grados mientras mantiene activa la animación de caminata.
func iniciar_giro() -> void:
	_cambiar_estado(Estado.GIRANDO)
	_tiempo_en_estado = 0.0
	_velocidad_actual = 0.0

	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		_angulo_giro_inicio = _pivot_visual.rotation_degrees.y
		# Si íbamos a la derecha (+X), el destino es la izquierda (-X = -90° / 270°)
		if _direccion_actual > 0.0:
			_angulo_giro_destino = _angulo_giro_inicio + 180.0
		else:
			_angulo_giro_destino = _angulo_giro_inicio - 180.0

	# Garantizar que 'Strut Walking' sigue sonando/reproduciéndose ininterrumpidamente
	var ap := _obtener_animation_player()
	if ap and ap.has_animation(anim_caminar) and not ap.is_playing():
		ap.play(anim_caminar)


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


## Aplica manualmente el material configurado a las mallas del pirata.
func aplicar_material() -> void:
	_aplicar_material()


# ─────────────────────────────────────────────
# FUNCIONES PRIVADAS
# ─────────────────────────────────────────────

func _procesar_caminata(delta: float) -> void:
	var distancia_restante: float = distancia_recorrido - _distancia_acumulada

	# Desaceleración suave al aproximarse al final del tramo
	if distancia_restante <= distancia_desaceleracion:
		var factor_freno: float = clampf(distancia_restante / maxf(distancia_desaceleracion, 0.01), 0.0, 1.0)
		var vel_deseada: float = lerpf(VELOCIDAD_MINIMA_DESACELERACION, velocidad_caminar, factor_freno)
		_velocidad_actual = move_toward(_velocidad_actual, vel_deseada, (velocidad_caminar / 0.3) * delta)
	else:
		# Aceleración progresiva desde el arranque o post-giro
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
		# Curva ease-in-out cosenoidal para giro suave y natural
		var curva_suave: float = 0.5 - 0.5 * cos(progreso * PI)
		_pivot_visual.rotation_degrees.y = lerpf(_angulo_giro_inicio, _angulo_giro_destino, curva_suave)

	if _tiempo_en_estado >= tiempo_giro:
		_finalizar_giro()


func _finalizar_giro() -> void:
	_direccion_actual = -_direccion_actual
	_distancia_acumulada = 0.0
	_actualizar_orientacion_visual()
	direccion_cambiada.emit(_direccion_actual)
	_cambiar_estado(Estado.CAMINANDO)
	_tiempo_en_estado = 0.0


func _configurar_pivot() -> void:
	if is_instance_valid(_pivot_visual):
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
	if _direccion_actual > 0.0:
		_pivot_visual.rotation_degrees.y = ANGULO_PIVOT_DERECHA
	else:
		_pivot_visual.rotation_degrees.y = ANGULO_PIVOT_IZQUIERDA


func _inicializar_animator() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return

	if ap.has_animation(anim_caminar):
		var clip_caminar := ap.get_animation(anim_caminar)
		if clip_caminar:
			clip_caminar.loop_mode = Animation.LOOP_LINEAR


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
	var mat: Material = _material_sin_outline(material_npc) if sin_linea_negra else material_npc
	var skel := _obtener_skeleton()
	if skel:
		_aplicar_material_recursivo(skel, mat)
	else:
		_aplicar_material_recursivo(self, mat)


func _aplicar_material_recursivo(nodo: Node, mat: Material) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		if sin_linea_negra and mi.is_in_group("outline_meshes"):
			mi.remove_from_group("outline_meshes")
		mi.material_override = mat
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mi.set_surface_override_material(0, mat)
	for hijo in nodo.get_children():
		_aplicar_material_recursivo(hijo, mat)


## Duplica el material sin el pase de contorno toon.
func _material_sin_outline(mat: Material) -> Material:
	if mat is StandardMaterial3D and (mat as StandardMaterial3D).next_pass != null:
		var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		dup.next_pass = null
		return dup
	return mat


## Re-quita el contorno tras el forzar_outline global del nivel.
func _reaplicar_sin_outline() -> void:
	var arbol := get_tree()
	if arbol == null:
		return
	await arbol.process_frame
	await arbol.process_frame
	if not is_inside_tree():
		return
	if sin_linea_negra:
		_aplicar_material()


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)
