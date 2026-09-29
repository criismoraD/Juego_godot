@tool
class_name PirataGoblinNPC
extends Node3D

## NPC Neutral Pirata Goblin: Patrulla una distancia configurable caminando
## continuamente con la animación 'Strut Walking'.
## Al alcanzar el límite del recorrido, desacelera suavemente, rota 180 grados
## de forma orgánica manteniendo la animación 'Strut Walking', cambia de sentido
## y retoma la marcha con aceleración progresiva en un ciclo continuo sin fin.
##
## Incluye sistema interactivo de diálogo idéntico a OrcoCerdo y Gateno:
## detección de proximidad con tinte morado, prompt [E] Hablar, globo de texto
## con SpeechBubbleComponent, pausa de patrulla y giro hacia el jugador durante el diálogo.

# ─────────────────────────────────────────────
# 1. SEÑALES
# ─────────────────────────────────────────────
signal estado_cambiado(nuevo_estado: Estado)
signal direccion_cambiada(nueva_direccion: float)
signal dialogo_iniciado(linea: String)
signal dialogo_avanzado(indice: int, linea: String)
signal dialogo_terminado
signal proximidad_jugador_cambiada(cerca: bool)

# ─────────────────────────────────────────────
# 2. ENUMS Y CONSTANTES
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
const NOMBRE_ANIM_IDLE: StringName = &"Idle"
const ANGULO_PIVOT_DERECHA: float = 90.0
const ANGULO_PIVOT_IZQUIERDA: float = -90.0
const VELOCIDAD_MINIMA_DESACELERACION: float = 0.15

const COLOR_TINTE_MORADO: Color = Color(0.78, 0.48, 0.95, 0.0)
const ALFA_TINTE_MAXIMO: float = 0.22
const TEXTO_PROMPT_DEFECTO: String = "[E] Hablar"
const ALTURA_DEFECTO_PROMPT: float = 1.25
const LINEAS_DIALOGO_DEFECTO: PackedStringArray = [
	"PIRATA_GOBLIN_PUEBLO_1",
	"PIRATA_GOBLIN_PUEBLO_2",
	"PIRATA_GOBLIN_PUEBLO_3"
]

# ─────────────────────────────────────────────
# 3. EXPORTS – Configuración Visual
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
# 4. EXPORTS – Patrulla y Recorrido
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
# 5. EXPORTS – Animación
# ─────────────────────────────────────────────
@export_category("Animación")
@export var anim_caminar: StringName = NOMBRE_ANIM_CAMINAR
@export_range(0.5, 2.0, 0.05) var velocidad_animacion: float = 1.0

# ─────────────────────────────────────────────
# 6. EXPORTS – Interacción y Diálogo
# ─────────────────────────────────────────────
@export_category("Interacción y Diálogo")
@export var dialogo_interactivo: bool = false:  ## Habilita detección de proximidad, tinte morado y diálogo con [E]
	set(valor):
		dialogo_interactivo = valor
		if is_inside_tree() and is_node_ready():
			_actualizar_configuracion_dialogo()

@export var radio_interaccion: float = 1.35  ## Distancia en metros para activar la proximidad y prompt
@export var duracion_vinetas: float = 6.0   ## Duración en segundos de cada viñeta antes de auto-avanzar (0 = solo manual)
## Claves de traducción (translations.csv); SpeechBubbleUI las resuelve con tr().
@export var lineas_dialogo: PackedStringArray = LINEAS_DIALOGO_DEFECTO

# ─────────────────────────────────────────────
# 7. VARIABLES PÚBLICAS (ESTADO NEUTRAL)
# ─────────────────────────────────────────────
var es_enemigo: bool = false  ## Flag explícito: es un NPC neutral pacífico, nunca enemigo
var es_neutral: bool = true   ## Flag de entidad neutral para sistemas de detección y combate

# ─────────────────────────────────────────────
# 8. VARIABLES PRIVADAS
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

var _jugador_cerca: bool = false
var _cerca_por_area: bool = false
var _dialogo_activo: bool = false
var _indice_dialogo: int = 0
var _estaba_caminando_antes_de_dialogo: bool = false
var _direccion_previa_dialogo: float = 1.0
var _angulo_pivot_previo_dialogo: float = 90.0
var _tween_giro_dialogo: Tween = null
var _tint_mat: StandardMaterial3D = null
var _tween_proximidad: Tween = null
var _jugador_ref: Node3D = null

