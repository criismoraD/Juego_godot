@tool
class_name RatonaHerrera
extends Node3D

## NPC Neutral Ratona Herrera:
## Puede patrullar una distancia configurable desplazándose horizontalmente en el eje X (2.5D)
## con su animación 'caminar' y giro orgánico de 180° del Pivot al alcanzar el límite,
## al igual que el Orco Cerdo.
## Cuando está con las animaciones desactivadas (modo estático), ejecuta de forma predeterminada
## su animación 'Idle herrera' en loop continuo y suave.

# ─────────────────────────────────────────────
# SEÑALES
# ─────────────────────────────────────────────
signal estado_cambiado(nuevo_estado: Estado)
signal animacion_cambiada(nombre_animacion: StringName)
signal direccion_cambiada(nueva_direccion: float)

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

const MATERIAL_DEFECTO: StandardMaterial3D = preload("res://Entities/NPC_RatonaHerrera/RatonaHerrera_Mat.tres")
const SHADER_TOON_OUTLINE: Shader = preload("res://System/Shaders/TOON_LINEANEGRA.gdshader")
const NOMBRE_ANIM_CAMINAR: StringName = &"caminar"
const NOMBRE_ANIM_IDLE_HERRERA: StringName = &"Idle herrera"
const ANGULO_PIVOT_DERECHA: float = 90.0
const ANGULO_PIVOT_IZQUIERDA: float = -90.0
const VELOCIDAD_MINIMA_DESACELERACION: float = 0.2
const FACTOR_FRENO_DEFAULT: float = 0.4

# ─────────────────────────────────────────────
# EXPORTS – Configuración Visual
# ─────────────────────────────────────────────
@export_category("Configuración Visual")
@export var material_npc: StandardMaterial3D = MATERIAL_DEFECTO:
	set(nuevo_material):
		material_npc = nuevo_material
		_aplicar_material()

@export var sin_linea_negra: bool = false:  ## Quita la línea 2D / contorno toon (next_pass) de las mallas
	set(v):
		sin_linea_negra = v
		_aplicar_material()

## Grosor del contorno (el sistema global lo fuerza a 20 en runtime;
## se re-aplica diferido). Más fino = menos líneas interiores visibles.
@export_range(0.0, 20.0, 0.5) var grosor_linea_negra: float = 12.0:
	set(v):
		grosor_linea_negra = v
		_aplicar_grosor_linea()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()

# ─────────────────────────────────────────────
# EXPORTS – Patrulla y Desplazamiento
# ─────────────────────────────────────────────
@export_category("Patrulla y Desplazamiento")
@export var estatico: bool = false:  ## Si está activo (animaciones de patrulla desactivadas), ejecuta 'Idle herrera'
	set(valor):
		if estatico == valor:
			return
		estatico = valor
		animaciones_desactivadas = valor
		_actualizar_modo_estatico()

@export var animaciones_desactivadas: bool = false:  ## Alias explícito para desactivar animaciones de patrulla y ejecutar 'Idle herrera'
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

@export_range(0.0, 360.0, 0.5, "suffix:°") var posar_angulo: float = 0.0:  ## Ángulo Y de orientación (0° = Frente, 90° = Derecha, 180° = Espalda, 270° = Izquierda)
	set(grados):
		posar_angulo = wrapf(grados, 0.0, 360.0)
		if not posar_360:
			posar_360 = true
		_actualizar_orientacion_visual()

@export_group("")

# ─────────────────────────────────────────────
# EXPORTS – Nombres y Velocidades de Animación
# ─────────────────────────────────────────────
@export_category("Animaciones")
@export var anim_caminar: StringName = NOMBRE_ANIM_CAMINAR
@export var anim_idle_defecto: StringName = NOMBRE_ANIM_IDLE_HERRERA
@export_range(0.1, 2.0, 0.05) var velocidad_anim_idle: float = 0.6:  ## Escala de velocidad para ralentizar o acelerar 'Idle herrera' (ej. 0.6 = ralentizada)
	set(valor):
		velocidad_anim_idle = maxf(valor, 0.05)
		_aplicar_velocidad_animacion()

@export_range(0.1, 2.0, 0.05) var velocidad_anim_caminar: float = 1.0:  ## Escala de velocidad para la animación de caminata
	set(valor):
		velocidad_anim_caminar = maxf(valor, 0.05)
		_aplicar_velocidad_animacion()

# ─────────────────────────────────────────────
# EXPORTS – Previsualización en Editor
# ─────────────────────────────────────────────
@export_category("Previsualización en Editor")
@export_enum("Ninguna", "Idle herrera", "caminar", "Martillar", "baile", "correr", "Idle", "Climbing", "Hit", "muerte", "muerte 2") var previsualizar_animacion: String = "Idle herrera":
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

	if sin_linea_negra:
		_reaplicar_sin_outline()
	else:
		_reaplicar_grosor_linea()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _activo:
		return

	if estatico or animaciones_desactivadas:
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
	if ap.has_animation(anim_caminar):
		var clip := ap.get_animation(anim_caminar)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if ap.current_animation != anim_caminar or not ap.is_playing():
			ap.play(anim_caminar, tiempo_transicion)
		animacion_cambiada.emit(anim_caminar)


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
		if ap.has_animation(anim_caminar) and not ap.is_playing():
			ap.play(anim_caminar)


