@tool
class_name OrcoCerdo
extends Node3D

## NPC Neutral Orco Cerdo: Patrulla una distancia configurable caminando
## con la animación 'Caminar con lanza'. Al alcanzar el límite del recorrido,
## desacelera suavemente, rota 180 grados de forma orgánica en el Pivot
## manteniendo la marcha activa, cambia de sentido y retoma el avance
## con aceleración progresiva en un ciclo continuo sin fin.
## Porta una Lanza Orco equipada en su mano derecha (mixamorig_RightHand).

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
const POSE_RESPIRACION: String = "Respiracion"
const POSE_SECRETO: String = "Secreto"

enum Estado {
	CAMINANDO,
	GIRANDO,
	ESTATICO,
}

enum Direccion {
	DERECHA = 1,
	IZQUIERDA = -1,
}

const MATERIAL_DEFECTO: StandardMaterial3D = preload("res://Entities/NPC_OrcoCerdo/OrcoCerdo_Mat.tres")
const ESCENA_LANZA: PackedScene = preload("res://Entities/NPC_OrcoCerdo/LanzaOrco.tscn")
const NOMBRE_ANIM_CAMINAR: StringName = &"Caminar con lanza"
const HUESO_MANO_DERECHA: String = "mixamorig_RightHand"
const ANGULO_PIVOT_DERECHA: float = 90.0
const ANGULO_PIVOT_IZQUIERDA: float = -90.0
const VELOCIDAD_MINIMA_DESACELERACION: float = 0.2

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
# EXPORTS – Patrulla y Recorrido
# ─────────────────────────────────────────────
@export_category("Patrulla y Recorrido")
@export var estatico: bool = false:  ## Si está activo, detiene la patrulla y ejecuta la pose estática configurada (ej. 'Secreto')
	set(valor):
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
@export_range(0.1, 1.5, 0.05) var tiempo_transicion: float = 0.3  ## Tiempo de crossfade al iniciar animación
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
@export_enum("Respiracion", "Secreto", "Idle desarmado", "Idle ballesta", "Baile") var pose_estatica: String = POSE_RESPIRACION:  ## Pose o animación cuando el Orco Cerdo está estático (ej. 'Secreto')
	set(nueva_pose):
		pose_estatica = nueva_pose
		pose_estatica_cambiada.emit(pose_estatica)
		if estatico:
			_actualizar_modo_estatico()

@export_range(0.1, 2.0, 0.05) var velocidad_anim_pose: float = 1.0:  ## Velocidad de reproducción para la pose animada
	set(valor):
		velocidad_anim_pose = maxf(valor, 0.05)
		_aplicar_velocidad_animacion()

@export_group("Respiración Procedural", "respiracion_")
@export_range(0.5, 4.0, 0.1) var respiracion_velocidad: float = 1.8  ## Velocidad del ciclo de respiración (rad/s)
@export_range(0.005, 0.08, 0.005) var respiracion_intensidad: float = 0.02  ## Intensidad de la deformación sutil de respiración (2%)
@export_group("")

# ─────────────────────────────────────────────
# EXPORTS – Lanza Mano Derecha
# ─────────────────────────────────────────────
@export_category("Lanza Mano Derecha")
@export var equipar_lanza: bool = true:
	set(valor):
		equipar_lanza = valor
		if is_node_ready():
			_configurar_lanza()

# ─────────────────────────────────────────────
# EXPORTS – Nombres de Animaciones
# ─────────────────────────────────────────────
@export_category("Animación")
@export var anim_caminar: StringName = NOMBRE_ANIM_CAMINAR

# ─────────────────────────────────────────────
# EXPORTS – Previsualización en Editor
# ─────────────────────────────────────────────
@export_category("Previsualización en Editor")
@export_enum("Ninguna", "Caminar con lanza", "Secreto", "Idle desarmado", "Idle ballesta", "Baile", "Ataque lanza") var previsualizar_animacion: String = "Ninguna":
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
var _bone_attachment: BoneAttachment3D = null
var _instancia_lanza: Node3D = null
var _nodo_modelo_ref: Node3D = null
var _tiempo_respiracion: float = 0.0
var _escala_base_modelo: Vector3 = Vector3.ONE

