class_name CinematicaOleada5
extends Node

## Cinemática al completar la oleada 5 de NIVEL01 (isla "Paso de Medea").
## Sustituye la cortinilla negra de continuar:
## 1. La cámara arranca directamente en el plano cercano de la isla (sin
##    travelling de entrada): Perrena aparece ya grande en pantalla.
## 2. Perrena aparece corriendo desde la derecha (humo de pisadas estilo
##    defensoras ballesteras) y se detiene a mitad de isla.
## 3. Sigue caminando (animación Caminar) hasta el límite de la isla, el punto
##    donde se detiene el imp embajador (x = FINAL_X).
## 4. La protagonista queda situada en el segundo piso, delante del escudo
##    (no sobre la escalera).
## Sin input: el jugador y el botón de cambio de personaje se bloquean al
## empezar y se liberan al terminar, cuando se invoca la continuación (flujo
## normal a oleada 6).
## Perrena ÚNICA: si ya existe una en escena (p. ej. el jugador la controla)
## se reutiliza en vez de instanciar otra; al terminar se le devuelve el
## control intacto. Con el mismo tamaño que la controlable (copia su escala).
## A prueba de fallos: cualquier referencia ausente aborta a la continuación
## sin colgar el juego. Sin temporizadores: todo avanza en _process (pausa
## segura) con posiciones relativas a los valores base (sin absolutos).

enum Fase { CORRER, PAUSA, CAMINAR, DIALOGO, FIN }

const ESCENA_PERRENA: PackedScene = preload("res://Entities/Jugador_Perrena/Perrena.tscn")
const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
## Escena de diálogo al llegar al límite (estilo intro, con el png de Eryn).
const ESCENA_DIALOGO: PackedScene = preload("res://UI/DialogoConversacionNivel5.tscn")
const RUTA_JINGLE: String = "res://TEST_/Perrena Jingle.mp3"
const RUTA_SHADER_CONTORNO: String = "res://System/Shaders/TOON_LINEANEGRA.gdshader"
## Contorno mínimo durante la escena (todos los personajes). No baja de
## 8 px: con menos, el resolve de MSAA en viewports de fondo transparente
## perfora la línea y asoman píxeles claros en la silueta (el ancho es en
## píxeles de pantalla: 8 ya se ve delgado con la cámara cercana).
const CONTORNO_MINIMO: float = 8.0

const RUTAS_CAMARAS: Array[String] = [
	"SubViewportFrente3D/CamaraFrente",
	"SubViewportMedio3D/CamaraMedio",
	"SubViewportFondo3D/CamaraFondoDOF",
]
## Encuadre de la escena (medido en runtime): el fov NO mueve estas cámaras
## (proyección frustum) y cambiar a ortogonal rompía el DOF/niebla/contornos
## (personajes emborronados en manchas negras). La cámara se coloca de una
## vez en el plano cercano (render idéntico al juego) y sigue a Perrena en
## su carrera: personajes grandes desde el primer frame.
const FOCO_Y: float = 2.2
const FOCO_Z: float = 23.05
## La corredora va a la derecha del centro mientras avanza a la izquierda.
## El máximo recorta para no enseñar la franja azul del cielo donde el fondo
## dibujado ya no cubre (borde derecho).
const SEGUIR_DX: float = -1.2
const SEGUIR_X_MIN: float = -7.5
const SEGUIR_X_MAX: float = 3.0
const SEGUIR_SUAVIZADO: float = 5.0

const SPAWN_X: float = 6.2
const PAUSA_X: float = 0.3
const FINAL_X: float = -5.0
const POS_Z: float = 0.05
const V_CORRER: float = 1.2
const V_CAMINAR: float = 0.9
const T_PAUSA: float = 0.9

## Smear suave al correr y transiciones suaves de animación
const DISTANCIA_FRENADO_SUAVE: float = 0.45
const ACEL_CAMINAR: float = 3.2
const DECEL_LLEGADA: float = 2.5
const XFADE_LOCOMOCION_CINE: float = 0.28
const SMEAR_CORRER_X: float = 0.12  ## Estiramiento longitudinal suave al correr (+12%)
const SMEAR_CORRER_Y: float = 0.07  ## Compresión vertical sutil para conservar volumen (-7%)
const SMEAR_CORRER_Z: float = 0.04  ## Compresión lateral sutil (-4%)
const SMEAR_LERP_SPEED: float = 8.0  ## Rapidez con la que el smear acompaña la velocidad

const SUELO_ISLA_Y: float = 0.2
## Los pies visuales van por encima del origen (medido: ~+0.28 Perrena);
## plantar por huesos, no por origen, evita que flote.
const PIES_EPS: float = 0.02
const PIES_SUAVIZADO: float = 14.0

## Eryn delante del escudo del segundo piso (EscudoDestruible4 en x=-7.38),
## no sobre la escalera (Ladder2 desemboca en x≈-8.3).
const ERYN_POS: Vector3 = Vector3(-7.62, 3.3, 0.05)
const ERYN_RAYO_Z: float = -0.38

## Sonido durante la escena: solo ambiente del bosque (3, con loop), sin
## música. Al terminar, la continuación (oleada 6) restaura la música de
## batalla por su cuenta.
const MUSICA_CINEMATICA: int = 3

const HUMO_NOMBRE: String = "HumoPisadasCine"

var terminada: bool = false

