@tool
class_name GatetaMercader
extends Node3D

## NPC Mercader (Gateta): Se ubica en el pueblo con su animación de Idle en loop.
## Cada intervalo aleatorio de entre 20 y 25 segundos cambia a la animación de Dwarf Idle.
## Las transiciones de ida y vuelta se realizan mediante crossfade suave (blend)
## para evitar cortes bruscos y lograr un movimiento orgánico y natural.

# ─────────────────────────────────────────────
# SEÑALES
# ─────────────────────────────────────────────
signal estado_cambiado(nuevo_estado: Estado)
signal animacion_cambiada(nombre_animacion: StringName)

# ─────────────────────────────────────────────
# ENUMS Y CONSTANTES
# ─────────────────────────────────────────────
enum Estado {
	IDLE,
	DWARF,
}

const MATERIAL_DEFECTO: StandardMaterial3D = preload("res://Entities/NPC_GatetaMercader/GatetaMercader_Mat.tres")
const NOMBRE_ANIM_IDLE: StringName = &"Idle"
const NOMBRE_ANIM_DWARF: StringName = &"Dwarf Idle"
const DURACION_DEFECTO_DWARF: float = 7.0333  ## Duración en segundos del clip Dwarf Idle

# ─────────────────────────────────────────────
# EXPORTS – Configuración Visual
# ─────────────────────────────────────────────
@export_category("Configuración Visual")
@export var material_npc: StandardMaterial3D = MATERIAL_DEFECTO:
	set(nuevo_material):
		material_npc = nuevo_material
		_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()

# ─────────────────────────────────────────────
# EXPORTS – Tiempos y Transiciones Suaves
# ─────────────────────────────────────────────
@export_category("Tiempos de Animación")
@export var tiempo_min_idle: float = 20.0  ## Tiempo mínimo en segundos en Idle antes de cambiar
@export var tiempo_max_idle: float = 25.0  ## Tiempo máximo en segundos en Idle antes de cambiar
@export var duracion_dwarf: float = 0.0    ## Si es > 0, tiempo forzado; si es <= 0, usa la duración natural del clip
@export_range(0.1, 2.0, 0.05) var tiempo_transicion: float = 0.75:  ## Duración del crossfade/blend entre animaciones (s)
	set(nuevo_tiempo):
		tiempo_transicion = maxf(nuevo_tiempo, 0.05)
		_actualizar_blend_times()

# ─────────────────────────────────────────────
# EXPORTS – Nombres de Animaciones
# ─────────────────────────────────────────────
@export_category("Animaciones")
@export var anim_idle: StringName = NOMBRE_ANIM_IDLE
@export var anim_dwarf: StringName = NOMBRE_ANIM_DWARF

# ─────────────────────────────────────────────
# VARIABLES PRIVADAS
# ─────────────────────────────────────────────
var _estado_actual: Estado = Estado.IDLE
var _tiempo_para_cambio: float = 20.0
var _tiempo_en_estado: float = 0.0
var _duracion_natural_dwarf: float = DURACION_DEFECTO_DWARF
var _activo: bool = true
var _anim_player_ref: AnimationPlayer = null

