@tool
class_name HombrePez
extends Node3D

## NPC Hombre Pez en el nivel pueblo (y ambiente general).
## Aplica material con textura a sus mallas, gestiona capa visual (capa 1 frente, capa 2 fondo),
## implementa animación procedural de respiración sutil y sistema de interacción de diálogo:
## iluminación con overlay morado al acercarse, prompt "[E] Hablar", viñetas de diálogo con
## SpeechBubbleComponent, giro suave hacia el jugador y retorno a su orientación original al terminar.

# ─────────────────────────────────────────────────────────────────────────────
# SEÑALES
# ─────────────────────────────────────────────────────────────────────────────
signal dialogo_iniciado(linea: String)
signal dialogo_avanzado(indice: int, linea: String)
signal dialogo_terminado
signal proximidad_jugador_cambiada(cerca: bool)

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTES
# ─────────────────────────────────────────────────────────────────────────────
const INDICE_SUPERFICIE_PRINCIPAL: int = 0
const EXPONENTE_CURVA_RESPIRACION: float = 1.3

const COLOR_TINTE_MORADO: Color = Color(0.78, 0.48, 0.95, 0.0)
const ALFA_TINTE_MAXIMO: float = 0.22
const TEXTO_PROMPT_DEFECTO: String = "[E] Hablar"
const ALTURA_DEFECTO_PROMPT: float = 0.95
const OFFSET_CABEZA_DEFECTO: Vector3 = Vector3(0.0, 0.85, 0.0)
const LINEAS_DIALOGO_DEFECTO: PackedStringArray = [
	"HOMBREPEZ_PUEBLO_1",
	"HOMBREPEZ_PUEBLO_2"
]

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────
@export_category("Configuración Visual")
@export var material_hombre_pez: StandardMaterial3D:
	set(nuevo_material):
		material_hombre_pez = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		if is_node_ready():
			_aplicar_capa_visual(self)

@export_group("Animación Respiración")
@export var habilitar_respiracion: bool = true:
	set(valor):
		habilitar_respiracion = valor
		if not habilitar_respiracion and is_instance_valid(modelo):
			modelo.scale = Vector3.ONE

@export var velocidad_respiracion: float = 2.0  ## Ciclo de respiración en radianes/segundo (~3.1s por ciclo)
@export var amplitud_estiramiento_y: float = 0.035  ## Estiramiento sutil vertical de la parte superior (3.5%)
@export var amplitud_expansion_xz: float = 0.015  ## Expansión sutil del torso/pecho (1.5%)
@export var previsualizar_en_editor: bool = true  ## Si es true, la respiración se visualiza también en el editor

@export_category("Interacción y Diálogo")
@export var dialogo_interactivo: bool = true:  ## Habilita detección de proximidad, tinte morado y diálogo con [E]
	set(valor):
		dialogo_interactivo = valor
		if is_inside_tree() and is_node_ready():
			_actualizar_configuracion_dialogo()

@export var radio_interaccion: float = 1.6  ## Distancia horizontal en X para activar (estar frente al NPC)
@export var distancia_max_z: float = 4.0  ## Tolerancia de profundidad Z entre planos 2.5D
@export var tolerancia_y: float = 2.5  ## Tolerancia vertical en Y
@export var duracion_vinetas: float = 6.0  ## Duración en segundos de cada viñeta antes de auto-avanzar (0 = solo manual)
## Claves de traducción (translations.csv); SpeechBubbleUI las resuelve con tr().
@export var lineas_dialogo: PackedStringArray = LINEAS_DIALOGO_DEFECTO

# ─────────────────────────────────────────────────────────────────────────────
# VARIABLES PRIVADAS
# ─────────────────────────────────────────────────────────────────────────────
var _tiempo_respiracion: float = 0.0

var _jugador_cerca: bool = false
var _cerca_por_area: bool = false
var _dialogo_activo: bool = false
var _indice_dialogo: int = 0
var _rotacion_y_base_modelo: float = 0.0
var _tint_mat: StandardMaterial3D = null
var _tween_proximidad: Tween = null
var _jugador_ref: Node3D = null

# ─────────────────────────────────────────────────────────────────────────────
# ONREADY
# ─────────────────────────────────────────────────────────────────────────────
@onready var modelo: Node3D = $Model if has_node("Model") else null
@onready var prompt_hablar: Label3D = %PromptHablar if has_node("%PromptHablar") else null
@onready var speech_bubble: SpeechBubbleComponent = %SpeechBubbleComponent if has_node("%SpeechBubbleComponent") else null
@onready var area_interaccion: Area3D = %AreaInteraccion if has_node("%AreaInteraccion") else null

# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES BUILT-IN
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("npcs")
	add_to_group("npc_dialogo")
	if "fondo" in name.to_lower():
		capa_visual = 2
	_aplicar_material()
	_aplicar_capa_visual(self)
	_capturar_rotacion_base()
	_actualizar_configuracion_dialogo()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not previsualizar_en_editor:
		return

	if not Engine.is_editor_hint() and _es_dialogo_activo():
		_procesar_proximidad_jugador(delta)

	if not habilitar_respiracion or not is_instance_valid(modelo):
		return

	_actualizar_respiracion(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _es_dialogo_activo() or not _jugador_cerca:
		return
	if not _dialogo_activo and _hay_otro_npc_hablando():
		return

	var es_tecla_e: bool = (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_ENTER))
	var es_accion_interact: bool = event.is_action_pressed("interact") if InputMap.has_action("interact") else false
	if es_tecla_e or es_accion_interact:
		_interactuar_o_avanzar_dialogo()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES PÚBLICAS
# ─────────────────────────────────────────────────────────────────────────────
## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


## Resetea la escala del modelo al valor neutro.
func reiniciar_respiracion() -> void:
	_tiempo_respiracion = 0.0
	if is_instance_valid(modelo):
		modelo.scale = Vector3.ONE


## Dispara la interacción o avanza a la siguiente viñeta de diálogo.
func interactuar() -> void:
	_interactuar_o_avanzar_dialogo()


## Avanza explícitamente a la siguiente viñeta.
func avanzar_dialogo() -> void:
	_avanzar_dialogo()


## Cierra el diálogo activo inmediatamente.
func cerrar_dialogo() -> void:
	_cerrar_dialogo()


## Retorna true si actualmente está desplegando diálogo.
func esta_hablando_dialogo() -> bool:
	return _dialogo_activo


## Retorna true si el sistema interactivo de diálogo está habilitado.
func es_dialogo_activo() -> bool:
	return _es_dialogo_activo()


## Retorna true si el jugador se encuentra dentro del rango de interacción.
func esta_jugador_cerca() -> bool:
	return _jugador_cerca


## Retorna el índice de viñeta actual (0 si cerrado, 1 para la primera, etc.).
func obtener_indice_dialogo() -> int:
	return _indice_dialogo


## Retorna el material de tinte morado utilizado en el overlay.
func obtener_material_tinte() -> StandardMaterial3D:
	return _tint_mat


## Retorna la referencia al nodo Label3D del prompt [E] Hablar.
func obtener_prompt_hablar() -> Label3D:
	return _obtener_prompt_hablar()


## Retorna la referencia al componente SpeechBubbleComponent.
func obtener_speech_bubble() -> SpeechBubbleComponent:
	return _obtener_speech_bubble()


## Retorna el ángulo Y base de rotación del modelo.
func obtener_rotacion_base_modelo() -> float:
	return _rotacion_y_base_modelo


## Retorna el ángulo Y actual de rotación del modelo.
func obtener_angulo_actual_modelo() -> float:
	if is_instance_valid(modelo):
		return modelo.rotation_degrees.y
	return 0.0


## HombrePez mantiene su orientación original fija y no realiza giros.
func orientar_hacia_jugador(_animado: bool = true) -> void:
	pass


## Permite simular o fijar programáticamente la proximidad del jugador (tests/cinemáticas).
func fijar_jugador_cerca(cerca: bool) -> void:
	_cerca_por_area = cerca
	if _jugador_cerca != cerca:
		_jugador_cerca = cerca
		_on_proximidad_jugador_cambiada(cerca)


# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES PRIVADAS – RESPIRACIÓN Y VISUALES
# ─────────────────────────────────────────────────────────────────────────────
func _actualizar_respiracion(delta: float) -> void:
	_tiempo_respiracion += delta
	var onda_seno: float = sin(_tiempo_respiracion * velocidad_respiracion)
	var curva: float = pow(0.5 + 0.5 * onda_seno, EXPONENTE_CURVA_RESPIRACION)
	
	var escala_y: float = 1.0 + curva * amplitud_estiramiento_y
	var escala_xz: float = 1.0 + curva * amplitud_expansion_xz
	modelo.scale = Vector3(escala_xz, escala_y, escala_xz)


func _capturar_rotacion_base() -> void:
	if is_instance_valid(modelo):
		_rotacion_y_base_modelo = modelo.rotation_degrees.y