var _fase: int = Fase.CORRER
var _t: float = 0.0
var _nivel = null
var _al_terminar: Callable = Callable()
var _eryn: Player = null
var _perrena: Perrena = null
var _humo: GPUParticles3D = null
var _camaras: Array[Dictionary] = []
var _bloqueo_aplicado: bool = false
## La corredora ya existía y estaba activa (el jugador la controlaba).
var _era_activa: bool = false
## Eryn estaba aparcada (el jugador controlaba a Perrena): se muestra para
## la escena y al final se devuelve a su estado.
var _eryn_aparcada: bool = false
var _eryn_visible_prev: bool = true
var _eryn_input_prev: bool = true
var _runner_input_prev: bool = true
var _runner_phys_prev: bool = true
var _runner_proc_prev: bool = true
var _runner_shot_prev: bool = false
var _btn_swap: Button = null
var _btn_swap_prev: bool = false
var _aliadas_prev: bool = true
var _fx: float = 5.0
## Máscaras del compositor (sombra falsa y haces pintados para el encuadre
## base): como la cámara se mueve, se fijan al mundo (posición + escala
## desde el centro) para que no se descuadren. Margen para no abrir bordes.
const RUTAS_MASCARAS: Array[String] = [
	"Compositor3D/SombraFalsaRect",
	"Compositor3D/LuzHacesFijaRect",
]
const MARGEN_MASCARA: float = 1.15
const FACTOR_ANCHO_CAM: float = 0.3554
var _mascaras_base: Array = []
var _contornos_prev: Array = []
var _contornos_vistos := {}
## Sombra falsa circular (SombraPersonaje): se apaga en la escena y queda
## solo la sombra real de las luces. Por nodo (muere con la escena).
var _sombras_falsas_prev: Array = []
## FXAA + MSAA de los viewports de personajes: con cámara en movimiento el
## FXAA hace shimmer en los bordes alfa de PNGs (torre, arbustos, pasto) y
## el resolve de MSAA sobre fondo transparente perfora el contorno fino
## (píxeles claros en la silueta). En juego la cámara nunca se mueve y no
## se nota; en la escena se apagan y se restauran al salir.
const RUTAS_VIEWPORTS_FXAA: Array[String] = [
	"SubViewportMedio3D",
	"SubViewportFrente3D",
]
var _fxaa_prev: Array = []
## Fondo (SubViewportFondo3D): el nivel lo limita a 30 FPS (UPDATE_ONCE por
## timer) para ahorrar; con la cámara quieta no se nota, pero al viajar en
## la escena el fondo va desfasado del frente/medio (60 FPS) y sus objetos
## (torre, bustos, arbustos) parpadean. Durante la escena se fuerza a
## UPDATE_ALWAYS y el timer del nivel se detiene; se restaura al salir.
const RUTA_VIEWPORT_FONDO: String = "SubViewportFondo3D"
var _fondo_prev: Dictionary = {}
var _sombras_prev: Array = []
## CAPA001 (filtro de tono morado): Sprite3D fijo entre cámara y escena. Al
## mover la cámara se sale de campo (franja de cielo) o se pierde el tono;
## sigue a la cámara a distancia fija con el tamaño justo para cubrir el
## encuadre. A la torre muere con la escena.
const RUTA_CAPA_TONO: String = "CAPA001"
const CAPA_DIST: float = 5.0
const CAPA_MARGEN: float = 1.2
const CAPA_ANCHO_FACTOR: float = 0.3554
var _capa_nodo: Sprite3D = null
var _capa_pos_base := Vector3.ZERO
## Nieblas de guerra: solo visibles durante la cinemática (a la torre muere).
const RUTAS_NIEBLA: Array[String] = ["NieblaGuerra", "NieblaGuerra3"]
var _niebla_nodos: Array = []
## Cadáveres del goblin ballestero sobre la isla: decorado de la escena,
## solo visibles durante la cinemática (congelados en el último frame de
## su muerte por su propio script; aquí solo se muestran/ocultan como las
## nieblas). A la torre mueren con la escena.
const RUTAS_CADAVERES_GOBLIN: Array[String] = ["GoblinBallesteroCadaver", "GoblinBallesteroCadaver2"]
var _cadaveres_nodos: Array = []
var _capa_esc_base := Vector3.ONE
var _capa_lista: bool = false
## Perrena corre sin arco en la escena (se oculta al empezar).
var _arco_nodo: Node3D = null
var _arco_visible_prev: bool = true
var _skel_perrena: Skeleton3D = null
var _skel_eryn: Skeleton3D = null
var _suelo_perrena: float = SUELO_ISLA_Y
var _suelo_eryn: float = 3.3
var _eryn_lista: bool = false

# === ESTADO SMEAR SUAVE Y TRANSICIÓN ===
var _perrena_model: Node3D = null
var _perrena_model_scale_base: Vector3 = Vector3.ONE
var _perrena_model_pos_base: Vector3 = Vector3.ZERO
var _perrena_model_rot_base: Vector3 = Vector3.ZERO
var _smear_scale_current: Vector3 = Vector3.ONE
var _frenando: bool = false
var _v_actual: float = V_CORRER
var _v_caminar_actual: float = 0.0


## nivel: nodo del nivel (llamadas dinámicas: _set_movimiento_jugador_bloqueado).
## al_terminar: continuación (flujo a oleada 6).
func iniciar(nivel, al_terminar: Callable) -> void:
	_nivel = nivel
	_al_terminar = al_terminar
	_eryn = _buscar_protagonista()
	if _eryn == null:
		push_warning("[CinematicaOleada5] Sin protagonista; se continúa sin escena.")
		_abortar()
		return
	_eryn_aparcada = not _eryn.is_in_group("player")
	_eryn_visible_prev = _eryn.visible
	_eryn_input_prev = _eryn.is_processing_unhandled_input()
	_eryn.set_process_unhandled_input(false)
	nivel._set_movimiento_jugador_bloqueado(true)
	_bloqueo_aplicado = true
	AudioManager.play_music(MUSICA_CINEMATICA, true, 12.0)
	_aplicar_pausa_combate(true)
	_fijar_sombras(true)
	_ajustar_fxaa(true)
	_ajustar_fondo_fps(true)
	_ocultar_icono_refuerzo()
	# La canoa aliada no debe ser visible en la cinemática en que aparece Perrena
	if is_instance_valid(nivel) and "trayectoria_embarcaciones" in nivel and is_instance_valid(nivel.trayectoria_embarcaciones):
		if nivel.trayectoria_embarcaciones.has_method("ocultar_o_despawnear_canoa"):
			nivel.trayectoria_embarcaciones.ocultar_o_despawnear_canoa()
	for canoa in get_tree().get_nodes_in_group("canoas_aliadas"):
		if is_instance_valid(canoa):
			if canoa.has_method("ocultar_y_desactivar"):
				canoa.ocultar_y_desactivar()
			else:
				canoa.visible = false
			canoa.queue_free()
	_mostrar_niebla(true)
	_ajustar_contornos(true)
	_ajustar_sombra_falsa(true)
	_reunir_mascaras()
	_bloquear_boton_swap(true)
	_reunir_camaras()
	_preparar_capa_tono()
	_fx = _foco_clamp(SPAWN_X + SEGUIR_DX)
	# Sin travelling de entrada: la cámara parte directamente en el plano
	# cercano donde aparece Perrena (misma proyección, solo posición; la
	# base queda guardada para poder abortar/restaurar). Capa de tono y
	# máscaras se sincronizan ya con el nuevo encuadre (sin destello).
	if not _camaras.is_empty():
		_snap_camara_foco()
		_seguir_capa_tono()
		_seguir_mascaras()
	_empezar_carrera()