## Pausa el desplazamiento / desactiva animaciones de patrulla y activa 'Idle herrera' por defecto.
func pausar() -> void:
	estatico = true
	animaciones_desactivadas = true
	_actualizar_modo_estatico()


## Reanuda la patrulla y desplazamiento activo con la animación de caminata.
func reanudar() -> void:
	estatico = false
	animaciones_desactivadas = false
	_actualizar_modo_estatico()


## Desactiva las animaciones de desplazamiento, ejecutando 'Idle herrera' por defecto.
func desactivar_animaciones() -> void:
	pausar()


## Activa las animaciones de desplazamiento reanudando la patrulla.
func activar_animaciones() -> void:
	reanudar()


## Retorna true si el NPC está en modo estático o con animaciones de desplazamiento desactivadas.
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


## Aplica manualmente el material configurado a las mallas del modelo.
func aplicar_material() -> void:
	_aplicar_material()


## Permite posar a la Ratona Herrera en cualquier ángulo de 360 grados.
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


## Retorna si tiene activa la línea 2D (contorno toon).
func tiene_linea_2d() -> bool:
	return not sin_linea_negra


## Activa o desactiva la línea 2D (contorno toon).
func configurar_linea_2d(activa: bool) -> void:
	sin_linea_negra = not activa


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

	if ap.has_animation(anim_caminar):
		var clip_caminar := ap.get_animation(anim_caminar)
		if clip_caminar:
			clip_caminar.loop_mode = Animation.LOOP_LINEAR

	if ap.has_animation(anim_idle_defecto):
		var clip_idle := ap.get_animation(anim_idle_defecto)
		if clip_idle:
			clip_idle.loop_mode = Animation.LOOP_LINEAR


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
	var mat: Material = _material_sin_outline(material_npc) if sin_linea_negra else material_npc
	var meshes := find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi:
			if sin_linea_negra and mi.is_in_group("outline_meshes"):
				mi.remove_from_group("outline_meshes")
			elif not sin_linea_negra and not mi.is_in_group("outline_meshes"):
				mi.add_to_group("outline_meshes")
			mi.material_override = mat
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				mi.set_surface_override_material(0, mat)


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


## Re-aplica el grosor propio tras el forzar_outline global del nivel
## (que impone 20.0 a todo). Solo cuando conserva la línea.
func _reaplicar_grosor_linea() -> void:
	var arbol := get_tree()
	if arbol == null:
		return
	await arbol.process_frame
	await arbol.process_frame
	if not is_inside_tree():
		return
	_aplicar_grosor_linea()


## Fija el grosor del contorno en sus materiales activos.
func _aplicar_grosor_linea() -> void:
	if sin_linea_negra:
		return
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var outline = (mat as StandardMaterial3D).next_pass
				if outline is ShaderMaterial:
					(outline as ShaderMaterial).set_shader_parameter("outline_width", grosor_linea_negra)


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)


func _actualizar_modo_estatico() -> void:
	if not is_inside_tree() and not is_node_ready():
		return

	if estatico or animaciones_desactivadas:
		_cambiar_estado(Estado.ESTATICO)
		_velocidad_actual = 0.0
		var ap := _obtener_animation_player()
		if ap and ap.has_animation(anim_idle_defecto):
			ap.speed_scale = velocidad_anim_idle
			var clip := ap.get_animation(anim_idle_defecto)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
			if ap.current_animation != anim_idle_defecto or not ap.is_playing():
				ap.play(anim_idle_defecto, tiempo_transicion)
			animacion_cambiada.emit(anim_idle_defecto)
	else:
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
	if ap.has_animation(previsualizar_animacion):
		var clip := ap.get_animation(previsualizar_animacion)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if previsualizar_animacion == anim_idle_defecto:
			ap.speed_scale = velocidad_anim_idle
		elif previsualizar_animacion == anim_caminar:
			ap.speed_scale = velocidad_anim_caminar
		else:
			ap.speed_scale = 1.0
		ap.play(previsualizar_animacion)


func _aplicar_velocidad_animacion() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	if ap.current_animation == anim_idle_defecto or (Engine.is_editor_hint() and previsualizar_animacion == anim_idle_defecto):
		ap.speed_scale = velocidad_anim_idle
	elif ap.current_animation == anim_caminar or (Engine.is_editor_hint() and previsualizar_animacion == anim_caminar):
		ap.speed_scale = velocidad_anim_caminar
	else:
		ap.speed_scale = 1.0