# ─────────────────────────────────────────────
# BUILT-INS
# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("allies")
	add_to_group("npcs")
	_aplicar_material()
	_aplicar_capa_visual()
	_inicializar_animator()
	
	if Engine.is_editor_hint():
		return
	
	_programar_proximo_cambio()
	# Al arrancar, iniciar Idle sin blend para que pose inicial aparezca de inmediato
	_reproducir_animacion(anim_idle, 0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _activo:
		return
	
	_tiempo_en_estado += delta
	
	match _estado_actual:
		Estado.IDLE:
			if _tiempo_en_estado >= _tiempo_para_cambio:
				reproducir_dwarf()
		Estado.DWARF:
			var duracion_total: float = duracion_dwarf if duracion_dwarf > 0.0 else _duracion_natural_dwarf
			# Comienza el crossfade de regreso hacia Idle antes de que termine el clip de Dwarf,
			# permitiendo que las dos animaciones se mezclen suavemente sin que se note el corte.
			var tiempo_disparo_retorno: float = maxf(duracion_total - tiempo_transicion, 0.1)
			if _tiempo_en_estado >= tiempo_disparo_retorno:
				reproducir_idle()


# ─────────────────────────────────────────────
# FUNCIONES PÚBLICAS
# ─────────────────────────────────────────────

## Cambia el estado a Idle y reproduce su animación con transición suave en loop continuo.
func reproducir_idle() -> void:
	_cambiar_estado(Estado.IDLE)
	_tiempo_en_estado = 0.0
	_programar_proximo_cambio()
	
	var ap := _obtener_animation_player()
	if ap and ap.has_animation(anim_idle):
		var clip := ap.get_animation(anim_idle)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		_reproducir_animacion(anim_idle, tiempo_transicion)
		animacion_cambiada.emit(anim_idle)


## Cambia el estado a Dwarf y reproduce su animación con transición suave.
func reproducir_dwarf() -> void:
	_cambiar_estado(Estado.DWARF)
	_tiempo_en_estado = 0.0
	
	var ap := _obtener_animation_player()
	if ap and ap.has_animation(anim_dwarf):
		var clip := ap.get_animation(anim_dwarf)
		if clip:
			clip.loop_mode = Animation.LOOP_NONE
			_duracion_natural_dwarf = clip.length
		_reproducir_animacion(anim_dwarf, tiempo_transicion)
		animacion_cambiada.emit(anim_dwarf)


## Retorna el estado actual del NPC.
func obtener_estado() -> Estado:
	return _estado_actual


## Retorna el tiempo programado para el próximo cambio a Dwarf.
func obtener_tiempo_para_cambio() -> float:
	return _tiempo_para_cambio


## Retorna el tiempo acumulado en el estado actual.
func obtener_tiempo_en_estado() -> float:
	return _tiempo_en_estado


## Retorna la duración del tiempo de transición (blend) configurada.
func obtener_tiempo_transicion() -> float:
	return tiempo_transicion


## Configura el rango de tiempo de espera antes de cambiar a Dwarf.
func configurar_intervalo(min_seg: float, max_seg: float) -> void:
	tiempo_min_idle = minf(min_seg, max_seg)
	tiempo_max_idle = maxf(min_seg, max_seg)
	_programar_proximo_cambio()


## Aplica manualmente el material configurado a las mallas hijas.
func aplicar_material() -> void:
	_aplicar_material()


# ─────────────────────────────────────────────
# FUNCIONES PRIVADAS
# ─────────────────────────────────────────────

func _inicializar_animator() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	
	if ap.has_animation(anim_idle):
		var clip_idle := ap.get_animation(anim_idle)
		if clip_idle:
			clip_idle.loop_mode = Animation.LOOP_LINEAR
	
	if ap.has_animation(anim_dwarf):
		var clip_dwarf := ap.get_animation(anim_dwarf)
		if clip_dwarf:
			clip_dwarf.loop_mode = Animation.LOOP_NONE
			_duracion_natural_dwarf = clip_dwarf.length
	
	_actualizar_blend_times()
	
	if not ap.animation_finished.is_connected(_on_animation_finished):
		ap.animation_finished.connect(_on_animation_finished)


func _actualizar_blend_times() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	if ap.has_animation(anim_idle) and ap.has_animation(anim_dwarf):
		ap.set_blend_time(anim_idle, anim_dwarf, tiempo_transicion)
		ap.set_blend_time(anim_dwarf, anim_idle, tiempo_transicion)


func _reproducir_animacion(nombre: StringName, blend: float) -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	if ap.has_animation(nombre):
		ap.play(nombre, blend)


func _programar_proximo_cambio() -> void:
	var min_t := maxf(tiempo_min_idle, 0.1)
	var max_t := maxf(tiempo_max_idle, min_t)
	_tiempo_para_cambio = randf_range(min_t, max_t)


func _cambiar_estado(nuevo: Estado) -> void:
	if _estado_actual == nuevo:
		return
	_estado_actual = nuevo
	estado_cambiado.emit(_estado_actual)


func _on_animation_finished(nombre_anim: StringName) -> void:
	if Engine.is_editor_hint():
		return
	
	# Respaldo de seguridad por si Dwarf termina antes del disparo suave anticipado
	if nombre_anim == anim_dwarf and _estado_actual == Estado.DWARF:
		reproducir_idle()


func _obtener_animation_player() -> AnimationPlayer:
	if is_instance_valid(_anim_player_ref):
		return _anim_player_ref
	
	var ap := get_node_or_null("%AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref
	
	ap = get_node_or_null("Model/AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref
	
	var encontrados := find_children("*", "AnimationPlayer", true, false)
	if not encontrados.is_empty():
		_anim_player_ref = encontrados[0] as AnimationPlayer
		return _anim_player_ref
	
	return null


func _aplicar_material() -> void:
	if material_npc == null:
		return
	_aplicar_material_recursivo(self)


func _aplicar_material_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		mi.material_override = material_npc
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mi.set_surface_override_material(0, material_npc)
	for hijo in nodo.get_children():
		_aplicar_material_recursivo(hijo)


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)