func _process(delta: float) -> void:
	if terminada:
		return
	_seguir_capa_tono()
	_seguir_mascaras()
	match _fase:
		Fase.CORRER:
			if not is_instance_valid(_perrena):
				_abortar()
				return
			# Transición suave a idle antes de PAUSA_X (sin parón seco ni corte de animación)
			if not _frenando and _perrena.global_position.x <= PAUSA_X + DISTANCIA_FRENADO_SUAVE:
				_frenando = true
				if _perrena.anim_tree:
					_perrena.anim_tree.set("parameters/Locomotion/transition_request", "idle")

			if _frenando:
				var t_freno: float = clampf((_perrena.global_position.x - PAUSA_X) / DISTANCIA_FRENADO_SUAVE, 0.0, 1.0)
				_v_actual = lerpf(0.20, V_CORRER, t_freno)
			else:
				_v_actual = V_CORRER

			_perrena.global_position.x -= _v_actual * delta
			_actualizar_smear_correr(delta)
			_seguir_corredora(delta)
			_suelo_perrena = _suelo_y(_perrena.global_position.x, _perrena.global_position.y, POS_Z, _suelo_perrena)
			_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, delta)
			_plantar_eryn(delta)
			if _perrena.global_position.x <= PAUSA_X:
				_perrena.global_position.x = PAUSA_X
				_v_actual = 0.0
				_actualizar_smear_correr(delta)
				_poner_pose(_perrena, "idle", false)
				_emitir_humo(false)
				_frenando = false
				_fase = Fase.PAUSA
				_t = 0.0
		Fase.PAUSA:
			_t += delta
			_actualizar_smear_correr(delta)
			_seguir_corredora(delta)
			_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, delta)
			_plantar_eryn(delta)
			if _t >= T_PAUSA:
				_poner_pose(_perrena, "walk_fwd", false)
				_sonar_jingle()
				_fase = Fase.CAMINAR
				_v_caminar_actual = 0.0
		Fase.CAMINAR:
			if not is_instance_valid(_perrena):
				_abortar()
				return
			# Aceleración suave al empezar a caminar (elimina la arrancada robótica)
			if _perrena.global_position.x > FINAL_X + 0.5:
				_v_caminar_actual = move_toward(_v_caminar_actual, V_CAMINAR, delta * ACEL_CAMINAR)
			else:
				# Desaceleración suave al aproximarse a la posición final
				var t_llegada: float = clampf((_perrena.global_position.x - FINAL_X) / 0.5, 0.0, 1.0)
				_v_caminar_actual = lerpf(0.15, V_CAMINAR, t_llegada)
				if _perrena.anim_tree and _perrena.global_position.x <= FINAL_X + 0.25:
					_perrena.anim_tree.set("parameters/Locomotion/transition_request", "idle")

			_perrena.global_position.x -= _v_caminar_actual * delta
			_seguir_corredora(delta)
			_suelo_perrena = _suelo_y(_perrena.global_position.x, _perrena.global_position.y, POS_Z, _suelo_perrena)
			_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, delta)
			_plantar_eryn(delta)
			if _perrena.global_position.x <= FINAL_X:
				_perrena.global_position.x = FINAL_X
				_v_caminar_actual = 0.0
				_reset_smear()
				_poner_pose(_perrena, "idle", false)
				_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, 1.0)
				_emitir_humo(false)
				_fase = Fase.DIALOGO
				_esperar_dialogo()
		Fase.DIALOGO:
			# En espera del diálogo (Siguiente/Saltar): lo cierra el jugador.
			_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, delta)
			_plantar_eryn(delta)
			pass
		Fase.FIN:
			pass


## Protagonista activa que no sea Perrena; si no hay (el jugador controla a
## Perrena), la Eryn aparcada que quede en escena. Se busca desde la raíz
## (current_scene no sirve: puede ser nula o no contener el nivel).
func _buscar_protagonista() -> Player:
	if not is_inside_tree() or get_tree() == null:
		return null
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and not (p is Perrena):
			return p as Player
	return _buscar_en_escena(false) as Player


## Corredora ÚNICA: reutiliza la Perrena que ya haya en escena o instancia
## una. Con el mismo tamaño que la controlable (copia la escala de Eryn,
## igual que hace el cambio de personaje). Deja registrado si ya estaba
## activa (la controlaba el jugador): una recién instanciada también entra
## al grupo "player" en su _ready, así que el grupo NO sirve para saberlo.
func _obtener_perrena() -> Perrena:
	_era_activa = false
	var hallada := _buscar_en_escena(true) as Perrena
	if hallada:
		_era_activa = hallada.is_in_group("player")
		return hallada
	var nueva := ESCENA_PERRENA.instantiate() as Perrena
	(_nivel as Node).add_child(nueva)
	return nueva


## Barrido del árbol completo buscando un personaje: Perrena (perrena=true)
## o protagonista no-Perrena (perrena=false).
func _buscar_en_escena(perrena: bool) -> Node:
	if not is_inside_tree() or get_tree() == null:
		return null
	var root: Node = get_tree().root
	if not root:
		return null
	var pila: Array[Node] = [root]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if perrena and n is Perrena:
			return n
		if not perrena and n is Player and not (n is Perrena):
			return n as Player
		pila.append_array(n.get_children())
	return null


func _reunir_camaras() -> void:
	_camaras.clear()
	for ruta in RUTAS_CAMARAS:
		var cam := (_nivel as Node).get_node_or_null(ruta) as Camera3D
		if cam:
			_camaras.append({"cam": cam, "pos": cam.position})


func _foco_pos() -> Vector3:
	return Vector3(_fx, FOCO_Y, FOCO_Z)


func _foco_clamp(x: float) -> float:
	return clampf(x, SEGUIR_X_MIN, SEGUIR_X_MAX)


## Seguimiento suave de la corredora (solo encuadre X; Y/Z fijos del plano).
func _seguir_corredora(delta: float) -> void:
	if not is_instance_valid(_perrena):
		return
	_fx = lerpf(_fx, _foco_clamp(_perrena.global_position.x + SEGUIR_DX), clampf(delta * SEGUIR_SUAVIZADO, 0.0, 1.0))
	for d in _camaras:
		var cam: Camera3D = d["cam"]
		if is_instance_valid(cam):
			cam.position = _foco_pos()


