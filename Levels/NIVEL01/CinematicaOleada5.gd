class_name CinematicaOleada5
extends Node

## Cinemática al completar la oleada 5 de NIVEL01 (isla "Paso de Medea").
## Sustituye la cortinilla negra de continuar:
## 1. Zoom de cámara hacia la isla enemiga (derecha).
## 2. Perrena aparece corriendo desde la derecha (humo de pisadas estilo
##    defensoras ballesteras) y se detiene a mitad de isla.
## 3. Sigue caminando (animación Caminar) hasta el límite de la isla, el punto
##    donde se detiene el imp embajador (x = FINAL_X).
## 4. La protagonista queda situada en el segundo piso, detrás del escudo.
## Sin input: el jugador y el botón de cambio de personaje se bloquean al
## empezar y se liberan al terminar, cuando se invoca la continuación (flujo
## normal a oleada 6).
## Perrena ÚNICA: si ya existe una en escena (p. ej. el jugador la controla)
## se reutiliza en vez de instanciar otra; al terminar se le devuelve el
## control intacto. Con el mismo tamaño que la controlable (copia su escala).
## A prueba de fallos: cualquier referencia ausente aborta a la continuación
## sin colgar el juego. Sin temporizadores: todo avanza en _process (pausa
## segura) con posiciones y fov relativos a los valores base (sin absolutos).

enum Fase { ZOOM, CORRER, PAUSA, CAMINAR, DIALOGO, RESTAURAR, FIN }

const ESCENA_PERRENA: PackedScene = preload("res://Entities/Jugador_Perrena/Perrena.tscn")
const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
## Escena de diálogo al llegar al límite (estilo intro, con el png de Eryn).
const ESCENA_DIALOGO: PackedScene = preload("res://UI/DialogoConversacionNivel5.tscn")
const RUTA_JINGLE: String = "res://TEST_/Perrena Jingle.mp3"
const RUTA_SHADER_CONTORNO: String = "res://System/Shaders/TOON_LINEANEGRA.gdshader"
## Contorno mínimo durante la escena (todos los personajes).
const CONTORNO_MINIMO: float = 3.0

const RUTAS_CAMARAS: Array[String] = [
	"SubViewportFrente3D/CamaraFrente",
	"SubViewportMedio3D/CamaraMedio",
	"SubViewportFondo3D/CamaraFondoDOF",
]
## Encuadre de la escena (medido en runtime): el fov NO mueve estas cámaras
## (proyección frustum) y cambiar a ortogonal rompía el DOF/niebla/contornos
## (personajes emborronados en manchas negras). El zoom es un travelling con
## seguimiento y la misma proyección (render idéntico al juego): la cámara se
## acerca para ver grandes a los personajes y sigue a Perrena en su carrera.
const FOCO_Y: float = 2.2
const FOCO_Z: float = 23.05
## La corredora va a la derecha del centro mientras avanza a la izquierda.
## El máximo recorta para no enseñar la franja azul del cielo donde el fondo
## dibujado ya no cubre (borde derecho).
const SEGUIR_DX: float = -1.2
const SEGUIR_X_MIN: float = -7.5
const SEGUIR_X_MAX: float = 3.0
const SEGUIR_SUAVIZADO: float = 5.0
const T_ZOOM: float = 1.4
const T_RESTAURAR: float = 1.0

const SPAWN_X: float = 6.2
const PAUSA_X: float = 0.3
const FINAL_X: float = -5.0
const POS_Z: float = 0.05
const V_CORRER: float = 1.2
const V_CAMINAR: float = 0.9
const T_PAUSA: float = 0.9
const SUELO_ISLA_Y: float = 0.2
## Los pies visuales van por encima del origen (medido: ~+0.28 Perrena);
## plantar por huesos, no por origen, evita que flote.
const PIES_EPS: float = 0.02
const PIES_SUAVIZADO: float = 14.0

const ERYN_POS: Vector3 = Vector3(-8.35, 3.3, 0.05)
const ERYN_RAYO_Z: float = -0.38

## Sonido durante la escena: solo ambiente del bosque (3, con loop), sin
## música. Al terminar, la continuación (oleada 6) restaura la música de
## batalla por su cuenta.
const MUSICA_CINEMATICA: int = 3