# ─────────────────────────────────────────────
# 9. ONREADY
# ─────────────────────────────────────────────
@onready var prompt_hablar: Label3D = %PromptHablar if has_node("%PromptHablar") else null
@onready var speech_bubble: SpeechBubbleComponent = %SpeechBubbleComponent if has_node("%SpeechBubbleComponent") else null
@onready var area_interaccion: Area3D = %AreaInteraccion if has_node("%AreaInteraccion") else null

# ─────────────────────────────────────────────
# 10. BUILT-INS
# ─────────────────────────────────────────────
func _init() -> void:
	add_to_group("allies")
	add_to_group("npcs")
	add_to_group("neutral_npcs")


func _ready() -> void:
	add_to_group("allies")
	add_to_group("npcs")
	add_to_group("npc_dialogo")
	add_to_group("neutral_npcs")
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemigos"):
		remove_from_group("enemigos")

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

	if _es_dialogo_activo():
		_configurar_dialogo_interactivo()

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

	if _es_dialogo_activo():
		_procesar_proximidad_jugador(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _es_dialogo_activo() or not _jugador_cerca:
		return
	if not _dialogo_activo and _hay_otro_npc_hablando():
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E and not event.echo):
		_interactuar_o_avanzar_dialogo()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────
# 11. FUNCIONES PÚBLICAS
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
		if _direccion_actual > 0.0:
			_angulo_giro_destino = _angulo_giro_inicio + 180.0
		else:
			_angulo_giro_destino = _angulo_giro_inicio - 180.0

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


## Retorna si el diálogo interactivo está actualmente habilitado en este Pirata.
func es_dialogo_activo() -> bool:
	return _es_dialogo_activo()


## Retorna true si el jugador está actualmente dentro del radio de interacción.
func esta_jugador_cerca() -> bool:
	return _jugador_cerca


## Retorna true si una conversación está actualmente abierta.
func esta_hablando_dialogo() -> bool:
	return _dialogo_activo


## Retorna el índice actual de viñeta (0 = no iniciado, 1..3 = viñeta 1..3).
func obtener_indice_dialogo() -> int:
	return _indice_dialogo


## Simula o dispara la interacción del jugador (equivalente a presionar [E]).
func interactuar() -> void:
	_interactuar_o_avanzar_dialogo()


## Avanza forzadamente a la siguiente viñeta de diálogo.
func avanzar_dialogo() -> void:
	_avanzar_dialogo()


## Cierra el diálogo activo inmediatamente.
func cerrar_dialogo() -> void:
	_cerrar_dialogo()


## Permite simular o fijar programáticamente la proximidad del jugador (útil para tests y cinemáticas).
func fijar_jugador_cerca(cerca: bool) -> void:
	_cerca_por_area = cerca
	if _jugador_cerca != cerca:
		_jugador_cerca = cerca
		_on_proximidad_jugador_cambiada(cerca)


## Retorna el material de tinte morado utilizado en el overlay.
func obtener_material_tinte() -> StandardMaterial3D:
	return _tint_mat


## Retorna la referencia al nodo Label3D del prompt [E] Hablar.
func obtener_prompt_hablar() -> Label3D:
	return _obtener_prompt_hablar()


## Retorna la referencia al componente SpeechBubbleComponent.
func obtener_speech_bubble() -> SpeechBubbleComponent:
	return _obtener_speech_bubble()


## Retorna la dirección que el NPC seguía en su ruta antes de hablar.
func obtener_direccion_previa_dialogo() -> float:
	return _direccion_previa_dialogo


## Retorna el ángulo Y actual de rotación del Pivot visual.
func obtener_angulo_pivot() -> float:
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		return _pivot_visual.rotation_degrees.y
	return 0.0


## Orienta manualmente al NPC hacia la posición del jugador.
func orientar_hacia_jugador(animado: bool = true) -> void:
	_orientar_hacia_jugador(animado)


# ─────────────────────────────────────────────
# 12. FUNCIONES PRIVADAS
# ─────────────────────────────────────────────

func _procesar_caminata(delta: float) -> void:
	if _dialogo_activo:
		return

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
	if _dialogo_activo:
		return

	_configurar_pivot()

	if is_instance_valid(_pivot_visual) and tiempo_giro > 0.0:
		var progreso: float = clampf(_tiempo_en_estado / tiempo_giro, 0.0, 1.0)
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

	if ap.has_animation(NOMBRE_ANIM_IDLE):
		var clip_idle := ap.get_animation(NOMBRE_ANIM_IDLE)
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


func _material_sin_outline(mat: Material) -> Material:
	if mat is StandardMaterial3D and (mat as StandardMaterial3D).next_pass != null:
		var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		dup.next_pass = null
		return dup
	return mat


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