## CAPA001 sigue a la cámara a distancia fija con el tamaño justo para
## cubrir el encuadre (ancho visible a esa profundidad + margen): el tono
## morado se mantiene durante todo el seguimiento. Sin cámaras o sin capa,
## no-op.
func _preparar_capa_tono() -> void:
	_capa_nodo = (_nivel as Node).get_node_or_null(RUTA_CAPA_TONO) as Sprite3D
	_capa_lista = _capa_nodo != null and not _camaras.is_empty()
	if _capa_lista:
		_capa_pos_base = _capa_nodo.position
		_capa_esc_base = _capa_nodo.scale


func _seguir_capa_tono() -> void:
	if not _capa_lista:
		return
	var cam: Camera3D = _camaras[0]["cam"] as Camera3D
	if not is_instance_valid(cam) or not is_instance_valid(_capa_nodo):
		return
	_capa_nodo.global_position = Vector3(
		cam.global_position.x, cam.global_position.y, cam.global_position.z - CAPA_DIST
	)
	var tex := _capa_nodo.texture as Texture2D
	if tex == null or tex.get_width() <= 0:
		return
	var vp: Viewport = cam.get_viewport()
	var aspecto: float = 9.0 / 16.0
	if vp:
		var tam: Vector2 = vp.get_visible_rect().size
		if tam.x > 0.0:
			aspecto = tam.y / tam.x
	var ancho_necesario: float = CAPA_ANCHO_FACTOR * CAPA_DIST * CAPA_MARGEN
	var tam_tex := Vector2(tex.get_width(), tex.get_height()) * 0.01
	_capa_nodo.scale = Vector3(
		ancho_necesario / tam_tex.x, ancho_necesario * aspecto / tam_tex.y, _capa_esc_base.z
	)


func _restaurar_capa_tono() -> void:
	if not is_instance_valid(_capa_nodo):
		return
	_capa_nodo.position = _capa_pos_base
	_capa_nodo.scale = _capa_esc_base


## Coloca la cámara de golpe en el plano cercano del foco (arranque sin
## travelling): mismas posiciones que el seguimiento, proyección intacta.
func _snap_camara_foco() -> void:
	for d in _camaras:
		var cam: Camera3D = d["cam"]
		if is_instance_valid(cam):
			cam.position = _foco_pos()


## Devuelve la cámara a su encuadre base (sin travelling de vuelta).
func _restaurar_camara() -> void:
	for d in _camaras:
		var cam: Camera3D = d["cam"]
		if not is_instance_valid(cam):
			continue
		cam.position = d["pos"]


## Diálogo "Conversación nivel 5" al llegar al límite: mismo sistema del
## intro (el jugador lo cierra con Siguiente/Saltar) y al cerrarse se entra
## a la torre. Lee la configuración del nivel con valores iguales a los del
## diálogo inicial por defecto.
func _esperar_dialogo() -> void:
	var sfx = (_nivel as Node).get("sfx_habla_dialogo")
	await (_nivel as Node)._mostrar_dialogo_escena(
		ESCENA_DIALOGO,
		_cfg_dialogo("velocidad_texto_novela", 0.02),
		int(_cfg_dialogo("chars_por_habla_protagonista", 7)),
		_cfg_dialogo("intervalo_min_habla_protagonista", 0.18),
		sfx as AudioStream,
		_cfg_dialogo("pitch_habla_protagonista", 1.1),
		_cfg_dialogo("volumen_habla_protagonista_db", -16.0)
	)
	_entrar_torre()


func _cfg_dialogo(nombre: String, defecto: float) -> float:
	var v = (_nivel as Node).get(nombre)
	if v == null:
		return defecto
	return float(v)


## Al cerrar la conversación se entra a la torre (interludio): se registra
## el regreso para que al salir empiece la oleada 6 y se cambia de escena
## con cortinilla circular, igual que la puerta. La escena actual muere con
## el cambio, así que no hay nada que restaurar.
## entrada_torre_habilitada = false solo en tests (evita cambiar de escena).
var entrada_torre_habilitada: bool = true


func _entrar_torre() -> void:
	if is_instance_valid(_eryn):
		if has_node("/root/SceneManager"):
			get_node("/root/SceneManager").posicion_retorno_puerta = _eryn.global_position
		GameUI.regreso_flechas_explosivas = int(_eryn.get("flechas_explosivas")) if "flechas_explosivas" in _eryn else 0
		GameUI.regreso_flechas_multiples = int(_eryn.get("flechas_multiples")) if "flechas_multiples" in _eryn else 0
		GameUI.regreso_municion_activa = int(_eryn.get("municion_activa")) if "municion_activa" in _eryn else 0
	GameUI.regreso_desde_interior_oleada = 5
	GameUI.regreso_conversacion_nivel5 = true
	# Los materiales son recursos compartidos (sobreviven al cambio de
	# escena): restaurar contornos aquí o quedarían finos para siempre.
	_ajustar_contornos(false)
	_reset_smear()
	terminada = true
	if entrada_torre_habilitada and has_node("/root/SceneManager"):
		_reproducir_sonido_puerta()
		get_node("/root/SceneManager").cambiar_escena_cortinilla_circular("res://Levels/Player_Interior.tscn")
	queue_free()


## SFX de puerta al entrar a la torre (igual que la puerta del nivel).
func _reproducir_sonido_puerta() -> void:
	var stream: AudioStream = load("res://TEST_/abrir_puerta.wav")
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
	player.stream = stream
	player.volume_db = 2.0
	player.bus = "Master"
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()


func _aplicar_pausa_combate(pausar: bool) -> void:
	if _nivel == null:
		return
	var nodo := _nivel as Node
	if pausar:
		_aliadas_prev = bool(nodo.get("_aliadas_activas"))
		if _aliadas_prev and nodo.has_method("_set_aliadas_modo_pacifico"):
			nodo.call("_set_aliadas_modo_pacifico")
		var sp = nodo.get("wave_spawner")
		if sp and is_instance_valid(sp) and sp.has_method("detener_spawning"):
			sp.call("detener_spawning")
	elif _aliadas_prev and nodo.has_method("_set_aliadas_activas"):
		nodo.call("_set_aliadas_activas", true)