const HUMO_NOMBRE: String = "HumoPisadasCine"

var terminada: bool = false

var _fase: int = Fase.ZOOM
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
## FXAA + bordes alfa de PNGs (torre, arbustos, pasto) + cámara en
## movimiento = shimmer. En juego la cámara nunca se mueve y no se nota;
## en la escena se apaga y se restaura al salir.
const RUTAS_VIEWPORTS_FXAA: Array[String] = [
	"SubViewportMedio3D",
	"SubViewportFrente3D",
]
var _fxaa_prev: Array = []
## Sombras direccionales (PSSM): sus splits siguen a la cámara y al hacer
## travelling tiemblan sobre torre/arbustos/pasto. En ortogonal quedan fijas.
var _sombras_prev: Array = []
## CAPA001 (filtro de tono morado): desactivada durante la escena.
const RUTA_CAPA_TONO: String = "CAPA001"
var _capa_nodo: Sprite3D = null
var _capa_visible_prev: bool = true
## Perrena corre sin arco en la escena (se oculta al empezar).
var _arco_nodo: Node3D = null
var _arco_visible_prev: bool = true
var _skel_perrena: Skeleton3D = null
var _skel_eryn: Skeleton3D = null
var _suelo_perrena: float = SUELO_ISLA_Y
var _suelo_eryn: float = 3.3
var _eryn_lista: bool = false


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
	_ocultar_icono_refuerzo()
	_ajustar_contornos(true)
	_ajustar_sombra_falsa(true)
	_reunir_mascaras()
	_bloquear_boton_swap(true)
	_reunir_camaras()
	_ocultar_capa_tono(true)
	_fx = _foco_clamp(SPAWN_X + SEGUIR_DX)
	if _camaras.is_empty():
		_empezar_carrera()
	else:
		_fase = Fase.ZOOM
		_t = 0.0


func _process(delta: float) -> void:
	if terminada:
		return
	_seguir_mascaras()
	match _fase:
		Fase.ZOOM:
			_t += delta
			_aplicar_camara(_suavizado(clampf(_t / T_ZOOM, 0.0, 1.0)))
			if _t >= T_ZOOM:
				_empezar_carrera()
		Fase.CORRER:
			if not is_instance_valid(_perrena):
				_abortar()
				return
			_perrena.global_position.x -= V_CORRER * delta
			_seguir_corredora(delta)
			_suelo_perrena = _suelo_y(_perrena.global_position.x, _perrena.global_position.y, POS_Z, _suelo_perrena)
			_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, delta)
			_plantar_eryn(delta)
			if _perrena.global_position.x <= PAUSA_X:
				_perrena.global_position.x = PAUSA_X
				_poner_pose(_perrena, "idle", false)
				_emitir_humo(false)
				_fase = Fase.PAUSA
				_t = 0.0
		Fase.PAUSA:
			_t += delta
			_seguir_corredora(delta)
			_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, delta)
			_plantar_eryn(delta)
			if _t >= T_PAUSA:
				_poner_pose(_perrena, "walk_fwd", false)
				_sonar_jingle()
				_fase = Fase.CAMINAR
		Fase.CAMINAR:
			if not is_instance_valid(_perrena):
				_abortar()
				return
			_perrena.global_position.x -= V_CAMINAR * delta
			_seguir_corredora(delta)
			_suelo_perrena = _suelo_y(_perrena.global_position.x, _perrena.global_position.y, POS_Z, _suelo_perrena)
			_plantar_pies(_perrena, _skel_perrena, _suelo_perrena, delta)
			_plantar_eryn(delta)
			if _perrena.global_position.x <= FINAL_X:
				_perrena.global_position.x = FINAL_X
				_poner_pose(_perrena, "idle", false)
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
	var pila: Array[Node] = [get_tree().root]
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


## Seguimiento suave de la corredora (solo encuadre X; Y/Z fijos del zoom).
func _seguir_corredora(delta: float) -> void:
	if not is_instance_valid(_perrena):
		return
	_fx = lerpf(_fx, _foco_clamp(_perrena.global_position.x + SEGUIR_DX), clampf(delta * SEGUIR_SUAVIZADO, 0.0, 1.0))
	for d in _camaras:
		var cam: Camera3D = d["cam"]
		if is_instance_valid(cam):
			cam.position = _foco_pos()