# ─────────────────────────────────────────────
# 13. SISTEMA DE DIÁLOGO E INTERACCIÓN
# ─────────────────────────────────────────────

func _es_dialogo_activo() -> bool:
	if dialogo_interactivo:
		return true
	var n: String = name.to_lower()
	return n.contains("texto") or n.contains("dialogo") or n.contains("interactivo") or n.contains("npc 1")


func _configurar_dialogo_interactivo() -> void:
	_configurar_tinte_morado()
	var prompt := _obtener_prompt_hablar()
	if is_instance_valid(prompt):
		prompt.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
	_obtener_speech_bubble()
	_configurar_area_interaccion()


func _actualizar_configuracion_dialogo() -> void:
	if _es_dialogo_activo():
		_configurar_dialogo_interactivo()
	else:
		if is_instance_valid(prompt_hablar):
			prompt_hablar.visible = false
		if is_instance_valid(speech_bubble):
			speech_bubble.ocultar()


func _configurar_tinte_morado() -> void:
	if _tint_mat:
		return
	_tint_mat = StandardMaterial3D.new()
	_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint_mat.albedo_color = COLOR_TINTE_MORADO
	_aplicar_tinte_recursivo(self)


func _aplicar_tinte_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		if not mi.name.to_lower().contains("bubble") and not mi.name.to_lower().contains("prompt"):
			mi.material_overlay = _tint_mat
	for hijo in nodo.get_children():
		_aplicar_tinte_recursivo(hijo)


func _obtener_prompt_hablar() -> Label3D:
	if is_instance_valid(prompt_hablar):
		return prompt_hablar
	prompt_hablar = get_node_or_null("%PromptHablar") as Label3D
	if not prompt_hablar:
		prompt_hablar = find_child("PromptHablar", true, false) as Label3D
	if not prompt_hablar and _es_dialogo_activo():
		_crear_prompt_hablar_dinamico()
	return prompt_hablar


func _crear_prompt_hablar_dinamico() -> void:
	if is_instance_valid(prompt_hablar):
		return
	var lbl := Label3D.new()
	lbl.name = "PromptHablar"
	lbl.transform.origin = Vector3(0.0, ALTURA_DEFECTO_PROMPT, 0.0)
	lbl.pixel_size = 0.0035
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.render_priority = 2
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 1.0, 1.0, 0.0)
	lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.0)
	lbl.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
	lbl.font_size = 22
	lbl.outline_size = 5
	lbl.visible = false
	add_child(lbl)
	prompt_hablar = lbl


func _obtener_speech_bubble() -> SpeechBubbleComponent:
	if is_instance_valid(speech_bubble):
		return speech_bubble
	speech_bubble = get_node_or_null("%SpeechBubbleComponent") as SpeechBubbleComponent
	if not speech_bubble:
		speech_bubble = find_child("SpeechBubbleComponent", true, false) as SpeechBubbleComponent
	if not speech_bubble and _es_dialogo_activo():
		_crear_speech_bubble_dinamico()
	return speech_bubble


func _crear_speech_bubble_dinamico() -> void:
	if is_instance_valid(speech_bubble):
		return
	var sb := SpeechBubbleComponent.new()
	sb.name = "SpeechBubbleComponent"
	sb.offset_cabeza = Vector3(0.0, ALTURA_DEFECTO_PROMPT, 0.0)
	add_child(sb)
	speech_bubble = sb
	sb.dialogo_terminado.connect(_on_speech_bubble_dialogo_terminado)


func _configurar_area_interaccion() -> void:
	var area := get_node_or_null("%AreaInteraccion") as Area3D
	if not area:
		area = find_child("AreaInteraccion", true, false) as Area3D
	if not area:
		area = Area3D.new()
		area.name = "AreaInteraccion"
		area.collision_layer = 0
		area.collision_mask = 3
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := SphereShape3D.new()
		shape.radius = radio_interaccion
		col.shape = shape
		col.position.y = 0.5
		area.add_child(col)
		add_child(area)
	area_interaccion = area

	if not area.body_entered.is_connected(_on_body_entered_interaccion):
		area.body_entered.connect(_on_body_entered_interaccion)
	if not area.body_exited.is_connected(_on_body_exited_interaccion):
		area.body_exited.connect(_on_body_exited_interaccion)


func _on_body_entered_interaccion(body: Node3D) -> void:
	if not _es_dialogo_activo():
		return
	if body.is_in_group("player") or body.is_in_group("player_interior") or body is CharacterBody3D:
		_cerca_por_area = true