## Máscaras del compositor fijadas al mundo: con la cámara quieta coinciden
## con el encuadre base; al moverse se trasladan y escalan (desde el centro)
## para que lo pintado siga calzando. Con margen para no abrir bordes.
func _reunir_mascaras() -> void:
	_mascaras_base.clear()
	for ruta in RUTAS_MASCARAS:
		var rect := (_nivel as Node).get_node_or_null(ruta) as Control
		if rect == null:
			continue
		_mascaras_base.append({
			"rect": rect, "pivot": rect.pivot_offset, "escala": rect.scale,
			"pos": rect.position,
		})


func _seguir_mascaras() -> void:
	if _mascaras_base.is_empty() or _camaras.is_empty():
		return
	var cam: Camera3D = _camaras[0]["cam"] as Camera3D
	if not is_instance_valid(cam):
		return
	var base: Vector3 = _camaras[0]["pos"]
	var vp: Viewport = cam.get_viewport()
	var tam_vp := Vector2(1920, 1080)
	if vp:
		var vis: Vector2 = vp.get_visible_rect().size
		if vis.x > 0.0 and vis.y > 0.0:
			tam_vp = vis
	var s: float = FACTOR_ANCHO_CAM * base.z / maxf(FACTOR_ANCHO_CAM * cam.position.z, 0.001) * MARGEN_MASCARA
	var centro := tam_vp * 0.5
	# Píxeles por unidad de mundo iguales en ambos ejes (píxel cuadrado).
	var px_por_unidad: float = tam_vp.x / maxf(FACTOR_ANCHO_CAM * cam.position.z, 0.001)
	var despl := Vector2(
		-(cam.position.x - base.x) * px_por_unidad,
		-(cam.position.y - base.y) * px_por_unidad
	)
	for d in _mascaras_base:
		var rect := d["rect"] as Control
		if not is_instance_valid(rect):
			continue
		rect.pivot_offset = centro
		rect.scale = Vector2(s, s)
		rect.position = centro - tam_vp * s * 0.5 + despl


func _restaurar_mascaras() -> void:
	for d in _mascaras_base:
		var rect := d["rect"] as Control
		if not is_instance_valid(rect):
			continue
		rect.pivot_offset = d["pivot"]
		rect.scale = d["escala"]
		rect.position = d["pos"]
	_mascaras_base.clear()


## FXAA y MSAA apagados mientras la cámara se mueve (ver miembros).
func _ajustar_fxaa(apagar: bool) -> void:
	if _nivel == null:
		return
	if apagar:
		_fxaa_prev.clear()
		for ruta in RUTAS_VIEWPORTS_FXAA:
			var vp := (_nivel as Node).get_node_or_null(ruta) as SubViewport
			if vp == null:
				continue
			_fxaa_prev.append({
				"vp": vp, "modo": vp.screen_space_aa, "msaa": vp.msaa_3d,
			})
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.msaa_3d = Viewport.MSAA_DISABLED
	else:
		for d in _fxaa_prev:
			var vp := d["vp"] as SubViewport
			if is_instance_valid(vp):
				vp.screen_space_aa = int(d["modo"])
				vp.msaa_3d = int(d["msaa"])
		_fxaa_prev.clear()


## Fondo a máximos FPS durante la escena (ver miembro _fondo_prev): se
## apaga el limitador del nivel (timer UPDATE_ONCE a 30 FPS) y el viewport
## pasa a UPDATE_ALWAYS para que su cámara viaje síncrona con las demás.
## Sin nivel con limitador o sin viewport, no-op.
func _ajustar_fondo_fps(maximo: bool) -> void:
	if _nivel == null:
		return
	var vp := (_nivel as Node).get_node_or_null(RUTA_VIEWPORT_FONDO) as SubViewport
	if vp == null:
		return
	if maximo:
		if not _fondo_prev.is_empty():
			return
		var limitaba := bool((_nivel as Node).get("limitar_fps_subviewport_fondo_3d"))
		_fondo_prev = {"vp": vp, "modo": vp.render_target_update_mode, "limitaba": limitaba}
		if limitaba:
			(_nivel as Node).set("limitar_fps_subviewport_fondo_3d", false)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		if _fondo_prev.is_empty():
			return
		if is_instance_valid(vp):
			vp.render_target_update_mode = int(_fondo_prev["modo"])
		if bool(_fondo_prev["limitaba"]) and _nivel:
			(_nivel as Node).set("limitar_fps_subviewport_fondo_3d", true)
		_fondo_prev = {}


## Sombras direccionales fijas durante el travelling (ver miembros).
func _fijar_sombras(fijar: bool) -> void:
	if _nivel == null:
		return
	if fijar:
		_sombras_prev.clear()
		for l in (_nivel as Node).find_children("*", "DirectionalLight3D", true, false):
			var luz := l as DirectionalLight3D
			if luz == null:
				continue
			_sombras_prev.append({"luz": luz, "modo": luz.directional_shadow_mode})
			luz.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	else:
		for d in _sombras_prev:
			var luz := d["luz"] as DirectionalLight3D
			if is_instance_valid(luz):
				luz.directional_shadow_mode = d["modo"]
		_sombras_prev.clear()


## Sombra falsa circular apagada durante la escena (solo sombras reales).
## Sin limpiar el registro: se llama al empezar y al aparecer la corredora;
## lo ya guardado conserva su valor original para restaurar.
func _ajustar_sombra_falsa(ocultar: bool) -> void:
	if _nivel == null:
		return
	if ocultar:
		for s in (_nivel as Node).find_children("*", "SombraPersonaje", true, false):
			var blob := s as Node3D
			if blob == null or _sombra_registrada(blob):
				continue
			_sombras_falsas_prev.append({"nodo": blob, "visible": blob.visible})
			blob.visible = false
	else:
		for d in _sombras_falsas_prev:
			var blob := d["nodo"] as Node3D
			if is_instance_valid(blob):
				blob.visible = bool(d["visible"])
		_sombras_falsas_prev.clear()


func _sombra_registrada(blob: Node3D) -> bool:
	for d in _sombras_falsas_prev:
		if is_instance_valid(d["nodo"]) and d["nodo"] == blob:
			return true
	return false


## Perrena sin arco durante la escena (a la torre muere con ella).
func _ocultar_arco(ocultar: bool) -> void:
	if ocultar:
		_arco_nodo = _perrena.find_child("ARCO_ANIMADO", true, false) as Node3D
		if _arco_nodo == null:
			return
		_arco_visible_prev = _arco_nodo.visible
		_arco_nodo.visible = false
	elif is_instance_valid(_arco_nodo):
		_arco_nodo.visible = _arco_visible_prev
		_arco_nodo = null