# ─────────────────────────────────────────────
# BUILT-INS
# ─────────────────────────────────────────────
func _ready() -> void:
	_velocidad_actual = velocidad_caminar
	_configurar_pivot()
	_capturar_escala_base()
	_aplicar_material()
	_aplicar_capa_visual()
	_configurar_lanza()
	_inicializar_animator()
	
	_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
	_actualizar_orientacion_visual()
	
	if Engine.is_editor_hint():
		_actualizar_previsualizacion_editor()
		if estatico:
			_actualizar_modo_estatico()
		return
	
	if estatico:
		pausar()
	else:
		iniciar_caminata()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _activo:
		return
	
	if estatico:
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
	if ap and ap.has_animation(anim_caminar):
		var clip := ap.get_animation(anim_caminar)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if ap.current_animation != anim_caminar or not ap.is_playing():
			ap.play(anim_caminar, 0.3)
		animacion_cambiada.emit(anim_caminar)


## Inicia la rotación de 180 grados del Pivot al alcanzar el límite manteniendo la caminata.
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

	# Mantener 'Caminar con lanza' activa sin cambiar a ninguna animación torcida
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


## Retorna la instancia de la lanza acoplada, si existe.
func obtener_lanza() -> Node3D:
	if not is_instance_valid(_instancia_lanza):
		_instancia_lanza = find_child("LanzaOrco", true, false) as Node3D
	return _instancia_lanza


## Pausa la patrulla y deja al Orco Cerdo en modo estático con respiración sutil.
func pausar() -> void:
	estatico = true
	_actualizar_modo_estatico()


## Reanuda la patrulla y caminata del Orco Cerdo.
func reanudar() -> void:
	estatico = false
	_actualizar_modo_estatico()


## Retorna true si el Orco Cerdo está actualmente en modo estático.
func esta_estatico() -> bool:
	return estatico


## Permite cambiar la pose estática activa del Orco Cerdo (ej. 'Secreto', 'Respiracion').
func cambiar_pose_estatica(nueva_pose: String) -> void:
	pose_estatica = nueva_pose


## Retorna la pose estática configurada actualmente.
func obtener_pose_estatica() -> String:
	return pose_estatica


## Aplica manualmente el material configurado a las mallas del Orco.
func aplicar_material() -> void:
	_aplicar_material()


## Permite posar al Orco Cerdo en cualquier ángulo de 360 grados.
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


# ─────────────────────────────────────────────
# FUNCIONES PRIVADAS
# ─────────────────────────────────────────────

func _procesar_caminata(delta: float) -> void:
	var distancia_restante: float = distancia_recorrido - _distancia_acumulada

	# Gestionar desaceleración suave al aproximarse al final del recorrido
	if distancia_restante <= distancia_desaceleracion:
		var factor_freno: float = clampf(distancia_restante / maxf(distancia_desaceleracion, 0.01), 0.0, 1.0)
		var vel_deseada: float = lerpf(VELOCIDAD_MINIMA_DESACELERACION, velocidad_caminar, factor_freno)
		_velocidad_actual = move_toward(_velocidad_actual, vel_deseada, (velocidad_caminar / 0.4) * delta)
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

	var anim_secreto := _resolver_nombre_animacion_pose(POSE_SECRETO)
	if not anim_secreto.is_empty() and ap.has_animation(anim_secreto):
		var clip_secreto := ap.get_animation(anim_secreto)
		if clip_secreto:
			clip_secreto.loop_mode = Animation.LOOP_LINEAR