func _on_body_exited_interaccion(body: Node3D) -> void:
	if not _es_dialogo_activo():
		return
	if body.is_in_group("player") or body.is_in_group("player_interior") or body is CharacterBody3D:
		_cerca_por_area = false


func _obtener_jugador() -> Node3D:
	if is_instance_valid(_jugador_ref):
		return _jugador_ref
	var arbol := get_tree()
	if arbol == null:
		return null
	var j := arbol.get_first_node_in_group("player") as Node3D
	if not is_instance_valid(j):
		j = arbol.get_first_node_in_group("player_interior") as Node3D
	_jugador_ref = j
	return _jugador_ref


func _procesar_proximidad_jugador(_delta: float) -> void:
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return
	var dist: float = global_position.distance_to(jugador.global_position)
	var cerca_fisica: bool = (dist <= radio_interaccion) or _cerca_por_area
	# Solo el NPC en conversación permanece morado.
	var cerca: bool = cerca_fisica
	if not _dialogo_activo and cerca_fisica and _hay_otro_npc_hablando():
		cerca = false

	if cerca != _jugador_cerca:
		_jugador_cerca = cerca
		_on_proximidad_jugador_cambiada(cerca)


func _on_proximidad_jugador_cambiada(cerca: bool) -> void:
	_jugador_cerca = cerca
	proximidad_jugador_cambiada.emit(cerca)
	_animar_proximidad(cerca)
	if not cerca:
		if _dialogo_activo:
			_cerrar_dialogo()


func _animar_proximidad(activo: bool) -> void:
	if _tween_proximidad and _tween_proximidad.is_valid():
		_tween_proximidad.kill()

	_tween_proximidad = create_tween().set_parallel(true)
	var duracion: float = 0.3 if activo else 0.25
	var target_alpha_tint: float = ALFA_TINTE_MAXIMO if activo else 0.0
	var target_alpha_prompt: float = 1.0 if activo else 0.0

	var prompt := _obtener_prompt_hablar()
	if prompt and is_instance_valid(prompt):
		if activo and not _dialogo_activo:
			prompt.visible = true
		var alfa_final_prompt: float = 0.0 if _dialogo_activo else target_alpha_prompt
		_tween_proximidad.tween_property(prompt, "modulate:a", alfa_final_prompt, duracion).set_trans(Tween.TRANS_SINE)
		_tween_proximidad.tween_property(prompt, "outline_modulate:a", alfa_final_prompt, duracion).set_trans(Tween.TRANS_SINE)
		if not activo:
			_tween_proximidad.chain().tween_callback(func() -> void:
				if not _jugador_cerca and is_instance_valid(prompt):
					prompt.visible = false
			)

	if _tint_mat == null:
		_configurar_tinte_morado()

	if _tint_mat:
		_tween_proximidad.tween_method(
			func(alpha: float) -> void:
				if _tint_mat:
					_tint_mat.albedo_color = Color(COLOR_TINTE_MORADO.r, COLOR_TINTE_MORADO.g, COLOR_TINTE_MORADO.b, alpha),
			_tint_mat.albedo_color.a,
			target_alpha_tint,
			duracion
		).set_trans(Tween.TRANS_SINE)


func _interactuar_o_avanzar_dialogo() -> void:
	if not _es_dialogo_activo() or not _jugador_cerca:
		return
	if not _dialogo_activo and _hay_otro_npc_hablando():
		return

	if not _dialogo_activo:
		_iniciar_dialogo()
	else:
		_avanzar_dialogo()


func _girar_hacia_direccion_x(dir_x: float, animado: bool = true) -> void:
	var angulo_objetivo: float = ANGULO_PIVOT_DERECHA if dir_x > 0.0 else ANGULO_PIVOT_IZQUIERDA
	_girar_hacia_angulo(angulo_objetivo, animado)