## Nieblas de guerra visibles solo en la escena (a la torre mueren con ella).
func _mostrar_niebla(mostrar: bool) -> void:
	if _nivel == null:
		return
	if mostrar:
		_niebla_nodos.clear()
		for ruta in RUTAS_NIEBLA:
			var nodo := (_nivel as Node).get_node_or_null(ruta) as Node3D
			if nodo == null:
				continue
			_niebla_nodos.append({"nodo": nodo, "visible": nodo.visible})
			nodo.visible = true
	else:
		for d in _niebla_nodos:
			var nodo := d["nodo"] as Node3D
			if is_instance_valid(nodo):
				nodo.visible = bool(d["visible"])
		_niebla_nodos.clear()
	_mostrar_cadaver_goblin(mostrar)


## Cadáveres del goblin ballestero: decorado de la escena (congelados en el
## último frame de su muerte por su propio script). Visibles solo durante
## la cinemática; al abortar vuelven a ocultarse, y a la torre mueren con
## la escena (no hay que restaurarlos: el nivel los recoloca al recargar).
## Cada uno se muestra tal cual lo dejó el editor (posición y rotación).
func _mostrar_cadaver_goblin(mostrar: bool) -> void:
	if mostrar:
		if _cadaveres_nodos.is_empty():
			for ruta in RUTAS_CADAVERES_GOBLIN:
				var nodo := (_nivel as Node).get_node_or_null(ruta) as Node3D
				if nodo:
					_cadaveres_nodos.append(nodo)
		for nodo in _cadaveres_nodos:
			if is_instance_valid(nodo):
				nodo.visible = true
	else:
		for nodo in _cadaveres_nodos:
			if is_instance_valid(nodo):
				nodo.visible = false


## Icono de refuerzo (mensajera, oleada 5): no debe verse en la escena.
## Se oculta sin restaurar: la configuración de oleada 6 lo elimina.
func _ocultar_icono_refuerzo() -> void:
	for n in get_tree().get_nodes_in_group("icono_mensajera"):
		if is_instance_valid(n):
			n.set("visible", false)


## Jingle de Perrena al empezar a caminar: reproductor propio bajo el nivel
## (sobrevive al fin de la escena) que se autolibera al terminar.
func _sonar_jingle() -> void:
	if not ResourceLoader.exists(RUTA_JINGLE):
		return
	var stream := load(RUTA_JINGLE) as AudioStream
	if stream == null:
		return
	var rep := AudioStreamPlayer.new()
	rep.name = "JinglePerrenaCine"
	rep.stream = stream
	rep.bus = "Master"
	(_nivel as Node).add_child(rep)
	rep.finished.connect(rep.queue_free)
	rep.play()


## Contorno al mínimo en todos los personajes durante la escena (el plano
## cercano los agranda y la línea base se ve gruesa). Recorre el nivel
## buscando pases TOON_LINEANEGRA (en el propio material o en su next_pass)
## y restaura al terminar.
func _ajustar_contornos(minimo: bool) -> void:
	if _nivel == null:
		return
	if minimo:
		if not ResourceLoader.exists(RUTA_SHADER_CONTORNO):
			return
		var shader_contorno := load(RUTA_SHADER_CONTORNO) as Shader
		for m in (_nivel as Node).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi == null:
				continue
			_revisar_material(mi.material_override, shader_contorno)
			if mi.mesh:
				for i in range(mi.mesh.get_surface_count()):
					_revisar_material(mi.get_surface_override_material(i), shader_contorno)
					_revisar_material(mi.mesh.surface_get_material(i), shader_contorno)
		for d in _contornos_prev:
			var mat := d["mat"] as ShaderMaterial
			if is_instance_valid(mat):
				mat.set_shader_parameter("outline_width", CONTORNO_MINIMO)
	else:
		for d in _contornos_prev:
			var mat := d["mat"] as ShaderMaterial
			if is_instance_valid(mat):
				mat.set_shader_parameter("outline_width", float(d["ancho"]))
		_contornos_prev.clear()
		_contornos_vistos.clear()


func _revisar_material(base: Material, shader_contorno: Shader) -> void:
	var candidatos: Array[ShaderMaterial] = []
	if base is ShaderMaterial and (base as ShaderMaterial).shader == shader_contorno:
		candidatos.append(base as ShaderMaterial)
	if base is StandardMaterial3D:
		var siguiente := (base as StandardMaterial3D).next_pass as ShaderMaterial
		if siguiente and siguiente.shader == shader_contorno:
			candidatos.append(siguiente)
	for sm in candidatos:
		var id_mat: int = sm.get_instance_id()
		if _contornos_vistos.has(id_mat):
			continue
		_contornos_vistos[id_mat] = true
		_contornos_prev.append({"mat": sm, "ancho": sm.get_shader_parameter("outline_width")})


## El botón de cambio de personaje no debe usarse en plena escena (crearía
## otra Perrena y ocultaría a Eryn).
func _bloquear_boton_swap(bloquear: bool) -> void:
	if bloquear:
		_btn_swap = null
		var gui = (_nivel as Node).get("game_ui")
		if gui:
			_btn_swap = (gui as Node).find_child("BtnControlarPerrena", true, false) as Button
		if _btn_swap:
			_btn_swap_prev = _btn_swap.disabled
			_btn_swap.disabled = true
	elif is_instance_valid(_btn_swap):
		_btn_swap.disabled = _btn_swap_prev
		_btn_swap = null