func _aplicar_material() -> void:
	if material_hombre_pez == null:
		return
	var raiz_modelo: Node = modelo
	if not is_instance_valid(raiz_modelo):
		raiz_modelo = find_child("Model", true, false)
		if raiz_modelo == null:
			return
	_aplicar_a_instancias(raiz_modelo)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var malla_instancia: MeshInstance3D = nodo as MeshInstance3D
		malla_instancia.material_override = material_hombre_pez
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_hombre_pez)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


func _aplicar_capa_visual(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual(hijo)


# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES PRIVADAS – DIÁLOGO E INTERACCIÓN
# ─────────────────────────────────────────────────────────────────────────────
func _es_dialogo_activo() -> bool:
	return dialogo_interactivo


func _actualizar_configuracion_dialogo() -> void:
	if _es_dialogo_activo():
		_configurar_dialogo_interactivo()
	else:
		_desactivar_dialogo_interactivo()


func _desactivar_dialogo_interactivo() -> void:
	if _dialogo_activo:
		_cerrar_dialogo()
	if _jugador_cerca:
		_jugador_cerca = false
		_animar_proximidad(false)
	var prompt := _obtener_prompt_hablar()
	if is_instance_valid(prompt):
		prompt.visible = false


func _configurar_dialogo_interactivo() -> void:
	_configurar_tinte_morado()
	var prompt := _obtener_prompt_hablar()
	if is_instance_valid(prompt):
		prompt.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
	_obtener_speech_bubble()
	_asegurar_area_interaccion()


func _configurar_tinte_morado() -> void:
	if _tint_mat == null:
		_tint_mat = StandardMaterial3D.new()
		_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_mat.albedo_color = COLOR_TINTE_MORADO
		_tint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX

	var raiz: Node = modelo if is_instance_valid(modelo) else self
	var mallas := raiz.find_children("*", "MeshInstance3D", true, false)
	for m in mallas:
		var mi := m as MeshInstance3D
		if mi:
			mi.material_overlay = _tint_mat


func _obtener_prompt_hablar() -> Label3D:
	if is_instance_valid(prompt_hablar):
		return prompt_hablar
	prompt_hablar = get_node_or_null("PromptHablar") as Label3D
	if not prompt_hablar:
		prompt_hablar = Label3D.new()
		prompt_hablar.name = "PromptHablar"
		prompt_hablar.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
		prompt_hablar.pixel_size = 0.0035
		prompt_hablar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		prompt_hablar.render_priority = 2
		prompt_hablar.no_depth_test = true
		prompt_hablar.modulate = Color(1.0, 1.0, 1.0, 0.0)
		prompt_hablar.outline_modulate = Color(0.05, 0.05, 0.08, 0.0)
		prompt_hablar.font_size = 22
		prompt_hablar.outline_size = 5
		prompt_hablar.position = Vector3(0.0, ALTURA_DEFECTO_PROMPT, 0.0)
		add_child(prompt_hablar)
	return prompt_hablar


func _obtener_speech_bubble() -> SpeechBubbleComponent:
	if is_instance_valid(speech_bubble):
		return speech_bubble
	speech_bubble = get_node_or_null("SpeechBubbleComponent") as SpeechBubbleComponent
	if not speech_bubble:
		speech_bubble = SpeechBubbleComponent.new()
		speech_bubble.name = "SpeechBubbleComponent"
		speech_bubble.offset_cabeza = OFFSET_CABEZA_DEFECTO
		add_child(speech_bubble)
	if not speech_bubble.dialogo_terminado.is_connected(_on_speech_bubble_dialogo_terminado):
		speech_bubble.dialogo_terminado.connect(_on_speech_bubble_dialogo_terminado)
	return speech_bubble


func _asegurar_area_interaccion() -> void:
	if is_instance_valid(area_interaccion):
		return
	var area := get_node_or_null("AreaInteraccion") as Area3D
	if not area:
		area = Area3D.new()
		area.name = "AreaInteraccion"
		area.collision_layer = 0
		area.collision_mask = 3
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(6.0, 3.0, 6.0)
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
	var diff_x: float = absf(global_position.x - jugador.global_position.x)
	var diff_y: float = absf(global_position.y - jugador.global_position.y)
	var diff_z: float = absf(global_position.z - jugador.global_position.z)

	var cerca_fisica: bool = (diff_x <= radio_interaccion and diff_y <= tolerancia_y and diff_z <= distancia_max_z) or _cerca_por_area
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


func _iniciar_dialogo() -> void:
	if lineas_dialogo.is_empty():
		return
	if _hay_otro_npc_hablando():
		return

	_dialogo_activo = true
	_apagar_resaltado_otros_npcs()
	_indice_dialogo = 0

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