func _girar_hacia_angulo(angulo_objetivo: float, animado: bool = true) -> void:
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return

	if _tween_giro_dialogo and _tween_giro_dialogo.is_valid():
		_tween_giro_dialogo.kill()

	var angulo_act_rad: float = deg_to_rad(_pivot_visual.rotation_degrees.y)
	var angulo_obj_rad: float = deg_to_rad(angulo_objetivo)
	var diff_rad: float = wrapf(angulo_obj_rad - angulo_act_rad, -PI, PI)
	var angulo_final: float = _pivot_visual.rotation_degrees.y + rad_to_deg(diff_rad)

	if not animado or not is_inside_tree():
		_pivot_visual.rotation_degrees.y = angulo_final
		return

	_tween_giro_dialogo = create_tween()
	_tween_giro_dialogo.tween_property(_pivot_visual, "rotation_degrees:y", angulo_final, 0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _orientar_hacia_jugador(animado: bool = true) -> void:
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return

	var dir_local: Vector3 = to_local(jugador.global_position)
	dir_local.y = 0.0
	if dir_local.length_squared() < 0.001:
		return

	var angulo_objetivo: float = rad_to_deg(atan2(dir_local.x, dir_local.z))
	_girar_hacia_angulo(angulo_objetivo, animado)


func _reproducir_animacion_idle() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	if ap.has_animation(NOMBRE_ANIM_IDLE):
		var clip := ap.get_animation(NOMBRE_ANIM_IDLE)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = 1.0
		ap.play(NOMBRE_ANIM_IDLE, 0.2)


func _iniciar_dialogo() -> void:
	if lineas_dialogo.is_empty():
		return
	if _hay_otro_npc_hablando():
		return

	_dialogo_activo = true
	_apagar_resaltado_otros_npcs()
	_indice_dialogo = 0

	_direccion_previa_dialogo = _direccion_actual
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		_angulo_pivot_previo_dialogo = _pivot_visual.rotation_degrees.y
	else:
		_angulo_pivot_previo_dialogo = ANGULO_PIVOT_DERECHA if _direccion_actual > 0.0 else ANGULO_PIVOT_IZQUIERDA

	if _estado_actual == Estado.CAMINANDO or _estado_actual == Estado.GIRANDO:
		_estaba_caminando_antes_de_dialogo = true
		_velocidad_actual = 0.0
	else:
		_estaba_caminando_antes_de_dialogo = false

	_orientar_hacia_jugador(true)
	_reproducir_animacion_idle()

	var prompt := _obtener_prompt_hablar()
	if prompt and is_instance_valid(prompt):
		prompt.visible = false
		prompt.modulate.a = 0.0
		prompt.outline_modulate.a = 0.0

	_avanzar_dialogo()


func _avanzar_dialogo() -> void:
	var sb := _obtener_speech_bubble()
	if not sb:
		return

	_orientar_hacia_jugador(true)
	_reproducir_animacion_idle()

	if _indice_dialogo < lineas_dialogo.size():
		var texto_linea: String = lineas_dialogo[_indice_dialogo]
		var idx_actual: int = _indice_dialogo
		_indice_dialogo += 1
		sb.decir(texto_linea, duracion_vinetas)
		if idx_actual == 0:
			dialogo_iniciado.emit(texto_linea)
		else:
			dialogo_avanzado.emit(_indice_dialogo, texto_linea)
	else:
		_cerrar_dialogo()


func _cerrar_dialogo() -> void:
	if not _dialogo_activo and _indice_dialogo == 0:
		return

	_dialogo_activo = false
	_indice_dialogo = 0

	var sb := _obtener_speech_bubble()
	if sb and is_instance_valid(sb):
		sb.ocultar()

	dialogo_terminado.emit()

	if _jugador_cerca:
		var prompt := _obtener_prompt_hablar()
		if prompt and is_instance_valid(prompt):
			prompt.visible = true
			var tween := create_tween().set_parallel(true)
			tween.tween_property(prompt, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
			tween.tween_property(prompt, "outline_modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

	# Restaurar orientación y animación previa al diálogo
	if _estaba_caminando_antes_de_dialogo:
		_direccion_actual = _direccion_previa_dialogo
		_velocidad_actual = velocidad_caminar
		_cambiar_estado(Estado.CAMINANDO)
		var ap := _obtener_animation_player()
		if ap and ap.has_animation(anim_caminar):
			ap.play(anim_caminar, 0.2)
		_girar_hacia_direccion_x(_direccion_actual, true)
	else:
		_girar_hacia_angulo(_angulo_pivot_previo_dialogo, true)


func _on_speech_bubble_dialogo_terminado() -> void:
	if not _dialogo_activo:
		return
	if _indice_dialogo >= lineas_dialogo.size():
		_cerrar_dialogo()
	else:
		_avanzar_dialogo()


## True si algún otro NPC del grupo está actualmente en conversación.
## Solo el NPC en conversación debe permanecer morado.
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


## Apaga el resaltado de los demás NPCs al iniciar este diálogo.
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
func _forzar_apagado_proximidad() -> void:
	if _dialogo_activo:
		return
	_jugador_cerca = false
	_animar_proximidad(false)