## Al arrancar la escena (la vista ya está en el plano de la isla): se sitúa
## a Eryn fuera de campo y Perrena entra corriendo.
func _empezar_carrera() -> void:
	_poner_en_escena_eryn()
	_perrena = _obtener_perrena()
	if _perrena == null:
		_abortar()
		return
	_runner_input_prev = _perrena.is_processing_unhandled_input()
	_runner_phys_prev = _perrena.is_physics_processing()
	_runner_proc_prev = _perrena.is_processing()
	_runner_shot_prev = _perrena.is_shot_locked
	_perrena.set_process_unhandled_input(false)
	# Candado de disparo: la corredora conserva _process y ahí vive el
	# polling de clic. Sin esto dispara durante la escena (y aparcada en la
	# oleada 6). Solo se libera si era la controlable y se aborta.
	_perrena.is_shot_locked = true
	_perrena.visible = true
	if not _era_activa:
		Player.configurar_colision_aparcado(_perrena, false)
	# Mismo tamaño que la controlable (el cambio de personaje hace lo mismo).
	_perrena.scale = _eryn.scale
	_skel_perrena = _perrena.find_child("Skeleton3D", true, false) as Skeleton3D
	_suelo_perrena = _suelo_y(SPAWN_X, SUELO_ISLA_Y, POS_Z, SUELO_ISLA_Y)
	_perrena.global_position = Vector3(SPAWN_X, _suelo_perrena, POS_Z)
	_perrena.set_physics_process(false)
	_perrena_model = _obtener_modelo_perrena()
	if _perrena_model:
		_perrena_model_scale_base = _perrena_model.scale
		_perrena_model_pos_base = _perrena_model.position
		_perrena_model_rot_base = _perrena_model.rotation
	if _perrena.anim_tree and _perrena.anim_tree.tree_root and _perrena.anim_tree.tree_root.has_node("Locomotion"):
		var trans_loco = _perrena.anim_tree.tree_root.get_node("Locomotion") as AnimationNodeTransition
		if trans_loco:
			trans_loco.xfade_time = XFADE_LOCOMOCION_CINE
	_v_actual = V_CORRER
	_v_caminar_actual = 0.0
	_frenando = false
	AudioManager.reset_bow_hold()
	_construir_humo()
	# La corredora aparece ahora: su contorno y sombra también se ajustan.
	_ajustar_contornos(true)
	_ajustar_sombra_falsa(true)
	# Sin arco en la escena.
	_ocultar_arco(true)
	_poner_pose(_perrena, "run_fwd", false)
	_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, 1.0)
	_emitir_humo(true)
	_fase = Fase.CORRER


## Protagonista al segundo piso, delante del escudo (fuera de campo en el plano).
func _poner_en_escena_eryn() -> void:
	if not is_instance_valid(_eryn):
		return
	_eryn.visible = true
	_skel_eryn = _eryn.find_child("Skeleton3D", true, false) as Skeleton3D
	_suelo_eryn = _suelo_y(ERYN_POS.x, ERYN_POS.y, ERYN_RAYO_Z, ERYN_POS.y)
	_eryn.global_position = Vector3(ERYN_POS.x, _suelo_eryn, ERYN_POS.z)
	_poner_pose(_eryn, "idle", true)
	_plantar_pies(_eryn, _skel_eryn, _suelo_eryn, 1.0)
	_eryn_lista = true
	AudioManager.reset_bow_hold()


## Pose dirigida sin input: estado suelo, sin apuntado, locomoción del árbol
## y orientación fijada con snap. Cancela cualquier disparo en curso (si
## venía tensando al cerrar la oleada) y pinza las barras de carga.
func _poner_pose(personaje: Player, locomocion: String, mirar_derecha: bool) -> void:
	# La cadena de disparo vive en _process (polling directo): sin esto un
	# clic a mitad de escena dispara aunque la física esté apagada.
	personaje._cancel_current_shot()
	personaje.current_move_state = Player.MoveState.GROUND
	personaje.current_aim_state = Player.AimState.NONE
	personaje.velocity = Vector3.ZERO
	personaje.reset_torso_bone()
	personaje.set_motion_anim("ground")
	if personaje.anim_tree:
		personaje.anim_tree.set("parameters/Locomotion/transition_request", locomocion)
	# Acceso directo (como en los tests): el giro lo gobierna la escena.
	personaje._mirando_derecha = mirar_derecha
	personaje._apply_character_rotation(0.1, true)
	if personaje.charge_bar:
		personaje.charge_bar.visible = false
	if personaje.overcharge_bar:
		personaje.overcharge_bar.visible = false


## Humo de pisadas como el de las defensoras ballesteras (misma textura y
## presencia, calibrado para escala 0.3): malla espejada porque corre a la
## izquierda y soplo hacia atrás (+X).
func _construir_humo() -> void:
	_liberar_humo()
	_humo = GPUParticles3D.new()
	_humo.name = HUMO_NOMBRE
	_humo.emitting = false
	_humo.amount = 22
	_humo.lifetime = 0.7
	_humo.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 3, 4))
	_perrena.add_child(_humo)
	_humo.position = Vector3(0.15, 0.05, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TEXTURA_HUMO_PISADAS
	mat.particles_anim_h_frames = 9
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2

	var malla := QuadMesh.new()
	malla.material = mat
	malla.size = Vector2(-0.85, 0.85)
	_humo.draw_pass_1 = malla

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(1.0, 0.45, 0.0).normalized()
	pm.spread = 55.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.95
	pm.gravity = Vector3(0.0, 0.35, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.12, 0.02, 0.12)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.72, 0.72, 0.85))
	grad.set_color(1, Color(0.72, 0.72, 0.72, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex

	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.3), 0.0, 1.5)
	curva.add_point(Vector2(0.35, 1.0), 0.2, -0.3)
	curva.add_point(Vector2(0.7, 0.7), -0.5, -0.8)
	curva.add_point(Vector2(1.0, 0.0), -1.2, 0.0)
	var curva_tex := CurveTexture.new()
	curva_tex.curve = curva
	pm.scale_curve = curva_tex

	_humo.process_material = pm


func _emitir_humo(emitir: bool) -> void:
	if is_instance_valid(_humo):
		_humo.emitting = emitir


func _liberar_humo() -> void:
	if is_instance_valid(_humo):
		_humo.emitting = false
		_humo.queue_free()
	_humo = null


## Altura del suelo por rayo corto bajo los pies (cuerpos estáticos); si no
## hay impacto, el valor previo. El rayo nace sobre los pies para no tocar
## el arco/flecha y excluye a los personajes.
## Máscara 33: layer 1 (suelos) + layer 6 (DebrisCatcher de las plataformas
## oneway, siempre sólido: la plataforma apaga su layer 1 cuando el jugador
## está debajo y el rayo del suelo fallaría, dejando a Eryn flotando).
## Ancla: la corredora si ya existe; si no, la propia Eryn (su posición se
## calcula antes de instanciar a Perrena y el mundo es el mismo).
const MASCARA_RAYO_SUELO: int = 33