func _configurar_lanza() -> void:
	_instancia_lanza = find_child("LanzaOrco", true, false) as Node3D
	
	if not equipar_lanza:
		if is_instance_valid(_instancia_lanza):
			_instancia_lanza.visible = false
		return
	
	# Si la lanza ya existe en la escena (.tscn editable), respetarla y activarla
	if is_instance_valid(_instancia_lanza):
		_instancia_lanza.visible = true
		return
	
	# Si no existe en la escena, crearla dinámicamente en el hueso de la mano derecha
	var skel: Skeleton3D = _obtener_skeleton()
	if not skel:
		return
	
	var bone_idx: int = skel.find_bone(HUESO_MANO_DERECHA)
	if bone_idx == -1:
		return
	
	var attachments := skel.find_children("*", "BoneAttachment3D", false, false)
	for att in attachments:
		var ba := att as BoneAttachment3D
		if ba and ba.bone_name == HUESO_MANO_DERECHA:
			_bone_attachment = ba
			break
			
	if not is_instance_valid(_bone_attachment):
		_bone_attachment = BoneAttachment3D.new()
		_bone_attachment.name = "BoneAttachment_ManoDerecha"
		_bone_attachment.bone_name = HUESO_MANO_DERECHA
		_bone_attachment.bone_idx = bone_idx
		skel.add_child(_bone_attachment)
	
	if ESCENA_LANZA:
		_instancia_lanza = ESCENA_LANZA.instantiate() as Node3D
		_instancia_lanza.name = "LanzaOrco"
		_bone_attachment.add_child(_instancia_lanza)


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
	var skel := _obtener_skeleton()
	if skel:
		for c in skel.get_children():
			if c is MeshInstance3D:
				var mi := c as MeshInstance3D
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


func _actualizar_modo_estatico() -> void:
	if not is_inside_tree() and not is_node_ready():
		return
	
	if estatico:
		_cambiar_estado(Estado.ESTATICO)
		_velocidad_actual = 0.0
		var ap := _obtener_animation_player()
		var anim_pose := _resolver_nombre_animacion_pose(pose_estatica)
		if ap and not anim_pose.is_empty() and pose_estatica.to_lower() != "respiracion":
			_restaurar_transform_modelo()
			ap.speed_scale = velocidad_anim_pose
			var clip := ap.get_animation(anim_pose)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
			if ap.current_animation != anim_pose or not ap.is_playing():
				ap.play(anim_pose, tiempo_transicion)
			animacion_cambiada.emit(anim_pose)
		else:
			if ap:
				ap.stop()
	else:
		_restaurar_transform_modelo()
		if not Engine.is_editor_hint():
			iniciar_caminata()


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
	
	# Deformación sutil de respiración orgánica:
	# El eje Y (pecho vertical y elevación de hombros) se expande con la inhalación (+respiracion_intensidad)
	# Los ejes Z (profundidad torácica) y X (ancho) acompañan proporcionalmente
	var factor_y: float = 1.0 + (onda * respiracion_intensidad)
	var factor_z: float = 1.0 + (onda * respiracion_intensidad * 0.8)
	var factor_x: float = 1.0 + (onda * respiracion_intensidad * 0.4)
	
	nodo_modelo.scale = Vector3(
		_escala_base_modelo.x * factor_x,
		_escala_base_modelo.y * factor_y,
		_escala_base_modelo.z * factor_z
	)


func _actualizar_previsualizacion_editor() -> void:
	if not Engine.is_editor_hint():
		return
	var ap := _obtener_animation_player()
	if not ap:
		return
	if previsualizar_animacion == "Ninguna" or previsualizar_animacion.is_empty():
		if not estatico:
			ap.stop()
		return
	var anim_nombre := _resolver_nombre_animacion_pose(previsualizar_animacion)
	if not anim_nombre.is_empty() and ap.has_animation(anim_nombre):
		var clip := ap.get_animation(anim_nombre)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if anim_nombre == anim_caminar:
			ap.speed_scale = 1.0
		else:
			ap.speed_scale = velocidad_anim_pose
		ap.play(anim_nombre)


func _aplicar_velocidad_animacion() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	if ap.current_animation == anim_caminar or (Engine.is_editor_hint() and previsualizar_animacion == anim_caminar):
		ap.speed_scale = 1.0
	else:
		ap.speed_scale = velocidad_anim_pose


func _resolver_nombre_animacion_pose(pose: String) -> StringName:
	var ap := _obtener_animation_player()
	if not ap:
		return StringName()
	if ap.has_animation(pose):
		return StringName(pose)
	for anim in ap.get_animation_list():
		if anim.to_lower() == pose.to_lower():
			return StringName(anim)
	return StringName()