## CAPA001 desactivada durante la escena (a la torre muere con ella).
func _ocultar_capa_tono(ocultar: bool) -> void:
	if ocultar:
		_capa_nodo = (_nivel as Node).get_node_or_null(RUTA_CAPA_TONO) as Sprite3D
		if _capa_nodo == null:
			return
		_capa_visible_prev = _capa_nodo.visible
		_capa_nodo.visible = false
	elif is_instance_valid(_capa_nodo):
		_capa_nodo.visible = _capa_visible_prev
		_capa_nodo = null


## Origen del travelling de vuelta (posición de seguimiento al llegar).
func _fijar_origen_rest() -> void:
	for d in _camaras:
		var cam: Camera3D = d["cam"]
		if is_instance_valid(cam):
			d["rest"] = cam.position


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
	terminada = true
	if entrada_torre_habilitada and has_node("/root/SceneManager"):
		get_node("/root/SceneManager").cambiar_escena_cortinilla_circular("res://Levels/Player_Interior.tscn")
	queue_free()


func _aplicar_camara(k: float) -> void:
	for d in _camaras:
		var cam: Camera3D = d["cam"]
		if not is_instance_valid(cam):
			continue
		var base: Vector3 = d["pos"]
		cam.position = base.lerp(_foco_pos(), k)


func _restaurar_camara(k: float) -> void:
	for d in _camaras:
		var cam: Camera3D = d["cam"]
		if not is_instance_valid(cam):
			continue
		var base: Vector3 = d["pos"]
		var origen: Vector3 = d.get("rest", cam.position)
		cam.position = origen.lerp(base, k)


func _suavizado(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Durante la escena no aparecen enemigos ni atacan las defensoras: se
## detiene el spawner y las aliadas quedan visibles pero quietas (modo
## pacífico). Se respeta el ajuste previo (modo debug las deja apagadas).
func _aplicar_pausa_combate(pausar: bool) -> void:
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


## FXAA apagado durante el travelling (ver miembros).
func _ajustar_fxaa(apagar: bool) -> void:
	if apagar:
		_fxaa_prev.clear()
		for ruta in RUTAS_VIEWPORTS_FXAA:
			var vp := (_nivel as Node).get_node_or_null(ruta) as SubViewport
			if vp == null:
				continue
			_fxaa_prev.append({"vp": vp, "modo": vp.screen_space_aa})
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	else:
		for d in _fxaa_prev:
			var vp := d["vp"] as SubViewport
			if is_instance_valid(vp):
				vp.screen_space_aa = int(d["modo"])
		_fxaa_prev.clear()


## Sombras direccionales fijas durante el travelling (ver miembros).
func _fijar_sombras(fijar: bool) -> void:
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


## Contorno al mínimo en todos los personajes durante la escena (el zoom los
## agranda y la línea base se ve gruesa). Recorre el nivel buscando pases
## TOON_LINEANEGRA (en el propio material o en su next_pass) y restaura al
## terminar.
func _ajustar_contornos(minimo: bool) -> void:
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


## Al terminar el zoom (la vista ya está en la isla): se sitúa a Eryn fuera
## de campo y Perrena entra corriendo.
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


## Protagonista al segundo piso, detrás del escudo (fuera de campo en el zoom).
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
func _suelo_y(x: float, ref_y: float, z_rayo: float, defecto: float) -> float:
	if _perrena == null or not is_inside_tree():
		return defecto
	var espacio := _perrena.get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		Vector3(x, ref_y + 0.6, z_rayo), Vector3(x, ref_y - 2.5, z_rayo), 1
	)
	var excluir: Array[RID] = [_perrena.get_rid()]
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
	_fijar_origen_rest()
	_restaurar_camara(1.0)
	_ocultar_capa_tono(false)
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
	_ajustar_sombra_falsa(false)
	_fijar_sombras(false)
	_ajustar_fxaa(false)
	_restaurar_mascaras()
	_bloquear_boton_swap(false)
	terminada = true
	if _al_terminar.is_valid():
		_al_terminar.call()
	queue_free()