func _suelo_y(x: float, ref_y: float, z_rayo: float, defecto: float) -> float:
	var ancla: Node3D = _perrena if is_instance_valid(_perrena) else _eryn
	if ancla == null or not ancla.is_inside_tree():
		return defecto
	var espacio := ancla.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(x, ref_y + 0.6, z_rayo), Vector3(x, ref_y - 2.5, z_rayo), MASCARA_RAYO_SUELO
	)
	var excluir: Array[RID] = []
	if is_instance_valid(_perrena) and _perrena is CollisionObject3D:
		excluir.append((_perrena as CollisionObject3D).get_rid())
	if is_instance_valid(_eryn) and _eryn is CollisionObject3D:
		excluir.append((_eryn as CollisionObject3D).get_rid())
	consulta.exclude = excluir
	var impacto := espacio.intersect_ray(consulta)
	if impacto.is_empty():
		return defecto
	var cuerpo: Object = impacto.get("collider")
	if not (cuerpo is StaticBody3D or cuerpo is AnimatableBody3D):
		return defecto
	return (impacto["position"] as Vector3).y


## Pega los pies al suelo: desplaza el origen para que el pie más bajo toque
## suelo + EPS (el pie de apoyo en cada paso). Con delta 1.0 coloca de golpe.
func _plantar_pies(personaje: Player, skel: Skeleton3D, suelo_y: float, delta: float) -> void:
	if not is_instance_valid(personaje) or skel == null or not is_instance_valid(skel):
		return
	var il: int = skel.find_bone("mixamorig_LeftFoot")
	var ir: int = skel.find_bone("mixamorig_RightFoot")
	if il == -1 or ir == -1:
		return
	var pl: Vector3 = skel.global_transform * skel.get_bone_global_pose(il).origin
	var pr: Vector3 = skel.global_transform * skel.get_bone_global_pose(ir).origin
	var pies: float = minf(pl.y, pr.y)
	var base: Transform3D = personaje.global_transform
	base.origin.y = lerpf(base.origin.y, base.origin.y + (suelo_y + PIES_EPS - pies), clampf(delta * PIES_SUAVIZADO, 0.0, 1.0))
	personaje.global_transform = base


func _plantar_eryn(delta: float) -> void:
	if not _eryn_lista:
		return
	_plantar_pies(_eryn, _skel_eryn, _suelo_eryn, delta)


## Perrena queda visible en el límite, sin colisión, fuera del grupo player
## y sin física: no estorba la oleada 6 (no la fijan plataformas, enemigos
## ni HUD, que tiran del grupo).
func _estacionar_perrena() -> void:
	if not is_instance_valid(_perrena):
		return
	_perrena.remove_from_group("player")
	Player.configurar_colision_aparcado(_perrena, true)
	_perrena.set_physics_process(false)


## Si Eryn estaba aparcada (se mostró para la escena), vuelve a su estado.
func _restaurar_eryn_aparcada() -> void:
	if not _eryn_aparcada or not is_instance_valid(_eryn):
		return
	_eryn.visible = _eryn_visible_prev
	_eryn.set_process_unhandled_input(false)
	_eryn.set_physics_process(false)
	_eryn.set_process(false)
	if _eryn.is_in_group("player"):
		_eryn.remove_from_group("player")


## Ruta de fallo (faltan referencias a mitad de escena): se restaura lo
## posible y se sigue el flujo normal a oleada 6 sin pasar por la torre.
func _abortar() -> void:
	push_warning("[CinematicaOleada5] Secuencia abortada; se continúa a oleada 6.")
	_restaurar_camara()
	_restaurar_capa_tono()
	_ocultar_arco(false)
	_liberar_humo()
	if _era_activa and is_instance_valid(_perrena):
		_perrena.set_physics_process(_runner_phys_prev)
		_perrena.set_process(_runner_proc_prev)
		_perrena.set_process_unhandled_input(_runner_input_prev)
		_perrena.is_shot_locked = _runner_shot_prev
	elif is_instance_valid(_perrena):
		_estacionar_perrena()
	if is_instance_valid(_eryn) and not _eryn_aparcada:
		_eryn.set_process_unhandled_input(_eryn_input_prev)
	_restaurar_eryn_aparcada()
	if _bloqueo_aplicado and _nivel:
		(_nivel as Node).call("_set_movimiento_jugador_bloqueado", false)
		_bloqueo_aplicado = false
	_aplicar_pausa_combate(false)
	_ajustar_contornos(false)
	_mostrar_niebla(false)
	_ajustar_sombra_falsa(false)
	_fijar_sombras(false)
	_ajustar_fxaa(false)
	_ajustar_fondo_fps(false)
	_restaurar_mascaras()
	_bloquear_boton_swap(false)
	_reset_smear()
	terminada = true
	if _al_terminar.is_valid():
		_al_terminar.call()
	queue_free()


func _exit_tree() -> void:
	_reset_smear()


# ==============================================================================
# SMEAR SUAVE AL CORRER Y CONTROL VISUAL
# ==============================================================================

func _obtener_modelo_perrena() -> Node3D:
	if not is_instance_valid(_perrena):
		return null
	var model: Node3D = _perrena.find_child("PerrenaModel", false, false) as Node3D
	if not model and "visual_model" in _perrena and _perrena.visual_model:
		model = _perrena.visual_model as Node3D
	if not model:
		for child in _perrena.get_children():
			if child is Node3D and child.name.ends_with("Model"):
				model = child as Node3D
				break
	return model


func _actualizar_smear_correr(delta: float) -> void:
	if not _perrena_model or not is_instance_valid(_perrena_model):
		_perrena_model = _obtener_modelo_perrena()
	if not _perrena_model or not is_instance_valid(_perrena_model):
		return

	var target_factor: Vector3 = Vector3.ONE
	if _fase == Fase.CORRER and _v_actual > 0.01:
		var ratio_vel: float = clampf(_v_actual / V_CORRER, 0.0, 1.0)
		target_factor = Vector3(
			1.0 + SMEAR_CORRER_X * ratio_vel,
			1.0 - SMEAR_CORRER_Y * ratio_vel,
			1.0 - SMEAR_CORRER_Z * ratio_vel
		)

	_smear_scale_current = _smear_scale_current.lerp(target_factor, clampf(delta * SMEAR_LERP_SPEED, 0.0, 1.0))
	if _smear_scale_current.distance_to(target_factor) < 0.003:
		_smear_scale_current = target_factor
	_perrena_model.scale = _perrena_model_scale_base * _smear_scale_current


func _reset_smear() -> void:
	_smear_scale_current = Vector3.ONE
	if _perrena_model and is_instance_valid(_perrena_model):
		_perrena_model.scale = _perrena_model_scale_base
		_perrena_model.position = _perrena_model_pos_base
		_perrena_model.rotation = _perrena_model_rot_base
